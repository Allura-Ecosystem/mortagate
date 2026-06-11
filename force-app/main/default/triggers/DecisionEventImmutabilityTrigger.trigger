/**
 * Append-only guard for Decision_Event__c. Delegates to a handler class so the
 * logic stays unit-testable and the trigger body stays thin (one-trigger-per-object).
 */
trigger DecisionEventImmutabilityTrigger on Decision_Event__c (before update, before delete) {
    if (Trigger.isUpdate) {
        DecisionEventImmutability.handleBeforeUpdate(Trigger.new);
    } else if (Trigger.isDelete) {
        DecisionEventImmutability.handleBeforeDelete(Trigger.old);
    }
}
