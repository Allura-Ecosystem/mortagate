/**
 * LoanDiagnosisServiceTest — proves the read-only "what's wrong with this loan?"
 * action narrates stored replay checks, respects the guardrails, writes an
 * Agent_Action_Log__c, and handles the no-replay case.
 */
@IsTest
private class LoanDiagnosisServiceTest {

    @TestSetup
    static void seed() {
        Loan__c loan = new Loan__c(
            Borrower_Name__c = 'Sabir Asheed Sr.',
            Loan_Amount__c   = 380000,
            Property_Value__c = 475000,
            Loan_Type__c     = 'Conventional',
            Purpose__c       = 'Purchase',
            Approval_Date__c = Date.newInstance(2025, 3, 15)
        );
        insert loan;

        Audit_Case__c ac = new Audit_Case__c(
            Loan__c = loan.Id, Loan_Application__c = 'a0DiagTest',
            Status__c = 'In_Review', Risk_Tier__c = 'High',
            Due_At__c = Datetime.now().addDays(30)
        );
        insert ac;

        insert new List<Borrower_Snapshot__c>{
            new Borrower_Snapshot__c(Audit_Case__c = ac.Id, Fact_Category__c = 'Income',
                DTI_Ratio__c = 44.8, Annual_Income__c = 95000, Monthly_Income__c = 7916.67),
            new Borrower_Snapshot__c(Audit_Case__c = ac.Id, Fact_Category__c = 'Credit',
                FICO_Score__c = 710)
        };

        Policy_Version__c pv = new Policy_Version__c(
            Version_Label__c = 'Q1 2025 Conventional', Version_Number__c = 1,
            Effective_Date__c = Date.newInstance(2025, 1, 1), Is_Active__c = true,
            Policy_Type__c = 'Conventional'
        );
        insert pv;

        insert new List<Policy_Rule__c>{
            new Policy_Rule__c(Policy_Version__c = pv.Id, Rule_Code__c = 'DTI_MAX',
                Rule_Label__c = 'Max DTI', Rule_Category__c = 'Income', Operator__c = 'LTE',
                Threshold_Value__c = 43, Fact_Field__c = 'DTI_Ratio__c', Severity__c = 'Hard_Decline'),
            new Policy_Rule__c(Policy_Version__c = pv.Id, Rule_Code__c = 'FICO_MIN',
                Rule_Label__c = 'Min FICO', Rule_Category__c = 'Credit', Operator__c = 'GTE',
                Threshold_Value__c = 620, Fact_Field__c = 'FICO_Score__c', Severity__c = 'Hard_Decline')
        };
    }

    private static Id sabirCaseId() {
        return [SELECT Id FROM Audit_Case__c WHERE Loan__r.Borrower_Name__c = 'Sabir Asheed Sr.' LIMIT 1].Id;
    }

    @IsTest
    static void diagnose_surfacesDtiViolation_andLogsAction() {
        Id caseId = sabirCaseId();
        ReplayService.replay(caseId); // populate Replay_Check__c

        Test.startTest();
        LoanDiagnosisService.Response r = LoanDiagnosisService.diagnoseCase(caseId);
        Test.stopTest();

        System.assert(r.hasViolations, 'DTI_MAX must be reported as a violation');
        System.assertEquals(1, r.violationCount, 'Exactly DTI_MAX fails (44.8 > 43)');
        // THE LEO FLIP: summary now LEADS WITH the plain name; the raw code lives
        // on as a parenthetical badge.
        System.assert(r.summary.contains('Debt vs. income too high'),
            'Summary leads with the plain-language name (the Leo flip)');
        System.assert(r.summary.contains('DTI_MAX'),
            'Summary keeps the raw code as a parenthetical badge');
        System.assert(r.summary.contains('(DTI_MAX)'),
            'Code appears specifically as the (CODE) badge after the plain name');
        // Clearer numbers: direction phrase + both values.
        System.assert(r.summary.contains('the most allowed is 43'),
            'Ceiling rule (DTI_MAX) phrased as "the most allowed is" with the threshold');
        System.assert(r.summary.contains('but this loan is 44.8'),
            'Summary still shows the actual loan value in plain numbers');
        System.assert(r.summary.contains('human auditor'),
            'Summary must defer final determination to the human auditor');
        System.assert(!r.summary.toLowerCase().contains('denied'),
            'Guardrail: must never say the loan should be denied');
        System.assertEquals(false, r.stale, 'Replay newer than loan edit => not stale');

        // LOG-BEFORE-EXECUTE: exactly one append-only intent row, written with
        // Status 'Initiated' BEFORE the narration ran. It is NEVER updated to
        // 'Success' — the outcome lands on an appended Audit_Event__c instead.
        List<Agent_Action_Log__c> logs = [
            SELECT Id, Action_Name__c, Subagent__c, Status__c, Output_Summary__c, Audit_Case__c
            FROM Agent_Action_Log__c WHERE Audit_Case__c = :caseId
        ];
        System.assertEquals(1, logs.size(), 'One governed intent log per diagnosis');
        System.assertEquals('Summarize_Case', logs[0].Action_Name__c);
        System.assertEquals('Auditor_Assistant', logs[0].Subagent__c);
        System.assertEquals('Initiated', logs[0].Status__c,
            'Intent row is logged BEFORE execution, so it stays Initiated (append-only)');

        // DUAL-WRITE (FR-23): two Audit_Event__c 'Agent_Action' rows bracket the
        // action — one before (initiated), one after (outcome). The outcome event
        // carries the real result (Success) and the narrated summary.
        List<Audit_Event__c> agentEvents = [
            SELECT Payload__c, Related_Record_Id__c
            FROM Audit_Event__c
            WHERE Audit_Case__c = :caseId AND Event_Type__c = 'Agent_Action'
            ORDER BY CreatedDate ASC
        ];
        System.assertEquals(2, agentEvents.size(),
            'Dual-write brackets the action: one initiated event, one outcome event');
        System.assert(agentEvents[0].Payload__c.contains('"phase":"initiated"'),
            'First Agent_Action event is the before-execute (initiated) write');
        System.assert(agentEvents[1].Payload__c.contains('"phase":"outcome"'),
            'Second Agent_Action event is the after-execute (outcome) write');
        System.assert(agentEvents[1].Payload__c.contains('"status":"Success"'),
            'Outcome event records the real Success result (never patched onto the log)');
        System.assertEquals(String.valueOf(logs[0].Id), agentEvents[1].Related_Record_Id__c,
            'Outcome event back-links to the intent Agent_Action_Log__c row');
    }

    @IsTest
    static void diagnose_noReplayYet_returnsRunReplayMessage() {
        Id caseId = sabirCaseId();

        Test.startTest();
        LoanDiagnosisService.Response r = LoanDiagnosisService.diagnoseCase(caseId);
        Test.stopTest();

        System.assertEquals(false, r.hasViolations);
        System.assert(r.summary.contains('Run the check first'),
            'Without replay checks, prompt (in plain language) to run the check first');
        // Even the no-replay path logs before it executes and dual-writes.
        List<Agent_Action_Log__c> logs = [
            SELECT Status__c FROM Agent_Action_Log__c WHERE Audit_Case__c = :caseId
        ];
        System.assertEquals(1, logs.size(), 'Even the no-replay path is logged');
        System.assertEquals('Initiated', logs[0].Status__c,
            'Intent row logged before execution stays Initiated');

        List<Audit_Event__c> agentEvents = [
            SELECT Payload__c FROM Audit_Event__c
            WHERE Audit_Case__c = :caseId AND Event_Type__c = 'Agent_Action'
            ORDER BY CreatedDate ASC
        ];
        System.assertEquals(2, agentEvents.size(),
            'No-replay path still dual-writes initiated + outcome events');
        System.assert(agentEvents[1].Payload__c.contains('"status":"Partial"'),
            'No-replay outcome is recorded as Partial on the appended event');
    }

    // ── R-11: diagnosing a TWICE-replayed case counts the latest batch only ──

    @IsTest
    static void diagnose_doubleReplay_doesNotDoubleCountViolations() {
        Id caseId = sabirCaseId();

        // First (superseded) batch, backdated so it is provably older.
        List<Replay_Check__c> firstBatch = ReplayService.replay(caseId);
        Datetime backdated = Datetime.now().addHours(-1);
        for (Replay_Check__c rc : firstBatch) { rc.Replay_Timestamp__c = backdated; }
        update firstBatch;

        // Second (current) batch.
        ReplayService.replay(caseId);

        Test.startTest();
        LoanDiagnosisService.Response r = LoanDiagnosisService.diagnoseCase(caseId);
        Test.stopTest();

        // This 2-rule fixture has exactly 1 violation (DTI_MAX). Two stacked
        // batches must NOT report 2 — only the latest batch is diagnosed.
        System.assertEquals(1, r.violationCount,
            'Duplicate replays must not double-count violations');
        System.assertEquals(2, r.findings.size(),
            'Findings reflect ONE batch (2 rules), not the stacked 4');
    }

    @IsTest
    static void diagnose_invocableEntryPoint_returnsResponsePerRequest() {
        Id caseId = sabirCaseId();
        ReplayService.replay(caseId);

        LoanDiagnosisService.Request req = new LoanDiagnosisService.Request();
        req.auditCaseId = caseId;

        Test.startTest();
        List<LoanDiagnosisService.Response> out =
            LoanDiagnosisService.diagnose(new List<LoanDiagnosisService.Request>{ req });
        Test.stopTest();

        System.assertEquals(1, out.size());
        System.assert(out[0].findings.size() >= 2, 'Findings list one line per replay check');
    }

    // ── Bulk safety: the invocable path is a bulk entry point. 200+ requests in
    //    one transaction must stay within governor limits (all reads hoisted,
    //    all writes batched: 3 SOQL + 3 DML regardless of request count). ──────

    @IsTest
    static void diagnose_bulk200_isGovernorSafe_andDualWrites() {
        List<Loan__c> loans = new List<Loan__c>();
        for (Integer i = 0; i < 200; i++) {
            loans.add(new Loan__c(
                Borrower_Name__c  = 'Bulk Borrower ' + i,
                Loan_Amount__c    = 300000,
                Property_Value__c = 400000,
                Loan_Type__c      = 'Conventional',
                Purpose__c        = 'Purchase',
                Approval_Date__c  = Date.today()
            ));
        }
        insert loans;

        List<Audit_Case__c> cases = new List<Audit_Case__c>();
        for (Integer i = 0; i < 200; i++) {
            cases.add(new Audit_Case__c(
                Loan__c             = loans[i].Id,
                Loan_Application__c = 'bulk-' + i,
                Status__c           = 'In_Review',
                Risk_Tier__c        = 'High',
                Due_At__c           = Datetime.now().addDays(30)
            ));
        }
        insert cases;

        List<LoanDiagnosisService.Request> reqs = new List<LoanDiagnosisService.Request>();
        for (Audit_Case__c c : cases) {
            LoanDiagnosisService.Request req = new LoanDiagnosisService.Request();
            req.auditCaseId = c.Id;
            reqs.add(req);
        }

        Test.startTest();
        Integer soqlBefore = Limits.getQueries();
        Integer dmlBefore  = Limits.getDmlStatements();
        List<LoanDiagnosisService.Response> out = LoanDiagnosisService.diagnose(reqs);
        Integer soqlUsed = Limits.getQueries() - soqlBefore;
        Integer dmlUsed  = Limits.getDmlStatements() - dmlBefore;
        Test.stopTest();

        System.assertEquals(200, out.size(), 'One response per request');
        // Constant cost — proves no SOQL/DML in the per-case loop. The read path
        // is <=3 SOQL (AuditSoql short-circuits its 2nd query when a case has no
        // replay batch) and stays flat no matter how many requests arrive.
        System.assert(soqlUsed <= 3,
            'Reads are hoisted: <=3 SOQL for any request count, got ' + soqlUsed);
        System.assertEquals(3, dmlUsed, 'Writes are batched: 3 DML for any request count');

        // One append-only intent row per action, all 'Initiated'.
        System.assertEquals(200, [SELECT COUNT() FROM Agent_Action_Log__c WHERE Status__c = 'Initiated'],
            '200 intent logs, all logged before execute');
        // Dual-write: 2 Agent_Action events per action (initiated + outcome).
        System.assertEquals(400, [SELECT COUNT() FROM Audit_Event__c WHERE Event_Type__c = 'Agent_Action'],
            '400 Agent_Action events (initiated + outcome) across 200 actions');
    }
}
