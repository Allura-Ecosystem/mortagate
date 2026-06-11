/**
 * End-to-end engine tests including the BULK SAFETY proof Brooks reserved
 * confidence for: 200 applications decided inside one transaction without
 * breaching SOQL/DML governor limits, demonstrating the 3 SOQL + 1 DML contract
 * scales independently of record count.
 */
@IsTest
private class LoanDecisionServiceTest {

    @IsTest
    static void endToEnd_approvedPath() {
        PolicyEngineTestFactory.standardRules();
        Loan_Application__c app = PolicyEngineTestFactory.application();
        insert app;
        insert PolicyEngineTestFactory.facts(app.Id, 0.30, 740, 0.80);

        Test.startTest();
        Decision_Event__c event = LoanDecisionService.decideOne(app.Id);
        Test.stopTest();

        System.assertEquals('APPROVED', event.Outcome__c);
        System.assertNotEquals(null, event.Rule_Version__c);
        System.assert(event.Evaluated_Rule_Count__c > 0);
    }

    @IsTest
    static void endToEnd_hardDeclinePath_capturesReason() {
        PolicyEngineTestFactory.standardRules();
        Loan_Application__c app = PolicyEngineTestFactory.application();
        insert app;
        insert PolicyEngineTestFactory.facts(app.Id, 0.55, 740, 0.80); // DTI over 0.43

        Test.startTest();
        Decision_Event__c event = LoanDecisionService.decideOne(app.Id);
        Test.stopTest();

        System.assertEquals('HARD_DECLINED', event.Outcome__c);
        System.assertEquals(1, event.Hard_Decline_Count__c);
        System.assert(String.isNotBlank(event.Decline_Reason__c));
    }

    @IsTest
    static void bulk_200Applications_withinGovernorLimits() {
        PolicyEngineTestFactory.standardRules();

        List<Loan_Application__c> apps = new List<Loan_Application__c>();
        for (Integer i = 0; i < 200; i++) { apps.add(PolicyEngineTestFactory.application()); }
        insert apps;

        List<Extracted_Facts__c> facts = new List<Extracted_Facts__c>();
        Set<Id> appIds = new Set<Id>();
        for (Loan_Application__c a : apps) {
            appIds.add(a.Id);
            // Alternate clean vs. over-DTI to exercise both branches in bulk.
            Decimal dti = Math.mod(appIds.size(), 2) == 0 ? 0.30 : 0.55;
            facts.add(PolicyEngineTestFactory.facts(a.Id, dti, 740, 0.80));
        }
        insert facts;

        Test.startTest();
        Integer soqlBefore = Limits.getQueries();
        Integer dmlBefore = Limits.getDmlStatements();
        List<Decision_Event__c> events = LoanDecisionService.decide(appIds, 'SYSTEM');
        Integer soqlUsed = Limits.getQueries() - soqlBefore;
        Integer dmlUsed = Limits.getDmlStatements() - dmlBefore;
        Test.stopTest();

        System.assertEquals(200, events.size(), 'One decision per application');
        // The contract: a fixed query/DML budget regardless of N.
        System.assert(soqlUsed <= 3, 'Expected <=3 SOQL for the whole batch, used ' + soqlUsed);
        System.assert(dmlUsed <= 1, 'Expected <=1 DML for the whole batch, used ' + dmlUsed);
    }

    @IsTest
    static void factAssembler_buildsContext() {
        Loan_Application__c app = PolicyEngineTestFactory.application();
        insert app;
        insert PolicyEngineTestFactory.facts(app.Id, 0.30, 740, 0.80);
        insert new Evidence__c(
            Application__c = app.Id, Document_Type__c = 'PAY_STUB',
            Content_Version_Id__c = '068000000000000AAA',
            Upload_Date__c = Datetime.now(), Extraction_Status__c = 'COMPLETED');

        Test.startTest();
        PolicyEvaluationContext ctx = FactAssemblerService.assembleOne(app.Id);
        Test.stopTest();

        System.assertEquals(0.30, (Decimal) ctx.applicantFacts.get('DTI_Ratio__c'));
        System.assertEquals('VERIFIED', ctx.evidenceStatus.get('PAY_STUB'));
    }

    @IsTest
    static void flowEntryPoint_returnsOutcome() {
        PolicyEngineTestFactory.standardRules();
        Loan_Application__c app = PolicyEngineTestFactory.application();
        insert app;
        insert PolicyEngineTestFactory.facts(app.Id, 0.30, 740, 0.80);

        LoanDecisionService.DecisionFlowRequest req = new LoanDecisionService.DecisionFlowRequest();
        req.applicationId = app.Id;
        req.triggeredBy = 'RE_EVALUATION';

        Test.startTest();
        List<LoanDecisionService.DecisionFlowResult> out =
            LoanDecisionService.decideFromFlow(new List<LoanDecisionService.DecisionFlowRequest>{ req });
        Test.stopTest();

        System.assertEquals('APPROVED', out[0].outcome);
        System.assertNotEquals(null, out[0].decisionEventId);
    }
}
