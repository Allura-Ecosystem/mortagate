/**
 * Shared test data builders for the policy engine. Keeps tests terse and the
 * rule/fact setup in one place so kernel changes have a single fixture to update.
 */
@IsTest
public class PolicyEngineTestFactory {

    /** A governing rule. Defaults make a passing INCOME/WARNING rule; override as needed. */
    public static Policy_Rule_Version__c rule(String code, String factField, String op,
                                              Decimal threshold, String severity) {
        return new Policy_Rule_Version__c(
            Rule_Code__c = code,
            Rule_Label__c = code,
            Rule_Category__c = 'INCOME',
            Fact_Field__c = factField,
            Operator__c = op,
            Threshold_Value__c = threshold,
            Severity__c = severity,
            Rule_Explanation__c = code + ' explanation',
            Effective_Date__c = Date.today().addDays(-30),
            Version_Number__c = 1,
            Is_Active__c = true
        );
    }

    /** Insert a standard, realistic governing rule set covering each severity tier. */
    public static List<Policy_Rule_Version__c> standardRules() {
        List<Policy_Rule_Version__c> rules = new List<Policy_Rule_Version__c>{
            rule('DTI_MAX', 'DTI_Ratio__c', 'LTE', 0.43, 'HARD_DECLINE'),
            rule('LTV_CONVENTIONAL', 'LTV_Ratio__c', 'LTE', 0.97, 'SOFT_DECLINE'),
            rule('FICO_MIN', 'FICO_Score__c', 'GTE', 620, 'HARD_DECLINE'),
            rule('EMPLOYMENT_MIN', 'Employment_Months__c', 'GTE', 24, 'WARNING'),
            rule('INCOME_MIN', 'Annual_Income__c', 'GTE', 30000, 'SOFT_DECLINE')
        };
        rules[1].Rule_Category__c = 'COLLATERAL';
        rules[2].Rule_Category__c = 'CREDIT';
        insert rules;
        return rules;
    }

    /** A clean, fully-passing fact map against standardRules(). */
    public static Map<String, Object> passingFacts() {
        return new Map<String, Object>{
            'DTI_Ratio__c' => 0.35,
            'LTV_Ratio__c' => 0.80,
            'FICO_Score__c' => 740,
            'Employment_Months__c' => 60,
            'Annual_Income__c' => 120000
        };
    }

    public static PolicyEvaluationContext context(Map<String, Object> facts) {
        return new PolicyEvaluationContext(null, facts, new Map<String, String>());
    }

    public static Loan_Application__c application() {
        return new Loan_Application__c(
            Status__c = 'IN_REVIEW',
            Purpose__c = 'PURCHASE',
            Property_Value__c = 500000,
            Requested_Amount__c = 400000,
            Annual_Income__c = 120000,
            Current_Stage__c = 'REVIEW',
            Loan_Type__c = 'CONVENTIONAL'
        );
    }

    public static Extracted_Facts__c facts(Id appId, Decimal dti, Integer fico, Decimal ltv) {
        return new Extracted_Facts__c(
            Application__c = appId,
            Fact_Type__c = 'CREDIT',
            DTI_Ratio__c = dti,
            FICO_Score__c = fico,
            LTV_Ratio__c = ltv,
            Employment_Months__c = 60,
            Annual_Income__c = 120000,
            Extracted_Date__c = Datetime.now()
        );
    }
}
