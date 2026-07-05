/**
 * ViolationAlertServiceTest — proves the ONE side-effect copilot action:
 *   • hero case with a failing replay → exactly one controlled internal Task,
 *     WhatId-linked to the case, failing rules in plain words, owned by the
 *     assigned auditor, plus the ADR-26 log-before-execute dual-write;
 *   • idempotent second call → no duplicate Task, Partial 'already alerted';
 *   • clean case (no Fails) → no Task, graceful 'no violations' Partial;
 *   • ghost case → fails closed at the immutable intent insert, zero orphan trail;
 *   • bulk-200 → constant SOQL/DML, 200 intent logs / 400 events, ≤ 1 Task per case.
 *
 * Never emails, never contacts anyone external — the only write is an internal Task.
 */
@IsTest
private class ViolationAlertServiceTest {

    @TestSetup
    static void seed() {
        Loan__c loan = new Loan__c(
            Borrower_Name__c = 'Sabir Asheed Sr.', Loan_Amount__c = 380000,
            Property_Value__c = 475000, Loan_Type__c = 'Conventional',
            Purpose__c = 'Purchase', LOS_Loan_Id__c = 'LOS-ALERT-1',
            Approval_Date__c = Date.newInstance(2025, 3, 15));
        insert loan;

        Audit_Case__c ac = new Audit_Case__c(
            Loan__c = loan.Id, Loan_Application__c = 'a0AlertHero',
            Borrower_Name_Snapshot__c = 'Sabir Asheed Sr.',
            Status__c = 'In_Review', Risk_Tier__c = 'High',
            Auditor__c = UserInfo.getUserId(),
            Due_At__c = Datetime.now().addDays(10));
        insert ac;

        // DTI 44.8 > 43 => DTI_MAX Fail. No LTV fact => LTV_MAX Unverifiable.
        insert new List<Borrower_Snapshot__c>{
            new Borrower_Snapshot__c(Audit_Case__c = ac.Id, Fact_Category__c = 'Income',
                DTI_Ratio__c = 44.8),
            new Borrower_Snapshot__c(Audit_Case__c = ac.Id, Fact_Category__c = 'Credit',
                FICO_Score__c = 710)
        };

        Policy_Version__c pv = new Policy_Version__c(
            Version_Label__c = 'Q1 2025 Conventional', Version_Number__c = 1,
            Effective_Date__c = Date.newInstance(2025, 1, 1), Is_Active__c = true,
            Policy_Type__c = 'Conventional');
        insert pv;

        insert new List<Policy_Rule__c>{
            new Policy_Rule__c(Policy_Version__c = pv.Id, Rule_Code__c = 'DTI_MAX',
                Rule_Label__c = 'Max DTI', Rule_Category__c = 'Income', Operator__c = 'LTE',
                Threshold_Value__c = 43, Fact_Field__c = 'DTI_Ratio__c', Severity__c = 'Hard_Decline'),
            new Policy_Rule__c(Policy_Version__c = pv.Id, Rule_Code__c = 'LTV_MAX',
                Rule_Label__c = 'Max LTV', Rule_Category__c = 'Collateral', Operator__c = 'LTE',
                Threshold_Value__c = 80, Fact_Field__c = 'LTV_Ratio__c', Severity__c = 'Hard_Decline')
        };
    }

    private static Id heroCaseId() {
        return [SELECT Id FROM Audit_Case__c WHERE Loan_Application__c = 'a0AlertHero' LIMIT 1].Id;
    }

    // ── POSITIVE ──────────────────────────────────────────────────────────
    @IsTest
    static void sendAlert_heroCase_createsOneTask_withRules_andDualWrites() {
        Id caseId = heroCaseId();
        ReplayService.replay(caseId);
        String caseName = [SELECT Name FROM Audit_Case__c WHERE Id = :caseId].Name;

        Test.startTest();
        ViolationAlertService.Response r = ViolationAlertService.sendAlertForCase(caseId);
        Test.stopTest();

        System.assert(r.alertCreated, 'A Task was created for a case with violations');
        System.assertEquals(1, r.violationCount, 'DTI_MAX is the single violation');
        System.assert(!r.summary.toLowerCase().contains('denied'), 'Guardrail: never denied');

        List<Task> tasks = [SELECT Subject, Description, WhatId, OwnerId, Status
                            FROM Task WHERE WhatId = :caseId];
        System.assertEquals(1, tasks.size(), 'Exactly one alert Task');
        System.assertEquals('Violation alert: ' + caseName, tasks[0].Subject, 'Subject names the case');
        System.assertEquals(caseId, tasks[0].WhatId, 'Task links back to the case (WhatId)');
        System.assertEquals(UserInfo.getUserId(), tasks[0].OwnerId, 'Owned by the assigned auditor');
        System.assert(tasks[0].Description.contains('Debt vs. income too high'), 'Plain-word rule in body');
        System.assert(tasks[0].Description.contains('(DTI_MAX)'), 'Rule code badge in body');

        assertDualWrite(caseId, 'Send_Violation_Alert', 'Success');
    }

    // ── IDEMPOTENCY (Negative-ish) ────────────────────────────────────────
    @IsTest
    static void sendAlert_secondCall_isIdempotent_noDuplicateTask() {
        Id caseId = heroCaseId();
        ReplayService.replay(caseId);

        Test.startTest();
        ViolationAlertService.sendAlertForCase(caseId);          // first: creates task
        ViolationAlertService.Response r2 = ViolationAlertService.sendAlertForCase(caseId); // second: no dup
        Test.stopTest();

        System.assert(!r2.alertCreated, 'Second call creates no Task');
        System.assert(r2.alreadyAlerted, 'Second call reports already-alerted');
        System.assertEquals('Partial', r2.actionStatus, 'Idempotent re-call is a Partial');

        System.assertEquals(1, [SELECT COUNT() FROM Task WHERE WhatId = :caseId],
            'Still exactly one Task after a duplicate request');
        // Both invocations still logged (log-before-execute is unconditional).
        System.assertEquals(2,
            [SELECT COUNT() FROM Agent_Action_Log__c
             WHERE Audit_Case__c = :caseId AND Action_Name__c = 'Send_Violation_Alert'],
            'Both invocations wrote an intent log');
    }

    // ── CLEAN CASE ────────────────────────────────────────────────────────
    @IsTest
    static void sendAlert_cleanCase_noTask_gracefulPartial() {
        Loan__c loan = new Loan__c(Borrower_Name__c = 'Clean', Loan_Amount__c = 200000,
            Property_Value__c = 300000, Loan_Type__c = 'Conventional', Purpose__c = 'Purchase',
            Approval_Date__c = Date.today());
        insert loan;
        Audit_Case__c ac = new Audit_Case__c(Loan__c = loan.Id, Loan_Application__c = 'clean-alert',
            Status__c = 'Ready_for_Signoff', Risk_Tier__c = 'Low', Due_At__c = Datetime.now().addDays(5));
        insert ac;
        // A latest replay batch with only a Pass check → no violations.
        Id ruleId = [SELECT Id FROM Policy_Rule__c WHERE Rule_Code__c = 'DTI_MAX' LIMIT 1].Id;
        insert new Replay_Check__c(Audit_Case__c = ac.Id, Policy_Rule__c = ruleId,
            Rule_Name__c = 'FICO_MIN', Result__c = 'Pass', Expected_Value__c = '620',
            Actual_Value__c = '710', Replay_Timestamp__c = Datetime.now());

        Test.startTest();
        ViolationAlertService.Response r = ViolationAlertService.sendAlertForCase(ac.Id);
        Test.stopTest();

        System.assert(!r.alertCreated, 'No Task when there are no violations');
        System.assertEquals(0, r.violationCount, 'Zero violations');
        System.assertEquals('Partial', r.actionStatus, 'Graceful Partial');
        System.assert(r.summary.contains('nothing to alert'), 'No-violations message');
        System.assertEquals(0, [SELECT COUNT() FROM Task WHERE WhatId = :ac.Id], 'No Task created');
        assertDualWrite(ac.Id, 'Send_Violation_Alert', 'Partial');
    }

    // ── GHOST CASE (fail-closed) ──────────────────────────────────────────
    @IsTest
    static void sendAlert_nonexistentCase_failsClosed_noOrphanTrail() {
        Id fakeCase = Schema.SObjectType.Audit_Case__c.getKeyPrefix() + '000000000001AAA';

        Test.startTest();
        Boolean threw = false;
        try {
            ViolationAlertService.sendAlertForCase(fakeCase);
        } catch (Exception e) {
            threw = true;
        }
        Test.stopTest();

        System.assert(threw, 'A nonexistent case fails closed (cannot alert against a ghost case)');
        System.assertEquals(0,
            [SELECT COUNT() FROM Agent_Action_Log__c WHERE Audit_Case__c = :fakeCase],
            'No orphan intent log');
        System.assertEquals(0,
            [SELECT COUNT() FROM Task WHERE WhatId = :fakeCase], 'No orphan Task');
    }

    // ── BULK 200 ──────────────────────────────────────────────────────────
    @IsTest
    static void sendAlert_bulk200_isGovernorSafe_oneTaskPerCase() {
        List<Loan__c> loans = new List<Loan__c>();
        for (Integer i = 0; i < 200; i++) {
            loans.add(new Loan__c(Borrower_Name__c = 'Bulk ' + i, Loan_Amount__c = 300000,
                Property_Value__c = 400000, Loan_Type__c = 'Conventional',
                Purpose__c = 'Purchase', Approval_Date__c = Date.today()));
        }
        insert loans;

        List<Audit_Case__c> cases = new List<Audit_Case__c>();
        for (Integer i = 0; i < 200; i++) {
            cases.add(new Audit_Case__c(Loan__c = loans[i].Id, Loan_Application__c = 'bulk-a-' + i,
                Status__c = 'In_Review', Risk_Tier__c = 'High', Due_At__c = Datetime.now().addDays(30)));
        }
        insert cases;

        // Each case gets a latest replay batch with one Fail check (Auditor__c left
        // null so the running-user fallback branch is exercised under load).
        Id ruleId = [SELECT Id FROM Policy_Rule__c WHERE Rule_Code__c = 'DTI_MAX' LIMIT 1].Id;
        List<Replay_Check__c> checks = new List<Replay_Check__c>();
        Datetime ts = Datetime.now();
        for (Audit_Case__c c : cases) {
            checks.add(new Replay_Check__c(Audit_Case__c = c.Id, Policy_Rule__c = ruleId,
                Rule_Name__c = 'DTI_MAX', Result__c = 'Fail', Expected_Value__c = '43',
                Actual_Value__c = '44.8', Replay_Timestamp__c = ts));
        }
        insert checks;

        List<ViolationAlertService.Request> reqs = new List<ViolationAlertService.Request>();
        for (Audit_Case__c c : cases) {
            ViolationAlertService.Request req = new ViolationAlertService.Request();
            req.auditCaseId = c.Id;
            reqs.add(req);
        }

        Test.startTest();
        Integer soqlBefore = Limits.getQueries();
        Integer dmlBefore  = Limits.getDmlStatements();
        List<ViolationAlertService.Response> out = ViolationAlertService.sendAlert(reqs);
        Integer soqlUsed = Limits.getQueries() - soqlBefore;
        Integer dmlUsed  = Limits.getDmlStatements() - dmlBefore;
        Test.stopTest();

        System.assertEquals(200, out.size(), 'One response per request');
        System.assert(soqlUsed <= 4, 'Reads hoisted: constant SOQL, got ' + soqlUsed);
        System.assertEquals(4, dmlUsed, 'Writes batched: logs + events + tasks + events = 4 DML');

        System.assertEquals(200,
            [SELECT COUNT() FROM Agent_Action_Log__c
             WHERE Action_Name__c = 'Send_Violation_Alert' AND Status__c = 'Initiated'],
            '200 intent logs, all Initiated');
        System.assertEquals(400,
            [SELECT COUNT() FROM Audit_Event__c WHERE Event_Type__c = 'Agent_Action'],
            '400 Agent_Action events across 200 actions');
        System.assertEquals(200,
            [SELECT COUNT() FROM Task WHERE Subject LIKE 'Violation alert:%'],
            'Exactly one Task per case (≤ 1 per case)');
    }

    // ── shared dual-write assertion ───────────────────────────────────────
    private static void assertDualWrite(Id caseId, String action, String expectedOutcome) {
        List<Agent_Action_Log__c> logs = [
            SELECT Action_Name__c, Status__c FROM Agent_Action_Log__c WHERE Audit_Case__c = :caseId];
        System.assertEquals(1, logs.size(), 'One governed intent log');
        System.assertEquals(action, logs[0].Action_Name__c, 'Action picklist value matches');
        System.assertEquals('Initiated', logs[0].Status__c, 'Intent stays Initiated');

        List<Audit_Event__c> events = [
            SELECT Payload__c FROM Audit_Event__c
            WHERE Audit_Case__c = :caseId AND Event_Type__c = 'Agent_Action'
            ORDER BY CreatedDate ASC];
        System.assertEquals(2, events.size(), 'Dual-write: initiated + outcome');
        System.assert(events[0].Payload__c.contains('"phase":"initiated"'), 'First event initiated');
        System.assert(events[1].Payload__c.contains('"phase":"outcome"'), 'Second event outcome');
        System.assert(events[1].Payload__c.contains('"status":"' + expectedOutcome + '"'),
            'Outcome event records the real status');
    }
}
