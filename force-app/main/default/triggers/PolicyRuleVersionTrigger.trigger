/**
 * Lifecycle enforcement for Policy_Rule_Version__c — "rules are data" (ADR-4) made
 * safe for non-developers. Thin trigger body delegates to the handler so the
 * invariant logic stays unit-testable (one-trigger-per-object).
 *
 *  - before insert: assign Version_Number__c (monotonic per Rule_Code) + link Supersedes__c
 *  - after  insert: expire the superseded prior active version (lifecycle fields only)
 *  - before update: block LOGIC-field edits on versions already cited by a decision
 *  - before delete: never (the audit trail may point to it)
 */
trigger PolicyRuleVersionTrigger on Policy_Rule_Version__c (
        before insert, after insert, before update, before delete) {
    if (Trigger.isInsert && Trigger.isBefore) {
        PolicyRuleVersionHandler.handleBeforeInsert(Trigger.new);
    } else if (Trigger.isInsert && Trigger.isAfter) {
        PolicyRuleVersionHandler.handleAfterInsert(Trigger.new);
    } else if (Trigger.isUpdate && Trigger.isBefore) {
        PolicyRuleVersionHandler.handleBeforeUpdate(Trigger.new, Trigger.oldMap);
    } else if (Trigger.isDelete && Trigger.isBefore) {
        PolicyRuleVersionHandler.handleBeforeDelete(Trigger.old);
    }
}
