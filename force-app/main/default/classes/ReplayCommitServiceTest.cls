/**
 * ReplayCommitServiceTest — PNB coverage for ReplayCommitService.
 *
 * P = Positive: Sabir Sr. case with 10 replay checks (1 Fail DTI, 9 Pass)
 * N = Negative: empty results list returns empty, no DML
 * B = Bulk: 200 cases, each with 5 checks = 1000 Replay_Check__c in one DML
 *
 * @group Audit Replay Kernel
 */
@IsTest
private class ReplayCommitServiceTest {

    // ─── Test Data Helpers ─────────────────────────────────────────────

    private static Loan__c createLoan() {
        Loan__c loan = new Loan__c(
            Borrower_Name__c  = 'Test Borrower',
            Loan_Amount__c    = 250000,
            Property_Value__c = 312500,
            Loan_Type__c      = 'Conventional',
            Purpose__c        = 'Purchase',
            Approval_Date__c  = Date.today()
        );
        insert loan;
        return loan;
    }

    private static Audit_Case__c createCase(String name) {
        Loan__c loan = createLoan();
        Audit_Case__c ac = new Audit_Case__c(
            Loan__c              = loan.Id,
            Loan_Application__c  = 'a0000000000TEST1',
            Status__c            = 'In_Review',
            Risk_Tier__c         = 'High',
            Due_At__c            = Datetime.now().addDays(30)
        );
        insert ac;
        return ac;
    }

    private static Policy_Version__c createPolicyVersion() {
        Policy_Version__c pv = new Policy_Version__c(
            Version_Label__c   = 'Q1 2025 Conventional',
            Version_Number__c  = 1,
            Effective_Date__c  = Date.newInstance(2025, 1, 1),
            Is_Active__c       = true,
            Policy_Type__c     = 'Conventional'
        );
        insert pv;
        return pv;
    }

    private static List<Policy_Rule__c> createRules(Id policyVersionId, Integer count) {
        List<Policy_Rule__c> rules = new List<Policy_Rule__c>();
        for (Integer i = 0; i < count; i++) {
            rules.add(new Policy_Rule__c(
                Policy_Version__c = policyVersionId,
                Rule_Code__c      = 'RULE_' + String.valueOf(i).leftPad(3, '0'),
                Rule_Label__c     = 'Test Rule ' + i,
                Rule_Category__c  = 'Income',
                Operator__c       = 'LTE',
                Threshold_Value__c = 43,
                Fact_Field__c     = 'DTI_Ratio__c',
                Severity__c       = 'Hard_Decline',
                Sort_Order__c     = i
            ));
        }
        insert rules;
        return rules;
    }

    private static ReplayCommitService.ReplayCheckResult buildResult(
        Id caseId, Id ruleId, String ruleName, String result,
        String expected, String actual, Integer sortOrder
    ) {
        ReplayCommitService.ReplayCheckResult r = new ReplayCommitService.ReplayCheckResult();
        r.auditCaseId       = caseId;
        r.policyRuleId      = ruleId;
        r.ruleName          = ruleName;
        r.result            = result;
        r.expectedValue     = expected;
        r.actualValue       = actual;
        r.rationale         = result == 'Fail'
            ? 'Actual exceeds threshold'
            : 'Within threshold';
        r.sortOrder         = sortOrder;
        return r;
    }

    // ─── P: Positive — Sabir Sr. case ──────────────────────────────────

    @IsTest
    static void positive_sabirSrCase_createsChecksAndEvent() {
        Audit_Case__c ac = createCase('Sabir Sr.');
        Policy_Version__c pv = createPolicyVersion();
        List<Policy_Rule__c> rules = createRules(pv.Id, 10);

        List<ReplayCommitService.ReplayCheckResult> results =
            new List<ReplayCommitService.ReplayCheckResult>();

        // Rule 0 = DTI_MAX → Fail (44.8% vs 43%)
        results.add(buildResult(
            ac.Id, rules[0].Id, 'DTI_MAX', 'Fail', '43', '44.8', 0
        ));

        // Rules 1–9 = Pass
        for (Integer i = 1; i < 10; i++) {
            results.add(buildResult(
                ac.Id, rules[i].Id, rules[i].Rule_Label__c, 'Pass',
                '43', '38.2', i
            ));
        }

        Test.startTest();
        List<Replay_Check__c> checks = ReplayCommitService.commitReplayChecks(results);
        Test.stopTest();

        // Verify 10 Replay_Check__c records inserted
        System.assertEquals(10, checks.size(), 'Expected 10 replay checks');
        for (Replay_Check__c rc : checks) {
            System.assertNotEquals(null, rc.Id, 'Each check should have an Id');
        }

        // Verify the first check is the DTI Fail
        Replay_Check__c dtiCheck = [
            SELECT Result__c, Expected_Value__c, Actual_Value__c, Rule_Name__c
            FROM Replay_Check__c
            WHERE Id = :checks[0].Id
        ];
        System.assertEquals('Fail', dtiCheck.Result__c);
        System.assertEquals('43', dtiCheck.Expected_Value__c);
        System.assertEquals('44.8', dtiCheck.Actual_Value__c);

        // Verify Audit_Event__c created with Replay_Executed
        List<Audit_Event__c> events = [
            SELECT Event_Type__c, Audit_Case__c
            FROM Audit_Event__c
            WHERE Audit_Case__c = :ac.Id
            AND Event_Type__c = 'Replay_Executed'
        ];
        System.assertEquals(1, events.size(), 'Expected 1 Replay_Executed event');
    }

    // ─── N: Negative — empty results ───────────────────────────────────

    @IsTest
    static void negative_emptyResults_returnsEmptyNoDml() {
        Test.startTest();
        List<Replay_Check__c> checks = ReplayCommitService.commitReplayChecks(
            new List<ReplayCommitService.ReplayCheckResult>()
        );
        Test.stopTest();

        System.assertEquals(0, checks.size(), 'Empty input should return empty list');
        System.assertEquals(0, [SELECT COUNT() FROM Replay_Check__c],
            'No Replay_Check__c should exist');
        System.assertEquals(0, [SELECT COUNT() FROM Audit_Event__c],
            'No Audit_Event__c should exist');
    }

    @IsTest
    static void negative_nullResults_returnsEmptyNoDml() {
        Test.startTest();
        List<Replay_Check__c> checks = ReplayCommitService.commitReplayChecks(null);
        Test.stopTest();

        System.assertEquals(0, checks.size(), 'Null input should return empty list');
    }

    // ─── B: Bulk — 200 cases × 5 checks = 1000 records ────────────────

    @IsTest
    static void bulk_200Cases_withinGovernorLimits() {
        Policy_Version__c pv = createPolicyVersion();
        List<Policy_Rule__c> rules = createRules(pv.Id, 5);

        // Create 200 loans in bulk, then 200 audit cases
        List<Loan__c> loans = new List<Loan__c>();
        for (Integer i = 0; i < 200; i++) {
            loans.add(new Loan__c(
                Borrower_Name__c  = 'Bulk Borrower ' + i,
                Loan_Amount__c    = 250000,
                Property_Value__c = 312500,
                Loan_Type__c      = 'Conventional',
                Purpose__c        = 'Purchase',
                Approval_Date__c  = Date.today()
            ));
        }
        insert loans;

        List<Audit_Case__c> cases = new List<Audit_Case__c>();
        for (Integer i = 0; i < 200; i++) {
            cases.add(new Audit_Case__c(
                Loan__c              = loans[i].Id,
                Loan_Application__c  = 'a0000000000TEST1',
                Status__c            = 'In_Review',
                Risk_Tier__c         = 'Medium',
                Due_At__c            = Datetime.now().addDays(30)
            ));
        }
        insert cases;

        // Build 1000 results (200 cases × 5 rules)
        List<ReplayCommitService.ReplayCheckResult> results =
            new List<ReplayCommitService.ReplayCheckResult>();
        for (Audit_Case__c ac : cases) {
            for (Integer r = 0; r < 5; r++) {
                results.add(buildResult(
                    ac.Id, rules[r].Id, rules[r].Rule_Label__c,
                    'Pass', '43', '38.2', r
                ));
            }
        }

        Test.startTest();
        Integer dmlBefore = Limits.getDmlStatements();
        List<Replay_Check__c> checks = ReplayCommitService.commitReplayChecks(results);
        Integer dmlUsed = Limits.getDmlStatements() - dmlBefore;
        Test.stopTest();

        // Verify record count
        System.assertEquals(1000, checks.size(), 'Expected 1000 replay checks');
        System.assertEquals(1000, [SELECT COUNT() FROM Replay_Check__c],
            'All 1000 should be persisted');

        // Verify DML budget: 1 (checks) + 1 (events) = 2
        System.assert(dmlUsed <= 2,
            'Expected at most 2 DML statements, got ' + dmlUsed);

        // Verify 200 audit events (one per case)
        System.assertEquals(200, [SELECT COUNT() FROM Audit_Event__c
            WHERE Event_Type__c = 'Replay_Executed'],
            'Expected 200 Replay_Executed events (one per case)');
    }
}
