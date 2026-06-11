# Append-Only Audit

Decision_Event__c is immutable. No UPDATE, no DELETE. Enforced by `DecisionEventImmutabilityTrigger` (before update / before delete -> addError). A changed outcome is a NEW event with `Triggered_By__c = RE_EVALUATION`, never an edit. Field History Tracking is not a substitute — it is opt-in, capped, and silently truncates. The engine's bulk contract is 3 SOQL + 1 DML for N applications (enforced by `apex-quality` skill; proven at 200 by `LoanDecisionServiceTest`).

**Enforcement:** `DecisionEventImmutabilityTrigger` + `DecisionEventImmutabilityTest` (insert allowed; bulk update blocked; bulk delete blocked).

**Source:** ADR-1, ADR-5, B4, B7.
