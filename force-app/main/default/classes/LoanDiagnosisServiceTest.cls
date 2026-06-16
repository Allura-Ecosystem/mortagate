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
        System.assert(r.summary.contains('DTI_MAX'), 'Summary names the violated rule');
        System.assert(r.summary.contains('human auditor'),
            'Summary must defer final determination to the human auditor');
        System.assert(!r.summary.toLowerCase().contains('denied'),
            'Guardrail: must never say the loan should be denied');
        System.assertEquals(false, r.stale, 'Replay newer than loan edit => not stale');

        List<Agent_Action_Log__c> logs = [
            SELECT Action_Name__c, Subagent__c, Status__c, Audit_Case__c
            FROM Agent_Action_Log__c WHERE Audit_Case__c = :caseId
        ];
        System.assertEquals(1, logs.size(), 'One governed action log per diagnosis');
        System.assertEquals('Summarize_Case', logs[0].Action_Name__c);
        System.assertEquals('Auditor_Assistant', logs[0].Subagent__c);
        System.assertEquals('Success', logs[0].Status__c);
    }

    @IsTest
    static void diagnose_noReplayYet_returnsRunReplayMessage() {
        Id caseId = sabirCaseId();

        Test.startTest();
        LoanDiagnosisService.Response r = LoanDiagnosisService.diagnoseCase(caseId);
        Test.stopTest();

        System.assertEquals(false, r.hasViolations);
        System.assert(r.summary.contains('Replay has not been run'),
            'Without replay checks, prompt to run replay first');
        System.assertEquals(1,
            [SELECT COUNT() FROM Agent_Action_Log__c WHERE Audit_Case__c = :caseId],
            'Even the no-replay path is logged');
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
}
