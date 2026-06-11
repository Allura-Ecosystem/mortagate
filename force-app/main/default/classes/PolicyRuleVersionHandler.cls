/**
 * Lifecycle rules for Policy_Rule_Version__c — "rules are data" (ADR-4) made safe
 * for non-developers. Analysts version rules through the UI; this handler enforces
 * the invariants so they cannot create an inconsistent or unauditable policy set:
 *
 *  - Auto-version: Version_Number__c is assigned, not typed (monotonic per Rule_Code).
 *  - Supersession: creating vN+1 expires the prior active version and links Supersedes__c.
 *  - Immutability after reference: once a version is cited by any Decision_Event__c,
 *    its LOGIC fields (operator/threshold/fact/severity/explanation) can never change.
 *    Lifecycle fields (Expiration_Date/Is_Active/Supersedes) remain settable so
 *    supersession can still expire a referenced version going forward.
 *  - No deletes: a rule version is never removed (the audit trail may point to it).
 *
 * Bulk-safe: fixed query budget regardless of row count.
 */
public with sharing class PolicyRuleVersionHandler {

    // Fields whose change after reference would rewrite history — forbidden once cited.
    private static final Set<String> LOGIC_FIELDS = new Set<String>{
        'Operator__c', 'Threshold_Value__c', 'Threshold_High__c', 'Allowed_Values__c',
        'Fact_Field__c', 'Severity__c', 'Rule_Category__c', 'Rule_Explanation__c'
    };

    @TestVisible private static Boolean suppressRecursion = false;

    // ---- INSERT: assign version + link supersedes ---------------------------
    public static void handleBeforeInsert(List<Policy_Rule_Version__c> news) {
        Set<String> codes = new Set<String>();
        for (Policy_Rule_Version__c r : news) {
            if (String.isNotBlank(r.Rule_Code__c)) { codes.add(r.Rule_Code__c); }
        }
        // Current highest active version per Rule_Code (1 SOQL).
        Map<String, Policy_Rule_Version__c> currentByCode = new Map<String, Policy_Rule_Version__c>();
        Map<String, Integer> maxVersionByCode = new Map<String, Integer>();
        for (Policy_Rule_Version__c r : [
            SELECT Id, Rule_Code__c, Version_Number__c, Is_Active__c, Expiration_Date__c
            FROM Policy_Rule_Version__c
            WHERE Rule_Code__c IN :codes
            ORDER BY Version_Number__c DESC
        ]) {
            Integer v = r.Version_Number__c == null ? 0 : r.Version_Number__c.intValue();
            if (!maxVersionByCode.containsKey(r.Rule_Code__c)
                    || v > maxVersionByCode.get(r.Rule_Code__c)) {
                maxVersionByCode.put(r.Rule_Code__c, v);
            }
            // First active, no-expiration record seen per code is the current governing one.
            if (r.Is_Active__c == true && r.Expiration_Date__c == null
                    && !currentByCode.containsKey(r.Rule_Code__c)) {
                currentByCode.put(r.Rule_Code__c, r);
            }
        }

        Map<String, Integer> running = maxVersionByCode.clone();
        for (Policy_Rule_Version__c r : news) {
            if (String.isBlank(r.Rule_Code__c)) { continue; }
            Integer next = (running.containsKey(r.Rule_Code__c) ? running.get(r.Rule_Code__c) : 0) + 1;
            if (r.Version_Number__c == null) { r.Version_Number__c = next; }
            running.put(r.Rule_Code__c, Math.max(next, r.Version_Number__c.intValue()));

            // Link supersession if a prior governing version exists.
            if (currentByCode.containsKey(r.Rule_Code__c)) {
                r.Supersedes__c = currentByCode.get(r.Rule_Code__c).Id;
            }
        }
    }

    // ---- INSERT (after): expire the superseded prior versions ---------------
    public static void handleAfterInsert(List<Policy_Rule_Version__c> news) {
        if (suppressRecursion) { return; }
        Map<Id, Date> expireTo = new Map<Id, Date>();
        for (Policy_Rule_Version__c r : news) {
            if (r.Supersedes__c != null && r.Effective_Date__c != null) {
                expireTo.put(r.Supersedes__c, r.Effective_Date__c);
            }
        }
        if (expireTo.isEmpty()) { return; }

        List<Policy_Rule_Version__c> priors = new List<Policy_Rule_Version__c>();
        for (Id priorId : expireTo.keySet()) {
            priors.add(new Policy_Rule_Version__c(
                Id = priorId,
                Expiration_Date__c = expireTo.get(priorId),
                Is_Active__c = false
            ));
        }
        suppressRecursion = true;
        try {
            update priors; // only lifecycle fields — allowed even if referenced
        } finally {
            suppressRecursion = false;
        }
    }

    // ---- UPDATE: block logic changes on referenced versions -----------------
    public static void handleBeforeUpdate(List<Policy_Rule_Version__c> news,
                                          Map<Id, Policy_Rule_Version__c> oldMap) {
        if (suppressRecursion) { return; }

        // Which of these are referenced by a decision? (1 SOQL)
        Set<Id> referenced = new Set<Id>();
        for (AggregateResult ar : [
            SELECT Rule_Version__c rv
            FROM Decision_Event__c
            WHERE Rule_Version__c IN :oldMap.keySet()
            GROUP BY Rule_Version__c
        ]) {
            referenced.add((Id) ar.get('rv'));
        }
        if (referenced.isEmpty()) { return; }

        for (Policy_Rule_Version__c r : news) {
            if (!referenced.contains(r.Id)) { continue; }
            Policy_Rule_Version__c old = oldMap.get(r.Id);
            for (String f : LOGIC_FIELDS) {
                if (r.get(f) != old.get(f)) {
                    r.addError('This rule version has already governed a decision and its ' +
                        'criteria are now locked. Create a new version to change ' + f + '.');
                    break;
                }
            }
        }
    }

    // ---- DELETE: never -------------------------------------------------------
    public static void handleBeforeDelete(List<Policy_Rule_Version__c> olds) {
        for (Policy_Rule_Version__c r : olds) {
            r.addError('Policy rule versions cannot be deleted. Deactivate or supersede instead.');
        }
    }
}
