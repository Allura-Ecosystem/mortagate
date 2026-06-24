/**
 * ReplayCommitService -Layer 3 of the audit replay kernel.
 *
 * The ONLY class that writes replay results. Takes in-memory
 * ReplayCheckResults (already evaluated, zero DB dependency) and persists
 * Replay_Check__c records in a single bulk DML, then logs an Audit_Event__c
 * via AuditEventService.
 *
 * Budget: 0 SOQL, 2 DML (1 insert Replay_Check__c + 1 insert Audit_Event__c).
 * Bulk-safe: handles N cases in one call.
 *
 * @group Audit Replay Kernel
 * @see AuditEventService
 * @see DecisionCommitService (origination-side analog)
 */
public with sharing class ReplayCommitService {

    /**
     * Represents a single replay check result ready for persistence.
     * Built by the caller (ReplayService orchestrator) from PolicyRuleEvaluator output.
     */
    public class ReplayCheckResult {
        public Id auditCaseId;
        public Id policyRuleId;
        public String ruleName;
        public String result;           // Pass, Fail, Indeterminate
        public String expectedValue;
        public String actualValue;
        public Id evidenceItemId;
        public Id borrowerSnapshotId;
        public String rationale;
        public Integer sortOrder;

        public ReplayCheckResult() {}
    }

    /**
     * Persist replay check results and log the replay event.
     *
     * @param results List of ReplayCheckResult -one per rule evaluated per case
     * @return The inserted Replay_Check__c records (with Ids populated)
     */
    public static List<Replay_Check__c> commitReplayChecks(List<ReplayCheckResult> results) {
        if (results == null || results.isEmpty()) {
            return new List<Replay_Check__c>();
        }

        Datetime now = Datetime.now();
        List<Replay_Check__c> checks = new List<Replay_Check__c>();

        // Collect distinct case Ids for the audit event(s)
        Set<Id> caseIds = new Set<Id>();

        for (ReplayCheckResult r : results) {
            checks.add(new Replay_Check__c(
                Audit_Case__c         = r.auditCaseId,
                Policy_Rule__c        = r.policyRuleId,
                Rule_Name__c          = r.ruleName,
                Result__c             = r.result,
                Expected_Value__c     = r.expectedValue,
                Actual_Value__c       = r.actualValue,
                Evidence_Item__c      = r.evidenceItemId,
                Borrower_Snapshot__c  = r.borrowerSnapshotId,
                Rationale__c          = r.rationale,
                Replay_Timestamp__c   = now,
                Sort_Order__c         = r.sortOrder
            ));
            caseIds.add(r.auditCaseId);
        }

        insert checks;  // 1 DML for N results

        // Log one Audit_Event__c per case
        List<Audit_Event__c> events = new List<Audit_Event__c>();
        for (Id caseId : caseIds) {
            events.add(new Audit_Event__c(
                Audit_Case__c    = caseId,
                Event_Type__c    = 'Replay_Executed',
                Actor__c         = UserInfo.getName(),
                Timestamp__c     = now,
                Payload__c       = '{"replayCheckCount":' + checks.size() + '}'
            ));
        }
        AuditEventService.logEvents(events);  // 1 DML

        return checks;
    }
}
