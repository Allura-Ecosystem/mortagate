/**
 * Layer 1 of the policy engine — the ONLY class that reads the database on the
 * engine's behalf. It assembles immutable PolicyEvaluationContext objects and
 * resolves the governing rule set. Bulk-safe: builds contexts for N applications
 * in a fixed number of queries (1 facts + 1 evidence + 1 rules), never per-record.
 */
public with sharing class FactAssemblerService {

    /**
     * The fact fields we project from Extracted_Facts__c into the flat
     * applicantFacts map. Keys are Fact_Field__c API names referenced by rules.
     */
    private static final Set<String> FACT_FIELDS = new Set<String>{
        'Annual_Income__c', 'Monthly_Income__c', 'DTI_Ratio__c', 'FICO_Score__c',
        'LTV_Ratio__c', 'Employment_Months__c', 'Asset_Value__c'
    };

    /**
     * Build evaluation contexts for many applications at once.
     * @return Map of Loan_Application__c Id -> PolicyEvaluationContext
     */
    public static Map<Id, PolicyEvaluationContext> assemble(Set<Id> applicationIds) {
        Map<Id, Map<String, Object>> factsByApp = new Map<Id, Map<String, Object>>();
        Map<Id, Map<String, String>> evidenceByApp = new Map<Id, Map<String, String>>();

        for (Id appId : applicationIds) {
            factsByApp.put(appId, new Map<String, Object>());
            evidenceByApp.put(appId, new Map<String, String>());
        }

        // 1 SOQL — all facts for all applications. Latest extraction wins per field.
        for (Extracted_Facts__c f : [
            SELECT Application__c, Annual_Income__c, Monthly_Income__c, DTI_Ratio__c,
                   FICO_Score__c, LTV_Ratio__c, Employment_Months__c, Asset_Value__c,
                   Extracted_Date__c
            FROM Extracted_Facts__c
            WHERE Application__c IN :applicationIds
            ORDER BY Extracted_Date__c ASC NULLS FIRST
        ]) {
            Map<String, Object> facts = factsByApp.get(f.Application__c);
            putIfPresent(facts, 'Annual_Income__c', f.Annual_Income__c);
            putIfPresent(facts, 'Monthly_Income__c', f.Monthly_Income__c);
            putIfPresent(facts, 'DTI_Ratio__c', f.DTI_Ratio__c);
            putIfPresent(facts, 'FICO_Score__c', f.FICO_Score__c);
            putIfPresent(facts, 'LTV_Ratio__c', f.LTV_Ratio__c);
            putIfPresent(facts, 'Employment_Months__c', f.Employment_Months__c);
            putIfPresent(facts, 'Asset_Value__c', f.Asset_Value__c);
        }

        // 1 SOQL — evidence completeness per application.
        for (Evidence__c e : [
            SELECT Application__c, Document_Type__c, Extraction_Status__c
            FROM Evidence__c
            WHERE Application__c IN :applicationIds
        ]) {
            String status = e.Extraction_Status__c == 'COMPLETED' ? 'VERIFIED' : 'PENDING';
            evidenceByApp.get(e.Application__c).put(e.Document_Type__c, status);
        }

        Map<Id, PolicyEvaluationContext> result = new Map<Id, PolicyEvaluationContext>();
        for (Id appId : applicationIds) {
            result.put(appId, new PolicyEvaluationContext(
                appId, factsByApp.get(appId), evidenceByApp.get(appId)));
        }
        return result;
    }

    /** Convenience single-application overload. */
    public static PolicyEvaluationContext assembleOne(Id applicationId) {
        return assemble(new Set<Id>{ applicationId }).get(applicationId);
    }

    /**
     * Resolve the governing rule set as of a moment: active, within the
     * effective window, and the HIGHEST version per Rule_Code__c. 1 SOQL.
     * Optionally restrict to a set of categories (used by the pre-flight path).
     */
    public static List<Policy_Rule_Version__c> loadGoverningRules(Datetime asOf,
                                                                  Set<String> categories) {
        Date asOfDate = asOf.dateGmt();
        List<Policy_Rule_Version__c> candidates = [
            SELECT Id, Rule_Code__c, Version_Number__c, Operator__c, Threshold_Value__c,
                   Threshold_High__c, Allowed_Values__c, Fact_Field__c, Severity__c,
                   Rule_Category__c, Rule_Explanation__c, Override_Permitted__c
            FROM Policy_Rule_Version__c
            WHERE Is_Active__c = true
              AND Effective_Date__c <= :asOfDate
              AND (Expiration_Date__c = null OR Expiration_Date__c > :asOfDate)
            ORDER BY Rule_Code__c ASC, Version_Number__c DESC
        ];

        // Keep only the highest version per Rule_Code__c (first seen wins due to ORDER BY).
        Map<String, Policy_Rule_Version__c> governing = new Map<String, Policy_Rule_Version__c>();
        for (Policy_Rule_Version__c r : candidates) {
            if (categories != null && !categories.isEmpty()
                    && !categories.contains(r.Rule_Category__c)) {
                continue;
            }
            if (!governing.containsKey(r.Rule_Code__c)) {
                governing.put(r.Rule_Code__c, r);
            }
        }
        // Deterministic order: Map.values() iteration order is not guaranteed in
        // Apex. The verdict is order-independent (worst-wins), but the receipt and
        // any explanation sequencing must be stable across runs. Sort by Rule_Code__c.
        List<Policy_Rule_Version__c> ordered = governing.values();
        ordered.sort(new RuleCodeComparator());
        return ordered;
    }

    /** Stable ordering of governing rules by Rule_Code__c (ascending). */
    private class RuleCodeComparator implements Comparator<Policy_Rule_Version__c> {
        public Integer compare(Policy_Rule_Version__c a, Policy_Rule_Version__c b) {
            String ca = a.Rule_Code__c == null ? '' : a.Rule_Code__c;
            String cb = b.Rule_Code__c == null ? '' : b.Rule_Code__c;
            return ca.compareTo(cb);
        }
    }

    public static List<Policy_Rule_Version__c> loadGoverningRules(Datetime asOf) {
        return loadGoverningRules(asOf, null);
    }

    private static void putIfPresent(Map<String, Object> facts, String key, Object value) {
        if (value != null) { facts.put(key, value); }
    }
}
