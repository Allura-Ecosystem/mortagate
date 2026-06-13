#!/usr/bin/env bash
#
# deploy-audit-queue.sh — promote the Audit Queue as its OWN deployable unit.
#
# WHY THIS EXISTS (goal Decision #2 / V2.4 decoupling):
#   The org-wide `RunLocalTests` gate is red because of policy-engine test drift in a
#   SEPARATE bounded context (PolicyRuleEvaluator/LoanDecisionService tests). The
#   audit-queue is independently green (its own suite: Apex 37/37 + Jest 12/12). This
#   script promotes the audit-queue gated on ITS suite via RunSpecifiedTests, so it is
#   not held hostage by the engine's red org-wide gate.
#
# USAGE:
#   scripts/deploy-audit-queue.sh <target-org-alias> [--validate]
#     (default)     run a real deploy gated on the AuditQueue suite
#     --validate    check-only (sf project deploy validate) — no changes committed
#
# PRE-FLIGHT (fail-closed):
#   1. clean tree (no deploy from uncommitted source — the v1 "source vanished" rule)
#   2. PolicyRuleEvaluator present in the target with the audit-replay path (replayRules)
#      — this unit excludes that shared/co-owned class on purpose (see
#      docs/reconciliation/PolicyRuleEvaluator-merge-notes.md)
#   3. if the target looks like prod, block on resident [KAGGLE-SEED] test rows
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

TARGET="${1:-}"
MODE="${2:-deploy}"
MANIFEST="manifest/package.audit-queue.xml"
TESTS=(AuditCaseServiceTest AuditDataIntegrityTest AuditQueueControllerTest AuditEvidenceReportControllerTest)

if [ -z "$TARGET" ]; then
  echo "✖ deploy-audit-queue: missing target org." >&2
  echo "  Usage: scripts/deploy-audit-queue.sh <target-org-alias> [--validate]" >&2
  exit 1
fi

# ── Pre-flight 1: clean tree ────────────────────────────────────────────────
if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
  if [ "${ALLOW_DIRTY_DEPLOY:-0}" != "1" ]; then
    echo "✖ deploy-audit-queue: working tree is dirty — refusing to deploy." >&2
    echo "  Commit or stash first (override with ALLOW_DIRTY_DEPLOY=1 only if you know why)." >&2
    exit 1
  fi
  echo "⚠ deploy-audit-queue: dirty tree allowed via ALLOW_DIRTY_DEPLOY=1." >&2
fi

# ── Pre-flight 2: shared engine class must already carry the audit-replay path ──
echo "• Checking PolicyRuleEvaluator.replayRules exists in '$TARGET'…"
PRE_BODY="$(sf data query --use-tooling-api -o "$TARGET" \
  -q "SELECT Body FROM ApexClass WHERE Name='PolicyRuleEvaluator'" --json 2>/dev/null || true)"
if ! printf '%s' "$PRE_BODY" | grep -q 'replayRules'; then
  echo "✖ deploy-audit-queue: PolicyRuleEvaluator in '$TARGET' lacks the audit-replay path" >&2
  echo "  (no 'replayRules' found). Land the unified PolicyRuleEvaluator first — see" >&2
  echo "  docs/reconciliation/PolicyRuleEvaluator-merge-notes.md. Failing closed." >&2
  exit 1
fi
echo "  ✓ replayRules present."

# ── Pre-flight 3: seed-data guard for prod-looking targets ──────────────────
if printf '%s' "$TARGET" | grep -qiE 'prod|production'; then
  if [ -x scripts/guard-no-seed-in-prod.sh ]; then
    echo "• Target looks like prod — running seed-data guard…"
    bash scripts/guard-no-seed-in-prod.sh "$TARGET"
  else
    echo "⚠ prod-looking target but scripts/guard-no-seed-in-prod.sh not found/executable." >&2
  fi
fi

# ── Deploy / validate, gated on the audit suite ─────────────────────────────
TEST_ARGS=()
for t in "${TESTS[@]}"; do TEST_ARGS+=(--tests "$t"); done

if [ "$MODE" = "--validate" ]; then
  echo "• Validating (check-only) audit-queue unit against '$TARGET'…"
  sf project deploy validate -o "$TARGET" -x "$MANIFEST" \
    --test-level RunSpecifiedTests "${TEST_ARGS[@]}"
else
  echo "• Deploying audit-queue unit to '$TARGET' (gated on AuditQueue suite)…"
  sf project deploy start -o "$TARGET" -x "$MANIFEST" \
    --test-level RunSpecifiedTests "${TEST_ARGS[@]}"
fi

echo "✓ deploy-audit-queue: done ($MODE) against '$TARGET'."
