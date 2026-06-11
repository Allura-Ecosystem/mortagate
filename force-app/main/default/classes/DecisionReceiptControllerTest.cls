/**
 * Covers the Decision Receipt PDF controller: a valid event renders with its
 * parsed rule lines, a bad/absent Id is denied cleanly, and the controller never
 * performs DML (it is a pure read of an append-only record).
 */
@IsTest
private class DecisionReceiptControllerTest {

    private static String receiptJson() {
        // Mirrors the serialized List<RuleOutcome> that DecisionCommitService writes.
        List<Map<String, Object>> rows = new List<Map<String, Object>>{
            new Map<String, Object>{
                'ruleCode' => 'DTI_MAX', 'versionNumber' => 1, 'outcome' => 'FAIL',
                'severity' => 'HARD_DECLINE', 'category' => 'INCOME',
                'explanation' => 'Debt-to-income above the current limit.',
                'factValue' => 0.51, 'threshold' => 0.43
            },
            new Map<String, Object>{
                'ruleCode' => 'FICO_MIN', 'versionNumber' => 2, 'outcome' => 'PASS',
                'severity' => 'HARD_DECLINE', 'category' => 'CREDIT',
                'explanation' => 'Credit score meets the minimum.',
                'factValue' => 720, 'threshold' => 620
            }
        };
        return JSON.serialize(rows);
    }

    private static Decision_Event__c makeEvent() {
        Loan_Application__c app = PolicyEngineTestFactory.application();
        insert app;
        Decision_Event__c e = new Decision_Event__c(
            Application__c = app.Id,
            Outcome__c = 'HARD_DECLINED',
            Rule_Results_JSON__c = receiptJson(),
            Evaluated_Rule_Count__c = 2,
            Hard_Decline_Count__c = 1,
            Decision_Timestamp__c = Datetime.now(),
            Triggered_By__c = 'SYSTEM',
            Decline_Reason__c = 'Debt-to-income above the current limit.'
        );
        insert e;
        return e;
    }

    @IsTest
    static void validEvent_rendersParsedLines() {
        Decision_Event__c e = makeEvent();
        Test.setCurrentPage(Page.DecisionReceipt);
        ApexPages.currentPage().getParameters().put('id', e.Id);

        Test.startTest();
        DecisionReceiptController ctrl = new DecisionReceiptController();
        Test.stopTest();

        System.assertEquals(false, ctrl.accessDenied, 'A valid Id must not be denied');
        System.assertNotEquals(null, ctrl.event, 'Event should load');
        System.assertEquals('HARD_DECLINED', ctrl.event.Outcome__c);
        System.assertEquals(2, ctrl.ruleLines.size(), 'Both rule rows should parse');
        System.assertEquals('DTI_MAX', ctrl.ruleLines[0].ruleCode);
        System.assertEquals('v1', ctrl.ruleLines[0].version);
        System.assert(ctrl.ruleLines[0].isFail, 'FAIL row should be flagged');
        System.assert(!ctrl.ruleLines[1].isFail, 'PASS row should not be flagged');
    }

    @IsTest
    static void missingId_isDeniedCleanly() {
        Test.setCurrentPage(Page.DecisionReceipt);
        // no id param

        Test.startTest();
        DecisionReceiptController ctrl = new DecisionReceiptController();
        Test.stopTest();

        System.assert(ctrl.accessDenied, 'No Id supplied must be denied');
        System.assertEquals(null, ctrl.event, 'No event should load');
        System.assert(String.isNotBlank(ctrl.accessMessage), 'A reason should be shown');
    }

    @IsTest
    static void malformedJson_doesNotBreakHeader() {
        Loan_Application__c app = PolicyEngineTestFactory.application();
        insert app;
        Decision_Event__c e = new Decision_Event__c(
            Application__c = app.Id,
            Outcome__c = 'APPROVED',
            Rule_Results_JSON__c = 'not-json',
            Evaluated_Rule_Count__c = 0,
            Hard_Decline_Count__c = 0,
            Decision_Timestamp__c = Datetime.now(),
            Triggered_By__c = 'SYSTEM'
        );
        insert e;

        Test.setCurrentPage(Page.DecisionReceipt);
        ApexPages.currentPage().getParameters().put('id', e.Id);

        Test.startTest();
        DecisionReceiptController ctrl = new DecisionReceiptController();
        Test.stopTest();

        System.assertEquals(false, ctrl.accessDenied, 'Header still renders');
        System.assertEquals(0, ctrl.ruleLines.size(), 'Bad JSON yields no lines, no exception');
    }
}
