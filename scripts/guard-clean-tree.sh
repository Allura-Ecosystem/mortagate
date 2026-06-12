#!/usr/bin/env bash
#
# guard-clean-tree.sh — V0.3 deploy guard for the Mortgage Audit project.
#
# WHY THIS EXISTS:
#   In v1 the audit-queue source "vanished" because it lived only in ignored
#   scratch and was deployed straight to the org with no committed rollback
#   point. This guard enforces the v2 guardrail: NEVER deploy from a dirty
#   tree. A deploy must be reproducible from a committed state, so that the
#   org is never the only durable copy of what is running.
#
# USAGE:
#   bash scripts/guard-clean-tree.sh        # exits 0 if clean, 1 if dirty
#   Wired into:  npm run deploy             (gates `sf project deploy start`)
#                .husky/pre-push            (blocks pushing a dirty tree)
#
# EMERGENCY OVERRIDE (use sparingly, documented in the deploy checklist):
#   ALLOW_DIRTY_DEPLOY=1 npm run deploy
#
set -euo pipefail

# 1. Must be inside a git work tree — a deploy with no version control at all
#    is exactly the v1 failure mode.
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "✖ guard-clean-tree: not inside a git repository." >&2
  echo "  The audit-queue source must be version-controlled before any deploy" >&2
  echo "  (root cause of the v1 'source vanished' incident). Aborting." >&2
  exit 1
fi

# 2. A rollback tag should exist so a bad deploy can be reverted.
if ! git tag --list 'audit-queue-v1' | grep -q 'audit-queue-v1'; then
  echo "⚠ guard-clean-tree: rollback tag 'audit-queue-v1' not found." >&2
  echo "  Create the rollback point before deploying:  git tag -a audit-queue-v1" >&2
  # Warn-only — do not hard-block on the tag, but make it loud.
fi

# 3. The working tree must be clean (no staged, unstaged, or untracked changes).
DIRTY="$(git status --porcelain)"
if [ -n "$DIRTY" ]; then
  if [ "${ALLOW_DIRTY_DEPLOY:-0}" = "1" ]; then
    echo "⚠ guard-clean-tree: tree is DIRTY but ALLOW_DIRTY_DEPLOY=1 — proceeding under override." >&2
    echo "$DIRTY" | sed 's/^/    /' >&2
    exit 0
  fi
  echo "✖ guard-clean-tree: working tree is DIRTY — refusing to deploy." >&2
  echo "  Commit (or stash) these changes first so the deploy is reproducible:" >&2
  echo "$DIRTY" | sed 's/^/    /' >&2
  echo "" >&2
  echo "  Then re-run, or use the documented override for emergencies:" >&2
  echo "    ALLOW_DIRTY_DEPLOY=1 <your deploy command>" >&2
  exit 1
fi

echo "✓ guard-clean-tree: tree clean, on $(git rev-parse --abbrev-ref HEAD) @ $(git rev-parse --short HEAD) — safe to deploy."
exit 0
