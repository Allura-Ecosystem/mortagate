/**
 * Layer 2 of the policy engine — the kernel.
 *
 * A PURE FUNCTION: it takes a context and a pre-loaded governing rule set and
 * returns a verdict. It performs ZERO SOQL and ZERO DML. All database access
 * is the caller's responsibility (FactAssemblerService loads, DecisionCommitService
 * writes). That separation is what makes this class exhaustively unit-testable
 * without touching the org and bulk-safe by construction.
 *
 * Verdict precedence (worst wins):
 *   any HARD_DECLINE fail  -> HARD_DECLINED
 *   any SOFT_DECLINE fail  -> PENDING_REVIEW
 *   any WARNING fail       -> APPROVED_WITH_CONDITIONS
 *   otherwise              -> APPROVED
 */
public with sharing class PolicyRuleEvaluator {

    /**
     * @param ctx   immutable facts/evidence/timestamp
     * @param rules the governing rule set, already resolved by the caller
     *              (active, in effective window, one version per Rule_Code__c)
     */
    public static EvaluationResult evaluate(PolicyEvaluationContext ctx,
                                            List<Policy_Rule_Version__c> rules) {
        EvaluationResult result = new EvaluationResult();
        result.evaluationTimestamp = ctx.evaluationTimestamp;

        if (rules == null) { rules = new List<Policy_Rule_Version__c>(); }

        for (Policy_Rule_Version__c rule : rules) {
            result.totalRulesEvaluated++;
            Object factValue = ctx.applicantFacts.get(rule.Fact_Field__c);

            RuleOutcome outcome;
            if (factValue == null) {
                // Fact not yet available — never a decline, always indeterminate.
                outcome = new RuleOutcome(rule, 'INDETERMINATE', null);
                result.indeterminateCount++;
            } else {
                Boolean passed = evaluateOperator(
                    factValue,
                    rule.Operator__c,
                    rule.Threshold_Value__c,
                    rule.Threshold_High__c,
                    rule.Allowed_Values__c
                );
                outcome = new RuleOutcome(rule, passed ? 'PASS' : 'FAIL', factValue);
                if (!passed) {
                    tallyFailure(result, rule.Severity__c);
                }
            }
            result.triggeredRules.add(outcome);
        }

        result.verdict = deriveVerdict(result);
        return result;
    }

    private static void tallyFailure(EvaluationResult result, String severity) {
        switch on severity {
            when 'HARD_DECLINE' { result.hardDeclineCount++; }
            when 'SOFT_DECLINE' { result.softDeclineCount++; }
            when 'WARNING'      { result.warningCount++; }
            when else           { /* ADVISORY failures do not affect verdict */ }
        }
    }

    private static String deriveVerdict(EvaluationResult result) {
        if (result.hardDeclineCount > 0) { return 'HARD_DECLINED'; }
        if (result.softDeclineCount > 0) { return 'PENDING_REVIEW'; }
        if (result.warningCount > 0)     { return 'APPROVED_WITH_CONDITIONS'; }
        return 'APPROVED';
    }

    /**
     * The operator dispatch. Comparisons are numeric for the relational
     * operators and string-membership for the list operators, mirroring the
     * Operator__c picklist in BLUEPRINT §B6.
     */
    @TestVisible
    private static Boolean evaluateOperator(Object factValue, String operator,
                                            Decimal threshold, Decimal thresholdHigh,
                                            String allowedValuesJson) {
        switch on operator {
            when 'GT'  { return toDecimal(factValue) > threshold; }
            when 'GTE' { return toDecimal(factValue) >= threshold; }
            when 'LT'  { return toDecimal(factValue) < threshold; }
            when 'LTE' { return toDecimal(factValue) <= threshold; }
            when 'EQ'  { return toDecimal(factValue) == threshold; }
            when 'BETWEEN' {
                Decimal v = toDecimal(factValue);
                return v >= threshold && v <= thresholdHigh;
            }
            when 'IN_LIST' {
                return parseList(allowedValuesJson).contains(String.valueOf(factValue));
            }
            when 'NOT_IN_LIST' {
                return !parseList(allowedValuesJson).contains(String.valueOf(factValue));
            }
            when else {
                throw new PolicyEngineException('Unknown operator: ' + operator);
            }
        }
    }

    private static Set<String> parseList(String json) {
        if (String.isBlank(json)) { return new Set<String>(); }
        try {
            List<Object> raw = (List<Object>) System.JSON.deserializeUntyped(json);
            Set<String> out = new Set<String>();
            for (Object o : raw) { out.add(String.valueOf(o)); }
            return out;
        } catch (Exception e) {
            throw new PolicyEngineException('Malformed Allowed_Values__c JSON: ' + e.getMessage());
        }
    }

    @TestVisible
    private static Decimal toDecimal(Object value) {
        if (value == null) { return null; }
        if (value instanceof Decimal)  { return (Decimal) value; }
        if (value instanceof Integer)  { return Decimal.valueOf((Integer) value); }
        if (value instanceof Long)     { return Decimal.valueOf((Long) value); }
        if (value instanceof Double)   { return Decimal.valueOf((Double) value); }
        if (value instanceof String) {
            String s = (String) value;
            if (String.isBlank(s)) { return null; }
            return Decimal.valueOf(s);
        }
        throw new PolicyEngineException('Fact value is not numeric: ' + value);
    }
}
