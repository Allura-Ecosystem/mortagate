/**
 * AuditQueueControllerTest -- Tests for the AuditQueueController @AuraEnabled methods.
 *
 * Validates queue retrieval, dashboard metrics (all 5 keys), and case creation
 * through the thin controller wrapper.
 *
 * @group Audit LWC Controllers
 * @see AuditQueueController
 */
@IsTest
private class AuditQueueControllerTest {

    @TestSetup
    static void setupData() {
        // Policy version (legacy required fields)
        Policy_Rule_Version__c policy = new Policy_Rule_Version__c(
            Name = 'Controller Test Policy',
            Version_Number__c = 1,
            Status__c = 'Active',
            DTI_Threshold__c = 43,
            Min_Credit_Score__c = 620,
            Rule_Code__c = 'CTRL_TEST',
            Rule_Label__c = 'Controller Test Policy',
            Fact_Field__c = 'DTI'
        );
        insert policy;

        // Create cases covering multiple metric buckets
        List<Audit_Case__c> cases = new List<Audit_Case__c>();

        // Case 1: Assigned to current user, high risk, SLA at risk
        cases.add(new Audit_Case__c(
            Loan_Application__c = 'a0000000000CTRL1',
            Sampling_Reason__c = 'Risk_Based',
            Approval_Timestamp__c = Datetime.now().addDays(-30),
            Status__c = 'In_Review',
            Auditor__c = UserInfo.getUserId(),
            Risk_Tier__c = 'High',
            Due_At__c = Datetime.now().addDays(1)
        ));

        // Case 2: Critical risk, not assigned to current user
        cases.add(new Audit_Case__c(
            Loan_Application__c = 'a0000000000CTRL2',
            Sampling_Reason__c = 'Targeted',
            Approval_Timestamp__c = Datetime.now().addDays(-20),
            Status__c = 'Created',
            Risk_Tier__c = 'Critical',
            Due_At__c = Datetime.now().addDays(10)
        ));

        // Case 3: Evidence needed
        cases.add(new Audit_Case__c(
            Loan_Application__c = 'a0000000000CTRL3',
            Sampling_Reason__c = 'Random',
            Approval_Timestamp__c = Datetime.now().addDays(-15),
            Status__c = 'Evidence_Needed',
            Due_At__c = Datetime.now().addDays(5)
        ));

        // Case 4: Ready for sign-off
        cases.add(new Audit_Case__c(
            Loan_Application__c = 'a0000000000CTRL4',
            Sampling_Reason__c = 'Random',
            Approval_Timestamp__c = Datetime.now().addDays(-10),
            Status__c = 'Ready_For_Signoff',
            Due_At__c = Datetime.now().addDays(7)
        ));

        // Case 5: Closed (should NOT appear in most metrics)
        cases.add(new Audit_Case__c(
            Loan_Application__c = 'a0000000000CTRL5',
            Sampling_Reason__c = 'Random',
            Approval_Timestamp__c = Datetime.now().addDays(-60),
            Status__c = 'Closed',
            Risk_Tier__c = 'High'
        ));

        insert cases;
    }

    // ---------------------------------------------------------------
    // getQueue
    // ---------------------------------------------------------------

    @IsTest
    static void test_getQueue_noFilters_returnsOpenCases() {
        Test.startTest();
        List<Audit_Case__c> queue = AuditQueueController.getQueue(null, null, null, null, null, null, null);
        Test.stopTest();

        // Closed case should be excluded (default filter in service)
        System.assert(queue.size() >= 4, 'Should return at least 4 open cases');
        for (Audit_Case__c c : queue) {
            System.assertNotEquals('Closed', c.Status__c,
                'Closed cases should not appear in unfiltered queue');
        }
    }

    @IsTest
    static void test_getQueue_statusFilter() {
        Test.startTest();
        List<Audit_Case__c> queue = AuditQueueController.getQueue('In_Review', null, null, null, null, null, null);
        Test.stopTest();

        System.assert(!queue.isEmpty(), 'Should find In_Review cases');
        for (Audit_Case__c c : queue) {
            System.assertEquals('In_Review', c.Status__c,
                'All returned cases should be In_Review');
        }
    }

    @IsTest
    static void test_getQueue_riskTierFilter() {
        Test.startTest();
        List<Audit_Case__c> queue = AuditQueueController.getQueue(null, 'Critical', null, null, null, null, null);
        Test.stopTest();

        System.assert(!queue.isEmpty(), 'Should find Critical risk cases');
        for (Audit_Case__c c : queue) {
            System.assertEquals('Critical', c.Risk_Tier__c,
                'All returned cases should be Critical');
        }
    }

    // ---------------------------------------------------------------
    // getMetrics
    // ---------------------------------------------------------------

    @IsTest
    static void test_getMetrics_returnsAllFiveKeys() {
        Test.startTest();
        Map<String, Integer> metrics = AuditQueueController.getMetrics();
        Test.stopTest();

        // Verify all 5 keys exist
        System.assert(metrics.containsKey('assignedToMe'),
            'Should have assignedToMe key');
        System.assert(metrics.containsKey('highRisk'),
            'Should have highRisk key');
        System.assert(metrics.containsKey('evidenceNeeded'),
            'Should have evidenceNeeded key');
        System.assert(metrics.containsKey('readyForSignoff'),
            'Should have readyForSignoff key');
        System.assert(metrics.containsKey('slaAtRisk'),
            'Should have slaAtRisk key');

        // Verify expected counts from test data
        System.assertEquals(1, metrics.get('assignedToMe'),
            'One case assigned to current user');
        System.assert(metrics.get('highRisk') >= 1,
            'At least 1 high/critical open case (closed excluded)');
        System.assertEquals(1, metrics.get('evidenceNeeded'),
            'One case in Evidence_Needed status');
        System.assertEquals(1, metrics.get('readyForSignoff'),
            'One case in Ready_For_Signoff status');
        System.assert(metrics.get('slaAtRisk') >= 1,
            'At least 1 case due within 2 days');
    }

    @IsTest
    static void test_getMetrics_excludesClosedFromAssignedToMe() {
        // Create a closed case assigned to current user
        Audit_Case__c closedAssigned = new Audit_Case__c(
            Loan_Application__c = 'a0000000000CLSD1',
            Sampling_Reason__c = 'Random',
            Approval_Timestamp__c = Datetime.now().addDays(-90),
            Status__c = 'Closed',
            Auditor__c = UserInfo.getUserId()
        );
        insert closedAssigned;

        Test.startTest();
        Map<String, Integer> metrics = AuditQueueController.getMetrics();
        Test.stopTest();

        // Still only 1 assigned to current user (the closed one is excluded)
        System.assertEquals(1, metrics.get('assignedToMe'),
            'Closed cases should not count in assignedToMe');
    }

    // ---------------------------------------------------------------
    // getApprovers (F1 fix — backs the queue's Approver filter)
    // ---------------------------------------------------------------

    @IsTest
    static void test_getApprovers_returnsDistinctApproversOnOpenCases() {
        // An open case with an approver set (the @TestSetup cases leave it null).
        Id approverId = UserInfo.getUserId();
        Audit_Case__c withApprover = new Audit_Case__c(
            Loan_Application__c = 'a0000000000APPR1',
            Sampling_Reason__c = 'Risk_Based',
            Approval_Timestamp__c = Datetime.now().addDays(-3),
            Status__c = 'In_Review',
            Original_Approver__c = approverId
        );
        insert withApprover;

        Test.startTest();
        List<Map<String, String>> approvers = AuditQueueController.getApprovers();
        Test.stopTest();

        System.assert(!approvers.isEmpty(),
            'Should return the approver on the open case');

        Boolean found = false;
        for (Map<String, String> a : approvers) {
            System.assert(a.containsKey('id'), 'Each entry has an id');
            System.assert(a.containsKey('name'), 'Each entry has a name');
            if (a.get('id') == String.valueOf(approverId)) {
                found = true;
                System.assertEquals(UserInfo.getName(), a.get('name'),
                    'Approver name should match the User.Name');
            }
        }
        System.assert(found,
            'The current user should appear as an approver');
    }

    @IsTest
    static void test_getApprovers_emptyWhenNoApproverSet() {
        // The @TestSetup cases never set Original_Approver__c, so with no extra
        // data the distinct-approver query returns nothing.
        Test.startTest();
        List<Map<String, String>> approvers = AuditQueueController.getApprovers();
        Test.stopTest();

        System.assert(approvers.isEmpty(),
            'No open case carries an approver, so the list is empty');
    }

    // ---------------------------------------------------------------
    // createAuditCase
    // ---------------------------------------------------------------

    @IsTest
    static void test_createAuditCase_insertsAndReturns() {
        // Need a user ID for originalApproverId -- use current user for test
        Id approverId = UserInfo.getUserId();
        Datetime approvalTs = Datetime.now().addDays(-5);

        Test.startTest();
        Audit_Case__c created = AuditQueueController.createAuditCase(
            'LN-TEST-CREATE-001',
            'Ad_Hoc',
            String.valueOf(approverId),
            approvalTs
        );
        Test.stopTest();

        System.assertNotEquals(null, created.Id, 'Should have an Id after insert');
        System.assertEquals('Created', created.Status__c,
            'New case should be in Created status');

        // Verify event was logged
        List<Audit_Event__c> events = [
            SELECT Event_Type__c FROM Audit_Event__c
            WHERE Audit_Case__c = :created.Id
        ];
        System.assertEquals(1, events.size(), 'Should log Case_Created event');
        System.assertEquals('Case_Created', events[0].Event_Type__c);
    }

    // ---------------------------------------------------------------
    // Bulk safety: 200+ record metric query
    // ---------------------------------------------------------------

    @IsTest
    static void test_getMetrics_bulkSafe_200records() {
        List<Audit_Case__c> bulkCases = new List<Audit_Case__c>();
        for (Integer i = 0; i < 200; i++) {
            bulkCases.add(new Audit_Case__c(
                Loan_Application__c = 'a000000000BLK' + String.valueOf(i).leftPad(4, '0'),
                Sampling_Reason__c = 'Random',
                Approval_Timestamp__c = Datetime.now().addDays(-i),
                Status__c = 'In_Review',
                Risk_Tier__c = 'Low',
                Due_At__c = Datetime.now().addDays(30)
            ));
        }
        insert bulkCases;

        Test.startTest();
        Map<String, Integer> metrics = AuditQueueController.getMetrics();
        Test.stopTest();

        // Metrics should return without governor limit issues
        System.assert(metrics.containsKey('assignedToMe'),
            'Metrics should still work with 200+ records in org');
    }
}