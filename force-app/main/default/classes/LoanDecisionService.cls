/**
 * Public entry point for a full loan decision. Orchestrates the three layers
 * without violating their separation:
 *
 *   FactAssemblerService (read)  ->  PolicyRuleEvaluator (pure)  ->  DecisionCommitService (write)
 *
 * Bulk-safe for N applications: 3 SOQL (facts + evidence + rules) + 1 DML.
 * Callable from Flow (invocable) or other Apex.
 */
public with sharing class LoanDecisionService {

    /** Decide N applications. Returns the committed, immutable Decision_Event__c records. */
    public static List<Decision_Event__c> decide(Set<Id> applicationIds, String triggeredBy) {
        if (applicationIds == null || applicationIds.isEmpty()) {
            return new List<Decision_Event__c>();
        }

        // Layer 1 — read (2 SOQL inside assemble + 1 SOQL for rules).
        Map<Id, PolicyEvaluationContext> contexts = FactAssemblerService.assemble(applicationIds);
        List<Policy_Rule_Version__c> rules = FactAssemblerService.loadGoverningRules(Datetime.now());
        Id governingVersionId = rules.isEmpty() ? null : rules[0].Id;

        // Layer 2 — pure evaluation, zero SOQL/DML in the loop.
        List<DecisionCommitService.CommitRequest> toCommit =
            new List<DecisionCommitService.CommitRequest>();
        for (Id appId : applicationIds) {
            EvaluationResult result = PolicyRuleEvaluator.evaluate(contexts.get(appId), rules);
            DecisionCommitService.CommitRequest req =
                new DecisionCommitService.CommitRequest(appId, result, governingVersionId);
            req.triggeredBy = triggeredBy;
            toCommit.add(req);
        }

        // Layer 3 — write (1 DML).
        return DecisionCommitService.commitDecisions(toCommit);
    }

    public static Decision_Event__c decideOne(Id applicationId) {
        return decide(new Set<Id>{ applicationId }, 'SYSTEM')[0];
    }

    @InvocableMethod(label='Evaluate Loan Application'
        description='Runs the policy kernel and appends an immutable Decision_Event__c.')
    public static List<DecisionFlowResult> decideFromFlow(List<DecisionFlowRequest> requests) {
        Set<Id> appIds = new Set<Id>();
        String triggerSource = 'SYSTEM';
        for (DecisionFlowRequest r : requests) {
            if (r.applicationId != null) { appIds.add(r.applicationId); }
            if (String.isNotBlank(r.triggeredBy)) { triggerSource = r.triggeredBy; }
        }
        Map<Id, Decision_Event__c> byApp = new Map<Id, Decision_Event__c>();
        for (Decision_Event__c e : decide(appIds, triggerSource)) {
            byApp.put(e.Application__c, e);
        }
        List<DecisionFlowResult> out = new List<DecisionFlowResult>();
        for (DecisionFlowRequest r : requests) {
            DecisionFlowResult res = new DecisionFlowResult();
            Decision_Event__c e = byApp.get(r.applicationId);
            if (e != null) {
                res.outcome = e.Outcome__c;
                res.decisionEventId = e.Id;
                res.declineReason = e.Decline_Reason__c;
                res.hardDeclineCount = e.Hard_Decline_Count__c == null
                    ? 0 : e.Hard_Decline_Count__c.intValue();
                // Allura HITL: anything that could promote an application (approve,
                // approve-with-conditions, send-to-review) must be authorized by a
                // human. Only a hard decline is a terminal, fully-automated outcome.
                res.requiresHumanReview = (e.Outcome__c != 'HARD_DECLINED');
            }
            out.add(res);
        }
        return out;
    }

    public class DecisionFlowRequest {
        @InvocableVariable(required=true) public Id applicationId;
        @InvocableVariable public String triggeredBy; // SYSTEM | UNDERWRITER | RE_EVALUATION
    }

    public class DecisionFlowResult {
        @InvocableVariable public String outcome;
        @InvocableVariable public Id decisionEventId;   // pass to the VF receipt page (?id=)
        @InvocableVariable public String declineReason;
        @InvocableVariable public Integer hardDeclineCount;
        @InvocableVariable public Boolean requiresHumanReview; // gates the status-promotion flow
    }
}
