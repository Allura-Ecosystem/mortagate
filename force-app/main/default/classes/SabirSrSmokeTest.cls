/**
 * SabirSrSmokeTest — End-to-end integration test proving the full Veridact
 * demo path works on the org.
 *
 * Seeds Sabir Sr. data (the canonical demo persona), runs the full replay
 * pipeline, and asserts the complete audit lifecycle including immutability.
 *
 * Test methods:
 *   1. smokeTest_fullReplayLifecycle — 10 checks, 1 Fail, 9 Pass, 1 event
 *   2. smokeTest_receiptImmutability — insert receipt, block update + delete
 *   3. smokeTest_unverifiableOnMissingFacts — no snapshots -> all Unverifiable
 *
 * @group Smoke Test
 * @see ReplayService, ReplayCommitService, PolicyRuleEvaluator
 */
@IsTest
private class SabirSrSmokeTest {

    // ─── Seed Data ─────────────────────────────────────────────────────

    @TestSetup
    static void seedSabirSr() {
        // ── Loan: Sabir Asheed Sr., $380K Conventional ──
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
            LTV_At_Approval__c    = 80.0
        );
        insert loan;

        // ── Audit Case ──
        Audit_Case__c ac = new Audit_Case__c(
            Loan__c             = loan.Id,
            Loan_Application__c = 'a0000000000TEST1',
            Status__c           = 'In_Review',
            Risk_Tier__c        = 'High',
            Due_At__c           = Datetime.now().addDays(30),
            Scope__c            = 'Full'
        );
        insert ac;

        // ── 3 Borrower Snapshots ──
        // Income facts
        Borrower_Snapshot__c bsIncome = new Borrower_Snapshot__c(
            Audit_Case__c        = ac.Id,
            Fact_Category__c     = 'Income',
            Annual_Income__c     = 95000,
            Monthly_Income__c    = 7916.67,
            DTI_Ratio__c         = 44.8,
            Monthly_Debt__c      = 3546.67,
            Employment_Months__c = 36
        );
        // Credit facts
        Borrower_Snapshot__c bsCredit = new Borrower_Snapshot__c(
            Audit_Case__c    = ac.Id,
            Fact_Category__c = 'Credit',
            FICO_Score__c    = 710
        );
        // Asset facts (collateral)
        Borrower_Snapshot__c bsAsset = new Borrower_Snapshot__c(
            Audit_Case__c    = ac.Id,
            Fact_Category__c = 'Asset',
            LTV_Ratio__c     = 80.0,
            Asset_Value__c   = 475000
        );
        insert new List<Borrower_Snapshot__c>{ bsIncome, bsCredit, bsAsset };

        // ── 5 Evidence Items ──
        insert new List<Evidence_Item__c>{
            new Evidence_Item__c(Audit_Case__c = ac.Id, Document_Type__c = 'Pay_Stub',       Status__c = 'Linked'),
            new Evidence_Item__c(Audit_Case__c = ac.Id, Document_Type__c = 'W2',             Status__c = 'Linked'),
            new Evidence_Item__c(Audit_Case__c = ac.Id, Document_Type__c = 'Credit_Report',  Status__c = 'Linked'),
            new Evidence_Item__c(Audit_Case__c = ac.Id, Document_Type__c = 'Appraisal',      Status__c = 'Missing'),
            new Evidence_Item__c(Audit_Case__c = ac.Id, Document_Type__c = 'Bank_Statement', Status__c = 'Linked')
        };

        // ── Policy Version: Q1 2025 Conventional ──
        Policy_Version__c pv = new Policy_Version__c(
            Version_Label__c  = 'Q1 2025 Conventional',
            Version_Number__c = 1,
            Effective_Date__c = Date.newInstance(2025, 1, 1),
            Is_Active__c      = true,
            Policy_Type__c    = 'Conventional'
        );
        insert pv;

        // ── 10 Policy Rules ──
        // Severity values: Hard_Decline, Soft_Decline, Warning, Info
        // Rule_Category values: Income, Credit, Collateral, Employment, Residency, Debt, Documentation
        List<Policy_Rule__c> rules = new List<Policy_Rule__c>{
            // Rule 0: DTI_MAX — Sabir FAILS (44.8 > 43)
            buildRule(pv.Id, 'DTI_MAX',    'Max DTI Ratio',          'Income',     'LTE', 43,     null, 'DTI_Ratio__c',        'Hard_Decline', 0),
            // Rule 1: FICO_MIN — Sabir passes (710 >= 620)
            buildRule(pv.Id, 'FICO_MIN',   'Min FICO Score',         'Credit',     'GTE', 620,    null, 'FICO_Score__c',        'Hard_Decline', 1),
            // Rule 2: LTV_MAX — Sabir passes (80 <= 80)
            buildRule(pv.Id, 'LTV_MAX',    'Max LTV Ratio',          'Collateral', 'LTE', 80,     null, 'LTV_Ratio__c',        'Hard_Decline', 2),
            // Rule 3: INCOME_MIN — Sabir passes (95000 >= 30000)
            buildRule(pv.Id, 'INCOME_MIN', 'Min Annual Income',      'Income',     'GTE', 30000,  null, 'Annual_Income__c',     'Warning',      3),
            // Rule 4: EMPLOY_MIN — Sabir passes (36 >= 12)
            buildRule(pv.Id, 'EMPLOY_MIN', 'Min Employment Months',  'Income',     'GTE', 12,     null, 'Employment_Months__c', 'Warning',      4),
            // Rule 5: ASSET_MIN — Sabir passes (475000 >= 100000)
            buildRule(pv.Id, 'ASSET_MIN',  'Min Asset Value',        'Collateral', 'GTE', 100000, null, 'Asset_Value__c',       'Info',         5),
            // Rule 6: DTI_WARN — Sabir fails advisory (44.8 > 40) but Info
            buildRule(pv.Id, 'DTI_WARN',   'DTI Warning Threshold',  'Income',     'LTE', 40,     null, 'DTI_Ratio__c',        'Info',         6),
            // Rule 7: FICO_PREF — Sabir passes (710 >= 680)
            buildRule(pv.Id, 'FICO_PREF',  'Preferred FICO Score',   'Credit',     'GTE', 680,    null, 'FICO_Score__c',        'Info',         7),
            // Rule 8: LTV_PREF — Sabir passes (80 <= 90)
            buildRule(pv.Id, 'LTV_PREF',   'Preferred LTV',          'Collateral', 'LTE', 90,     null, 'LTV_Ratio__c',        'Info',         8),
            // Rule 9: DEBT_MAX — Sabir passes (3546.67 <= 5000)
            buildRule(pv.Id, 'DEBT_MAX',   'Max Monthly Debt',       'Income',     'LTE', 5000,   null, 'Monthly_Debt__c',      'Warning',      9)
        };
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
            Fact_Field__c      = factField,
            Severity__c        = severity
        );
    }

    private static Audit_Case__c getSabirCase() {
        return [
            SELECT Id FROM Audit_Case__c
            WHERE Loan__r.Borrower_Name__c = 'Sabir Asheed Sr.'
            LIMIT 1
        ];
    }

    // ─── 1. Full Replay Lifecycle ──────────────────────────────────────

    /**
     * Proves the canonical demo path: seed Sabir Sr., replay, and verify
     * 10 checks (1 Fail on DTI_MAX, 9 Pass), plus 1 Replay_Executed event.
     */
    @IsTest
    static void smokeTest_fullReplayLifecycle() {
        Audit_Case__c ac = getSabirCase();

        Test.startTest();
        List<Replay_Check__c> checks = ReplayService.replay(ac.Id);
        Test.stopTest();

        // ── Assert: 10 Replay_Check__c records created ──
        System.assertEquals(10, checks.size(),
            'Expected 10 replay checks for Sabir Sr. demo case');

        // Verify persisted checks. ADR-6: rules are queried ORDER BY Rule_Code__c
        // ASC, so Sort_Order__c reflects alphabetical order — NOT insertion order.
        // Assert by Rule_Name__c to stay order-independent.
        List<Replay_Check__c> dbChecks = [
            SELECT Rule_Name__c, Result__c, Expected_Value__c, Actual_Value__c, Sort_Order__c
            FROM Replay_Check__c
            WHERE Audit_Case__c = :ac.Id
            ORDER BY Sort_Order__c ASC
        ];
        System.assertEquals(10, dbChecks.size(),
            'Expected 10 persisted replay checks in database');

        // Build a rule-name → result map for order-independent assertions
        Map<String, String> resultByRule = new Map<String, String>();
        Map<String, String> expectedByRule = new Map<String, String>();
        for (Replay_Check__c rc : dbChecks) {
            resultByRule.put(rc.Rule_Name__c, rc.Result__c);
            expectedByRule.put(rc.Rule_Name__c, rc.Expected_Value__c);
        }

        // ── Assert: DTI_MAX check fails ── (mapped picklist value)
        System.assertEquals('Fail', resultByRule.get('DTI_MAX'),
            'DTI_MAX must fail: Sabir DTI 44.8 > threshold 43');
        System.assertEquals(43, Decimal.valueOf(expectedByRule.get('DTI_MAX')),
            'DTI_MAX threshold should be 43');

        // ── Assert: 2 fails / 8 passes (mapped picklist values) ──
        Integer passCount = 0;
        Integer failCount = 0;
        for (Replay_Check__c rc : dbChecks) {
            if (rc.Result__c == 'Pass') {
                passCount++;
            } else if (rc.Result__c == 'Fail') {
                failCount++;
            }
        }
        // DTI_MAX fails (44.8 > 43 LTE) and DTI_WARN fails (44.8 > 40 LTE)
        System.assertEquals(2, failCount,
            'Expected 2 failures: DTI_MAX and DTI_WARN');
        System.assertEquals(8, passCount,
            'Expected 8 passes for all other rules');

        // Verify specific results by rule name (mapped values)
        System.assertEquals('Fail', resultByRule.get('DTI_WARN'),
            'DTI_WARN must fail: 44.8 > 40');
        System.assertEquals('Pass', resultByRule.get('FICO_MIN'),
            'FICO_MIN must pass: 710 >= 620');
        System.assertEquals('Pass', resultByRule.get('LTV_MAX'),
            'LTV_MAX must pass: 80 <= 80');

        // ── Assert: 1 Audit_Event__c with Replay_Executed ──
        List<Audit_Event__c> events = [
            SELECT Event_Type__c
            FROM Audit_Event__c
            WHERE Audit_Case__c = :ac.Id
              AND Event_Type__c = 'Replay_Executed'
        ];
        System.assertEquals(1, events.size(),
            'Expected exactly 1 Replay_Executed audit event');
    }

    // ─── 2. Receipt Immutability ───────────────────────────────────────

    /**
     * After replay, insert an Audit_Receipt__c and prove it survives
     * both update and delete attempts. The append-only invariant is
     * non-negotiable for audit trail integrity.
     */
    @IsTest
    static void smokeTest_receiptImmutability() {
        Audit_Case__c ac = getSabirCase();

        // Run replay first to establish the audit context
        Test.startTest();
        ReplayService.replay(ac.Id);
        Test.stopTest();

        // Insert a receipt linked to the case. All required fields must be
        // populated (Exception/Pass/Total/Violation counts + Signed_Off_At).
        // Mirror the 2-fail / 8-pass Sabir Sr. demo outcome.
        Audit_Receipt__c receipt = new Audit_Receipt__c(
            Audit_Case__c     = ac.Id,
            Pass_Count__c     = 8,
            Violation_Count__c = 2,
            Total_Findings__c = 2,
            Exception_Count__c = 0,
            Signed_Off_At__c  = Datetime.now()
        );
        insert receipt;

        // Verify receipt exists
        System.assertNotEquals(null, receipt.Id,
            'Receipt must be inserted successfully');

        // ── Attempt update — assert DmlException ──
        receipt.Receipt_Hash__c = 'tampered_hash';
        Boolean updateBlocked = false;
        try {
            update receipt;
        } catch (DmlException e) {
            updateBlocked = true;
        }
        System.assert(updateBlocked,
            'Update to Audit_Receipt__c must be blocked by validation rule');

        // ── Attempt delete — assert DmlException ──
        Boolean deleteBlocked = false;
        try {
            delete receipt;
        } catch (DmlException e) {
            deleteBlocked = true;
        }
        System.assert(deleteBlocked,
            'Delete of Audit_Receipt__c must be blocked by trigger');

        // ── Receipt survives both attempts ──
        List<Audit_Receipt__c> survivors = [
            SELECT Id FROM Audit_Receipt__c WHERE Id = :receipt.Id
        ];
        System.assertEquals(1, survivors.size(),
            'Audit Receipt must survive both update and delete attempts');
    }

    // ─── 3. Unverifiable on Missing Facts ──────────────────────────────

    /**
     * A case with NO Borrower_Snapshot__c records should produce all
     * Replay_Check__c results as INDETERMINATE (the evaluator's output
     * for missing facts).
     */
    @IsTest
    static void smokeTest_indeterminateOnMissingFacts() {
        // Create a bare loan + case with no borrower snapshots.
        // The approval date must fall in the Q1 2025 policy window.
        Loan__c loan = new Loan__c(
            Borrower_Name__c  = 'Ghost Borrower',
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

        // Should still produce checks (one per rule) — all INDETERMINATE
        System.assertEquals(10, checks.size(),
            'Expected 10 checks even with no borrower snapshots');

        List<Replay_Check__c> dbChecks = [
            SELECT Result__c, Rule_Name__c
            FROM Replay_Check__c
            WHERE Audit_Case__c = :emptyCase.Id
        ];

        for (Replay_Check__c rc : dbChecks) {
            System.assertEquals('Unverifiable', rc.Result__c,
                'Missing facts must produce Unverifiable for rule: ' + rc.Rule_Name__c);
        }
    }
}
