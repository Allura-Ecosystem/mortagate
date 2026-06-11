/**
 * Unit tests for the pure kernel. No DML required to test evaluation logic —
 * that is the whole point of keeping the evaluator side-effect free.
 */
@IsTest
private class PolicyRuleEvaluatorTest {

    private static List<Policy_Rule_Version__c> inMemoryRules() {
        return new List<Policy_Rule_Version__c>{
            PolicyEngineTestFactory.rule('DTI_MAX', 'DTI_Ratio__c', 'LTE', 0.43, 'HARD_DECLINE'),
            PolicyEngineTestFactory.rule('LTV_MAX', 'LTV_Ratio__c', 'LTE', 0.97, 'SOFT_DECLINE'),
            PolicyEngineTestFactory.rule('EMP_MIN', 'Employment_Months__c', 'GTE', 24, 'WARNING')
        };
    }

    @IsTest
    static void allRulesPass_yieldsApproved() {
        EvaluationResult r = PolicyRuleEvaluator.evaluate(
            PolicyEngineTestFactory.context(new Map<String, Object>{
                'DTI_Ratio__c' => 0.30, 'LTV_Ratio__c' => 0.80, 'Employment_Months__c' => 60
            }), inMemoryRules());
        System.assertEquals('APPROVED', r.verdict);
        System.assertEquals(3, r.totalRulesEvaluated);
        System.assertEquals(0, r.hardDeclineCount);
    }

    @IsTest
    static void hardDecline_dominates() {
        EvaluationResult r = PolicyRuleEvaluator.evaluate(
            PolicyEngineTestFactory.context(new Map<String, Object>{
                'DTI_Ratio__c' => 0.55, 'LTV_Ratio__c' => 0.99, 'Employment_Months__c' => 6
            }), inMemoryRules());
        System.assertEquals('HARD_DECLINED', r.verdict, 'Hard decline must win over soft/warning');
        System.assertEquals(1, r.hardDeclineCount);
    }

    @IsTest
    static void softDecline_yieldsPendingReview() {
        EvaluationResult r = PolicyRuleEvaluator.evaluate(
            PolicyEngineTestFactory.context(new Map<String, Object>{
                'DTI_Ratio__c' => 0.30, 'LTV_Ratio__c' => 0.99, 'Employment_Months__c' => 60
            }), inMemoryRules());
        System.assertEquals('PENDING_REVIEW', r.verdict);
    }

    @IsTest
    static void warningOnly_yieldsApprovedWithConditions() {
        EvaluationResult r = PolicyRuleEvaluator.evaluate(
            PolicyEngineTestFactory.context(new Map<String, Object>{
                'DTI_Ratio__c' => 0.30, 'LTV_Ratio__c' => 0.80, 'Employment_Months__c' => 6
            }), inMemoryRules());
        System.assertEquals('APPROVED_WITH_CONDITIONS', r.verdict);
        System.assertEquals(1, r.warningCount);
    }

    @IsTest
    static void missingFact_isIndeterminate_notDecline() {
        EvaluationResult r = PolicyRuleEvaluator.evaluate(
            PolicyEngineTestFactory.context(new Map<String, Object>{
                'DTI_Ratio__c' => 0.30  // LTV and employment absent
            }), inMemoryRules());
        System.assertEquals('APPROVED', r.verdict, 'Absent facts must not decline');
        System.assertEquals(2, r.indeterminateCount);
    }

    @IsTest
    static void everyOperator_isExercised() {
        Map<String, Object> facts = new Map<String, Object>{ 'Annual_Income__c' => 100000 };
        System.assert(PolicyRuleEvaluator.evaluateOperator(100000, 'GT', 50000, null, null));
        System.assert(PolicyRuleEvaluator.evaluateOperator(100000, 'GTE', 100000, null, null));
        System.assert(PolicyRuleEvaluator.evaluateOperator(100000, 'LT', 200000, null, null));
        System.assert(PolicyRuleEvaluator.evaluateOperator(100000, 'LTE', 100000, null, null));
        System.assert(PolicyRuleEvaluator.evaluateOperator(100000, 'EQ', 100000, null, null));
        System.assert(PolicyRuleEvaluator.evaluateOperator(100000, 'BETWEEN', 50000, 150000, null));
        System.assert(PolicyRuleEvaluator.evaluateOperator('VA', 'IN_LIST', null, null, '["VA","FHA"]'));
        System.assert(PolicyRuleEvaluator.evaluateOperator('JUMBO', 'NOT_IN_LIST', null, null, '["VA","FHA"]'));
    }

    @IsTest
    static void unknownOperator_throws() {
        try {
            PolicyRuleEvaluator.evaluateOperator(1, 'BOGUS', 0, null, null);
            System.assert(false, 'Expected PolicyEngineException');
        } catch (PolicyEngineException e) {
            System.assert(e.getMessage().contains('Unknown operator'));
        }
    }

    @IsTest
    static void stringNumericCoercion_works() {
        System.assertEquals(0.5.setScale(1),
            PolicyRuleEvaluator.toDecimal('0.5').setScale(1));
    }

    @IsTest
    static void receiptJson_isSerializable() {
        EvaluationResult r = PolicyRuleEvaluator.evaluate(
            PolicyEngineTestFactory.context(new Map<String, Object>{ 'DTI_Ratio__c' => 0.55 }),
            inMemoryRules());
        System.assert(String.isNotBlank(r.toReceiptJson()));
        System.assertEquals('DTI_MAX explanation', r.firstDeclineReason());
    }
}
