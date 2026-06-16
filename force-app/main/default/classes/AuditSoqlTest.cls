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
}
