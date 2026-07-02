/**
 * CaseSummaryServiceTest — proves the read-only "summarize this case" action
 * assembles a plain-English briefing from stored data, holds the guardrails
 * (never "denied", always defers to the human auditor), and honours the ADR-26
 * log-before-execute dual-write (Initiated intent log + initiated/outcome event
 * pair) while staying bulk-safe (constant SOQL/DML).
 */
@IsTest
private class CaseSummaryServiceTest {

    @TestSetup
    static void seed() {
        // Hero-case shape: DTI fails, FICO passes, LTV is unverifiable (no fact),
        // and two required trailing docs are still missing.
        Loan__c loan = new Loan__c(
            Borrower_Name__c  = 'Sabir Asheed Sr.',
            Loan_Amount__c    = 380000,
            Property_Value__c  = 475000,
            Loan_Type__c      = 'Conventional',
            Purpose__c        = 'Purchase',
            LOS_Loan_Id__c    = 'LOS-HERO-1',
            Approval_Date__c  = Date.newInstance(2025, 3, 15)
        );
        insert loan;

        Audit_Case__c ac = new Audit_Case__c(
            Loan__c = loan.Id, Loan_Application__c = 'a0SummaryTest',
            Borrower_Name_Snapshot__c = 'Sabir Asheed Sr.',
            Status__c = 'In_Review', Risk_Tier__c = 'High',
            Due_At__c = Datetime.now().addDays(10)
        );
        insert ac;

        insert new List<Borrower_Snapshot__c>{
            new Borrower_Snapshot__c(Audit_Case__c = ac.Id, Fact_Category__c = 'Income',
                DTI_Ratio__c = 44.8, Annual_Income__c = 95000, Monthly_Income__c = 7916.67),
            new Borrower_Snapshot__c(Audit_Case__c = ac.Id, Fact_Category__c = 'Credit',
                FICO_Score__c = 710)
        };

        // Two required trailing documents, still Missing (the hero case), plus one
        // linked document so the linked/total counts are meaningful.
        insert new List<Evidence_Item__c>{
            new Evidence_Item__c(Audit_Case__c = ac.Id, Document_Type__c = 'Recorded_Mortgage',
                Status__c = 'Missing', Required__c = true),
            new Evidence_Item__c(Audit_Case__c = ac.Id, Document_Type__c = 'Final_Title_Policy',
                Status__c = 'Missing', Required__c = true),
            new Evidence_Item__c(Audit_Case__c = ac.Id, Document_Type__c = 'Pay_Stub',
                Status__c = 'Linked', Required__c = true)
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
                Threshold_Value__c = 620, Fact_Field__c = 'FICO_Score__c', Severity__c = 'Hard_Decline'),
            // LTV_MAX has no LTV fact in the snapshot => Unverifiable check.
            new Policy_Rule__c(Policy_Version__c = pv.Id, Rule_Code__c = 'LTV_MAX',
                Rule_Label__c = 'Max LTV', Rule_Category__c = 'Collateral', Operator__c = 'LTE',
                Threshold_Value__c = 80, Fact_Field__c = 'LTV_Ratio__c', Severity__c = 'Hard_Decline')
        };
    }

    private static Id heroCaseId() {
        return [SELECT Id FROM Audit_Case__c WHERE Loan_Application__c = 'a0SummaryTest' LIMIT 1].Id;
    }

    @IsTest
    static void summarize_heroCase_narratesFactsAndLogsDualWrite() {
        Id caseId = heroCaseId();
        ReplayService.replay(caseId);

        Test.startTest();
        CaseSummaryService.Response r = CaseSummaryService.summarizeCase(caseId);
        Test.stopTest();

        // Replay tallies from the deterministic kernel.
        System.assert(r.hasViolations, 'DTI_MAX must surface as a violation');
        System.assertEquals(1, r.violationCount, 'Exactly DTI_MAX fails');
        System.assertEquals(1, r.passCount, 'FICO_MIN passes');
        System.assertEquals(1, r.unverifiableCount, 'LTV_MAX is unverifiable (no LTV fact)');

        // Facts appear as whole-number percents / raw score.
        System.assert(r.summary.contains('DTI 44.8%'), 'DTI printed as whole-number percent: ' + r.summary);
        System.assert(r.summary.contains('FICO 710'), 'FICO printed as raw score');
        System.assert(r.summary.contains('Debt vs. income too high (DTI_MAX)'),
            'Failing rule named plainly with code badge');

        // Evidence rollup: 1 of 3 linked, 2 required missing incl. the trailing docs.
        System.assert(r.summary.contains('1 of 3 documents linked'), 'Evidence counts: ' + r.summary);
        System.assert(r.summary.contains('2 required'), 'Two required documents missing');
        System.assert(r.summary.contains('Recorded Mortgage'), 'Trailing doc surfaced');
        System.assert(r.summary.contains('Final Title Policy'), 'Trailing doc surfaced');

        // Header facts.
        System.assert(r.summary.contains('Status: In Review'), 'Status de-underscored');
        System.assert(r.summary.contains('Risk tier: High'), 'Risk tier reported');
        System.assert(r.summary.contains('due in about'), 'SLA phrased from Due_At');

        // Guardrails.
        System.assert(r.summary.contains('human auditor'), 'Defers final call to a person');
        System.assert(!r.summary.toLowerCase().contains('denied'), 'Never says denied');
        System.assertEquals(false, r.stale, 'Replay newer than loan edit');

        assertDualWrite(caseId, 'Summarize_Case', 'Success');
    }

    @IsTest
    static void summarize_cleanCase_noReplay_isSuccessAndGraceful() {
        Id caseId = heroCaseId();

        Test.startTest();
        CaseSummaryService.Response r = CaseSummaryService.summarizeCase(caseId);
        Test.stopTest();

        System.assertEquals(false, r.hasViolations, 'No replay => no violations reported');
        System.assert(r.summary.contains('has not been run'), 'Prompts to run the check first');
        System.assert(!r.summary.toLowerCase().contains('denied'), 'Guardrail holds with no replay');
        // Still logs before execute and dual-writes (Success — the summary itself succeeded).
        assertDualWrite(caseId, 'Summarize_Case', 'Success');
    }

    @IsTest
    static void summarize_nonexistentCase_failsClosed_noOrphanTrail() {
        // A syntactically valid Audit_Case key that matches no record. Governance
        // reality (docs said "graceful"): you CANNOT log-before-execute against a
        // ghost case — the immutable Agent_Action_Log__c insert rejects a dangling
        // parent, so the whole action fails closed and writes NO orphan audit trail.
        Id fakeCase = Schema.SObjectType.Audit_Case__c.getKeyPrefix() + '000000000001AAA';

        Test.startTest();
        Boolean threw = false;
        try {
            CaseSummaryService.summarizeCase(fakeCase);
        } catch (Exception e) {
            threw = true;
        }
        Test.stopTest();

        System.assert(threw, 'A nonexistent case fails closed (cannot audit a ghost case)');
        System.assertEquals(0,
            [SELECT COUNT() FROM Agent_Action_Log__c WHERE Audit_Case__c = :fakeCase],
            'No orphan intent log is created for a nonexistent case');
        System.assertEquals(0,
            [SELECT COUNT() FROM Audit_Event__c WHERE Audit_Case__c = :fakeCase],
            'No orphan audit event is created for a nonexistent case');
    }

    @IsTest
    static void summarize_bulk200_isGovernorSafe_andDualWrites() {
        List<Loan__c> loans = new List<Loan__c>();
        for (Integer i = 0; i < 200; i++) {
            loans.add(new Loan__c(Borrower_Name__c = 'Bulk ' + i, Loan_Amount__c = 300000,
                Property_Value__c = 400000, Loan_Type__c = 'Conventional',
                Purpose__c = 'Purchase', Approval_Date__c = Date.today()));
        }
        insert loans;

        List<Audit_Case__c> cases = new List<Audit_Case__c>();
        for (Integer i = 0; i < 200; i++) {
            cases.add(new Audit_Case__c(Loan__c = loans[i].Id, Loan_Application__c = 'bulk-' + i,
                Status__c = 'In_Review', Risk_Tier__c = 'High', Due_At__c = Datetime.now().addDays(30)));
        }
        insert cases;

        List<CaseSummaryService.Request> reqs = new List<CaseSummaryService.Request>();
        for (Audit_Case__c c : cases) {
            CaseSummaryService.Request req = new CaseSummaryService.Request();
            req.auditCaseId = c.Id;
            reqs.add(req);
        }

        Test.startTest();
        Integer soqlBefore = Limits.getQueries();
        Integer dmlBefore  = Limits.getDmlStatements();
        List<CaseSummaryService.Response> out = CaseSummaryService.summarize(reqs);
        Integer soqlUsed = Limits.getQueries() - soqlBefore;
        Integer dmlUsed  = Limits.getDmlStatements() - dmlBefore;
        Test.stopTest();

        System.assertEquals(200, out.size(), 'One response per request');
        System.assert(soqlUsed <= 5, 'Reads hoisted: constant SOQL regardless of count, got ' + soqlUsed);
        System.assertEquals(3, dmlUsed, 'Writes batched: 3 DML for any request count');

        System.assertEquals(200,
            [SELECT COUNT() FROM Agent_Action_Log__c WHERE Action_Name__c = 'Summarize_Case' AND Status__c = 'Initiated'],
            '200 intent logs, all Initiated');
        System.assertEquals(400,
            [SELECT COUNT() FROM Audit_Event__c WHERE Event_Type__c = 'Agent_Action'],
            '400 Agent_Action events (initiated + outcome) across 200 actions');
    }

    // ── shared assertion ────────────────────────────────────────────────
    private static void assertDualWrite(Id caseId, String action, String expectedOutcome) {
        List<Agent_Action_Log__c> logs = [
            SELECT Action_Name__c, Status__c FROM Agent_Action_Log__c WHERE Audit_Case__c = :caseId];
        System.assertEquals(1, logs.size(), 'One governed intent log');
        System.assertEquals(action, logs[0].Action_Name__c, 'Action picklist value matches');
        System.assertEquals('Initiated', logs[0].Status__c, 'Intent stays Initiated (append-only)');

        List<Audit_Event__c> events = [
            SELECT Payload__c FROM Audit_Event__c
            WHERE Audit_Case__c = :caseId AND Event_Type__c = 'Agent_Action'
            ORDER BY CreatedDate ASC];
        System.assertEquals(2, events.size(), 'Dual-write: initiated + outcome');
        System.assert(events[0].Payload__c.contains('"phase":"initiated"'), 'First event is initiated');
        System.assert(events[1].Payload__c.contains('"phase":"outcome"'), 'Second event is outcome');
        System.assert(events[1].Payload__c.contains('"status":"' + expectedOutcome + '"'),
            'Outcome event records the real status');
    }
}
