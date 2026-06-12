/**
 * AuditEventPreventDelete — Prevents deletion of Audit_Event__c records.
 *
 * Combined with the Prevent_Edit_After_Creation validation rule,
 * this completes the append-only invariant: no updates, no deletes.
 *
 * @see AD-01 in RISKS-AND-DECISIONS.md
 */
trigger AuditEventPreventDelete on Audit_Event__c (before delete) {
    for (Audit_Event__c evt : Trigger.old) {
        evt.addError('Audit Events are append-only. Records cannot be deleted.');
    }
}