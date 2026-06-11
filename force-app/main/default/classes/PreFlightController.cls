/**
 * Thin @AuraEnabled bridge so the c-pre-check-result LWC can call the same
 * kernel that governs the full decision. No business logic lives here — it
 * delegates to PreFlightEvaluator so the band the borrower sees on screen is
 * produced by the real policy rules, not a parallel guess.
 */
public with sharing class PreFlightController {

    @AuraEnabled(cacheable=false)
    public static Map<String, Object> getBand(Decimal annualIncome,
                                              Decimal propertyValue,
                                              String loanType) {
        PreFlightEvaluator.PreFlightRequest req = new PreFlightEvaluator.PreFlightRequest();
        req.annualIncome = annualIncome;
        req.propertyValue = propertyValue;
        req.loanType = String.isBlank(loanType) ? 'CONVENTIONAL' : loanType;

        List<PreFlightEvaluator.PreFlightResult> results =
            PreFlightEvaluator.evaluate(new List<PreFlightEvaluator.PreFlightRequest>{ req });

        if (results.isEmpty()) {
            throw new AuraHandledException('Unable to evaluate pre-check at this time.');
        }
        PreFlightEvaluator.PreFlightResult r = results[0];
        return new Map<String, Object>{
            'eligibility' => r.eligibility,
            'lowEstimate' => r.lowEstimate,
            'highEstimate' => r.highEstimate,
            'estimatedDTI' => r.estimatedDTI,
            'estimatedLTV' => r.estimatedLTV,
            'guidance' => r.guidance
        };
    }
}
