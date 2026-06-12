/**
 * PolicyVersionSelector — Selects the correct historical policy version
 * for a given approval date.
 *
 * Shared utility used by AuditCaseService (on case creation) and
 * CaseReviewController (on replay). Encapsulates the temporal query
 * so the selection logic lives in one place.
 *
 * @group Audit Replay Kernel
 * @see AD-09 in RISKS-AND-DECISIONS.md — Historical Policy Selection
 */
public with sharing class PolicyVersionSelector {

    /**
     * Select the policy version that was active at a given approval date.
     *
     * Query strategy:
     * 1. Find the most recent policy version whose Effective_Date__c <= approvalDate
     *    and Status__c IN ('Active', 'Superseded') — superseded versions were active at some point.
     * 2. If no match, fall back to the current Active version.
     * 3. If no Active version exists, return null.
     *
     * @param approvalDate The original loan approval date/time
     * @return The Policy_Rule_Version__c Id (as String for Text(18) fields), or null
     */
    public static String selectByApprovalDate(Datetime approvalDate) {
        if (approvalDate == null) {
            return selectCurrentActive();
        }

        Date approvalDateOnly = approvalDate.date();

        // Find the best historical match
        List<Policy_Rule_Version__c> matches = [
            SELECT Id
            FROM Policy_Rule_Version__c
            WHERE Effective_Date__c <= :approvalDateOnly
              AND Status__c IN ('Active', 'Superseded')
            WITH USER_MODE
            ORDER BY Effective_Date__c DESC
            LIMIT 1
        ];

        if (!matches.isEmpty()) {
            return String.valueOf(matches[0].Id);
        }

        // Fall back to current Active
        return selectCurrentActive();
    }

    /**
     * Select the currently Active policy version.
     *
     * @return The Policy_Rule_Version__c Id (as String), or null if none is Active
     */
    public static String selectCurrentActive() {
        List<Policy_Rule_Version__c> active = [
            SELECT Id
            FROM Policy_Rule_Version__c
            WHERE Status__c = 'Active'
            WITH USER_MODE
            LIMIT 1
        ];
        return active.isEmpty() ? null : String.valueOf(active[0].Id);
    }

    /**
     * Load the full policy version record by Id string.
     * Used after selection to get threshold fields for PolicyRuleEvaluator.
     *
     * @param policyVersionId The Id as String (from Text(18) field)
     * @return The full Policy_Rule_Version__c record, or null
     */
    public static Policy_Rule_Version__c loadPolicyVersion(String policyVersionId) {
        if (String.isBlank(policyVersionId)) {
            return null;
        }

        Id policyId = Id.valueOf(policyVersionId);
        List<Policy_Rule_Version__c> versions = [
            SELECT Id, Name, Version_Number__c, Status__c,
                   DTI_Threshold__c, Min_Credit_Score__c,
                   HITL_Credit_Threshold__c, Max_Loan_No_Escalation__c,
                   Effective_Date__c
            FROM Policy_Rule_Version__c
            WHERE Id = :policyId
            WITH USER_MODE
            LIMIT 1
        ];
        return versions.isEmpty() ? null : versions[0];
    }
}