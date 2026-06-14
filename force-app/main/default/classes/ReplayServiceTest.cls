/**
 * ReplayServiceTest — PNB coverage for ReplayService orchestrator.
 *
 * P = Positive: Sabir Sr. end-to-end replay (10 rules, 1 Fail DTI, 9 Pass)
 * N = Negative: case with no borrower snapshot returns empty gracefully
 * B = Budget: verify SOQL and DML within governor budget
 *
 * @group Audit Replay Kernel
 */
@IsTest
private class ReplayServiceTest {

    // ─── Seed Data ─────────────────────────────────────────────────────

    /**
     * Build the Sabir Sr. demo case:
     *   Loan: $380K conventional, DTI 44.8%, FICO 710, LTV 80%
     *   Policy: Q1 2025 Conventional with 10 rules
     *   Evidence: 5 items (4 Linked, 1 Missing)
     */
    @TestSetup
    static void seedSabirSr() {
        // Loan
        Loan__c loan = new Loan__c(
            Borrower_Name__c       = 'Sabir Asheed Sr.',
            Loan_Amount__c         = 380000,
            Property_Value__c      = 475000,
            Annual_Income__c       = 95000,
            Loan_Type__c           = 'Conventional',
            Purpose__c             = 'Purchase',
            Approval_Date__c       = Date.newInstance(2025, 3, 15),
            Originating_Branch__c  = 'Durham Main',
            Approver_Name__c       = 'Janet Chen',
            FICO_At_Approval__c    = 710,
            DTI_At_Approval__c     = 44.8,
            LTV_At_Approval__c     = 80.0
        );
        insert loan;

        // Audit Case
        Audit_Case__c ac = new Audit_Case__c(
            Loan__c             = loan.Id,
            Loan_Application__c = 'a0000000000TEST1',
            Status__c           = 'In_Review',
            Risk_Tier__c        = 'High',
            Due_At__c           = Datetime.now().addDays(30),
            Scope__c            = 'Full'
        );
        insert ac;

        // Borrower Snapshot — income facts
        Borrower_Snapshot__c bsIncome = new Borrower_Snapshot__c(
            Audit_Case__c       = ac.Id,
            Fact_Category__c    = 'Income',
            Annual_Income__c    = 95000,
            Monthly_Income__c   = 7916.67,
            DTI_Ratio__c        = 44.8,
            Monthly_Debt__c     = 3546.67,
            Employment_Months__c = 36
        );
        // Borrower Snapshot — credit facts
        Borrower_Snapshot__c bsCredit = new Borrower_Snapshot__c(
            Audit_Case__c       = ac.Id,
            Fact_Category__c    = 'Credit',
            FICO_Score__c       = 710
        );
        // Borrower Snapshot — collateral facts
        Borrower_Snapshot__c bsCollateral = new Borrower_Snapshot__c(
            Audit_Case__c       = ac.Id,
            Fact_Category__c    = 'Collateral',
            LTV_Ratio__c        = 80.0,
            Asset_Value__c      = 475000
        );
        insert new List<Borrower_Snapshot__c>{ bsIncome, bsCredit, bsCollateral };

        // Evidence Items
        insert new List<Evidence_Item__c>{
            new Evidence_Item__c(Audit_Case__c = ac.Id, Document_Type__c = 'Pay_Stub', Status__c = 'Linked'),
            new Evidence_Item__c(Audit_Case__c = ac.Id, Document_Type__c = 'W2', Status__c = 'Linked'),
            new Evidence_Item__c(Audit_Case__c = ac.Id, Document_Type__c = 'Credit_Report', Status__c = 'Linked'),
            new Evidence_Item__c(Audit_Case__c = ac.Id, Document_Type__c = 'Appraisal', Status__c = 'Missing'),
            new Evidence_Item__c(Audit_Case__c = ac.Id, Document_Type__c = 'Bank_Statement', Status__c = 'Linked')
        };

        // Policy Version — Q1 2025 Conventional
        Policy_Version__c pv = new Policy_Version__c(
            Version_Label__c   = 'Q1 2025 Conventional',
            Version_Number__c  = 1,
            Effective_Date__c  = Date.newInstance(2025, 1, 1),
            Is_Active__c       = true,
            Policy_Type__c     = 'Conventional'
        );
        insert pv;

        // 10 Policy Rules
        List<Policy_Rule__c> rules = new List<Policy_Rule__c>();
        // Rule 0: DTI_MAX — Sabir fails this (44.8 > 43)
        rules.add(buildRule(pv.Id, 'DTI_MAX', 'Max DTI Ratio', 'Income', 'LTE', 43, null, 'DTI_Ratio__c', 'Hard_Decline', 0));
        // Rule 1: FICO_MIN — Sabir passes (710 >= 620)
        rules.add(buildRule(pv.Id, 'FICO_MIN', 'Min FICO Score', 'Credit', 'GTE', 620, null, 'FICO_Score__c', 'Hard_Decline', 1));
        // Rule 2: LTV_MAX — Sabir passes (80 <= 80)
        rules.add(buildRule(pv.Id, 'LTV_MAX', 'Max LTV Ratio', 'Collateral', 'LTE', 80, null, 'LTV_Ratio__c', 'Hard_Decline', 2));
        // Rule 3: INCOME_MIN — Sabir passes (95000 >= 30000)
        rules.add(buildRule(pv.Id, 'INCOME_MIN', 'Min Annual Income', 'Income', 'GTE', 30000, null, 'Annual_Income__c', 'Warning', 3));
        // Rule 4: EMPLOY_MIN — Sabir passes (36 >= 12)
        rules.add(buildRule(pv.Id, 'EMPLOY_MIN', 'Min Employment Months', 'Income', 'GTE', 12, null, 'Employment_Months__c', 'Warning', 4));
        // Rule 5: ASSET_MIN — Sabir passes (475000 >= 100000)
        rules.add(buildRule(pv.Id, 'ASSET_MIN', 'Min Asset Value', 'Collateral', 'GTE', 100000, null, 'Asset_Value__c', 'Info', 5));
        // Rule 6: DTI_WARNING — Sabir fails this too (44.8 > 40) but info
        rules.add(buildRule(pv.Id, 'DTI_WARN', 'DTI Warning Threshold', 'Income', 'LTE', 40, null, 'DTI_Ratio__c', 'Info', 6));
        // Rule 7: FICO_PREFERRED — Sabir passes (710 >= 680)
        rules.add(buildRule(pv.Id, 'FICO_PREF', 'Preferred FICO Score', 'Credit', 'GTE', 680, null, 'FICO_Score__c', 'Info', 7));
        // Rule 8: LTV_PREFERRED — Sabir passes (80 <= 90)
        rules.add(buildRule(pv.Id, 'LTV_PREF', 'Preferred LTV', 'Collateral', 'LTE', 90, null, 'LTV_Ratio__c', 'Info', 8));
        // Rule 9: DEBT_MAX — Sabir passes (3546.67 <= 5000)
        rules.add(buildRule(pv.Id, 'DEBT_MAX', 'Max Monthly Debt', 'Income', 'LTE', 5000, null, 'Monthly_Debt__c', 'Warning', 9));
        insert rules;
    }

    private static Policy_Rule__c buildRule(
        Id pvId, String code, String label, String category,
        String op, Decimal threshold, Decimal thresholdHigh,
        String factField, String severity, Integer sortOrder
    ) {
        return new Policy_Rule__c(
            Policy_Version__c  = pvId,
            Rule_Code__c       = code,
            Rule_Label__c      = label,
            Rule_Category__c   = category,
            Operator__c        = op,
            Threshold_Value__c = threshold,
            Threshold_High__c  = thresholdHigh,
            Fact_Field__c      = factField,
            Severity__c        = severity,
            Sort_Order__c      = sortOrder
        );
    }

    private static Audit_Case__c getSabirCase() {
        return [SELECT Id FROM Audit_Case__c LIMIT 1];
    }

    // ─── P: Positive — Sabir Sr. end-to-end ────────────────────────────

    @IsTest
    static void positive_sabirSr_produces10ChecksAnd1Event() {
        Audit_Case__c ac = getSabirCase();

        Test.startTest();
        List<Replay_Check__c> checks = ReplayService.replay(ac.Id);
        Test.stopTest();

        // 10 replay checks
        System.assertEquals(10, checks.size(), 'Expected 10 replay checks for Sabir Sr.');

        // Verify checks in DB
        List<Replay_Check__c> dbChecks = [
            SELECT Rule_Name__c, Result__c, Expected_Value__c, Actual_Value__c,
                   Sort_Order__c
            FROM Replay_Check__c
            WHERE Audit_Case__c = :ac.Id
            ORDER BY Sort_Order__c ASC
        ];
        System.assertEquals(10, dbChecks.size());

        // DTI_MAX should Fail (44.8 vs 43 LTE)
        Replay_Check__c dti = dbChecks[0];
        System.assertEquals('DTI_MAX', dti.Rule_Name__c);
        System.assertEquals('FAIL', dti.Result__c);
        System.assertEquals('43', dti.Expected_Value__c);

        // FICO_MIN should Pass (710 vs 620 GTE)
        Replay_Check__c fico = dbChecks[1];
        System.assertEquals('FICO_MIN', fico.Rule_Name__c);
        System.assertEquals('PASS', fico.Result__c);

        // Verify Audit_Event__c
        List<Audit_Event__c> events = [
            SELECT Event_Type__c
            FROM Audit_Event__c
            WHERE Audit_Case__c = :ac.Id
            AND Event_Type__c = 'Replay_Executed'
        ];
        System.assertEquals(1, events.size(), 'Expected 1 Replay_Executed event');
    }

    // ─── N: Negative — case with no snapshot ───────────────────────────

    @IsTest
    static void negative_noSnapshot_returnsEmptyGracefully() {
        // Create a bare case with a loan but no borrower snapshots
        Loan__c loan = new Loan__c(
            Borrower_Name__c  = 'Empty Case Borrower',
            Loan_Amount__c    = 200000,
            Property_Value__c = 250000,
            Loan_Type__c      = 'Conventional',
            Purpose__c        = 'Purchase',
            Approval_Date__c  = Date.newInstance(2025, 3, 15)
        );
        insert loan;

        Audit_Case__c emptyCase = new Audit_Case__c(
            Loan__c             = loan.Id,
            Loan_Application__c = 'a0000000000TEST2',
            Status__c           = 'In_Review',
            Risk_Tier__c        = 'Medium',
            Due_At__c           = Datetime.now().addDays(30)
        );
        insert emptyCase;

        Test.startTest();
        List<Replay_Check__c> checks = ReplayService.replay(emptyCase.Id);
        Test.stopTest();

        // All rules should evaluate with no matching facts → INDETERMINATE
        // (the evaluator treats missing facts as INDETERMINATE, not failure)
        for (Replay_Check__c rc : [
            SELECT Result__c FROM Replay_Check__c WHERE Audit_Case__c = :emptyCase.Id
        ]) {
            System.assertEquals('INDETERMINATE', rc.Result__c,
                'Missing facts should produce INDETERMINATE');
        }
    }

    // ─── B: Budget — verify SOQL and DML within limits ─────────────────

    @IsTest
    static void budget_sabirSr_within3Soql2Dml() {
        Audit_Case__c ac = getSabirCase();

        Test.startTest();
        Integer soqlBefore = Limits.getQueries();
        Integer dmlBefore = Limits.getDmlStatements();

        ReplayService.replay(ac.Id);

        Integer soqlUsed = Limits.getQueries() - soqlBefore;
        Integer dmlUsed = Limits.getDmlStatements() - dmlBefore;
        Test.stopTest();

        System.assert(soqlUsed <= 3,
            'Expected at most 3 SOQL, got ' + soqlUsed);
        System.assert(dmlUsed <= 2,
            'Expected at most 2 DML, got ' + dmlUsed);
    }
}
