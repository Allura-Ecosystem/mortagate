/**
 * FindingDraftServiceTest — proves the "draft the finding text" action assembles
 * a deterministic narrative from a failing replay check (by Id and by rule code),
 * NEVER inserts a Finding__c, holds the guardrails, and honours the ADR-26
 * log-before-execute dual-write while staying bulk-safe.
 */
@IsTest
private class FindingDraftServiceTest {

    @TestSetup
    static void seed() {
        Loan__c loan = new Loan__c(
            Borrower_Name__c = 'Sabir Asheed Sr.', Loan_Amount__c = 380000,
            Property_Value__c = 475000, Loan_Type__c = 'Conventional',
            Purpose__c = 'Purchase', LOS_Loan_Id__c = 'LOS-HERO-3',
            Approval_Date__c = Date.newInstance(2025, 3, 15));
        insert loan;

        Audit_Case__c ac = new Audit_Case__c(
            Loan__c = loan.Id, Loan_Application__c = 'a0DraftTest',
            Borrower_Name_Snapshot__c = 'Sabir Asheed Sr.',
            Status__c = 'In_Review', Risk_Tier__c = 'High',
            Due_At__c = Datetime.now().addDays(10));
        insert ac;

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
            new Policy_Rule__c(Policy_Version__c = pv.Id, Rule_Code__c = 'FICO_MIN',
                Rule_Label__c = 'Min FICO', Rule_Category__c = 'Credit', Operator__c = 'GTE',
                Threshold_Value__c = 620, Fact_Field__c = 'FICO_Score__c', Severity__c = 'Hard_Decline')
        };
    }

    private static Id heroCaseId() {
        return [SELECT Id FROM Audit_Case__c WHERE Loan_Application__c = 'a0DraftTest' LIMIT 1].Id;
    }

    @IsTest
    static void draft_fromCheckId_buildsNarrative_andInsertsNoFinding() {
        Id caseId = heroCaseId();
        ReplayService.replay(caseId);
        Replay_Check__c dti = [
            SELECT Id FROM Replay_Check__c
            WHERE Audit_Case__c = :caseId AND Rule_Name__c = 'DTI_MAX' LIMIT 1];

        Test.startTest();
        FindingDraftService.Response r = FindingDraftService.draftFromCheck(caseId, dti.Id);
        Test.stopTest();

        System.assert(r.found, 'The DTI_MAX check was found');
        System.assertEquals('DTI_MAX', r.ruleCode);
        System.assert(r.draftText.contains('DRAFT FINDING'), 'Marked as a draft');
        System.assert(r.draftText.contains('Debt vs. income too high (DTI_MAX)'),
            'Plain rule name + code badge');
        System.assert(r.draftText.contains('the most allowed is 43'), 'Expected threshold in words');
        System.assert(r.draftText.contains('44.8'), 'Actual loan value present');
        System.assert(r.draftText.contains('did not pass'), 'Result phrased without a verdict word');

        // Guardrails.
        System.assert(!r.draftText.toLowerCase().contains('denied'), 'Never says denied');
        System.assert(r.draftText.contains('human auditor'), 'Defers final determination');

        // CRITICAL: the action drafts text ONLY — no Finding__c is created.
        System.assertEquals(0, [SELECT COUNT() FROM Finding__c],
            'Draft action must not insert a Finding record');

        assertDualWrite(caseId, 'Draft_Finding_Text', 'Success');
    }

    @IsTest
    static void draft_fromRuleCode_resolvesLatestBatch() {
        Id caseId = heroCaseId();
        ReplayService.replay(caseId);

        Test.startTest();
        FindingDraftService.Response r = FindingDraftService.draftFromRuleCode(caseId, 'dti_max');
        Test.stopTest();

        System.assert(r.found, 'Rule code resolves (case-insensitive) against the latest batch');
        System.assertEquals('DTI_MAX', r.ruleCode);
        System.assert(r.draftText.contains('the most allowed is 43'), 'Narrative assembled from the check');
        System.assertEquals(0, [SELECT COUNT() FROM Finding__c], 'No Finding inserted');
    }

    @IsTest
    static void draft_withLinkedEvidence_narratesEvidenceLine() {
        Id caseId = heroCaseId();
        ReplayService.replay(caseId);
        Evidence_Item__c ev = new Evidence_Item__c(Audit_Case__c = caseId,
            Document_Type__c = 'Pay_Stub', Status__c = 'Linked', Required__c = true);
        insert ev;
        Replay_Check__c dti = [
            SELECT Id FROM Replay_Check__c
            WHERE Audit_Case__c = :caseId AND Rule_Name__c = 'DTI_MAX' LIMIT 1];
        dti.Evidence_Item__c = ev.Id;
        update dti;

        Test.startTest();
        FindingDraftService.Response r = FindingDraftService.draftFromCheck(caseId, dti.Id);
        Test.stopTest();

        System.assert(r.draftText.contains('Supporting evidence: Pay Stub is linked'),
            'Evidence linkage narrated: ' + r.draftText);
    }

    @IsTest
    static void draft_noMatchingCheck_isPartialAndDrafts_nothing() {
        Id caseId = heroCaseId();  // no replay run => no checks

        Test.startTest();
        FindingDraftService.Response r = FindingDraftService.draftFromRuleCode(caseId, 'DTI_MAX');
        Test.stopTest();

        System.assertEquals(false, r.found, 'No check to draft from');
        System.assertEquals('Partial', r.actionStatus);
        System.assert(r.draftText.contains('nothing to draft') || r.draftText.contains('Run the check'),
            'Graceful no-check message');
        System.assertEquals(0, [SELECT COUNT() FROM Finding__c], 'Still inserts no Finding');
        assertDualWrite(caseId, 'Draft_Finding_Text', 'Partial');
    }

    @IsTest
    static void draft_bulk200_isGovernorSafe_andDualWrites() {
        List<Loan__c> loans = new List<Loan__c>();
        for (Integer i = 0; i < 200; i++) {
            loans.add(new Loan__c(Borrower_Name__c = 'Bulk ' + i, Loan_Amount__c = 300000,
                Property_Value__c = 400000, Loan_Type__c = 'Conventional',
                Purpose__c = 'Purchase', Approval_Date__c = Date.today()));
        }
        insert loans;

        List<Audit_Case__c> cases = new List<Audit_Case__c>();
        for (Integer i = 0; i < 200; i++) {
            cases.add(new Audit_Case__c(Loan__c = loans[i].Id, Loan_Application__c = 'bulk-d-' + i,
                Status__c = 'In_Review', Risk_Tier__c = 'High', Due_At__c = Datetime.now().addDays(30)));
        }
        insert cases;

        List<FindingDraftService.Request> reqs = new List<FindingDraftService.Request>();
        for (Audit_Case__c c : cases) {
            FindingDraftService.Request req = new FindingDraftService.Request();
            req.auditCaseId = c.Id;
            req.ruleCode = 'DTI_MAX';
            reqs.add(req);
        }

        Test.startTest();
        Integer soqlBefore = Limits.getQueries();
        Integer dmlBefore  = Limits.getDmlStatements();
        List<FindingDraftService.Response> out = FindingDraftService.draft(reqs);
        Integer soqlUsed = Limits.getQueries() - soqlBefore;
        Integer dmlUsed  = Limits.getDmlStatements() - dmlBefore;
        Test.stopTest();

        System.assertEquals(200, out.size(), 'One response per request');
        System.assert(soqlUsed <= 3, 'Reads hoisted: constant SOQL, got ' + soqlUsed);
        System.assertEquals(3, dmlUsed, 'Writes batched: 3 DML for any request count');
        System.assertEquals(0, [SELECT COUNT() FROM Finding__c], 'No Finding inserted in bulk');

        System.assertEquals(200,
            [SELECT COUNT() FROM Agent_Action_Log__c WHERE Action_Name__c = 'Draft_Finding_Text' AND Status__c = 'Initiated'],
            '200 intent logs, all Initiated');
        System.assertEquals(400,
            [SELECT COUNT() FROM Audit_Event__c WHERE Event_Type__c = 'Agent_Action'],
            '400 Agent_Action events across 200 actions');
    }

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
