/**
 * Stateless soft pre-qualification for Screen 3 (Soft Pre-Check).
 *
 * Creates NO Loan_Application__c record. Runs the INCOME + COLLATERAL slice of
 * the governing rule set to derive a borrower-friendly eligibility band from
 * just income, property value, and loan type. Bulk-safe invocable: the rule set
 * is loaded ONCE for the whole request list.
 *
 * The band is rule-driven where rules exist (DTI/LTV thresholds are read from
 * the live policy set) and falls back to conservative defaults otherwise, so the
 * pre-check always reflects the same kernel that governs the full decision.
 */
public with sharing class PreFlightEvaluator {

    // Conservative fallbacks used only when no governing rule supplies a threshold.
    private static final Decimal DEFAULT_DTI = 0.43;
    private static final Map<String, Decimal> DEFAULT_LTV = new Map<String, Decimal>{
        'CONVENTIONAL' => 0.97, 'FHA' => 0.965, 'VA' => 1.00, 'USDA' => 1.00
    };

    // Amortization/display assumptions are CONFIG-AS-DATA (PreFlight_Assumption__mdt),
    // editable without a deployment so the band tracks the market instead of drifting
    // when rates move. The hardcoded values below are last-resort fallbacks only.
    private static final Decimal FALLBACK_RATE = 0.07;     // 7% illustrative
    private static final Integer FALLBACK_TERM = 360;      // 30-year
    private static final Decimal FALLBACK_BAND = 0.08;     // +/- 8% display range
    private static final Decimal FALLBACK_HEADROOM = 0.05; // 5% existing obligations

    @TestVisible private static Decimal assumedRate;
    @TestVisible private static Integer termMonths;
    @TestVisible private static Decimal bandWidth;
    @TestVisible private static Decimal monthlyDebtHeadroom;

    private static void loadAssumptions() {
        if (assumedRate != null) { return; } // load once per transaction
        assumedRate = FALLBACK_RATE;
        termMonths = FALLBACK_TERM;
        bandWidth = FALLBACK_BAND;
        monthlyDebtHeadroom = FALLBACK_HEADROOM;
        PreFlight_Assumption__mdt cfg = PreFlight_Assumption__mdt.getInstance('Default');
        if (cfg != null) {
            if (cfg.Annual_Rate__c != null) { assumedRate = cfg.Annual_Rate__c; }
            if (cfg.Term_Months__c != null) { termMonths = cfg.Term_Months__c.intValue(); }
            if (cfg.Band_Width__c != null) { bandWidth = cfg.Band_Width__c; }
            if (cfg.Debt_Headroom__c != null) { monthlyDebtHeadroom = cfg.Debt_Headroom__c; }
        }
    }

    @InvocableMethod(label='Pre-Flight Loan Check'
        description='Lightweight rule-driven eligibility band. Creates no Loan Application record.')
    public static List<PreFlightResult> evaluate(List<PreFlightRequest> requests) {
        List<PreFlightResult> results = new List<PreFlightResult>();
        if (requests == null || requests.isEmpty()) { return results; }

        loadAssumptions(); // config-as-data, cached; no SOQL (CMDT getInstance)

        // 1 SOQL for the whole batch.
        List<Policy_Rule_Version__c> rules = FactAssemblerService.loadGoverningRules(
            Datetime.now(), new Set<String>{ 'INCOME', 'COLLATERAL' });

        Decimal dtiCap = thresholdFor(rules, 'DTI_Ratio__c', DEFAULT_DTI);

        for (PreFlightRequest req : requests) {
            results.add(evaluateOne(req, rules, dtiCap));
        }
        return results;
    }

    private static PreFlightResult evaluateOne(PreFlightRequest req,
                                               List<Policy_Rule_Version__c> rules,
                                               Decimal dtiCap) {
        PreFlightResult res = new PreFlightResult();

        Decimal income = req.annualIncome == null ? 0 : req.annualIncome;
        Decimal propertyValue = req.propertyValue == null ? 0 : req.propertyValue;
        String loanType = String.isBlank(req.loanType) ? 'CONVENTIONAL' : req.loanType;

        Decimal ltvCap = thresholdFor(rules, 'LTV_Ratio__c',
            DEFAULT_LTV.containsKey(loanType) ? DEFAULT_LTV.get(loanType) : 0.95);

        // Capacity from income: monthly payment budget -> principal.
        Decimal monthlyIncome = income / 12;
        Decimal monthlyBudget = (monthlyIncome * dtiCap) - (monthlyIncome * monthlyDebtHeadroom);
        if (monthlyBudget < 0) { monthlyBudget = 0; }
        Decimal incomeCapacity = principalFromPayment(monthlyBudget);

        // Capacity from collateral: LTV cap * property value.
        Decimal collateralCapacity = propertyValue * ltvCap;

        Decimal maxLoan = incomeCapacity < collateralCapacity ? incomeCapacity : collateralCapacity;
        if (maxLoan < 0) { maxLoan = 0; }

        res.lowEstimate  = round1k(maxLoan * (1 - bandWidth));
        res.highEstimate = round1k(maxLoan * (1 + bandWidth));
        res.estimatedDTI = dtiCap;
        res.estimatedLTV = (propertyValue > 0) ? (maxLoan / propertyValue).setScale(4) : 0;

        // Banding: how binding is the constraint, and is there meaningful capacity?
        if (maxLoan <= 0 || income <= 0 || propertyValue <= 0) {
            res.eligibility = 'UNLIKELY';
            res.guidance = 'We need a bit more to estimate a range. A higher income or property value would help.';
        } else if (incomeCapacity < collateralCapacity * 0.6) {
            res.eligibility = 'BORDERLINE';
            res.guidance = 'Your income is the limiting factor. A co-borrower or a smaller loan may widen your options.';
        } else {
            res.eligibility = 'LIKELY_ELIGIBLE';
            // Guidance does NOT repeat the email CTA — the email label owns that ask.
            res.guidance = 'You look well within range.';
        }
        return res;
    }

    /** Standard mortgage principal from a monthly payment at the configured rate/term. */
    private static Decimal principalFromPayment(Decimal payment) {
        if (payment <= 0) { return 0; }
        Decimal r = assumedRate / 12;
        // P = M * (1 - (1+r)^-n) / r
        Double factor = (1 - Math.pow(1 + r.doubleValue(), -termMonths)) / r.doubleValue();
        return payment * Decimal.valueOf(factor);
    }

    private static Decimal thresholdFor(List<Policy_Rule_Version__c> rules,
                                        String factField, Decimal fallback) {
        for (Policy_Rule_Version__c r : rules) {
            if (r.Fact_Field__c == factField && r.Threshold_Value__c != null) {
                return r.Threshold_Value__c;
            }
        }
        return fallback;
    }

    private static Decimal round1k(Decimal v) {
        if (v == null) { return 0; }
        return (v / 1000).round(System.RoundingMode.HALF_UP) * 1000;
    }

    public class PreFlightRequest {
        @InvocableVariable(required=true) public Decimal annualIncome;
        @InvocableVariable(required=true) public Decimal propertyValue;
        @InvocableVariable(required=true) public String loanType; // CONVENTIONAL, FHA, VA, USDA
    }

    public class PreFlightResult {
        @InvocableVariable public String eligibility;   // LIKELY_ELIGIBLE, BORDERLINE, UNLIKELY
        @InvocableVariable public Decimal estimatedDTI;
        @InvocableVariable public Decimal estimatedLTV;
        @InvocableVariable public Decimal lowEstimate;
        @InvocableVariable public Decimal highEstimate;
        @InvocableVariable public String guidance;
    }
}
