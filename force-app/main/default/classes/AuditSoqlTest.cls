/**
 * AuditSoqlTest — proves the shared read primitive's four guarantees:
 *   - query() runs bound + user-mode and returns rows
 *   - count() runs bound + user-mode and returns a count
 *   - resolveSortField() honours the allowlist and falls back safely
 *   - resolveDirection() / resolveLimit() sanitize untrusted input
 *
 * Seeds two Loan__c + Audit_Case__c so the bound queries have something to find.
 */
@IsTest
private class AuditSoqlTest {

    @TestSetup
    static void seed() {
        List<Loan__c> loans = new List<Loan__c>{
            new Loan__c(Borrower_Name__c = 'Alpha Borrower', Loan_Amount__c = 100000,
                        Property_Value__c = 150000, Loan_Type__c = 'Conventional',
                        Purpose__c = 'Purchase', Approval_Date__c = Date.newInstance(2025, 3, 15),
                        LOS_Loan_Id__c = 'LA-AAA111'),
            new Loan__c(Borrower_Name__c = 'Bravo Borrower', Loan_Amount__c = 200000,
                        Property_Value__c = 260000, Loan_Type__c = 'FHA',
                        Purpose__c = 'Purchase', Approval_Date__c = Date.newInstance(2025, 3, 15),
                        LOS_Loan_Id__c = 'LA-BBB222')
        };
        insert loans;

        insert new List<Audit_Case__c>{
            new Audit_Case__c(Loan__c = loans[0].Id, Loan_Application__c = 'a01',
                              Status__c = 'In_Review', Risk_Tier__c = 'High',
                              Borrower_Name_Snapshot__c = 'Alpha Borrower',
                              Due_At__c = Datetime.now().addDays(10)),
            new Audit_Case__c(Loan__c = loans[1].Id, Loan_Application__c = 'a02',
                              Status__c = 'Closed', Risk_Tier__c = 'Low',
                              Borrower_Name_Snapshot__c = 'Bravo Borrower',
                              Due_At__c = Datetime.now().addDays(-2))
        };
    }

    @IsTest
    static void query_boundUserMode_returnsRows() {
        Test.startTest();
        List<SObject> rows = AuditSoql.query(
            'SELECT Id, Status__c FROM Audit_Case__c WHERE Status__c = :st ORDER BY Name ASC',
            new Map<String, Object>{ 'st' => 'In_Review' });
        Test.stopTest();

        System.assertEquals(1, rows.size(), 'One In_Review case seeded');
        System.assertEquals('In_Review', (String) rows[0].get('Status__c'));
    }

    @IsTest
    static void query_nullBinds_doesNotThrow() {
        Test.startTest();
        List<SObject> rows = AuditSoql.query('SELECT Id FROM Audit_Case__c', null);
        Test.stopTest();
        System.assertEquals(2, rows.size(), 'Both cases returned with no binds');
    }

    @IsTest
    static void count_boundUserMode_returnsCount() {
        Test.startTest();
        Integer n = AuditSoql.count(
            'SELECT COUNT() FROM Audit_Case__c WHERE Risk_Tier__c = :tier',
            new Map<String, Object>{ 'tier' => 'High' });
        Test.stopTest();
        System.assertEquals(1, n, 'One High-risk case');
    }

    @IsTest
    static void resolveSortField_honoursAllowlistAndFallsBack() {
        Map<String, String> allow = new Map<String, String>{ 'risk' => 'Risk_Tier__c' };
        System.assertEquals('Risk_Tier__c',
            AuditSoql.resolveSortField(allow, 'risk', 'Name'), 'Known key resolves');
        System.assertEquals('Name',
            AuditSoql.resolveSortField(allow, 'evil', 'Name'), 'Unknown key falls back');
        System.assertEquals('Name',
            AuditSoql.resolveSortField(allow, null, 'Name'), 'Null key falls back');
        System.assertEquals('Name',
            AuditSoql.resolveSortField(null, 'risk', 'Name'), 'Null allowlist falls back');
    }

    @IsTest
    static void resolveDirection_normalizes() {
        System.assertEquals('DESC', AuditSoql.resolveDirection('desc'));
        System.assertEquals('DESC', AuditSoql.resolveDirection('DESC'));
        System.assertEquals('ASC', AuditSoql.resolveDirection('asc'));
        System.assertEquals('ASC', AuditSoql.resolveDirection('garbage'));
        System.assertEquals('ASC', AuditSoql.resolveDirection(null));
    }

    @IsTest
    static void resolveLimit_clampsAndDefaults() {
        System.assertEquals(50, AuditSoql.resolveLimit(50, 100), 'In-range passes through');
        System.assertEquals(100, AuditSoql.resolveLimit(null, 100), 'Null => default');
        System.assertEquals(100, AuditSoql.resolveLimit(0, 100), 'Zero => default');
        System.assertEquals(100, AuditSoql.resolveLimit(-5, 100), 'Negative => default');
        System.assertEquals(AuditSoql.MAX_LIMIT, AuditSoql.resolveLimit(9999, 100),
            'Over-max clamps to MAX_LIMIT');
    }

    // ── latestChecksFor (R-11 supersede-by-query) ────────────────────────

    @IsTest
    static void latestChecksFor_nullAndEmpty_returnEmpty() {
        System.assertEquals(0, AuditSoql.latestChecksFor((Set<Id>) null).size(),
            'Null set => empty map');
        System.assertEquals(0, AuditSoql.latestChecksFor(new Set<Id>()).size(),
            'Empty set => empty map');
        System.assertEquals(0, AuditSoql.latestChecksFor((Id) null).size(),
            'Null id => empty list');
    }

    @IsTest
    static void latestChecksFor_returnsLatestBatchOnly() {
        Id caseId = [SELECT Id FROM Audit_Case__c WHERE Status__c = 'In_Review' LIMIT 1].Id;

        // Replay_Check__c requires Policy_Rule__c + Expected_Value__c — seed a
        // minimal policy + rule so direct inserts satisfy the schema.
        Policy_Version__c pv = new Policy_Version__c(
            Version_Label__c = 'Test Policy', Version_Number__c = 1,
            Effective_Date__c = Date.newInstance(2025, 1, 1), Is_Active__c = true,
            Policy_Type__c = 'Conventional');
        insert pv;
        Policy_Rule__c pr = new Policy_Rule__c(
            Policy_Version__c = pv.Id, Rule_Code__c = 'DTI_MAX', Rule_Label__c = 'Max DTI',
            Rule_Category__c = 'Income', Operator__c = 'LTE', Threshold_Value__c = 43,
            Fact_Field__c = 'DTI_Ratio__c', Severity__c = 'Hard_Decline');
        insert pr;

        // Two stacked batches: an older 3-check batch + a newer 2-check batch.
        Datetime older = Datetime.now().addHours(-2);
        Datetime newer = Datetime.now();
        List<Replay_Check__c> oldBatch = new List<Replay_Check__c>{
            newCheck(caseId, pr.Id, 'OLD_A', 'Fail', older, 0),
            newCheck(caseId, pr.Id, 'OLD_B', 'Fail', older, 1),
            newCheck(caseId, pr.Id, 'OLD_C', 'Pass', older, 2)
        };
        insert oldBatch;
        insert new List<Replay_Check__c>{
            newCheck(caseId, pr.Id, 'NEW_A', 'Pass', newer, 0),
            newCheck(caseId, pr.Id, 'NEW_B', 'Pass', newer, 1)
        };

        Test.startTest();
        List<Replay_Check__c> latest = AuditSoql.latestChecksFor(caseId);
        Test.stopTest();

        System.assertEquals(2, latest.size(), 'Only the newer 2-check batch is current');
        Set<String> names = new Set<String>();
        for (Replay_Check__c rc : latest) { names.add(rc.Rule_Name__c); }
        System.assert(names.contains('NEW_A') && names.contains('NEW_B'),
            'Latest batch rules surfaced');
        System.assert(!names.contains('OLD_A'),
            'Superseded batch rules excluded');
    }

    private static Replay_Check__c newCheck(Id caseId, Id ruleId, String name,
                                            String result, Datetime ts, Integer sortOrder) {
        return new Replay_Check__c(
            Audit_Case__c = caseId, Policy_Rule__c = ruleId, Rule_Name__c = name,
            Result__c = result, Expected_Value__c = '43',
            Replay_Timestamp__c = ts, Sort_Order__c = sortOrder);
    }
}
