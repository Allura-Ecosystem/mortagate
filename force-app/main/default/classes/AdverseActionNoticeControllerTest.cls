/**
 * Covers the Adverse Action Notice controller: a HARD_DECLINED event builds a notice
 * with specific reasons and the resolved ECOA block; a credit score on file produces
 * the FCRA disclosure; an approved event is not adverse action; a bad/absent Id is
 * denied cleanly. Pure read — no DML against the append-only event.
 */
@IsTest
private class AdverseActionNoticeControllerTest {

    private static String declineJson() {
        // Two FAIL rows (one HARD_DECLINE, one SOFT) plus a PASS that must be ignored.
        List<Map<String, Object>> rows = new List<Map<String, Object>>{
            new Map<String, Object>{
                'ruleCode' => 'DTI_MAX', 'versionNumber' => 1, 'outcome' => 'FAIL',
                'severity' => 'HARD_DECLINE', 'category' => 'INCOME',
                'explanation' => 'Your debt-to-income ratio exceeds our threshold of 43%.',
                'factValue' => 0.51, 'threshold' => 0.43
            },
            new Map<String, Object>{
                'ruleCode' => 'EMPLOYMENT_MIN', 'versionNumber' => 1, 'outcome' => 'FAIL',
                'severity' => 'WARNING', 'category' => 'INCOME',
                'explanation' => 'Your employment history is shorter than we usually require.',
                'factValue' => 8, 'threshold' => 24
            },
            new Map<String, Object>{
                'ruleCode' => 'FICO_MIN', 'versionNumber' => 1, 'outcome' => 'PASS',
                'severity' => 'HARD_DECLINE', 'category' => 'CREDIT',
                'explanation' => 'Credit score meets the minimum.',
                'factValue' => 720, 'threshold' => 620
            }
        };
        return JSON.serialize(rows);
    }

    /** Stand-in for the Default Adverse_Action_Config__mdt record (not DML-able). */
    private static AdverseActionService.Config configForTest() {
        AdverseActionService.Config c = new AdverseActionService.Config();
        c.creditorName = 'Veridact Lending';
        c.creditorAddress = '1 Market Street, Suite 400, San Francisco, CA 94105';
        c.agencyName = 'Consumer Financial Protection Bureau';
        c.agencyAddress = '1700 G Street NW, Washington, DC 20006';
        c.ecoaNoticeTemplate = 'The Federal Equal Credit Opportunity Act prohibits creditors '
            + 'from discriminating... The Federal agency that administers compliance with this '
            + 'law concerning this creditor is [AGENCY].';
        c.reasonLimit = 4;
        c.noticeWindowDays = 30;
        return c;
    }

    private static Decision_Event__c makeEvent(String outcome, String json, Id appId) {
        Decision_Event__c e = new Decision_Event__c(
            Application__c = appId,
            Outcome__c = outcome,
            Rule_Results_JSON__c = json,
            Evaluated_Rule_Count__c = 3,
            Hard_Decline_Count__c = outcome == 'HARD_DECLINED' ? 1 : 0,
            Decision_Timestamp__c = Datetime.now(),
            Triggered_By__c = 'SYSTEM',
            Decline_Reason__c = 'Your debt-to-income ratio exceeds our threshold of 43%.'
        );
        insert e;
        return e;
    }

    @IsTest
    static void declinedEvent_buildsCompliantNotice() {
        Loan_Application__c app = PolicyEngineTestFactory.application();
        insert app;
        Decision_Event__c e = makeEvent('HARD_DECLINED', declineJson(), app.Id);

        Test.setCurrentPage(Page.AdverseActionNotice);
        ApexPages.currentPage().getParameters().put('id', e.Id);

        // Inject config: custom metadata records are not DML-able in tests, so the
        // Default Adverse_Action_Config__mdt is supplied through the controller seam.
        AdverseActionNoticeController.configOverride = configForTest();

        Test.startTest();
        AdverseActionNoticeController ctrl = new AdverseActionNoticeController();
        Test.stopTest();

        System.assertEquals(false, ctrl.accessDenied, 'A valid decline must not be denied');
        System.assertNotEquals(null, ctrl.notice, 'Notice should build');
        System.assertEquals(true, ctrl.notice.isAdverseAction, 'HARD_DECLINED is adverse action');
        System.assert(ctrl.notice.reasons.size() >= 1, 'At least one specific reason');
        // HARD_DECLINE reason should be ranked first; PASS row excluded.
        System.assertEquals('DTI_MAX', ctrl.notice.reasons[0].ruleCode);
        System.assert(ctrl.notice.reasons[0].text.contains('43%'), 'Reason is specific');
        // ECOA block resolved with the Default CMDT agency.
        System.assert(!ctrl.notice.ecoaNotice.contains('[AGENCY]'), 'Agency token resolved');
        System.assert(String.isNotBlank(ctrl.notice.creditorName), 'Creditor identity from config');
    }

    @IsTest
    static void creditScoreOnFile_producesDisclosure() {
        Loan_Application__c app = PolicyEngineTestFactory.application();
        insert app;
        insert PolicyEngineTestFactory.facts(app.Id, 0.51, 612, 0.80);
        Decision_Event__c e = makeEvent('HARD_DECLINED', declineJson(), app.Id);

        Test.setCurrentPage(Page.AdverseActionNotice);
        ApexPages.currentPage().getParameters().put('id', e.Id);

        Test.startTest();
        AdverseActionNoticeController ctrl = new AdverseActionNoticeController();
        Test.stopTest();

        System.assertEquals(true, ctrl.notice.creditScoreDisclosed, 'FICO on file -> disclosed');
        System.assertEquals(612, ctrl.notice.creditScore);
        System.assert(ctrl.notice.scoreDisclosure.contains('612'), 'Score appears in disclosure');
    }

    @IsTest
    static void approvedEvent_isNotAdverseAction() {
        Loan_Application__c app = PolicyEngineTestFactory.application();
        insert app;
        Decision_Event__c e = makeEvent('APPROVED', '[]', app.Id);

        Test.setCurrentPage(Page.AdverseActionNotice);
        ApexPages.currentPage().getParameters().put('id', e.Id);

        Test.startTest();
        AdverseActionNoticeController ctrl = new AdverseActionNoticeController();
        Test.stopTest();

        System.assertEquals(false, ctrl.accessDenied);
        System.assertEquals(false, ctrl.notice.isAdverseAction, 'APPROVED is not adverse action');
    }

    @IsTest
    static void missingId_isDeniedCleanly() {
        Test.setCurrentPage(Page.AdverseActionNotice);
        // no id param

        Test.startTest();
        AdverseActionNoticeController ctrl = new AdverseActionNoticeController();
        Test.stopTest();

        System.assert(ctrl.accessDenied, 'No Id supplied must be denied');
        System.assertEquals(null, ctrl.notice, 'No notice should build');
        System.assert(String.isNotBlank(ctrl.accessMessage), 'A reason should be shown');
    }

    @IsTest
    static void malformedJson_doesNotBreakNotice() {
        Loan_Application__c app = PolicyEngineTestFactory.application();
        insert app;
        Decision_Event__c e = makeEvent('HARD_DECLINED', 'not-json', app.Id);

        Test.setCurrentPage(Page.AdverseActionNotice);
        ApexPages.currentPage().getParameters().put('id', e.Id);

        Test.startTest();
        AdverseActionNoticeController ctrl = new AdverseActionNoticeController();
        Test.stopTest();

        System.assertEquals(false, ctrl.accessDenied, 'Notice still renders');
        System.assertEquals(0, ctrl.notice.reasons.size(), 'Bad JSON yields no reasons, no exception');
        System.assertEquals(true, ctrl.notice.isAdverseAction, 'Still an adverse action');
    }
}
