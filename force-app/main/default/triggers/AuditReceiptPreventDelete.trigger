/**
 * AuditReceiptPreventDelete — Prevents deletion of Audit_Receipt__c records.
 *
 * Combined with the Prevent_Edit_After_Creation validation rule,
 * this completes the append-only invariant: no updates, no deletes.
 *
 * @see AD-01 in RISKS-AND-DECISIONS.md
 */
trigger AuditReceiptPreventDelete on Audit_Receipt__c (before delete) {
    for (Audit_Receipt__c rec : Trigger.old) {
        rec.addError('Audit Receipts are append-only. Records cannot be deleted.');
    }
}
