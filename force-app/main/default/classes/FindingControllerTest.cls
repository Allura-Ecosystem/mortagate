/**
 * FindingControllerTest — proves the Finding Detail data source + sole write
 * path for the canonical Sabir Sr. (DTI_MAX Fail) case.
 *
 * Coverage (PNB):
 *   Positive — getFindings returns a case's findings; getFinding loads one with
 *              its replay-check rule context; saveFinding creates and updates;
 *              an AI-drafted finding saved through this surface is marked
 *              AI_Draft_Accepted__c (SM-C2).
 *   Negative — null inputs and a missing Severity are rejected; a create with no
 *              audit case is rejected.
 */
@IsTest
private class FindingControllerTest {

    @TestSetup
    static void seedSabirSr() {
        Loan__c loan = new Loan__c(
            Borrower_Name__c      = 'Sabir Asheed Sr.',
            Loan_Amount__c        = 380000,
            Property_Value__c     = 475000,
            Annual_Income__c      = 95000,
            Loan_Type__c          = 'Conventional',
            Purpose__c            = 'Purchase',
            Approval_Date__c      = Date.newInstance(2025, 3, 15),
            Originating_Branch__c = 'Durham Main',
            Approver_Name__c      = 'Janet Chen',
            FICO_At_Approval__c   = 710,
            DTI_At_Approval__c    = 44.8,
            LTV_At_Approval__c    = 80.0,
            LOS_Loan_Id__c        = 'LA-558823'
        );
        insert loan;

        Audit_Case__c ac = new Audit_Case__c(
            Loan__c                   = loan.Id,
            Loan_Application__c       = 'a0000000000SGN1',
            Status__c                 = 'In_Review',
            Risk_Tier__c              = 'High',
            Borrower_Name_Snapshot__c = 'Sabir Asheed Sr.',
            Due_At__c                 = Datetime.now().addDays(30),
            Scope__c                  = 'Full'
        );
        insert ac;

        // Policy version + rule — Replay_Check__c.Policy_Rule__c is required.
        Policy_Version__c pv = new Policy_Version__c(
            Version_Label__c  = 'Q1 2025 Conventional',
            Version_Number__c = 1,
            Effective_Date__c = Date.newInstance(2025, 1, 1),
            Is_Active__c      = true,
            Policy_Type__c    = 'Conventional'
        );
        insert pv;
        Policy_Rule__c pr = new Policy_Rule__c(
            Policy_Version__c  = pv.Id,
            Rule_Code__c       = 'DTI_MAX',
            Rule_Label__c      = 'Max DTI Ratio',
            Rule_Category__c   = 'Income',
            Operator__c        = 'LTE',
            Threshold_Value__c = 43,
            Fact_Field__c      = 'DTI_Ratio__c',
            Severity__c        = 'Hard_Decline'
        );
        insert pr;

        // One replay check to anchor a finding's rule context (the DTI_MAX Fail).
        insert new Replay_Check__c(
            Audit_Case__c      = ac.Id,
            Policy_Rule__c     = pr.Id,
            Rule_Name__c       = 'DTI_MAX',
            Result__c          = 'Fail',
            Expected_Value__c  = '43',
            Actual_Value__c    = '44.8',
            Rationale__c       = 'DTI exceeds the maximum allowed at approval.',
            Sort_Order__c      = 0,
            Replay_Timestamp__c = Datetime.now()
        );
    }

    private static Id sabirCaseId() {
        return [SELECT Id FROM Audit_Case__c WHERE Borrower_Name_Snapshot__c = 'Sabir Asheed Sr.' LIMIT 1].Id;
    }

    private static Id dtiCheckId(Id caseId) {
        return [SELECT Id FROM Replay_Check__c WHERE Audit_Case__c = :caseId AND Rule_Name__c = 'DTI_MAX' LIMIT 1].Id;
    }

    // ── getFindings ──────────────────────────────────────────────────────

    @IsTest
    static void getFindings_returnsCaseFindings() {
        Id caseId = sabirCaseId();
        insert new Finding__c(
            Audit_Case__c = caseId, Severity__c = 'Violation',
            Category__c = 'Income', Disposition__c = 'Open',
            Description__c = 'DTI over the line.');

        Test.startTest();
        List<FindingController.FindingDto> rows = FindingController.getFindings(caseId);
        Test.stopTest();

        System.assertEquals(1, rows.size(), 'One finding for the case');
        System.assertEquals('Violation', rows[0].severity);
        System.assert(rows[0].isViolation, 'Violation flag set');
    }

    @IsTest
    static void getFindings_nullId_returnsEmpty() {
        System.assertEquals(0, FindingController.getFindings(null).size());
    }

    // ── getFinding (with replay-check rule context) ──

    @IsTest
    static void getFinding_loadsRuleContextFromReplayCheck() {
        Id caseId = sabirCaseId();
        Id checkId = dtiCheckId(caseId);
        Finding__c f = new Finding__c(
            Audit_Case__c = caseId, Replay_Check__c = checkId,
            Severity__c = 'Violation', Category__c = 'Income',
            Disposition__c = 'Open', Description__c = 'Linked to the DTI check.');
        insert f;

        Test.startTest();
        FindingController.FindingDto dto = FindingController.getFinding(f.Id);
        Test.stopTest();

        System.assertNotEquals(null, dto, 'DTO returned');
        System.assertEquals('DTI_MAX', dto.ruleName, 'Rule context pulled from replay check');
        System.assertEquals('Fail', dto.ruleResult);
        System.assertEquals('43', dto.expectedValue);
        System.assertEquals('44.8', dto.actualValue);
    }

    @IsTest
    static void getFinding_nullId_returnsNull() {
        System.assertEquals(null, FindingController.getFinding(null));
    }

    // ── saveFinding: create ──

    @IsTest
    static void saveFinding_create_insertsNewFinding() {
        Id caseId = sabirCaseId();
        FindingController.FindingInput inp = new FindingController.FindingInput();
        inp.auditCaseId      = caseId;
        inp.replayCheckId    = dtiCheckId(caseId);
        inp.severity         = 'Violation';
        inp.category         = 'Income';
        inp.disposition      = 'Open';
        inp.description      = 'DTI 44.8 exceeds the 43 ceiling; no documented exception.';

        Test.startTest();
        FindingController.FindingDto dto = FindingController.saveFinding(inp);
        Test.stopTest();

        System.assertNotEquals(null, dto.recordId, 'Finding inserted');
        System.assertEquals('Violation', dto.severity);
        System.assertEquals(1,
            [SELECT COUNT() FROM Finding__c WHERE Audit_Case__c = :caseId],
            'One finding on the case');
    }

    @IsTest
    static void saveFinding_exception_recordsReasonAndApprover() {
        Id caseId = sabirCaseId();
        FindingController.FindingInput inp = new FindingController.FindingInput();
        inp.auditCaseId       = caseId;
        inp.severity          = 'Exception';
        inp.category          = 'Income';
        inp.disposition       = 'Acknowledged';
        inp.exceptionReason   = 'Compensating reserves of 9 months documented.';
        inp.exceptionApprover = 'R. Patel (Credit Committee)';

        Test.startTest();
        FindingController.FindingDto dto = FindingController.saveFinding(inp);
        Test.stopTest();

        System.assert(dto.isException, 'Exception flag set');
        Finding__c f = [SELECT Exception_Reason__c, Exception_Approver__c
                        FROM Finding__c WHERE Id = :dto.recordId];
        System.assertEquals('Compensating reserves of 9 months documented.', f.Exception_Reason__c);
        System.assertEquals('R. Patel (Credit Committee)', f.Exception_Approver__c);
    }

    // ── saveFinding: update ──

    @IsTest
    static void saveFinding_update_changesSeverity() {
        Id caseId = sabirCaseId();
        Finding__c f = new Finding__c(
            Audit_Case__c = caseId, Severity__c = 'Pass',
            Category__c = 'Income', Disposition__c = 'Open');
        insert f;

        FindingController.FindingInput inp = new FindingController.FindingInput();
        inp.recordId    = f.Id;
        inp.severity    = 'Violation';
        inp.category    = 'Income';
        inp.disposition = 'Open';
        inp.description = 'Re-judged as a violation on review.';

        Test.startTest();
        FindingController.FindingDto dto = FindingController.saveFinding(inp);
        Test.stopTest();

        System.assertEquals('Violation', dto.severity, 'Severity updated');
        System.assertEquals(f.Id, dto.recordId, 'Same record updated, not a new one');
    }

    // ── saveFinding: AI draft acceptance (SM-C2) ──

    @IsTest
    static void saveFinding_aiDrafted_marksDraftAccepted() {
        Id caseId = sabirCaseId();
        Finding__c f = new Finding__c(
            Audit_Case__c = caseId, Severity__c = 'Violation',
            Category__c = 'Income', Disposition__c = 'Open',
            Description__c = 'AI: DTI breach with no exception on file.',
            AI_Drafted__c = true, AI_Draft_Accepted__c = false);
        insert f;

        FindingController.FindingInput inp = new FindingController.FindingInput();
        inp.recordId    = f.Id;
        inp.severity    = 'Violation';
        inp.category    = 'Income';
        inp.disposition = 'Acknowledged';
        inp.description = 'AI: DTI breach with no exception on file.';

        Test.startTest();
        FindingController.FindingDto dto = FindingController.saveFinding(inp);
        Test.stopTest();

        System.assert(dto.aiDrafted, 'Still flagged AI-drafted');
        System.assert(dto.aiDraftAccepted, 'AI draft accepted after auditor save (SM-C2)');
    }

    // ── saveFinding: negatives ──

    @IsTest
    static void saveFinding_null_throws() {
        Boolean threw = false;
        try { FindingController.saveFinding(null); }
        catch (AuraHandledException e) { threw = true; }
        System.assert(threw, 'Null input must throw');
    }

    @IsTest
    static void saveFinding_missingSeverity_throws() {
        FindingController.FindingInput inp = new FindingController.FindingInput();
        inp.auditCaseId = sabirCaseId();
        inp.category    = 'Income';

        Boolean threw = false;
        try { FindingController.saveFinding(inp); }
        catch (AuraHandledException e) { threw = true; }
        System.assert(threw, 'Missing severity must throw');
    }

    @IsTest
    static void saveFinding_createWithoutCase_throws() {
        FindingController.FindingInput inp = new FindingController.FindingInput();
        inp.severity = 'Violation';

        Boolean threw = false;
        try { FindingController.saveFinding(inp); }
        catch (AuraHandledException e) { threw = true; }
        System.assert(threw, 'Create with no audit case must throw');
    }
}
