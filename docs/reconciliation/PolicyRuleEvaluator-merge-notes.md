# Reconciliation: `PolicyRuleEvaluator` — forward engine ⊕ audit replay

**Status:** proposed merge for review. **Do not auto-apply** — this class is co-owned with
the parallel Brooks/engine session. This note + `PolicyRuleEvaluator.merged.cls` reduce the
decision to a yes/no.

## The problem

`PolicyRuleEvaluator` is hard-forked. Two copies share only the class name:

| | canonical / git (Brooks engine) | org (audit-pivot) |
|---|---|---|
| Lines | 132 | 293 |
| Public API | `evaluate(PolicyEvaluationContext, List<Policy_Rule_Version__c>) → EvaluationResult` | `replayRules(List<Reconstructed_Fact__c>, Policy_Rule_Version__c, Id) → List<Rule_Check__c>` + `replayRulesAsResults(...)` |
| Inner types | (none here) | `RuleCheckResult` |
| Private helpers | `tallyFailure`, `deriveVerdict`, `evaluateOperator`, `parseList`, `toDecimal` | `isUnverifiable`, `evaluateDTI`, `evaluateCreditScore`, `evaluateHITLCredit`, `evaluateLoanEscalation`, `setRationale` |
| Style | generic, config-driven operator dispatch | hardcoded rule-by-rule re-evaluation |
| External deps | `PolicyEvaluationContext`, `EvaluationResult`, `RuleOutcome`, `PolicyEngineException` | `Reconstructed_Fact__c`, `Rule_Check__c`, `Policy_Rule_Version__c` |

`CaseReviewController.runReplay` calls `replayRules(...)`, which the git copy does not have →
a fresh-org rebuild of the audit-queue fails to compile. This single fork is the **last thing**
between git and a full org rebuild of the audit-queue (per goal V4.1).

## Why the merge is mechanical, not a conflict

**The two method sets are disjoint — zero symbol collisions.**

- No two methods share a signature. `evaluate` ≠ `replayRules` ≠ `replayRulesAsResults`.
- No two helpers share a name (`evaluateOperator`/`parseList`/`toDecimal`/`tallyFailure`/
  `deriveVerdict` vs `isUnverifiable`/`evaluate{DTI,CreditScore,HITLCredit,LoanEscalation}`/
  `setRationale`).
- Inner type `RuleCheckResult` is unique to the replay side; the forward side defines none.
- Both are `public with sharing`, both PURE (no SOQL/DML).

So the reconciliation is a **union**: keep both public entry points and both private helper
sets in one class. `PolicyRuleEvaluator.merged.cls` in this folder is exactly that union.

### The one thing to confirm: the schema superset

The forward path reads `Threshold_Value__c / Threshold_High__c / Allowed_Values__c /
Operator__c / Fact_Field__c / Severity__c`; the replay path reads `DTI_Threshold__c /
Min_Credit_Score__c / HITL_Credit_Threshold__c / Max_Loan_No_Escalation__c / Fact_Type__c /
Value__c`. Both are fields on `Policy_Rule_Version__c`. Goal-file V4.1 established the org's
`Policy_Rule_Version__c` is a **superset** carrying both sets, so the merged class compiles
against the complete object **with no schema change**. Confirm this object (the full superset)
is the one on the PR branch before deploying. (It is, as of the V4.1 follow-up commit.)

## How to apply (reviewer steps)

1. Copy `docs/reconciliation/PolicyRuleEvaluator.merged.cls` over
   `force-app/main/default/classes/PolicyRuleEvaluator.cls` on `feat/audit-queue-v2`.
2. Deploy to a scratch/dev org that has BOTH dependency sets present:
   - engine companions: `PolicyEvaluationContext`, `EvaluationResult`, `RuleOutcome`,
     `PolicyEngineException`
   - audit objects: `Reconstructed_Fact__c`, `Rule_Check__c`, `Policy_Rule_Version__c` (superset)
3. Run BOTH suites green — they must not regress:
   - engine: `PolicyRuleEvaluatorTest`, `LoanDecisionServiceTest` (forward path)
   - audit-queue: `sf apex run test --suite-names AuditQueue` → 37/37
4. Only after both are green, drop this `docs/reconciliation/` copy and commit the unified
   class as the single source of truth.

## What this does NOT decide

- It does not merge `FactAssembler` (pivot) vs `FactAssemblerService` (canonical) — separate
  reconciliation, still open.
- It does not touch the engine's verdict semantics or the audit replay rule set — both are
  carried verbatim, so neither team's behaviour changes.

## Verification performed for this artifact

- Both source bodies pulled fresh: git copy from `force-app/.../PolicyRuleEvaluator.cls`
  (132 lines); org copy via Tooling API from `mortagate-de` (293 lines).
- Symbol-collision check: none (disjoint method/helper/type names, tabulated above).
- The merged file is a literal concatenation of both method sets under one class declaration
  with a unified header — no logic was rewritten.
