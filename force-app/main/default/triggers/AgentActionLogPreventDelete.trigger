/**
 * AgentActionLogPreventDelete — Enforces the append-only invariant on
 * Agent_Action_Log__c in code (ADR-1: enforcement lives in code so it cannot be
 * bypassed by Flow, API, or another trigger).
 *
 * Blocks BOTH update and delete with addError (bulk-safe), mirroring the
 * DecisionEventImmutabilityTrigger pattern. The Prevent_Edit_After_Creation
 * validation rule stays in place as defense in depth.
 *
 * The only legitimate way to record a changed outcome is to APPEND a new record
 * (a new Agent_Action_Log__c and/or Audit_Event__c) — never an edit.
 *
 * @see AD-01 in RISKS-AND-DECISIONS.md
 */
trigger AgentActionLogPreventDelete on Agent_Action_Log__c (before update, before delete) {
    if (Trigger.isUpdate) {
        for (Agent_Action_Log__c rec : Trigger.new) {
            rec.addError('Agent Action Logs are append-only. Records cannot be modified after creation.');
        }
    } else if (Trigger.isDelete) {
        for (Agent_Action_Log__c rec : Trigger.old) {
            rec.addError('Agent Action Logs are append-only. Records cannot be deleted.');
        }
    }
}
