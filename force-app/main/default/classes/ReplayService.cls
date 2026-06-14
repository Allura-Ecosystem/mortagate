/**
 * ReplayService — End-to-end audit replay orchestrator (US-1.4).
 *
 * Thin conductor: assembles audit-side facts, adapts the new schema objects
 * for the existing pure PolicyRuleEvaluator, and commits results via
 * ReplayCommitService.
 *
 *   Step 1: ASSEMBLE — query Audit_Case, Borrower_Snapshot, Evidence_Item,
 *           and governing Policy_Rule records (3 SOQL).
 *   Step 2: ADAPT — map Policy_Rule__c → in-memory Policy_Rule_Version__c
 *           so the evaluator's interface is unchanged.
 *   Step 3: EVALUATE — pure kernel (0 SOQL, 0 DML).
 *   Step 4: COMMIT — persist Replay_Check__c + Audit_Event (2 DML).
 *
 * Budget: 3 SOQL + 2 DML for a single case.
 *
 * @group Audit Replay Kernel
 */
public with sharing class ReplayService {

    /**
     * Run the full replay pipeline for one audit case.
     *
     * @param auditCaseId The Audit_Case__c to replay
     * @return The persisted Replay_Check__c records
     */
    public static List<Replay_Check__c> replay(Id auditCaseId) {

        // ── Step 1: ASSEMBLE ────────────────────────────────────────────

        // 1a. Load case with loan approval date (subquery Borrower_Snapshot + Evidence_Item)
        Audit_Case__c ac = [
            SELECT Id, Loan__c, Loan__r.Approval_Date__c,
                (SELECT Id, Fact_Category__c, DTI_Ratio__c, FICO_Score__c,
                        LTV_Ratio__c, Annual_Income__c, Monthly_Income__c,
                        Monthly_Debt__c, Employment_Months__c, Asset_Value__c,
                        Address_Tenure_Months__c
                 FROM Borrower_Snapshots__r),
                (SELECT Id, Document_Type__c, Status__c
                 FROM Evidence_Items__r)
            FROM Audit_Case__c
            WHERE Id = :auditCaseId
            WITH USER_MODE
            LIMIT 1
        ];  // 1 SOQL (with 2 subqueries)

        Date approvalDate = ac.Loan__r.Approval_Date__c;
        if (approvalDate == null) {
            return new List<Replay_Check__c>();
        }

        // Build fact map from Borrower_Snapshot__c records.
        // Each snapshot has typed numeric fields; the evaluator looks up by Fact_Field__c API name.
        Map<String, Object> facts = new Map<String, Object>();
        Map<Id, Borrower_Snapshot__c> snapshotById = new Map<Id, Borrower_Snapshot__c>();
        for (Borrower_Snapshot__c bs : ac.Borrower_Snapshots__r) {
            snapshotById.put(bs.Id, bs);
            putIfPresent(facts, 'DTI_Ratio__c', bs.DTI_Ratio__c);
            putIfPresent(facts, 'FICO_Score__c', bs.FICO_Score__c);
            putIfPresent(facts, 'LTV_Ratio__c', bs.LTV_Ratio__c);
            putIfPresent(facts, 'Annual_Income__c', bs.Annual_Income__c);
            putIfPresent(facts, 'Monthly_Income__c', bs.Monthly_Income__c);
            putIfPresent(facts, 'Monthly_Debt__c', bs.Monthly_Debt__c);
            putIfPresent(facts, 'Employment_Months__c', bs.Employment_Months__c);
            putIfPresent(facts, 'Asset_Value__c', bs.Asset_Value__c);
            putIfPresent(facts, 'Address_Tenure_Months__c', bs.Address_Tenure_Months__c);
        }

        // Build evidence status map
        Map<String, String> evidenceStatus = new Map<String, String>();
        for (Evidence_Item__c ei : ac.Evidence_Items__r) {
            evidenceStatus.put(ei.Document_Type__c, ei.Status__c);
        }

        // 1b. Resolve governing policy version by approval date
        Policy_Version__c policyVersion = [
            SELECT Id, Version_Number__c,
                (SELECT Id, Rule_Code__c, Rule_Label__c, Rule_Category__c,
                        Operator__c, Threshold_Value__c, Threshold_High__c,
                        Fact_Field__c, Severity__c, Rule_Explanation__c,
                        Allowed_Values__c, Override_Permitted__c, Sort_Order__c
                 FROM Policy_Rules__r
                 ORDER BY Sort_Order__c ASC NULLS LAST, Rule_Code__c ASC)
            FROM Policy_Version__c
            WHERE Is_Active__c = true
              AND Effective_Date__c <= :approvalDate
              AND (Expiration_Date__c = null OR Expiration_Date__c > :approvalDate)
            WITH USER_MODE
            ORDER BY Effective_Date__c DESC
            LIMIT 1
        ];  // 1 SOQL (with 1 subquery) — total now 2 SOQL

        List<Policy_Rule__c> rules = policyVersion.Policy_Rules__r;
        if (rules == null || rules.isEmpty()) {
            return new List<Replay_Check__c>();
        }

        // ── Step 2: ADAPT ───────────────────────────────────────────────

        // Map Policy_Rule__c → Policy_Rule_Version__c (in-memory) so the
        // existing pure evaluator works unchanged. Fields are 1:1 by name.
        Map<Id, Id> adaptedIdToRuleId = new Map<Id, Id>();
        List<Policy_Rule_Version__c> adaptedRules = new List<Policy_Rule_Version__c>();
        for (Policy_Rule__c pr : rules) {
            Policy_Rule_Version__c adapted = new Policy_Rule_Version__c(
                Rule_Code__c           = pr.Rule_Code__c,
                Rule_Label__c          = pr.Rule_Label__c,
                Rule_Category__c       = pr.Rule_Category__c,
                Operator__c            = pr.Operator__c,
                Threshold_Value__c     = pr.Threshold_Value__c,
                Threshold_High__c      = pr.Threshold_High__c,
                Fact_Field__c          = pr.Fact_Field__c,
                Severity__c            = pr.Severity__c,
                Rule_Explanation__c    = pr.Rule_Explanation__c,
                Allowed_Values__c      = pr.Allowed_Values__c,
                Override_Permitted__c  = pr.Override_Permitted__c,
                Version_Number__c      = policyVersion.Version_Number__c
            );
            adaptedRules.add(adapted);
            // Track mapping from adapted list index → original Policy_Rule__c Id
            adaptedIdToRuleId.put(adapted.Id, pr.Id);
        }

        PolicyEvaluationContext ctx = new PolicyEvaluationContext(
            auditCaseId, facts, evidenceStatus
        );

        // ── Step 3: EVALUATE ────────────────────────────────────────────

        EvaluationResult evalResult = PolicyRuleEvaluator.evaluate(ctx, adaptedRules);

        // ── Step 4: COMMIT ──────────────────────────────────────────────

        List<ReplayCommitService.ReplayCheckResult> commitResults =
            new List<ReplayCommitService.ReplayCheckResult>();

        // The first Borrower_Snapshot__c Id for linking (if any exist)
        Id snapshotId = snapshotById.isEmpty() ? null : new List<Id>(snapshotById.keySet())[0];

        for (Integer i = 0; i < evalResult.triggeredRules.size(); i++) {
            RuleOutcome ro = evalResult.triggeredRules[i];

            ReplayCommitService.ReplayCheckResult rcr = new ReplayCommitService.ReplayCheckResult();
            rcr.auditCaseId      = auditCaseId;
            rcr.policyRuleId     = rules[i].Id;  // original Policy_Rule__c Id
            rcr.ruleName         = ro.ruleCode;
            rcr.result           = ro.outcome;    // PASS, FAIL, INDETERMINATE
            rcr.expectedValue    = ro.threshold != null ? String.valueOf(ro.threshold) : null;
            rcr.actualValue      = ro.factValue != null ? String.valueOf(ro.factValue) : null;
            rcr.borrowerSnapshotId = snapshotId;
            rcr.rationale        = ro.explanation;
            rcr.sortOrder        = i;
            commitResults.add(rcr);
        }

        return ReplayCommitService.commit(commitResults);  // 2 DML
    }

    private static void putIfPresent(Map<String, Object> m, String key, Object val) {
        if (val != null) { m.put(key, val); }
    }
}
