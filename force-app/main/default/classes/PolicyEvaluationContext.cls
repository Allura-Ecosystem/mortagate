/**
 * Immutable input to the policy rule evaluator.
 *
 * Carries everything the (pure) evaluator needs and nothing it does not:
 * the facts to test, the evidence completeness map, and the moment the
 * evaluation represents. No SObjects, no DML handles — the evaluator
 * cannot reach the database through this object by design.
 */
public class PolicyEvaluationContext {
    public final Id loanApplicationId;
    public final Map<String, Object> applicantFacts;  // Fact_Field__c API name -> value
    public final Map<String, String> evidenceStatus;  // docType -> VERIFIED | PENDING | MISSING
    public final Datetime evaluationTimestamp;

    public PolicyEvaluationContext(Id loanAppId,
                                   Map<String, Object> facts,
                                   Map<String, String> evidence) {
        if (facts == null) { facts = new Map<String, Object>(); }
        if (evidence == null) { evidence = new Map<String, String>(); }
        this.loanApplicationId = loanAppId;
        this.applicantFacts = facts.clone();      // defensive copy — context is immutable
        this.evidenceStatus = evidence.clone();
        this.evaluationTimestamp = Datetime.now();
    }
}
