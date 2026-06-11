/**
 * Tests the soft pre-check. Verifies it produces a sensible band, reflects the
 * live policy thresholds, and stays bulk-safe (one rule load for many requests).
 */
@IsTest
private class PreFlightEvaluatorTest {

    private static PreFlightEvaluator.PreFlightRequest req(Decimal income, Decimal pv, String type) {
        PreFlightEvaluator.PreFlightRequest r = new PreFlightEvaluator.PreFlightRequest();
        r.annualIncome = income;
        r.propertyValue = pv;
        r.loanType = type;
        return r;
    }

    @IsTest
    static void healthyApplicant_isLikelyEligible() {
        PolicyEngineTestFactory.standardRules();
        Test.startTest();
        List<PreFlightEvaluator.PreFlightResult> out = PreFlightEvaluator.evaluate(
            new List<PreFlightEvaluator.PreFlightRequest>{ req(150000, 400000, 'CONVENTIONAL') });
        Test.stopTest();

        System.assertEquals('LIKELY_ELIGIBLE', out[0].eligibility);
        System.assert(out[0].highEstimate > out[0].lowEstimate);
        System.assert(out[0].lowEstimate > 0);
    }

    @IsTest
    static void zeroInputs_areUnlikely() {
        List<PreFlightEvaluator.PreFlightResult> out = PreFlightEvaluator.evaluate(
            new List<PreFlightEvaluator.PreFlightRequest>{ req(0, 0, 'FHA') });
        System.assertEquals('UNLIKELY', out[0].eligibility);
        System.assertEquals(0, out[0].lowEstimate);
    }

    @IsTest
    static void lowIncomeHighProperty_isBorderline() {
        List<PreFlightEvaluator.PreFlightResult> out = PreFlightEvaluator.evaluate(
            new List<PreFlightEvaluator.PreFlightRequest>{ req(35000, 900000, 'CONVENTIONAL') });
        System.assertEquals('BORDERLINE', out[0].eligibility,
            'Income should be the binding constraint here');
    }

    @IsTest
    static void bulk_manyRequests_singleRuleLoad() {
        PolicyEngineTestFactory.standardRules();
        List<PreFlightEvaluator.PreFlightRequest> reqs = new List<PreFlightEvaluator.PreFlightRequest>();
        for (Integer i = 0; i < 200; i++) { reqs.add(req(120000, 400000, 'CONVENTIONAL')); }

        Test.startTest();
        Integer before = Limits.getQueries();
        List<PreFlightEvaluator.PreFlightResult> out = PreFlightEvaluator.evaluate(reqs);
        Integer used = Limits.getQueries() - before;
        Test.stopTest();

        System.assertEquals(200, out.size());
        System.assert(used <= 1, 'Pre-flight must load rules once for the batch, used ' + used);
    }

    @IsTest
    static void emptyRequest_returnsEmpty() {
        System.assertEquals(0,
            PreFlightEvaluator.evaluate(new List<PreFlightEvaluator.PreFlightRequest>()).size());
    }
}
