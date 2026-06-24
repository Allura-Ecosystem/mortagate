/**
 * SignoffControllerTest — proves the Sign-off Receipt data source + sole write
 * path for the canonical Sabir Sr. case.
 *
 * Coverage (PNB):
 *   Positive — getReceipt previews latest-batch counts; signOff inserts ONE
 *              immutable receipt (Violation_Count__c = 2), closes the case, logs
 *              a Case_Signed_Off event.
 *   Negative — null id, case not ready, and a second signOff are all rejected;
 *              the receipt stays immutable.
 *   R-11     — a TWICE-replayed case signs ONE batch's counts (2 violations,
 *              not 4).
 */
@IsTest
private class SignoffControllerTest {

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
            Loan_Application__c       = 'a0000000000SGN1',
            Status__c                 = 'Ready_for_Signoff',
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

    // ── getReceipt: preview before sign-off ──

    @IsTest
    static void getReceipt_previewsLatestBatchCounts_noReceiptYet() {
        Id caseId = sabirCaseId();
        ReplayService.replay(caseId);

        Test.startTest();
        SignoffController.SignoffView v = SignoffController.getReceipt(caseId);
        Test.stopTest();

        System.assertNotEquals(null, v, 'View returned');
        System.assertEquals('Sabir Asheed Sr.', v.borrowerName);
        System.assert(v.isReadyForSignoff, 'Case is Ready_for_Signoff');
        System.assert(v.hasReplay, 'Replay checks present for preview');
        System.assertEquals(2, v.violationCount, 'DTI_MAX + DTI_WARN = 2 violations');
        System.assertEquals(8, v.passCount, '8 passes');
        System.assertEquals(0, v.unverifiableCount, 'No unverifiable checks');
        System.assertEquals(null, v.receipt, 'No receipt before sign-off');
    }

    @IsTest
    static void getReceipt_nullId_returnsNull() {
        System.assertEquals(null, SignoffController.getReceipt(null));
    }

    // ── signOff: positive — one immutable receipt, case closed, event logged ──

    @IsTest
    static void signOff_createsOneImmutableReceipt_andClosesCase() {
        Id caseId = sabirCaseId();
        ReplayService.replay(caseId);

        Test.startTest();
        SignoffController.SignoffView v = SignoffController.signOff(caseId);
        Test.stopTest();

        // Exactly one receipt with the latest-batch counts.
        List<Audit_Receipt__c> receipts = [
            SELECT Pass_Count__c, Violation_Count__c, Exception_Count__c,
                   Total_Findings__c, Receipt_Hash__c, Signed_Off_At__c
            FROM Audit_Receipt__c WHERE Audit_Case__c = :caseId
        ];
        System.assertEquals(1, receipts.size(), 'Exactly one receipt');
        System.assertEquals(2, receipts[0].Violation_Count__c, 'Violation_Count__c = 2');
        System.assertEquals(8, receipts[0].Pass_Count__c, 'Pass_Count__c = 8');
        System.assertEquals(0, receipts[0].Exception_Count__c, 'Exception_Count__c = 0');
        System.assertNotEquals(null, receipts[0].Receipt_Hash__c, 'Demo hash populated');
        System.assertEquals(64, receipts[0].Receipt_Hash__c.length(), 'SHA-256 hex length');

        // Case closed + sign-off fields stamped.
        Audit_Case__c ac = [SELECT Status__c, Signed_Off_At__c, Signed_Off_By__c
                            FROM Audit_Case__c WHERE Id = :caseId];
        System.assertEquals('Closed', ac.Status__c, 'Case closed on sign-off');
        System.assertNotEquals(null, ac.Signed_Off_At__c, 'Signed_Off_At__c stamped');
        System.assertEquals(UserInfo.getUserId(), ac.Signed_Off_By__c, 'Signed_Off_By__c stamped');

        // View reflects the signed receipt.
        System.assertNotEquals(null, v.receipt, 'View carries the signed receipt');
        System.assertEquals(2, v.receipt.violationCount);

        // Governed event logged.
        System.assertEquals(1,
            [SELECT COUNT() FROM Audit_Event__c
             WHERE Audit_Case__c = :caseId AND Event_Type__c = 'Case_Signed_Off'],
            'One Case_Signed_Off event');
    }

    // ── signOff: negative — null, not ready, second sign-off ──

    @IsTest
    static void signOff_nullId_throws() {
        Boolean threw = false;
        try { SignoffController.signOff(null); }
        catch (Exception e) { threw = true; }
        System.assert(threw, 'Null id must throw');
    }

    @IsTest
    static void signOff_caseNotReady_isRejected() {
        Id caseId = sabirCaseId();
        ReplayService.replay(caseId);
        update new Audit_Case__c(Id = caseId, Status__c = 'In_Review');

        Boolean threw = false;
        Test.startTest();
        try { SignoffController.signOff(caseId); }
        catch (AuraHandledException e) { threw = true; }
        Test.stopTest();

        System.assert(threw, 'A non-ready case cannot be signed off');
        System.assertEquals(0,
            [SELECT COUNT() FROM Audit_Receipt__c WHERE Audit_Case__c = :caseId],
            'No receipt created for a rejected sign-off');
    }

    @IsTest
    static void signOff_secondAttempt_isRejected_receiptImmutable() {
        Id caseId = sabirCaseId();
        ReplayService.replay(caseId);
        SignoffController.signOff(caseId);  // first — succeeds

        Boolean threw = false;
        Test.startTest();
        try { SignoffController.signOff(caseId); }
        catch (AuraHandledException e) { threw = true; }
        Test.stopTest();

        System.assert(threw, 'A second sign-off must be rejected');
        System.assertEquals(1,
            [SELECT COUNT() FROM Audit_Receipt__c WHERE Audit_Case__c = :caseId],
            'Still exactly one immutable receipt');
    }

    // ── R-11: a twice-replayed case signs ONE batch's counts ──

    @IsTest
    static void signOff_doubleReplay_countsLatestBatchOnly() {
        Id caseId = sabirCaseId();

        List<Replay_Check__c> firstBatch = ReplayService.replay(caseId);
        Datetime backdated = Datetime.now().addHours(-1);
        for (Replay_Check__c rc : firstBatch) { rc.Replay_Timestamp__c = backdated; }
        update firstBatch;
        ReplayService.replay(caseId);  // second batch

        System.assertEquals(20,
            [SELECT COUNT() FROM Replay_Check__c WHERE Audit_Case__c = :caseId],
            'Both append-only batches persist');

        Test.startTest();
        SignoffController.signOff(caseId);
        Test.stopTest();

        Audit_Receipt__c r = [SELECT Pass_Count__c, Violation_Count__c
                              FROM Audit_Receipt__c WHERE Audit_Case__c = :caseId];
        System.assertEquals(2, r.Violation_Count__c,
            'Receipt counts ONE batch (2 violations), not the stacked 4');
        System.assertEquals(8, r.Pass_Count__c, 'One batch of passes (8), not 16');
    }
}
