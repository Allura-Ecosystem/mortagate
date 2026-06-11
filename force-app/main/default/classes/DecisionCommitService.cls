/**
 * Layer 3 of the policy engine — the ONLY class that writes a decision.
 *
 * Takes EvaluationResults (already computed, in memory) and persists one
 * Decision_Event__c per application. Bulk-safe: a single DML insert for N
 * applications. These records are append-only — the DecisionEventImmutability
 * trigger blocks any subsequent update or delete.
 */
public with sharing class DecisionCommitService {

    public class CommitRequest {
        public Id applicationId;
        public EvaluationResult result;
        public Id ruleVersionId;        // governing version referenced by the receipt
        public Id evaluatedFactsId;     // optional snapshot pointer
        public String triggeredBy;      // SYSTEM | UNDERWRITER | RE_EVALUATION

        public CommitRequest(Id appId, EvaluationResult result, Id ruleVersionId) {
            this.applicationId = appId;
            this.result = result;
            this.ruleVersionId = ruleVersionId;
            this.triggeredBy = 'SYSTEM';
        }
    }

    /** Commit many decisions in one DML. Returns the inserted events. */
    public static List<Decision_Event__c> commitDecisions(List<CommitRequest> requests) {
        List<Decision_Event__c> events = new List<Decision_Event__c>();
        for (CommitRequest req : requests) {
            EvaluationResult r = req.result;
            events.add(new Decision_Event__c(
                Application__c        = req.applicationId,
                Outcome__c            = r.verdict,
                Rule_Version__c       = req.ruleVersionId,
                Evaluated_Facts__c    = req.evaluatedFactsId,
                Rule_Results_JSON__c  = r.toReceiptJson(),
                Evaluated_Rule_Count__c = r.totalRulesEvaluated,
                Hard_Decline_Count__c = r.hardDeclineCount,
                Decision_Timestamp__c = r.evaluationTimestamp,
                Triggered_By__c       = String.isBlank(req.triggeredBy) ? 'SYSTEM' : req.triggeredBy,
                Decline_Reason__c     = r.firstDeclineReason()
            ));
        }
        insert events;   // 1 DML for N applications
        return events;
    }

    public static Decision_Event__c commitOne(Id appId, EvaluationResult result, Id ruleVersionId) {
        return commitDecisions(new List<CommitRequest>{ new CommitRequest(appId, result, ruleVersionId) })[0];
    }
}
