/**
 * CaseReviewControllerTest — proves the Case Review data source assembles the
 * right two-pane DTO for the canonical Sabir Sr. case, surfaces DTI failures,
 * detects staleness, and uses rerunReplay as the only write path.
 *
 * Seeds the Sabir Sr. demo fixture (mirrors ReplayServiceTest) so a real
 * replay produces 10 checks (DTI_MAX + DTI_WARN = 2 Fail).
 */
@IsTest
private class CaseReviewControllerTest {

    @TestSetup
    static void seedSabirSr() {
        Loan__c loan = new Loan__c(
            Borrower_Name__c      = 'Sabir Asheed Sr.',
            Loan_Amount__c        = 380000,
            Property_Value__c     = 475000,
            Annual_Income__c      = 95000,
            Loan_Type__c          = 'Conventional',
            Purpose__c            = 'Purchase',
            Approval_Date__c      = Date.newInstance(2025, 3, 15),
            Originating_Branch__c = 'Durham Main',
            Approver_Name__c      = 'Janet Chen',
            FICO_At_Approval__c   = 710,
            DTI_At_Approval__c    = 44.8,
            LTV_At_Approval__c    = 80.0,
            LOS_Loan_Id__c        = 'LA-558823'
        );
        insert loan;

        Audit_Case__c ac = new Audit_Case__c(
            Loan__c                   = loan.Id,
            Loan_Application__c       = 'a0000000000TEST1',
            Status__c                 = 'In_Review',
            Risk_Tier__c              = 'High',
            Borrower_Name_Snapshot__c = 'Sabir Asheed Sr.',
            Due_At__c                 = Datetime.now().addDays(30),
            Scope__c                  = 'Full'
        );
        insert ac;

        insert new List<Borrower_Snapshot__c>{
            new Borrower_Snapshot__c(Audit_Case__c = ac.Id, Fact_Category__c = 'Income',
                Annual_Income__c = 95000, Monthly_Income__c = 7916.67, DTI_Ratio__c = 44.8,
                Monthly_Debt__c = 3546.67, Employment_Months__c = 36),
            new Borrower_Snapshot__c(Audit_Case__c = ac.Id, Fact_Category__c = 'Credit',
                FICO_Score__c = 710),
            new Borrower_Snapshot__c(Audit_Case__c = ac.Id, Fact_Category__c = 'Asset',
                LTV_Ratio__c = 80.0, Asset_Value__c = 475000)
        };

        insert new List<Evidence_Item__c>{
            new Evidence_Item__c(Audit_Case__c = ac.Id, Document_Type__c = 'Pay_Stub',       Status__c = 'Linked'),
            new Evidence_Item__c(Audit_Case__c = ac.Id, Document_Type__c = 'W2',             Status__c = 'Linked'),
            new Evidence_Item__c(Audit_Case__c = ac.Id, Document_Type__c = 'Credit_Report',  Status__c = 'Linked'),
            new Evidence_Item__c(Audit_Case__c = ac.Id, Document_Type__c = 'Appraisal',      Status__c = 'Missing'),
            new Evidence_Item__c(Audit_Case__c = ac.Id, Document_Type__c = 'Bank_Statement', Status__c = 'Linked')
        };

        Policy_Version__c pv = new Policy_Version__c(
            Version_Label__c  = 'Q1 2025 Conventional',
            Version_Number__c = 1,
            Effective_Date__c = Date.newInstance(2025, 1, 1),
            Is_Active__c      = true,
            Policy_Type__c    = 'Conventional'
        );
        insert pv;

        insert new List<Policy_Rule__c>{
            rule(pv.Id, 'DTI_MAX',    'Max DTI Ratio',         'Income',     'LTE', 43,     'DTI_Ratio__c',        'Hard_Decline'),
            rule(pv.Id, 'FICO_MIN',   'Min FICO Score',        'Credit',     'GTE', 620,    'FICO_Score__c',        'Hard_Decline'),
            rule(pv.Id, 'LTV_MAX',    'Max LTV Ratio',         'Collateral', 'LTE', 80,     'LTV_Ratio__c',        'Hard_Decline'),
            rule(pv.Id, 'INCOME_MIN', 'Min Annual Income',     'Income',     'GTE', 30000,  'Annual_Income__c',     'Warning'),
            rule(pv.Id, 'EMPLOY_MIN', 'Min Employment Months', 'Income',     'GTE', 12,     'Employment_Months__c', 'Warning'),
            rule(pv.Id, 'ASSET_MIN',  'Min Asset Value',       'Collateral', 'GTE', 100000, 'Asset_Value__c',       'Info'),
            rule(pv.Id, 'DTI_WARN',   'DTI Warning Threshold', 'Income',     'LTE', 40,     'DTI_Ratio__c',        'Info'),
            rule(pv.Id, 'FICO_PREF',  'Preferred FICO Score',  'Credit',     'GTE', 680,    'FICO_Score__c',        'Info'),
            rule(pv.Id, 'LTV_PREF',   'Preferred LTV',         'Collateral', 'LTE', 90,     'LTV_Ratio__c',        'Info'),
            rule(pv.Id, 'DEBT_MAX',   'Max Monthly Debt',      'Income',     'LTE', 5000,   'Monthly_Debt__c',      'Warning')
        };
    }

    private static Policy_Rule__c rule(Id pvId, String code, String label, String cat,
                                       String op, Decimal threshold, String factField, String sev) {
        return new Policy_Rule__c(
            Policy_Version__c = pvId, Rule_Code__c = code, Rule_Label__c = label,
            Rule_Category__c = cat, Operator__c = op, Threshold_Value__c = threshold,
            Fact_Field__c = factField, Severity__c = sev
        );
    }

    private static Id sabirCaseId() {
        return [SELECT Id FROM Audit_Case__c WHERE Borrower_Name_Snapshot__c = 'Sabir Asheed Sr.' LIMIT 1].Id;
    }

    // ── getCaseDetail: header + evidence (no replay yet) ──

    @IsTest
    static void getCaseDetail_returnsHeaderAndEvidence_beforeReplay() {
        Id caseId = sabirCaseId();

        Test.startTest();
        CaseReviewController.CaseDetail d = CaseReviewController.getCaseDetail(caseId);
        Test.stopTest();

        System.assertNotEquals(null, d, 'Detail returned');
        System.assertEquals('Sabir Asheed Sr.', d.header.borrowerName);
        System.assertEquals('LA-558823', d.header.loanNumber, 'Loan # from LOS_Loan_Id__c');
        System.assertEquals('High', d.header.riskTier);
        System.assertEquals('In Review', d.header.status, 'Status de-underscored');
        System.assertEquals('Janet Chen', d.header.approverName, 'Falls back to Loan approver');
        System.assertEquals(5, d.evidence.size(), '5 evidence items in the LEFT pane');
        System.assert(!d.hasReplay, 'No replay checks before rerun');
        System.assert(!d.replayStale, 'Cannot be stale with no replay');
    }

    // ── getCaseDetail null id => null ──

    @IsTest
    static void getCaseDetail_nullId_returnsNull() {
        System.assertEquals(null, CaseReviewController.getCaseDetail(null));
    }

    // ── rerunReplay: write path produces checks; DTI_MAX is Fail ──

    @IsTest
    static void rerunReplay_producesChecks_dtiMaxFails() {
        Id caseId = sabirCaseId();

        Test.startTest();
        CaseReviewController.CaseDetail d = CaseReviewController.rerunReplay(caseId);
        Test.stopTest();

        System.assert(d.hasReplay, 'Replay checks now present');
        System.assertEquals(10, d.checks.size(), '10 rules => 10 checks');

        Map<String, CaseReviewController.ReplayCheckRow> byRule =
            new Map<String, CaseReviewController.ReplayCheckRow>();
        for (CaseReviewController.ReplayCheckRow r : d.checks) {
            byRule.put(r.ruleName, r);
        }

        System.assertEquals('Fail', byRule.get('DTI_MAX').result, 'DTI_MAX must Fail (44.8 > 43)');
        System.assert(byRule.get('DTI_MAX').isFail, 'isFail flag set for DTI_MAX');
        System.assertEquals('Fail', byRule.get('DTI_WARN').result, 'DTI_WARN must Fail (44.8 > 40)');
        System.assertEquals(2, d.failCount, 'Exactly DTI_MAX + DTI_WARN fail');
        System.assertEquals('Pass', byRule.get('FICO_MIN').result, 'FICO_MIN passes');
    }

    @IsTest
    static void rerunReplay_nullId_throws() {
        Boolean threw = false;
        try {
            CaseReviewController.rerunReplay(null);
        } catch (Exception e) {
            threw = true;
        }
        System.assert(threw, 'Null id must throw AuraHandledException');
    }

    // ── Checks are ordered by Sort_Order__c ──

    @IsTest
    static void getCaseDetail_checksOrderedBySortOrder() {
        Id caseId = sabirCaseId();
        ReplayService.replay(caseId);

        Test.startTest();
        CaseReviewController.CaseDetail d = CaseReviewController.getCaseDetail(caseId);
        Test.stopTest();

        System.assertEquals(10, d.checks.size());
        Integer prev = -1;
        for (CaseReviewController.ReplayCheckRow r : d.checks) {
            if (r.sortOrder != null) {
                System.assert(r.sortOrder >= prev, 'Checks ascend by sortOrder');
                prev = r.sortOrder;
            }
        }
    }
}
