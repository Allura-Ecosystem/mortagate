/**
 * AuditQueueControllerTest — proves the Audit Queue data source returns the
 * right rows + metric counts, respects filters/sort/limits, and stays
 * order-independent. Seeds a small multi-status fixture (mirrors the demo
 * 5-card set) plus the canonical Sabir Sr. high-risk case.
 */
@IsTest
private class AuditQueueControllerTest {

    @TestSetup
    static void seed() {
        Id me = UserInfo.getUserId();

        // Every Audit_Case__c requires a Loan__c, so create one loan per case.
        List<Loan__c> loans = new List<Loan__c>{
            newLoan('Sabir Asheed Sr.', 380000, 'LA-558823'),
            newLoan('Yusuf Okonkwo', 284300, 'LA-557218'),
            newLoan('Rashida Calloway', 458000, 'LA-558790'),
            newLoan('Hideo Tanaka', 1875000, 'LA-559662'),
            newLoan('Eleanor Kwon', 349900, 'LA-560337')
        };
        insert loans;

        List<Audit_Case__c> cases = new List<Audit_Case__c>{
            new Audit_Case__c(
                Loan__c = loans[0].Id, Loan_Application__c = 'a01',
                Status__c = 'In_Review', Risk_Tier__c = 'High',
                Product_Type__c = 'Conventional', Branch__c = 'Durham Main',
                Loan_Amount__c = 380000, Borrower_Name_Snapshot__c = 'Sabir Asheed Sr.',
                Auditor__c = me,
                Due_At__c = Datetime.now().addDays(30)),
            // Evidence Needed
            new Audit_Case__c(
                Loan__c = loans[1].Id, Loan_Application__c = 'a02', Status__c = 'Evidence_Needed',
                Risk_Tier__c = 'Medium', Product_Type__c = 'FHA',
                Borrower_Name_Snapshot__c = 'Yusuf Okonkwo', Auditor__c = me,
                Due_At__c = Datetime.now().addDays(5)),
            // Ready for Signoff
            new Audit_Case__c(
                Loan__c = loans[2].Id, Loan_Application__c = 'a03', Status__c = 'Ready_for_Signoff',
                Risk_Tier__c = 'High', Product_Type__c = 'Conventional',
                Borrower_Name_Snapshot__c = 'Rashida Calloway',
                Due_At__c = Datetime.now().addDays(1)),
            // SLA at risk (overdue, unassigned)
            new Audit_Case__c(
                Loan__c = loans[3].Id, Loan_Application__c = 'a04', Status__c = 'In_Review',
                Risk_Tier__c = 'High', Product_Type__c = 'Conventional',
                Borrower_Name_Snapshot__c = 'Hideo Tanaka',
                Due_At__c = Datetime.now().addDays(-4)),
            // Low / clean, Closed
            new Audit_Case__c(
                Loan__c = loans[4].Id, Loan_Application__c = 'a05', Status__c = 'Closed',
                Risk_Tier__c = 'Low', Product_Type__c = 'VA',
                Borrower_Name_Snapshot__c = 'Eleanor Kwon',
                Due_At__c = Datetime.now().addDays(-1))
        };
        insert cases;
    }

    private static Loan__c newLoan(String borrower, Decimal amount, String losId) {
        return new Loan__c(
            Borrower_Name__c = borrower,
            Loan_Amount__c = amount,
            Property_Value__c = amount + 50000,
            Loan_Type__c = 'Conventional',
            Purpose__c = 'Purchase',
            Approval_Date__c = Date.newInstance(2025, 3, 15),
            LOS_Loan_Id__c = losId,
            Approver_Name__c = 'Janet Chen'
        );
    }

    @IsTest
    static void getQueue_returnsAllRows_withDerivedFields() {
        Test.startTest();
        List<AuditQueueController.AuditCaseRow> rows =
            AuditQueueController.getQueue(new AuditQueueController.AuditQueueFilters());
        Test.stopTest();

        System.assertEquals(5, rows.size(), 'All 5 seeded cases should return');

        Map<String, AuditQueueController.AuditCaseRow> byBorrower =
            new Map<String, AuditQueueController.AuditCaseRow>();
        for (AuditQueueController.AuditCaseRow r : rows) {
            byBorrower.put(r.borrowerName, r);
        }

        AuditQueueController.AuditCaseRow sabir = byBorrower.get('Sabir Asheed Sr.');
        System.assertEquals('LA-558823', sabir.loanNumber, 'Loan # from LOS_Loan_Id__c');
        System.assertEquals('High', sabir.riskTier);
        System.assertEquals('In Review', sabir.status, 'Status label de-underscored');
        System.assert(sabir.assignedToCurrentUser, 'Sabir assigned to running user');

        System.assertEquals('Met', byBorrower.get('Eleanor Kwon').slaLabel, 'Closed => Met');
        System.assertEquals('overdue', byBorrower.get('Hideo Tanaka').slaTone, 'Past due => overdue');
    }

    @IsTest
    static void getQueue_statusFilter_isApplied() {
        AuditQueueController.AuditQueueFilters f = new AuditQueueController.AuditQueueFilters();
        f.status = 'Evidence_Needed';

        Test.startTest();
        List<AuditQueueController.AuditCaseRow> rows = AuditQueueController.getQueue(f);
        Test.stopTest();

        System.assertEquals(1, rows.size(), 'Only the Evidence Needed case');
        System.assertEquals('Yusuf Okonkwo', rows[0].borrowerName);
    }

    @IsTest
    static void getQueue_myCasesOnly_filtersByAuditor() {
        AuditQueueController.AuditQueueFilters f = new AuditQueueController.AuditQueueFilters();
        f.myCasesOnly = true;

        Test.startTest();
        List<AuditQueueController.AuditCaseRow> rows = AuditQueueController.getQueue(f);
        Test.stopTest();

        System.assertEquals(2, rows.size(), 'Two cases assigned to the running user');
        for (AuditQueueController.AuditCaseRow r : rows) {
            System.assert(r.assignedToCurrentUser, 'Every row is mine');
        }
    }

    @IsTest
    static void getQueue_pageSize_isCappedAtMax() {
        AuditQueueController.AuditQueueFilters f = new AuditQueueController.AuditQueueFilters();
        f.pageSize = 9999; // exceeds MAX_LIMIT

        Test.startTest();
        List<AuditQueueController.AuditCaseRow> rows = AuditQueueController.getQueue(f);
        Test.stopTest();

        // Cap does not error and still returns the (small) fixture.
        System.assertEquals(5, rows.size());
    }

    @IsTest
    static void getQueue_nullFilters_defaultsSafely() {
        Test.startTest();
        List<AuditQueueController.AuditCaseRow> rows = AuditQueueController.getQueue(null);
        Test.stopTest();
        System.assertEquals(5, rows.size(), 'Null filters treated as no filters');
    }

    @IsTest
    static void getMetrics_countsEachCardCorrectly() {
        Test.startTest();
        AuditQueueController.AuditMetrics m = AuditQueueController.getMetrics();
        Test.stopTest();

        System.assertEquals(2, m.assignedToMe, 'Sabir + Evidence-Needed assigned to me, both open');
        System.assertEquals(3, m.highRisk, 'Sabir, Rashida, Hideo are High and not Closed');
        System.assertEquals(1, m.evidenceNeeded);
        System.assertEquals(1, m.readyForSignoff);
        // SLA at risk: due within 3 days or overdue, not Closed:
        // Rashida (+1d), Hideo (-4d). Eleanor is Closed (excluded). Yusuf +5d excluded.
        System.assertEquals(2, m.slaAtRisk);
        // QC window at risk: every seeded loan closed 2025-03-15 — long past the
        // 90-day window — so none sit in the final-14-day at-risk band.
        System.assertEquals(0, m.qcWindowAtRisk,
            'Seed anchors are all window-exceeded, none in the 0<daysLeft<=14 band');
    }

    // ── QC compliance window (Fannie Mae 90-day post-closing lens) ───────

    @IsTest
    static void getQueue_qcWindowDaysLeft_mathAndSign() {
        // Anchor dates chosen relative to today so the 90-day math is exact and
        // date-independent: daysLeft = 90 - (today - Approval_Date__c).
        Loan__c atRisk = newLoan('QC AtRisk', 300000, 'LA-QC-01');
        atRisk.Approval_Date__c = Date.today().addDays(-80);   // daysLeft = 10
        Loan__c blown = newLoan('QC Blown', 300000, 'LA-QC-02');
        blown.Approval_Date__c = Date.today().addDays(-100);   // daysLeft = -10
        Loan__c healthy = newLoan('QC Healthy', 300000, 'LA-QC-03');
        healthy.Approval_Date__c = Date.today().addDays(-10);  // daysLeft = 80
        insert new List<Loan__c>{ atRisk, blown, healthy };

        Datetime due = Datetime.now().addDays(7);
        insert new List<Audit_Case__c>{
            new Audit_Case__c(Loan__c = atRisk.Id, Loan_Application__c = 'q01',
                Status__c = 'In_Review', Risk_Tier__c = 'Medium', Due_At__c = due,
                Borrower_Name_Snapshot__c = 'QC AtRisk'),
            new Audit_Case__c(Loan__c = blown.Id, Loan_Application__c = 'q02',
                Status__c = 'In_Review', Risk_Tier__c = 'High', Due_At__c = due,
                Borrower_Name_Snapshot__c = 'QC Blown'),
            new Audit_Case__c(Loan__c = healthy.Id, Loan_Application__c = 'q03',
                Status__c = 'In_Review', Risk_Tier__c = 'Low', Due_At__c = due,
                Borrower_Name_Snapshot__c = 'QC Healthy')
        };

        Test.startTest();
        List<AuditQueueController.AuditCaseRow> rows = AuditQueueController.getQueue(null);
        Test.stopTest();

        Map<String, AuditQueueController.AuditCaseRow> byBorrower =
            new Map<String, AuditQueueController.AuditCaseRow>();
        for (AuditQueueController.AuditCaseRow r : rows) {
            byBorrower.put(r.borrowerName, r);
        }
        System.assertEquals(10, byBorrower.get('QC AtRisk').qcWindowDaysLeft, '90 - 80');
        System.assertEquals(-10, byBorrower.get('QC Blown').qcWindowDaysLeft,
            'Negative when the 90-day window is exceeded');
        System.assertEquals(80, byBorrower.get('QC Healthy').qcWindowDaysLeft, '90 - 10');
    }

    @IsTest
    static void getQueue_qcWindow_nullForClosedCase() {
        // Closed case (Eleanor Kwon, seeded) → QC clock retired → null.
        // (Approval_Date__c is org-required, so a truly anchor-less loan cannot
        // be seeded; the Closed branch is the realistic null path.)
        Test.startTest();
        List<AuditQueueController.AuditCaseRow> rows = AuditQueueController.getQueue(null);
        Test.stopTest();

        Map<String, AuditQueueController.AuditCaseRow> byBorrower =
            new Map<String, AuditQueueController.AuditCaseRow>();
        for (AuditQueueController.AuditCaseRow r : rows) {
            byBorrower.put(r.borrowerName, r);
        }
        System.assertEquals(null, byBorrower.get('Eleanor Kwon').qcWindowDaysLeft,
            'Closed case carries no live QC clock');
        // Sanity: an open seeded case DOES carry a (long-exceeded) clock.
        System.assertNotEquals(null, byBorrower.get('Sabir Asheed Sr.').qcWindowDaysLeft,
            'Open case always carries a QC clock');
    }

    @IsTest
    static void getMetrics_qcWindowAtRisk_countsFinalTwoWeeksOnly() {
        // Boundary-heavy fixture around the 0 < daysLeft <= 14 band.
        Loan__c edge14 = newLoan('QC Edge14', 300000, 'LA-QC-10');
        edge14.Approval_Date__c = Date.today().addDays(-76);  // daysLeft = 14 → counts
        Loan__c edge1 = newLoan('QC Edge1', 300000, 'LA-QC-11');
        edge1.Approval_Date__c = Date.today().addDays(-89);   // daysLeft = 1  → counts
        Loan__c edgeZero = newLoan('QC Zero', 300000, 'LA-QC-12');
        edgeZero.Approval_Date__c = Date.today().addDays(-90); // daysLeft = 0  → excluded
        Loan__c blown = newLoan('QC Blown2', 300000, 'LA-QC-13');
        blown.Approval_Date__c = Date.today().addDays(-100);  // daysLeft = -10 → excluded
        Loan__c healthy = newLoan('QC Healthy2', 300000, 'LA-QC-14');
        healthy.Approval_Date__c = Date.today().addDays(-10); // daysLeft = 80 → excluded
        Loan__c closedAtRisk = newLoan('QC Closed', 300000, 'LA-QC-15');
        closedAtRisk.Approval_Date__c = Date.today().addDays(-80); // in band but Closed → excluded
        insert new List<Loan__c>{ edge14, edge1, edgeZero, blown, healthy, closedAtRisk };

        Datetime due = Datetime.now().addDays(7);
        insert new List<Audit_Case__c>{
            new Audit_Case__c(Loan__c = edge14.Id, Loan_Application__c = 'm01', Due_At__c = due,
                Status__c = 'In_Review', Risk_Tier__c = 'Medium', Borrower_Name_Snapshot__c = 'QC Edge14'),
            new Audit_Case__c(Loan__c = edge1.Id, Loan_Application__c = 'm02', Due_At__c = due,
                Status__c = 'Evidence_Needed', Risk_Tier__c = 'High', Borrower_Name_Snapshot__c = 'QC Edge1'),
            new Audit_Case__c(Loan__c = edgeZero.Id, Loan_Application__c = 'm03', Due_At__c = due,
                Status__c = 'In_Review', Risk_Tier__c = 'Medium', Borrower_Name_Snapshot__c = 'QC Zero'),
            new Audit_Case__c(Loan__c = blown.Id, Loan_Application__c = 'm04', Due_At__c = due,
                Status__c = 'In_Review', Risk_Tier__c = 'High', Borrower_Name_Snapshot__c = 'QC Blown2'),
            new Audit_Case__c(Loan__c = healthy.Id, Loan_Application__c = 'm05', Due_At__c = due,
                Status__c = 'In_Review', Risk_Tier__c = 'Low', Borrower_Name_Snapshot__c = 'QC Healthy2'),
            new Audit_Case__c(Loan__c = closedAtRisk.Id, Loan_Application__c = 'm06', Due_At__c = due,
                Status__c = 'Closed', Risk_Tier__c = 'Medium', Borrower_Name_Snapshot__c = 'QC Closed')
        };

        Test.startTest();
        AuditQueueController.AuditMetrics m = AuditQueueController.getMetrics();
        Test.stopTest();

        // edge14 (daysLeft 14) + edge1 (daysLeft 1) count; zero/blown/healthy/closed excluded.
        // Seed cases all window-exceeded → contribute 0.
        System.assertEquals(2, m.qcWindowAtRisk,
            'Only open cases with 0 < daysLeft <= 14 count; boundaries 0 and Closed excluded');
    }
}
