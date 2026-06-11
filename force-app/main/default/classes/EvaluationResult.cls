/**
 * The verdict plus the full set of per-rule outcomes that produced it.
 * Pure data — produced by PolicyRuleEvaluator, consumed by DecisionCommitService.
 * Nothing here touches the database.
 */
public class EvaluationResult {
    public String verdict;        // APPROVED, APPROVED_WITH_CONDITIONS, PENDING_REVIEW, HARD_DECLINED
    public List<RuleOutcome> triggeredRules;
    public Integer totalRulesEvaluated;
    public Integer hardDeclineCount;
    public Integer softDeclineCount;
    public Integer warningCount;
    public Integer indeterminateCount;
    public Datetime evaluationTimestamp;

    public EvaluationResult() {
        this.triggeredRules = new List<RuleOutcome>();
        this.totalRulesEvaluated = 0;
        this.hardDeclineCount = 0;
        this.softDeclineCount = 0;
        this.warningCount = 0;
        this.indeterminateCount = 0;
    }

    /** Serializes the complete set of outcomes — the audit receipt body. */
    public String toReceiptJson() {
        return JSON.serializePretty(this.triggeredRules);
    }

    /** First human-readable explanation among failing rules, for borrower display. */
    public String firstDeclineReason() {
        for (RuleOutcome ro : triggeredRules) {
            if (ro.outcome == 'FAIL' && String.isNotBlank(ro.explanation)) {
                return ro.explanation;
            }
        }
        return null;
    }
}
