/**
 * PolicyRuleEvaluator — UNIFIED policy kernel (forward decision + audit replay).
 *
 * ┌───────────────────────────────────────────────────────────────────────────┐
 * │ PROPOSED MERGE — review artifact, NOT yet the deployed class.               │
 * │ This file reconciles the two hard-forked copies of PolicyRuleEvaluator:     │
 * │   • canonical/git (Brooks engine) — forward decision: evaluate() →          │
 * │     EvaluationResult, generic operator dispatch.                            │
 * │   • org (audit-pivot)            — audit replay: replayRules() →            │
 * │     List<Rule_Check__c>, rule-by-rule historical re-evaluation.             │
 * │ The two share ONLY the class name — zero method/symbol collisions — so the  │
 * │ reconciliation is a clean UNION. See PolicyRuleEvaluator-merge-notes.md.    │
 * └───────────────────────────────────────────────────────────────────────────┘
 *
 * Both halves are PURE FUNCTIONS: ZERO SOQL, ZERO DML. All database access is the
 * caller's responsibility (FactAssembler/FactAssemblerService load; commit services
 * write). That separation keeps the class exhaustively unit-testable and bulk-safe.
 *
 * ── Path 1: FORWARD DECISION (engine) ───────────────────────────────────────
 *   evaluate(PolicyEvaluationContext, List<Policy_Rule_Version__c>) → EvaluationResult
 *   Verdict precedence (worst wins):
 *     any HARD_DECLINE fail -> HARD_DECLINED
 *     any SOFT_DECLINE fail -> PENDING_REVIEW
 *     any WARNING fail      -> APPROVED_WITH_CONDITIONS
 *     otherwise             -> APPROVED
 *   Depends on companion engine types: PolicyEvaluationContext, EvaluationResult,
 *   RuleOutcome, PolicyEngineException (must be present in the target org).
 *
 * ── Path 2: AUDIT REPLAY (audit-queue) ──────────────────────────────────────
 *   replayRules(List<Reconstructed_Fact__c>, Policy_Rule_Version__c, Id) → List<Rule_Check__c>
 *   Evaluates a loan against the EXACT policy version active at original approval.
 *   Depends on audit objects: Reconstructed_Fact__c, Rule_Check__c, Policy_Rule_Version__c.
 *
 * Field dependency note: the forward path reads Threshold_Value__c / Threshold_High__c /
 * Allowed_Values__c / Operator__c / Fact_Field__c / Severity__c; the replay path reads
 * DTI_Threshold__c / Min_Credit_Score__c / HITL_Credit_Threshold__c /
 * Max_Loan_No_Escalation__c / Fact_Type__c / Value__c. Policy_Rule_Version__c in the org
 * is a confirmed SUPERSET carrying BOTH field sets, so this unified class compiles
 * against the complete object with no schema change required.
 *
 * @group Policy Engine + Audit Replay Kernel
 */
public with sharing class PolicyRuleEvaluator {

    // =========================================================================
    // Shared inner type (from the audit-replay path)
    // =========================================================================

    /** Result of evaluating a single rule (DTO form, used by replayRulesAsResults). */
    public class RuleCheckResult {
        public String ruleName;
        public String outcome;     // Pass, Exception, Violation, Unverifiable
        public String rationale;
        public String factType;
        public String factValue;
        public String threshold;

        public RuleCheckResult(String ruleName, String outcome, String rationale) {
            this.ruleName = ruleName;
            this.outcome = outcome;
            this.rationale = rationale;
        }
    }

    // =========================================================================
    // PATH 1 — FORWARD DECISION (canonical/Brooks engine)
    // =========================================================================

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

    // =========================================================================
    // PATH 2 — AUDIT REPLAY (audit-queue)
    // =========================================================================

    /**
     * Replay all policy rules against the reconstructed facts using
     * the historical policy version.
     *
     * PURE FUNCTION — no SOQL, no DML, no side effects.
     *
     * @param facts          Reconstructed facts for the audit case
     * @param policyVersion  The historical policy version record (all threshold fields populated)
     * @param auditCaseId    The audit case Id (for building Rule_Check__c records)
     * @return List of Rule_Check__c records (NOT yet inserted)
     */
    public static List<Rule_Check__c> replayRules(
        List<Reconstructed_Fact__c> facts,
        Policy_Rule_Version__c policyVersion,
        Id auditCaseId
    ) {
        Map<String, Reconstructed_Fact__c> factsByType = new Map<String, Reconstructed_Fact__c>();
        for (Reconstructed_Fact__c fact : facts) {
            factsByType.put(fact.Fact_Type__c, fact);
        }

        List<Rule_Check__c> checks = new List<Rule_Check__c>();

        checks.add(evaluateDTI(factsByType, policyVersion, auditCaseId));
        checks.add(evaluateCreditScore(factsByType, policyVersion, auditCaseId));

        if (policyVersion.HITL_Credit_Threshold__c != null) {
            checks.add(evaluateHITLCredit(factsByType, policyVersion, auditCaseId));
        }
        if (policyVersion.Max_Loan_No_Escalation__c != null) {
            checks.add(evaluateLoanEscalation(factsByType, policyVersion, auditCaseId));
        }

        return checks;
    }

    /**
     * Convenience overload returning RuleCheckResult DTOs instead of SObjects.
     * Useful for unit testing the pure logic without SObject dependencies.
     */
    public static List<RuleCheckResult> replayRulesAsResults(
        List<Reconstructed_Fact__c> facts,
        Policy_Rule_Version__c policyVersion
    ) {
        Map<String, Reconstructed_Fact__c> factsByType = new Map<String, Reconstructed_Fact__c>();
        for (Reconstructed_Fact__c fact : facts) {
            factsByType.put(fact.Fact_Type__c, fact);
        }

        List<RuleCheckResult> results = new List<RuleCheckResult>();

        Reconstructed_Fact__c dtiFact = factsByType.get('DTI');
        if (isUnverifiable(dtiFact)) {
            results.add(new RuleCheckResult('DTI Threshold', 'Unverifiable',
                'DTI fact not available or unverifiable from evidence.'));
        } else {
            Decimal dti = Decimal.valueOf(dtiFact.Value__c);
            Decimal threshold = policyVersion.DTI_Threshold__c;
            if (dti <= threshold) {
                results.add(new RuleCheckResult('DTI Threshold', 'Pass',
                    'DTI ' + dti + ' <= threshold ' + threshold + '.'));
            } else {
                results.add(new RuleCheckResult('DTI Threshold', 'Violation',
                    'DTI ' + dti + ' exceeds threshold ' + threshold + '.'));
            }
        }

        Reconstructed_Fact__c creditFact = factsByType.get('Credit_Score');
        if (isUnverifiable(creditFact)) {
            results.add(new RuleCheckResult('Min Credit Score', 'Unverifiable',
                'Credit score fact not available or unverifiable.'));
        } else {
            Decimal score = Decimal.valueOf(creditFact.Value__c);
            Decimal minScore = policyVersion.Min_Credit_Score__c;
            if (score >= minScore) {
                results.add(new RuleCheckResult('Min Credit Score', 'Pass',
                    'Credit score ' + score + ' >= minimum ' + minScore + '.'));
            } else {
                results.add(new RuleCheckResult('Min Credit Score', 'Violation',
                    'Credit score ' + score + ' below minimum ' + minScore + '.'));
            }
        }

        return results;
    }

    /**
     * Check if a fact value is parseable as a number.
     * Returns true for null, UNVERIFIABLE, PENDING_EXTRACTION, or non-numeric strings.
     */
    private static Boolean isUnverifiable(Reconstructed_Fact__c fact) {
        if (fact == null) return true;
        String val = fact.Value__c;
        if (String.isBlank(val) || val == 'UNVERIFIABLE' || val == 'PENDING_EXTRACTION') return true;
        try {
            Decimal.valueOf(val);
            return false;
        } catch (Exception e) {
            return true;
        }
    }

    // ---------------------------------------------------------------
    // Private rule evaluators — each returns a single Rule_Check__c
    // ---------------------------------------------------------------

    private static Rule_Check__c evaluateDTI(
        Map<String, Reconstructed_Fact__c> factsByType,
        Policy_Rule_Version__c policy,
        Id auditCaseId
    ) {
        Rule_Check__c check = new Rule_Check__c(
            Audit_Case__c = auditCaseId,
            Policy_Rule_Version__c = String.valueOf(policy.Id),
            Rule_Name__c = 'DTI Threshold'
        );

        Reconstructed_Fact__c dtiFact = factsByType.get('DTI');
        if (isUnverifiable(dtiFact)) {
            check.Outcome__c = 'Unverifiable';
            setRationale(check, 'DTI fact not available or unverifiable from evidence.');
            return check;
        }

        Decimal dti = Decimal.valueOf(dtiFact.Value__c);
        Decimal threshold = policy.DTI_Threshold__c;

        if (dti <= threshold) {
            check.Outcome__c = 'Pass';
            setRationale(check, 'DTI ' + dti + ' <= threshold ' + threshold + '. Pass.');
        } else {
            check.Outcome__c = 'Violation';
            setRationale(check, 'DTI ' + dti + ' exceeds threshold ' + threshold + '. Violation.');
        }

        return check;
    }

    private static Rule_Check__c evaluateCreditScore(
        Map<String, Reconstructed_Fact__c> factsByType,
        Policy_Rule_Version__c policy,
        Id auditCaseId
    ) {
        Rule_Check__c check = new Rule_Check__c(
            Audit_Case__c = auditCaseId,
            Policy_Rule_Version__c = String.valueOf(policy.Id),
            Rule_Name__c = 'Min Credit Score'
        );

        Reconstructed_Fact__c creditFact = factsByType.get('Credit_Score');
        if (isUnverifiable(creditFact)) {
            check.Outcome__c = 'Unverifiable';
            setRationale(check, 'Credit score fact not available or unverifiable.');
            return check;
        }

        Decimal score = Decimal.valueOf(creditFact.Value__c);
        Decimal minScore = policy.Min_Credit_Score__c;

        if (score >= minScore) {
            check.Outcome__c = 'Pass';
            setRationale(check, 'Credit score ' + score + ' >= minimum ' + minScore + '. Pass.');
        } else {
            check.Outcome__c = 'Violation';
            setRationale(check, 'Credit score ' + score + ' below minimum ' + minScore + '. Violation.');
        }

        return check;
    }

    private static Rule_Check__c evaluateHITLCredit(
        Map<String, Reconstructed_Fact__c> factsByType,
        Policy_Rule_Version__c policy,
        Id auditCaseId
    ) {
        Rule_Check__c check = new Rule_Check__c(
            Audit_Case__c = auditCaseId,
            Policy_Rule_Version__c = String.valueOf(policy.Id),
            Rule_Name__c = 'HITL Credit Threshold'
        );

        Reconstructed_Fact__c creditFact = factsByType.get('Credit_Score');
        if (isUnverifiable(creditFact)) {
            check.Outcome__c = 'Unverifiable';
            setRationale(check, 'Credit score fact not available for HITL evaluation.');
            return check;
        }

        Decimal score = Decimal.valueOf(creditFact.Value__c);
        Decimal hitlThreshold = policy.HITL_Credit_Threshold__c;

        if (score >= hitlThreshold) {
            check.Outcome__c = 'Pass';
            setRationale(check, 'Credit score ' + score + ' >= HITL threshold ' + hitlThreshold + '. No HITL review required.');
        } else {
            check.Outcome__c = 'Exception';
            setRationale(check, 'Credit score ' + score + ' < HITL threshold ' + hitlThreshold + '. Should have been routed for human review.');
        }

        return check;
    }

    private static Rule_Check__c evaluateLoanEscalation(
        Map<String, Reconstructed_Fact__c> factsByType,
        Policy_Rule_Version__c policy,
        Id auditCaseId
    ) {
        Rule_Check__c check = new Rule_Check__c(
            Audit_Case__c = auditCaseId,
            Policy_Rule_Version__c = String.valueOf(policy.Id),
            Rule_Name__c = 'Loan Escalation Threshold'
        );

        Reconstructed_Fact__c loanFact = factsByType.get('Loan_Amount');
        if (isUnverifiable(loanFact)) {
            check.Outcome__c = 'Unverifiable';
            setRationale(check, 'Loan amount fact not available or unverifiable.');
            return check;
        }

        Decimal amount = Decimal.valueOf(loanFact.Value__c);
        Decimal maxNoEscalation = policy.Max_Loan_No_Escalation__c;

        if (amount <= maxNoEscalation) {
            check.Outcome__c = 'Pass';
            setRationale(check, 'Loan amount ' + amount + ' <= escalation threshold ' + maxNoEscalation + '. No escalation required.');
        } else {
            check.Outcome__c = 'Exception';
            setRationale(check, 'Loan amount ' + amount + ' > escalation threshold ' + maxNoEscalation + '. Should have been escalated.');
        }

        return check;
    }

    /**
     * Safely set Rationale__c on a Rule_Check__c.
     * Uses dynamic field put so the class compiles and runs even if
     * Rationale__c is not yet deployed to the target org.
     */
    private static void setRationale(Rule_Check__c check, String rationale) {
        try {
            check.put('Rationale__c', rationale);
        } catch (SObjectException e) {
            // Rationale__c field not deployed to org yet — skip silently
        }
    }
}
