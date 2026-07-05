/**
 * SanctionsScreeningPreventDelete — Enforces the append-only invariant on
 * Sanctions_Screening__c in code (ADR-24 / ADR-1: enforcement lives in code so it
 * cannot be bypassed by Flow, API, or another trigger).
 *
 * Blocks BOTH update and delete with addError (bulk-safe), mirroring the
 * AgentActionLogPreventDelete idiom. The Prevent_Edit_After_Creation validation
 * rule stays in place as defense in depth.
 *
 * A sanctions screen is a receipt, not a mutable status: the only legitimate way
 * to record a changed disposition is to APPEND a new Sanctions_Screening__c —
 * never an edit. The newest Screened_At__c for a Loan__c is the current result.
 *
 * @see ADR-24 in RISKS-AND-DECISIONS.md
 * @see AD-01 in RISKS-AND-DECISIONS.md
 */
trigger SanctionsScreeningPreventDelete on Sanctions_Screening__c (before update, before delete) {
    if (Trigger.isUpdate) {
        for (Sanctions_Screening__c rec : Trigger.new) {
            rec.addError('Sanctions Screenings are append-only. Records cannot be modified after creation.');
        }
    } else if (Trigger.isDelete) {
        for (Sanctions_Screening__c rec : Trigger.old) {
            rec.addError('Sanctions Screenings are append-only. Records cannot be deleted.');
        }
    }
}
