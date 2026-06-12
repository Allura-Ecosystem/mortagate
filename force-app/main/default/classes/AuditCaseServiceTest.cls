/**
 * AuditCaseServiceTest — Tests for audit case lifecycle methods.
 *
 * @group Audit Case Management
 */
@IsTest
private class AuditCaseServiceTest {

    @IsTest
    static void test_createFromLoan_insertsCase() {
        Test.startTest();
        Audit_Case__c result = AuditCaseService.createFromLoan(
            UserInfo.getUserId(),
            'Random',
            UserInfo.getUserId(),
            Datetime.now().addDays(-30)
        );
        Test.stopTest();

        System.assertNotEquals(null, result.Id, 'Case should have an Id after insert');
        System.assertEquals('Created', result.Status__c, 'Status should be Created');

        List<Audit_Event__c> events = [
            SELECT Event_Type__c FROM Audit_Event__c
            WHERE Audit_Case__c = :result.Id
        ];
        System.assertEquals(1, events.size(), 'Should have one Case_Created event');
        System.assertEquals('Case_Created', events[0].Event_Type__c);
    }

    @IsTest
    static void test_createFromLoans_bulk() {
        List<Audit_Case__c> cases = new List<Audit_Case__c>();
        for (Integer i = 0; i < 200; i++) {
            cases.add(new Audit_Case__c(
                Loan_Application__c = 'a000000000BULK' + String.valueOf(i).leftPad(3, '0'),
                Sampling_Reason__c = 'Risk_Based',
                Approval_Timestamp__c = Datetime.now().addDays(-i)
            ));
        }

        Test.startTest();
        List<Audit_Case__c> results = AuditCaseService.createFromLoans(cases);
        Test.stopTest();

        System.assertEquals(200, results.size(), 'Should create 200 cases');
        Integer eventCount = [SELECT COUNT() FROM Audit_Event__c];
        System.assertEquals(200, eventCount, 'Should have 200 Case_Created events');
    }

    @IsTest
    static void test_assignCase_success() {
        Audit_Case__c testCase = new Audit_Case__c(
            Loan_Application__c   = 'a0000000000FAKE1',
            Sampling_Reason__c    = 'Targeted',
            Approval_Timestamp__c = Datetime.now().addDays(-10),
            Status__c             = 'Created'
        );
        insert testCase;

        Test.startTest();
        Audit_Case__c result = AuditCaseService.assignCase(
            testCase.Id,
            UserInfo.getUserId()
        );
        Test.stopTest();

        System.assertEquals('Assigned', result.Status__c, 'Status should be Assigned');
        System.assertEquals(UserInfo.getUserId(), result.Auditor__c, 'Auditor should be set');
        System.assertNotEquals(null, result.Assigned_At__c, 'Assigned_At should be set');

        List<Audit_Event__c> events = [
            SELECT Event_Type__c FROM Audit_Event__c
            WHERE Audit_Case__c = :testCase.Id
        ];
        System.assertEquals(1, events.size(), 'Should have Case_Assigned event');
        System.assertEquals('Case_Assigned', events[0].Event_Type__c);
    }

    @IsTest
    static void test_assignCase_selfAuditPrevention() {
        Audit_Case__c testCase = new Audit_Case__c(
            Loan_Application__c    = 'a0000000000FAKE2',
            Sampling_Reason__c     = 'Random',
            Original_Approver__c   = UserInfo.getUserId(),
            Approval_Timestamp__c  = Datetime.now().addDays(-5),
            Status__c              = 'Created'
        );
        insert testCase;

        Test.startTest();
        try {
            AuditCaseService.assignCase(testCase.Id, UserInfo.getUserId());
            System.assert(false, 'Should have thrown SelfAuditException');
        } catch (AuditCaseService.SelfAuditException e) {
            System.assert(
                e.getMessage().contains('cannot audit'),
                'Error should mention self-audit prevention'
            );
        }
        Test.stopTest();
    }

    @IsTest
    static void test_getQueue_noFilters() {
        List<Audit_Case__c> cases = new List<Audit_Case__c>();
        cases.add(new Audit_Case__c(
            Loan_Application__c = 'a0000000000TEST1',
            Sampling_Reason__c = 'Random',
            Approval_Timestamp__c = Datetime.now().addDays(-10),
            Status__c = 'In_Review',
            Risk_Tier__c = 'High'
        ));
        cases.add(new Audit_Case__c(
            Loan_Application__c = 'a0000000000TEST2',
            Sampling_Reason__c = 'Risk_Based',
            Approval_Timestamp__c = Datetime.now().addDays(-5),
            Status__c = 'Created',
            Risk_Tier__c = 'Critical'
        ));
        cases.add(new Audit_Case__c(
            Loan_Application__c = 'a0000000000TEST3',
            Sampling_Reason__c = 'Targeted',
            Approval_Timestamp__c = Datetime.now().addDays(-1),
            Status__c = 'Closed',
            Risk_Tier__c = 'Low'
        ));
        insert cases;

        Test.startTest();
        List<Audit_Case__c> results = AuditCaseService.getQueue(null, null, null, null, null, null, null);
        Test.stopTest();

        System.assertEquals(2, results.size(), 'Should return 2 non-closed cases');
    }

    @IsTest
    static void test_getQueue_filterByStatus() {
        List<Audit_Case__c> cases = new List<Audit_Case__c>();
        cases.add(new Audit_Case__c(
            Loan_Application__c = 'a0000000000FLT1',
            Sampling_Reason__c = 'Random',
            Approval_Timestamp__c = Datetime.now(),
            Status__c = 'In_Review',
            Risk_Tier__c = 'Medium'
        ));
        cases.add(new Audit_Case__c(
            Loan_Application__c = 'a0000000000FLT2',
            Sampling_Reason__c = 'Random',
            Approval_Timestamp__c = Datetime.now(),
            Status__c = 'Created',
            Risk_Tier__c = 'Low'
        ));
        insert cases;

        Test.startTest();
        List<Audit_Case__c> results = AuditCaseService.getQueue('In_Review', null, null, null, null, null, null);
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Should return only In_Review cases');
        System.assertEquals('In_Review', results[0].Status__c);
    }

    @IsTest
    static void test_getQueue_filterByRiskTier() {
        List<Audit_Case__c> cases = new List<Audit_Case__c>();
        cases.add(new Audit_Case__c(
            Loan_Application__c = 'a0000000000RK1',
            Sampling_Reason__c = 'Risk_Based',
            Approval_Timestamp__c = Datetime.now(),
            Status__c = 'In_Review',
            Risk_Tier__c = 'High'
        ));
        cases.add(new Audit_Case__c(
            Loan_Application__c = 'a0000000000RK2',
            Sampling_Reason__c = 'Random',
            Approval_Timestamp__c = Datetime.now(),
            Status__c = 'In_Review',
            Risk_Tier__c = 'Low'
        ));
        insert cases;

        Test.startTest();
        List<Audit_Case__c> results = AuditCaseService.getQueue(null, 'High', null, null, null, null, null);
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Should return only High risk cases');
        System.assertEquals('High', results[0].Risk_Tier__c);
    }

    // ---------------------------------------------------------------
    // getQueue — expanded filters (F-01: each control must narrow results)
    // Signature: (status, riskTier, approverId, samplingReason,
    //             approvalDays, auditorId, dueBefore)
    // ---------------------------------------------------------------

    @IsTest
    static void test_getQueue_filterBySamplingReason() {
        insert new List<Audit_Case__c>{
            new Audit_Case__c(Loan_Application__c = 'a0000000SMP1', Sampling_Reason__c = 'Risk_Based',
                Approval_Timestamp__c = Datetime.now(), Status__c = 'In_Review', Risk_Tier__c = 'High'),
            new Audit_Case__c(Loan_Application__c = 'a0000000SMP2', Sampling_Reason__c = 'Random',
                Approval_Timestamp__c = Datetime.now(), Status__c = 'In_Review', Risk_Tier__c = 'Low')
        };

        Test.startTest();
        List<Audit_Case__c> results =
            AuditCaseService.getQueue(null, null, null, 'Risk_Based', null, null, null);
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Should return only Risk_Based cases');
        System.assertEquals('Risk_Based', results[0].Sampling_Reason__c);
    }

    @IsTest
    static void test_getQueue_filterByApprover() {
        Id me = UserInfo.getUserId();
        insert new List<Audit_Case__c>{
            new Audit_Case__c(Loan_Application__c = 'a0000000APR1', Sampling_Reason__c = 'Random',
                Original_Approver__c = me, Approval_Timestamp__c = Datetime.now(),
                Status__c = 'In_Review', Risk_Tier__c = 'Medium'),
            new Audit_Case__c(Loan_Application__c = 'a0000000APR2', Sampling_Reason__c = 'Random',
                Approval_Timestamp__c = Datetime.now(), Status__c = 'In_Review', Risk_Tier__c = 'Medium')
        };

        Test.startTest();
        List<Audit_Case__c> results =
            AuditCaseService.getQueue(null, null, String.valueOf(me), null, null, null, null);
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Should return only cases for the given approver');
        System.assertEquals(me, results[0].Original_Approver__c);
    }

    @IsTest
    static void test_getQueue_filterByAuditor() {
        Id me = UserInfo.getUserId();
        insert new List<Audit_Case__c>{
            new Audit_Case__c(Loan_Application__c = 'a0000000AUD1', Sampling_Reason__c = 'Random',
                Auditor__c = me, Approval_Timestamp__c = Datetime.now(),
                Status__c = 'In_Review', Risk_Tier__c = 'Medium'),
            new Audit_Case__c(Loan_Application__c = 'a0000000AUD2', Sampling_Reason__c = 'Random',
                Approval_Timestamp__c = Datetime.now(), Status__c = 'In_Review', Risk_Tier__c = 'Medium')
        };

        Test.startTest();
        List<Audit_Case__c> results =
            AuditCaseService.getQueue(null, null, null, null, null, String.valueOf(me), null);
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Should return only cases for the given auditor');
        System.assertEquals(me, results[0].Auditor__c);
    }

    @IsTest
    static void test_getQueue_filterByApprovalWindow() {
        insert new List<Audit_Case__c>{
            new Audit_Case__c(Loan_Application__c = 'a0000000WIN1', Sampling_Reason__c = 'Random',
                Approval_Timestamp__c = Datetime.now().addDays(-2), Status__c = 'In_Review', Risk_Tier__c = 'Medium'),
            new Audit_Case__c(Loan_Application__c = 'a0000000WIN2', Sampling_Reason__c = 'Random',
                Approval_Timestamp__c = Datetime.now().addDays(-45), Status__c = 'In_Review', Risk_Tier__c = 'Medium')
        };

        Test.startTest();
        // Last 7 days → only the case approved 2 days ago
        List<Audit_Case__c> results =
            AuditCaseService.getQueue(null, null, null, null, '7', null, null);
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Should return only cases approved within the window');
        System.assert(results[0].Approval_Timestamp__c >= Datetime.now().addDays(-7),
            'Returned case must fall inside the approval window');
    }

    @IsTest
    static void test_getQueue_filterByDueBefore() {
        insert new List<Audit_Case__c>{
            new Audit_Case__c(Loan_Application__c = 'a0000000DUE1', Sampling_Reason__c = 'Random',
                Approval_Timestamp__c = Datetime.now(), Due_At__c = Datetime.now().addDays(2),
                Status__c = 'In_Review', Risk_Tier__c = 'Medium'),
            new Audit_Case__c(Loan_Application__c = 'a0000000DUE2', Sampling_Reason__c = 'Random',
                Approval_Timestamp__c = Datetime.now(), Due_At__c = Datetime.now().addDays(20),
                Status__c = 'In_Review', Risk_Tier__c = 'Medium')
        };

        Test.startTest();
        // Due on/before today+5 → only the case due in 2 days
        List<Audit_Case__c> results =
            AuditCaseService.getQueue(null, null, null, null, null, null, Date.today().addDays(5));
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Should return only cases due on/before the cutoff');
    }

    @IsTest
    static void test_getQueue_combinedFiltersNarrow() {
        Id me = UserInfo.getUserId();
        insert new List<Audit_Case__c>{
            new Audit_Case__c(Loan_Application__c = 'a0000000CMB1', Sampling_Reason__c = 'Risk_Based',
                Auditor__c = me, Approval_Timestamp__c = Datetime.now(),
                Status__c = 'In_Review', Risk_Tier__c = 'Critical'),
            new Audit_Case__c(Loan_Application__c = 'a0000000CMB2', Sampling_Reason__c = 'Risk_Based',
                Auditor__c = me, Approval_Timestamp__c = Datetime.now(),
                Status__c = 'In_Review', Risk_Tier__c = 'Low')
        };

        Test.startTest();
        List<Audit_Case__c> results =
            AuditCaseService.getQueue('In_Review', 'Critical', null, 'Risk_Based', null, String.valueOf(me), null);
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Combined filters should narrow to the single matching case');
        System.assertEquals('Critical', results[0].Risk_Tier__c);
    }

    // ---------------------------------------------------------------
    // Default ORDER BY — risk priority (regression guard)
    // Risk_Tier__c is a picklist: SOQL sorts by DEFINITION order
    // (Low, Medium, High, Critical). The queue must use DESC so the
    // highest-risk loans surface first; ASC buried Critical/High past
    // the LIMIT 200 cap (invisible until the queue exceeded 200 rows —
    // caught by the 614-row Kaggle load, 2026-06-12).
    // ---------------------------------------------------------------
    @IsTest
    static void test_getQueue_ordersHighestRiskFirst() {
        insert new List<Audit_Case__c>{
            new Audit_Case__c(Loan_Application__c = 'a000000ORD_L', Sampling_Reason__c = 'Random',
                Approval_Timestamp__c = Datetime.now(), Status__c = 'In_Review', Risk_Tier__c = 'Low'),
            new Audit_Case__c(Loan_Application__c = 'a000000ORD_M', Sampling_Reason__c = 'Random',
                Approval_Timestamp__c = Datetime.now(), Status__c = 'In_Review', Risk_Tier__c = 'Medium'),
            new Audit_Case__c(Loan_Application__c = 'a000000ORD_H', Sampling_Reason__c = 'Random',
                Approval_Timestamp__c = Datetime.now(), Status__c = 'In_Review', Risk_Tier__c = 'High'),
            new Audit_Case__c(Loan_Application__c = 'a000000ORD_C', Sampling_Reason__c = 'Random',
                Approval_Timestamp__c = Datetime.now(), Status__c = 'In_Review', Risk_Tier__c = 'Critical')
        };

        Test.startTest();
        List<Audit_Case__c> q = AuditCaseService.getQueue(null, null, null, null, null, null, null);
        Test.stopTest();

        Map<String, Integer> rank = new Map<String, Integer>();
        for (Integer i = 0; i < q.size(); i++) {
            String t = q[i].Risk_Tier__c;
            if (t != null && !rank.containsKey(t)) rank.put(t, i);
        }
        System.assertEquals('Critical', q[0].Risk_Tier__c, 'Highest-risk loan must be at the top of the queue');
        System.assert(rank.get('Critical') < rank.get('High'), 'Critical must rank above High');
        System.assert(rank.get('High') < rank.get('Medium'), 'High must rank above Medium');
        System.assert(rank.get('Medium') < rank.get('Low'), 'Medium must rank above Low');
    }

    // ---------------------------------------------------------------
    // LIMIT-cap visibility (P0) — the real failure mode behind the
    // ordering bug: a Critical case must NOT be buried past the 200-row
    // cap by a flood of Low-risk rows. Distinct from pure ordering:
    // this proves the highest-risk loan survives truncation.
    // ---------------------------------------------------------------
    @IsTest
    static void test_getQueue_criticalSurfacesDespite200Cap() {
        List<Audit_Case__c> lowRows = new List<Audit_Case__c>();
        for (Integer i = 0; i < 210; i++) {
            lowRows.add(new Audit_Case__c(
                Loan_Application__c = 'CAP' + String.valueOf(i).leftPad(3, '0'),
                Sampling_Reason__c = 'Random', Approval_Timestamp__c = Datetime.now(),
                Status__c = 'In_Review', Risk_Tier__c = 'Low'));
        }
        lowRows.add(new Audit_Case__c(
            Loan_Application__c = 'CAP_CRIT', Sampling_Reason__c = 'Risk_Based',
            Approval_Timestamp__c = Datetime.now(), Status__c = 'In_Review', Risk_Tier__c = 'Critical'));
        insert lowRows;

        Test.startTest();
        List<Audit_Case__c> q = AuditCaseService.getQueue(null, null, null, null, null, null, null);
        Test.stopTest();

        System.assertEquals(200, q.size(), 'Queue is capped at LIMIT 200');
        System.assertEquals('Critical', q[0].Risk_Tier__c,
            'The Critical case must surface at the top — never buried past the cap by 210 Low rows');
    }

    // ---------------------------------------------------------------
    // FLS / WITH USER_MODE enforcement (P1) — security boundary.
    // USER_MODE is present on every getQueue SOQL; this proves it is
    // actually ENFORCED: a user without access to Audit_Case__c must be
    // blocked, not silently handed admin-visible rows.
    // (User is a setup object — User DML is isolated in its own runAs
    //  block to avoid MIXED_DML_OPERATION with the Audit_Case__c insert.)
    // ---------------------------------------------------------------
    @IsTest
    static void test_getQueue_enforcesUserModeForRestrictedUser() {
        insert new Audit_Case__c(
            Loan_Application__c = 'FLS_PROBE', Sampling_Reason__c = 'Random',
            Approval_Timestamp__c = Datetime.now(), Status__c = 'In_Review', Risk_Tier__c = 'High');

        User restricted;
        System.runAs(new User(Id = UserInfo.getUserId())) {
            Profile p = [SELECT Id FROM Profile WHERE Name = 'Minimum Access - Salesforce' LIMIT 1];
            Long stamp = Datetime.now().getTime();
            restricted = new User(
                FirstName = 'FLS', LastName = 'Probe',
                Email = 'fls.probe@example.com.invalid',
                Username = 'fls.probe.' + stamp + '@example.com.invalid',
                Alias = 'flsp', ProfileId = p.Id,
                TimeZoneSidKey = 'America/New_York', LocaleSidKey = 'en_US',
                EmailEncodingKey = 'UTF-8', LanguageLocaleKey = 'en_US');
            insert restricted;
        }

        Boolean blocked = false;
        System.runAs(restricted) {
            try {
                AuditCaseService.getQueue(null, null, null, null, null, null, null);
            } catch (Exception e) {
                blocked = true; // WITH USER_MODE rejects a user lacking Audit_Case__c access
            }
        }
        System.assert(blocked,
            'WITH USER_MODE must block a user without access to Audit_Case__c — FLS/CRUD is enforced, not decorative');
    }

    // ---------------------------------------------------------------
    // SOQL-injection guard (P1) — getQueue builds dynamic SOQL but must
    // pass every user value as a BIND VARIABLE (filter fields come from a
    // hardcoded allow-list). Classic injection payloads must be treated
    // as literals → match nothing, never widen the result set or error.
    // If a refactor reintroduced string interpolation, the "OR …" clause
    // would widen and return the seeded row → this test goes red.
    // ---------------------------------------------------------------
    @IsTest
    static void test_getQueue_isInjectionSafe() {
        insert new Audit_Case__c(
            Loan_Application__c = 'INJ1', Sampling_Reason__c = 'Random',
            Approval_Timestamp__c = Datetime.now(), Status__c = 'In_Review', Risk_Tier__c = 'High');

        Test.startTest();
        List<Audit_Case__c> byStatus = AuditCaseService.getQueue(
            'In_Review\' OR Risk_Tier__c != null OR Status__c = \'', null, null, null, null, null, null);
        List<Audit_Case__c> byRisk = AuditCaseService.getQueue(
            null, 'High\' OR Loan_Application__c != null OR Risk_Tier__c = \'', null, null, null, null, null);
        List<Audit_Case__c> byReason = AuditCaseService.getQueue(
            null, null, null, 'Random\' OR \'1\'=\'1', null, null, null);
        Test.stopTest();

        System.assertEquals(0, byStatus.size(),
            'Injected status payload must match nothing — proves bind-variable literal handling');
        System.assertEquals(0, byRisk.size(), 'Injected risk-tier payload must match nothing');
        System.assertEquals(0, byReason.size(), 'Injected sampling-reason payload must match nothing');
    }
}