/**
 * AgentActionLogPreventDelete — Prevents deletion of Agent_Action_Log__c records.
 *
 * Combined with the Prevent_Edit_After_Creation validation rule,
 * this completes the append-only invariant: no updates, no deletes.
 *
 * @see AD-01 in RISKS-AND-DECISIONS.md
 */
trigger AgentActionLogPreventDelete on Agent_Action_Log__c (before delete) {
    for (Agent_Action_Log__c rec : Trigger.old) {
        rec.addError('Agent Action Logs are append-only. Records cannot be deleted.');
    }
}
