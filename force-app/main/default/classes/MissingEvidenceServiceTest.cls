/**
 * MissingEvidenceServiceTest — proves the read-only "what's still missing?" action
 * ranks required-missing evidence first, surfaces the trailing docs and any
 * Unverifiable replay checks, holds the guardrails, and honours the ADR-26
 * log-before-execute dual-write while staying bulk-safe.
 */
@IsTest
private class MissingEvidenceServiceTest {

    @TestSetup
    static void seed() {
        Loan__c loan = new Loan__c(
            Borrower_Name__c = 'Sabir Asheed Sr.', Loan_Amount__c = 380000,
            Property_Value__c = 475000, Loan_Type__c = 'Conventional',
            Purpose__c = 'Purchase', LOS_Loan_Id__c = 'LOS-HERO-2',
            Approval_Date__c = Date.newInstance(2025, 3, 15));
        insert loan;

        Audit_Case__c ac = new Audit_Case__c(
            Loan__c = loan.Id, Loan_Application__c = 'a0EvidenceTest',
            Borrower_Name_Snapshot__c = 'Sabir Asheed Sr.',
            Status__c = 'Evidence_Needed', Risk_Tier__c = 'High',
            Due_At__c = Datetime.now().addDays(10));
        insert ac;

        // FICO present (Credit passes) but no LTV fact => LTV_MAX unverifiable.
        insert new List<Borrower_Snapshot__c>{
            new Borrower_Snapshot__c(Audit_Case__c = ac.Id, Fact_Category__c = 'Income',
                DTI_Ratio__c = 44.8),
            new Borrower_Snapshot__c(Audit_Case__c = ac.Id, Fact_Category__c = 'Credit',
                FICO_Score__c = 710)
        };

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
        return [SELECT Id FROM Audit_Case__c WHERE Loan_Application__c = 'a0EvidenceTest' LIMIT 1].Id;
    }

    @IsTest
    static void listMissing_ranksRequiredFirst_andSurfacesUnverifiable() {
        Id caseId = heroCaseId();
        ReplayService.replay(caseId);

        Test.startTest();
        MissingEvidenceService.Response r = MissingEvidenceService.listMissingForCase(caseId);
        Test.stopTest();

        System.assertEquals(2, r.requiredMissingCount, 'Two required docs missing');
        System.assertEquals(3, r.missingEvidenceCount, '2 required + 1 optional missing');
        System.assertEquals(1, r.unverifiableCount, 'LTV_MAX is unverifiable');

        // Ranking: the first two ranked items are the required-missing docs.
        System.assert(r.items.size() >= 3, 'Ranked list has all outstanding items');
        System.assertEquals('Evidence', r.items[0].kind, 'Evidence ranked first');
        System.assert(r.items[0].required, 'First item is required-missing');
        System.assert(r.items[1].required, 'Second item is required-missing');
        // Unverifiable checks are ranked last.
        System.assertEquals('Unverifiable check', r.items[r.items.size() - 1].kind,
            'Unverifiable check ranked after evidence');

        System.assert(r.summary.contains('2 required'), 'Summary leads with required docs');
        System.assert(r.summary.contains('Recorded Mortgage'), 'Trailing doc named');
        System.assert(r.summary.contains('Final Title Policy'), 'Trailing doc named');
        System.assert(r.summary.contains('could not be verified'), 'Unverifiable narrated');
        System.assert(!r.summary.toLowerCase().contains('denied'), 'Guardrail: never denied');

        assertDualWrite(caseId, 'List_Missing_Evidence', 'Success');
    }

    @IsTest
    static void listMissing_cleanCase_reportsNothingOutstanding() {
        // A case whose evidence is all Linked and which has no unverifiable checks.
        Loan__c loan = new Loan__c(Borrower_Name__c = 'Clean', Loan_Amount__c = 200000,
            Property_Value__c = 300000, Loan_Type__c = 'Conventional', Purpose__c = 'Purchase',
            Approval_Date__c = Date.today());
        insert loan;
        Audit_Case__c ac = new Audit_Case__c(Loan__c = loan.Id, Loan_Application__c = 'clean-1',
            Status__c = 'Ready_for_Signoff', Risk_Tier__c = 'Low', Due_At__c = Datetime.now().addDays(5));
        insert ac;
        insert new Evidence_Item__c(Audit_Case__c = ac.Id, Document_Type__c = 'Pay_Stub',
            Status__c = 'Linked', Required__c = true);

        Test.startTest();
        MissingEvidenceService.Response r = MissingEvidenceService.listMissingForCase(ac.Id);
        Test.stopTest();

        System.assertEquals(0, r.missingEvidenceCount, 'Nothing missing');
        System.assertEquals(0, r.unverifiableCount, 'Nothing unverifiable');
        System.assert(r.items.isEmpty(), 'Empty ranked list');
        System.assert(r.summary.contains('Nothing is outstanding'), 'Clean-case message');
        assertDualWrite(ac.Id, 'List_Missing_Evidence', 'Success');
    }

    @IsTest
    static void listMissing_nonexistentCase_failsClosed_noOrphanTrail() {
        // Governance reality: a ghost case cannot be logged-before-execute — the
        // immutable Agent_Action_Log__c insert rejects a dangling parent, so the
        // action fails closed with no orphan audit trail.
        Id fakeCase = Schema.SObjectType.Audit_Case__c.getKeyPrefix() + '000000000001AAA';

        Test.startTest();
        Boolean threw = false;
        try {
            MissingEvidenceService.listMissingForCase(fakeCase);
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
    static void listMissing_bulk200_isGovernorSafe_andDualWrites() {
        List<Loan__c> loans = new List<Loan__c>();
        for (Integer i = 0; i < 200; i++) {
            loans.add(new Loan__c(Borrower_Name__c = 'Bulk ' + i, Loan_Amount__c = 300000,
                Property_Value__c = 400000, Loan_Type__c = 'Conventional',
                Purpose__c = 'Purchase', Approval_Date__c = Date.today()));
        }
        insert loans;

        List<Audit_Case__c> cases = new List<Audit_Case__c>();
        for (Integer i = 0; i < 200; i++) {
            cases.add(new Audit_Case__c(Loan__c = loans[i].Id, Loan_Application__c = 'bulk-e-' + i,
                Status__c = 'In_Review', Risk_Tier__c = 'High', Due_At__c = Datetime.now().addDays(30)));
        }
        insert cases;

        List<MissingEvidenceService.Request> reqs = new List<MissingEvidenceService.Request>();
        for (Audit_Case__c c : cases) {
            MissingEvidenceService.Request req = new MissingEvidenceService.Request();
            req.auditCaseId = c.Id;
            reqs.add(req);
        }

        Test.startTest();
        Integer soqlBefore = Limits.getQueries();
        Integer dmlBefore  = Limits.getDmlStatements();
        List<MissingEvidenceService.Response> out = MissingEvidenceService.listMissing(reqs);
        Integer soqlUsed = Limits.getQueries() - soqlBefore;
        Integer dmlUsed  = Limits.getDmlStatements() - dmlBefore;
        Test.stopTest();

        System.assertEquals(200, out.size(), 'One response per request');
        System.assert(soqlUsed <= 4, 'Reads hoisted: constant SOQL, got ' + soqlUsed);
        System.assertEquals(3, dmlUsed, 'Writes batched: 3 DML for any request count');

        System.assertEquals(200,
            [SELECT COUNT() FROM Agent_Action_Log__c WHERE Action_Name__c = 'List_Missing_Evidence' AND Status__c = 'Initiated'],
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
