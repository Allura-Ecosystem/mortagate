/**
 * EvidenceRequestServiceTest — proves the read-only "draft a request for the
 * missing papers" action lists required-missing documents first, holds the
 * guardrails (professional tone, never "denied", never sends, never persists a
 * draft or touches Evidence_Item__c), honours the ADR-26 log-before-execute
 * dual-write, fails closed on a ghost case, and stays bulk-safe.
 */
@IsTest
private class EvidenceRequestServiceTest {

    @TestSetup
    static void seed() {
        Loan__c loan = new Loan__c(
            Borrower_Name__c = 'Sabir Asheed Sr.', Loan_Amount__c = 380000,
            Property_Value__c = 475000, Loan_Type__c = 'Conventional',
            Purpose__c = 'Purchase', LOS_Loan_Id__c = 'LOS-HERO-3',
            Approval_Date__c = Date.newInstance(2025, 3, 15));
        insert loan;

        Audit_Case__c ac = new Audit_Case__c(
            Loan__c = loan.Id, Loan_Application__c = 'a0RequestTest',
            Borrower_Name_Snapshot__c = 'Sabir Asheed Sr.',
            Status__c = 'Evidence_Needed', Risk_Tier__c = 'High',
            Due_At__c = Datetime.now().addDays(10));
        insert ac;

        insert new List<Evidence_Item__c>{
            new Evidence_Item__c(Audit_Case__c = ac.Id, Document_Type__c = 'Recorded_Mortgage',
                Status__c = 'Missing', Required__c = true),
            new Evidence_Item__c(Audit_Case__c = ac.Id, Document_Type__c = 'Final_Title_Policy',
                Status__c = 'Missing', Required__c = true),
            new Evidence_Item__c(Audit_Case__c = ac.Id, Document_Type__c = 'Bank_Statement',
                Status__c = 'Missing', Required__c = false),
            new Evidence_Item__c(Audit_Case__c = ac.Id, Document_Type__c = 'Pay_Stub',
                Status__c = 'Linked', Required__c = true)
        };
    }

    private static Id heroCaseId() {
        return [SELECT Id FROM Audit_Case__c WHERE Loan_Application__c = 'a0RequestTest' LIMIT 1].Id;
    }

    @IsTest
    static void draft_listsRequiredFirst_andHoldsGuardrails() {
        Id caseId = heroCaseId();

        Test.startTest();
        EvidenceRequestService.Response r = EvidenceRequestService.draftForCase(caseId);
        Test.stopTest();

        System.assertEquals('Success', r.actionStatus, 'Hero case drafts successfully');
        System.assertEquals(2, r.requiredMissingCount, 'Two required docs missing');
        System.assertEquals(3, r.missingCount, '2 required + 1 optional missing');

        // Draft lists the missing required documents.
        System.assert(r.draftText.contains('Recorded Mortgage'), 'Required doc named');
        System.assert(r.draftText.contains('Final Title Policy'), 'Required doc named');
        System.assert(r.draftText.contains('Bank Statement'), 'Optional missing doc named');
        // Linked docs are NOT requested.
        System.assert(!r.draftText.contains('Pay Stub'), 'Linked doc is not requested');

        // Guardrails: professional tone, deadline placeholder, defers to auditor,
        // no decision/verdict language.
        System.assert(r.draftText.contains('[DATE]'), 'Polite deadline placeholder present');
        System.assert(r.draftText.contains(r.caseName), 'Case name included in the draft');
        System.assert(r.draftText.toLowerCase().contains('human auditor'),
            'Defers to the human auditor');
        System.assert(!r.draftText.toLowerCase().contains('denied'), 'Guardrail: never denied');
        System.assert(!r.draftText.toLowerCase().contains('approved'), 'Guardrail: no decision word');

        // Nothing was sent and nothing beyond the governance trail was created:
        // the draft is not persisted on any Evidence_Item__c or Finding__c.
        System.assertEquals(0, [SELECT COUNT() FROM Finding__c], 'No finding record created');
        for (Evidence_Item__c ei : [SELECT Status__c FROM Evidence_Item__c WHERE Audit_Case__c = :caseId]) {
            System.assertNotEquals('Requested', ei.Status__c, 'Evidence_Item__c is never mutated');
        }

        assertDualWrite(caseId, 'Draft_Evidence_Request', 'Success');
    }

    @IsTest
    static void draft_cleanCase_reportsNothingToRequest() {
        Loan__c loan = new Loan__c(Borrower_Name__c = 'Clean', Loan_Amount__c = 200000,
            Property_Value__c = 300000, Loan_Type__c = 'Conventional', Purpose__c = 'Purchase',
            Approval_Date__c = Date.today());
        insert loan;
        Audit_Case__c ac = new Audit_Case__c(Loan__c = loan.Id, Loan_Application__c = 'clean-req-1',
            Status__c = 'Ready_for_Signoff', Risk_Tier__c = 'Low', Due_At__c = Datetime.now().addDays(5));
        insert ac;
        insert new Evidence_Item__c(Audit_Case__c = ac.Id, Document_Type__c = 'Pay_Stub',
            Status__c = 'Linked', Required__c = true);

        Test.startTest();
        EvidenceRequestService.Response r = EvidenceRequestService.draftForCase(ac.Id);
        Test.stopTest();

        System.assertEquals('Partial', r.actionStatus, 'Clean case yields a graceful Partial');
        System.assertEquals(0, r.missingCount, 'Nothing missing to request');
        System.assertEquals(0, r.requiredMissingCount, 'No required doc missing');
        System.assert(r.draftText.contains('nothing to request'), 'Clean-case message');
        System.assert(!r.draftText.toLowerCase().contains('denied'), 'Guardrail: never denied');
        assertDualWrite(ac.Id, 'Draft_Evidence_Request', 'Partial');
    }

    @IsTest
    static void draft_nonexistentCase_failsClosed_noOrphanTrail() {
        // A ghost case cannot be logged-before-execute — the immutable
        // Agent_Action_Log__c insert rejects a dangling parent, so the action
        // fails closed with no orphan audit trail.
        Id fakeCase = Schema.SObjectType.Audit_Case__c.getKeyPrefix() + '000000000001AAA';

        Test.startTest();
        Boolean threw = false;
        try {
            EvidenceRequestService.draftForCase(fakeCase);
        } catch (Exception e) {
            threw = true;
        }
        Test.stopTest();

        System.assert(threw, 'A nonexistent case fails closed (cannot audit a ghost case)');
        System.assertEquals(0,
            [SELECT COUNT() FROM Agent_Action_Log__c WHERE Audit_Case__c = :fakeCase],
            'No orphan intent log for a nonexistent case');
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
            cases.add(new Audit_Case__c(Loan__c = loans[i].Id, Loan_Application__c = 'bulk-req-' + i,
                Status__c = 'In_Review', Risk_Tier__c = 'High', Due_At__c = Datetime.now().addDays(30)));
        }
        insert cases;

        List<Evidence_Item__c> evs = new List<Evidence_Item__c>();
        for (Audit_Case__c c : cases) {
            evs.add(new Evidence_Item__c(Audit_Case__c = c.Id, Document_Type__c = 'Appraisal',
                Status__c = 'Missing', Required__c = true));
        }
        insert evs;

        List<EvidenceRequestService.Request> reqs = new List<EvidenceRequestService.Request>();
        for (Audit_Case__c c : cases) {
            EvidenceRequestService.Request req = new EvidenceRequestService.Request();
            req.auditCaseId = c.Id;
            reqs.add(req);
        }

        Test.startTest();
        Integer soqlBefore = Limits.getQueries();
        Integer dmlBefore  = Limits.getDmlStatements();
        List<EvidenceRequestService.Response> out = EvidenceRequestService.draft(reqs);
        Integer soqlUsed = Limits.getQueries() - soqlBefore;
        Integer dmlUsed  = Limits.getDmlStatements() - dmlBefore;
        Test.stopTest();

        System.assertEquals(200, out.size(), 'One response per request');
        System.assert(soqlUsed <= 2, 'Reads hoisted: constant SOQL, got ' + soqlUsed);
        System.assertEquals(3, dmlUsed, 'Writes batched: 3 DML for any request count');

        System.assertEquals(200,
            [SELECT COUNT() FROM Agent_Action_Log__c
             WHERE Action_Name__c = 'Draft_Evidence_Request' AND Status__c = 'Initiated'],
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
