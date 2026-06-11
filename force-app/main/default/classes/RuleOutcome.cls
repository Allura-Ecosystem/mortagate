/**
 * The result of testing one Policy_Rule_Version__c against one applicant's facts.
 * Carries enough context to reconstruct the decision later — this is what makes
 * the receipt auditable: every rule, its threshold, the value tested, the verdict.
 */
public class RuleOutcome {
    public Id ruleVersionId;
    public String ruleCode;
    public Integer versionNumber;
    public String outcome;       // PASS, FAIL, INDETERMINATE
    public String severity;      // HARD_DECLINE, SOFT_DECLINE, WARNING, ADVISORY
    public String category;      // INCOME, CREDIT, COLLATERAL, COMPLIANCE, FRAUD
    public String explanation;   // human-readable, from Rule_Explanation__c
    public Object factValue;     // the actual value tested
    public Object threshold;     // what it was tested against

    public RuleOutcome(Policy_Rule_Version__c rule, String outcome, Object factValue) {
        this.ruleVersionId = rule.Id;
        this.ruleCode = rule.Rule_Code__c;
        this.versionNumber = rule.Version_Number__c == null ? null : rule.Version_Number__c.intValue();
        this.severity = rule.Severity__c;
        this.category = rule.Rule_Category__c;
        this.explanation = rule.Rule_Explanation__c;
        this.threshold = rule.Threshold_Value__c;
        this.outcome = outcome;
        this.factValue = factValue;
    }
}
