# Runbook — Audit Queue as a decoupled deployable unit

Promotes the audit-queue independently of the org-wide `RunLocalTests` gate (which is red
from policy-engine drift in a separate bounded context — goal Decision #2).

## Artifacts
- `manifest/package.audit-queue.xml` — the audit-queue footprint (7 objects, 13 Apex classes,
  1 trigger, the `auditQueue` LWC, the evidence-report page, the `AuditQueue` test suite).
  **Excludes `PolicyRuleEvaluator`** — shared, co-owned engine class (see
  `docs/reconciliation/PolicyRuleEvaluator-merge-notes.md`).
- `scripts/deploy-audit-queue.sh <org> [--validate]` — fail-closed pre-flight (clean tree;
  `PolicyRuleEvaluator.replayRules` must already exist in target; seed guard on prod targets)
  then deploys/validates gated on `RunSpecifiedTests` over the audit suite.

## Verification run (2026-06-12, check-only against `mortagate-de`)
`sf project deploy validate -o mortagate-de -x manifest/package.audit-queue.xml
--test-level RunSpecifiedTests --tests AuditCaseServiceTest --tests AuditDataIntegrityTest
--tests AuditQueueControllerTest --tests AuditEvidenceReportControllerTest`

- **Compiles + deploys as an isolated unit:** ✅ (recomposed from source, validated against org)
- **Audit suite:** ✅ 36/36 tests pass, 100%
- **Production coverage gate (≥75% per class):** ❌ **FAILS** — see gap below.

## ⚠️ The gap this surfaced: the replay kernel is under-tested

When the unit is validated with **only** its own test classes, per-class coverage is computed
from just those runs. The **queue** surface is well covered; the **replay** path is not:

| Class | Coverage | Role |
|---|---|---|
| `FactAssembler` | 8.7% | reconstructs facts from evidence |
| `AuditCommitService` | 0% | persists replay results |
| `CaseReviewController` | 0% | orchestrates `runReplay` |
| `FindingService` | 0% | maps violations → findings |
| `PolicyVersionSelector` | 52.6% | resolves historical policy version |

These classes are exercised indirectly today but have **no dedicated unit tests**, so they
fall under the 75% prod bar.

## What this means for Decision #1 (the prod-target call)

- **If the target is `mortagate-de` (Dev Edition):** coverage is **not** enforced on deploy —
  the unit deploys clean today. The decoupling is DONE for the dev org.
- **If the target is a real production org:** the unit cannot validate until the replay-kernel
  classes reach ≥75%. **Prerequisite:** add unit tests for `CaseReviewController.runReplay`,
  `FactAssembler.reconstructFacts(Bulk)`, `AuditCommitService.commitReplayResults`,
  `FindingService.createFromRuleChecks`, and `PolicyVersionSelector`. (The golden-path chain
  already seeded on AC-0001 is a ready-made fixture for these.)

## Next step
Decide the prod target. If prod: write the five replay-path test classes (est. one focused
session), re-run `scripts/deploy-audit-queue.sh <prod> --validate` until coverage clears,
then promote. If Dev Edition: run `scripts/deploy-audit-queue.sh mortagate-de` to promote now.
