/**
 * AnalyticsControllerTest — proves the portfolio analytics aggregate over the
 * LATEST replay batch (R-11) across open cases for the canonical Sabir Sr. case.
 *
 * Coverage (PNB):
 *   Positive — open Sabir case replayed once: 10 current checks, 2 fails =>
 *              violationRate 20%, one approver-drift row; missing-evidence
 *              count reflects an Open Documentation finding.
 *   R-11     — a twice-replayed case still aggregates ONE batch (10 checks, not
 *              20; 2 fails, not 4).
 *   Negative — empty org (no open cases) yields zeroed rates, no rows.
 *   Bulk     — many cases aggregate with a fixed SOQL budget (no SOQL in loops).
 */
@IsTest
private class AnalyticsControllerTest {

    @TestSetup
    static void seed() {
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
            Loan_Application__c       = 'a0000000000SGN1',
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

    // ── Positive: one open case, replayed once ──

    @IsTest
    static void getAnalytics_openCase_aggregatesLatestBatch() {
        Id caseId = sabirCaseId();
        ReplayService.replay(caseId);

        Test.startTest();
        AnalyticsController.AnalyticsView v = AnalyticsController.getAnalytics();
        Test.stopTest();

        System.assertEquals(1, v.openCaseCount, 'One open case');
        System.assertEquals(10, v.totalChecks, '10 current checks');
        System.assertEquals(20, v.violationRate, '2 of 10 fail => 20%');
        System.assertEquals(20, v.exceptionRate, '2 of 10 not-pass => 20%');
        System.assertEquals(1, v.approverDrift.size(), 'One approver-drift row');
        System.assertEquals(2, v.approverDrift[0].failCount, 'DTI_MAX + DTI_WARN');
        System.assertEquals(20, v.approverDrift[0].failRate);
    }

    @IsTest
    static void getAnalytics_countsMissingEvidenceFindings() {
        Id caseId = sabirCaseId();
        ReplayService.replay(caseId);
        insert new Finding__c(
            Audit_Case__c = caseId, Severity__c = 'Exception',
            Category__c = 'Documentation', Disposition__c = 'Open',
            Description__c = 'Appraisal addendum missing.');

        Test.startTest();
        AnalyticsController.AnalyticsView v = AnalyticsController.getAnalytics();
        Test.stopTest();

        System.assertEquals(1, v.missingEvidenceCount, 'One open Documentation finding');
    }

    // ── R-11: twice-replayed case aggregates ONE batch ──

    @IsTest
    static void getAnalytics_doubleReplay_countsLatestBatchOnly() {
        Id caseId = sabirCaseId();
        List<Replay_Check__c> firstBatch = ReplayService.replay(caseId);
        Datetime backdated = Datetime.now().addHours(-1);
        for (Replay_Check__c rc : firstBatch) { rc.Replay_Timestamp__c = backdated; }
        update firstBatch;
        ReplayService.replay(caseId);  // second batch

        Test.startTest();
        AnalyticsController.AnalyticsView v = AnalyticsController.getAnalytics();
        Test.stopTest();

        System.assertEquals(10, v.totalChecks, 'Latest batch only: 10, not 20');
        System.assertEquals(20, v.violationRate, 'Still 2 fails of 10, not 4 of 20');
    }

    // ── Negative: no open cases ──

    @IsTest
    static void getAnalytics_allClosed_returnsZeroed() {
        update new Audit_Case__c(Id = sabirCaseId(), Status__c = 'Closed');

        Test.startTest();
        AnalyticsController.AnalyticsView v = AnalyticsController.getAnalytics();
        Test.stopTest();

        System.assertEquals(0, v.openCaseCount);
        System.assertEquals(0, v.totalChecks);
        System.assertEquals(0, v.violationRate);
        System.assertEquals(0, v.exceptionRate);
        System.assertEquals(0, v.approverDrift.size());
    }

    // ── Bulk: many cases, fixed SOQL budget ──

    @IsTest
    static void getAnalytics_manyCases_bulkSafe() {
        Id loanId = [SELECT Id FROM Loan__c LIMIT 1].Id;
        List<Audit_Case__c> bulkCases = new List<Audit_Case__c>();
        for (Integer i = 0; i < 50; i++) {
            bulkCases.add(new Audit_Case__c(
                Loan__c = loanId,
                Loan_Application__c = 'a000bulk' + i,
                Status__c = 'In_Review',
                Risk_Tier__c = 'Medium',
                Borrower_Name_Snapshot__c = 'Bulk Borrower ' + i,
                Due_At__c = Datetime.now().addDays(10),
                Scope__c = 'Full'));
        }
        insert bulkCases;
        ReplayService.replay(sabirCaseId());

        Test.startTest();
        AnalyticsController.AnalyticsView v = AnalyticsController.getAnalytics();
        Test.stopTest();

        System.assertEquals(51, v.openCaseCount, 'All open cases counted');
        System.assert(Limits.getQueries() < 100, 'No SOQL governor blowout under bulk');
    }
}
