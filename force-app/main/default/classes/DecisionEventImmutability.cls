/**
 * Enforces the append-only invariant for Decision_Event__c (BLUEPRINT §B4).
 * A decision is a receipt: once written it can never be altered or erased.
 * This is enforced in code, not by convention — every UPDATE and DELETE is
 * blocked with addError, which is bulk-safe and cannot be bypassed by Flow,
 * API, or another trigger.
 *
 * The ONLY legitimate way to change an outcome is to append a NEW
 * Decision_Event__c (e.g. Triggered_By__c = RE_EVALUATION).
 */
public with sharing class DecisionEventImmutability {

    @TestVisible
    private static final String UPDATE_MSG =
        'Decision events are append-only and cannot be modified. ' +
        'To record a changed outcome, create a new decision event (re-evaluation).';

    @TestVisible
    private static final String DELETE_MSG =
        'Decision events are append-only and cannot be deleted. The audit trail is permanent.';

    public static void handleBeforeUpdate(List<Decision_Event__c> updated) {
        for (Decision_Event__c e : updated) {
            e.addError(UPDATE_MSG);
        }
    }

    public static void handleBeforeDelete(List<Decision_Event__c> toDelete) {
        for (Decision_Event__c e : toDelete) {
            e.addError(DELETE_MSG);
        }
    }
}
