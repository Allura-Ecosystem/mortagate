/**
 * AuditEvidenceReportControllerTest — V5.1.
 *
 * Proves the printable Audit Evidence Report controller is:
 *   • correct on the happy path (case + chain-of-custody trail),
 *   • chain-of-custody ordered (events oldest-first by Timestamp__c),
 *   • fail-closed on bad / missing / wrong-type / non-existent input, and
 *   • FLS-enforced — a user without access to the audit objects gets an
 *     error, never a partial evidence document (WITH USER_MODE, runAs).
 *
 * The page itself (PDF rendering) is not unit-testable headlessly; these
 * tests lock the controller's data + security contract that the page binds to.
 */
@IsTest
private class AuditEvidenceReportControllerTest {

    // Minimally-valid Audit_Case__c (mirrors the other audit test helpers).
    private static Audit_Case__c newCase(String snapshot) {
        return new Audit_Case__c(
            Loan_Application__c   = 'a0000000RPT1',
            Sampling_Reason__c    = 'Random',
            Approval_Timestamp__c = Datetime.now().addDays(-5),
            Status__c             = 'In_Review',
            Risk_Tier__c          = 'High',
            Borrower_Name_Snapshot__c = snapshot
        );
    }

    private static AuditEvidenceReportController buildFor(String idParam) {
        Test.setCurrentPage(Page.AuditEvidenceReport);
        if (idParam != null) {
            ApexPages.currentPage().getParameters().put('id', idParam);
        }
        return new AuditEvidenceReportController();
    }

    // ---------------------------------------------------------------
    // Happy path — accessible case yields a ready report anchored on the
    // write-once borrower snapshot, with its event trail attached.
    // ---------------------------------------------------------------
    @IsTest
    static void test_report_buildsForAccessibleCase() {
        Audit_Case__c c = newCase('Evelyn Hart');
        insert c;
        AuditEventService.logEvent(c.Id, 'Case_Created', UserInfo.getUserId(), '{"k":"v"}', null);

        Test.startTest();
        AuditEvidenceReportController ctrl = buildFor(c.Id);
        Test.stopTest();

        System.assert(ctrl.reportReady, 'A case the user can access must produce a ready report.');
        System.assertEquals(null, ctrl.errorMessage, 'No error expected on the happy path.');
        System.assertEquals(c.Id, ctrl.auditCase.Id, 'The reported case must match the requested Id.');
        System.assertEquals('Evelyn Hart', ctrl.auditCase.Borrower_Name_Snapshot__c,
            'Report identity must come from the write-once snapshot (ADR-001).');
        System.assert(ctrl.events.size() >= 1, 'The event trail must be populated.');
        System.assertNotEquals(null, ctrl.generatedAt, 'Provenance stamp must be set.');
    }

    // ---------------------------------------------------------------
    // Chain of custody — events must come back oldest-first, regardless of
    // insertion order, so the printed trail is chronological.
    // ---------------------------------------------------------------
    @IsTest
    static void test_report_chainOfCustodyOrderedOldestFirst() {
        Audit_Case__c c = newCase('Marcus Reed');
        insert c;

        Datetime base = Datetime.now().addHours(-3);
        // Insert deliberately OUT of chronological order.
        AuditEventService.logEvents(new List<Audit_Event__c>{
            new Audit_Event__c(Audit_Case__c = c.Id, Event_Type__c = 'Case_Assigned',
                Actor__c = 'u2', Timestamp__c = base.addMinutes(20)),
            new Audit_Event__c(Audit_Case__c = c.Id, Event_Type__c = 'Case_Created',
                Actor__c = 'u1', Timestamp__c = base),
            new Audit_Event__c(Audit_Case__c = c.Id, Event_Type__c = 'Case_Closed',
                Actor__c = 'u3', Timestamp__c = base.addMinutes(40))
        });

        Test.startTest();
        AuditEvidenceReportController ctrl = buildFor(c.Id);
        Test.stopTest();

        System.assert(ctrl.reportReady, 'Report should be ready.');
        System.assertEquals(3, ctrl.events.size(), 'All three events should be present.');
        System.assertEquals('Case_Created', ctrl.events[0].Event_Type__c, 'Oldest event must be first.');
        System.assertEquals('Case_Assigned', ctrl.events[1].Event_Type__c, 'Middle event second.');
        System.assertEquals('Case_Closed', ctrl.events[2].Event_Type__c, 'Newest event last.');
        for (Integer i = 1; i < ctrl.events.size(); i++) {
            System.assert(ctrl.events[i].Timestamp__c >= ctrl.events[i - 1].Timestamp__c,
                'Events must be in non-decreasing timestamp order (chain of custody).');
        }
    }

    // ---------------------------------------------------------------
    // Fail-closed: no id parameter at all.
    // ---------------------------------------------------------------
    @IsTest
    static void test_report_missingIdParam() {
        AuditEvidenceReportController ctrl = buildFor(null);
        System.assert(!ctrl.reportReady, 'Missing id must not produce a report.');
        System.assertNotEquals(null, ctrl.errorMessage, 'A user-facing error must be set.');
    }

    // ---------------------------------------------------------------
    // Fail-closed: malformed id string.
    // ---------------------------------------------------------------
    @IsTest
    static void test_report_malformedId() {
        AuditEvidenceReportController ctrl = buildFor('not-a-valid-id');
        System.assert(!ctrl.reportReady, 'Malformed id must not produce a report.');
        System.assertNotEquals(null, ctrl.errorMessage, 'A user-facing error must be set.');
    }

    // ---------------------------------------------------------------
    // Fail-closed: a well-formed id of the WRONG object type.
    // ---------------------------------------------------------------
    @IsTest
    static void test_report_wrongSObjectId() {
        AuditEvidenceReportController ctrl = buildFor(UserInfo.getUserId());
        System.assert(!ctrl.reportReady, 'A non-Audit_Case Id must not produce a report.');
        System.assertNotEquals(null, ctrl.errorMessage, 'A user-facing error must be set.');
    }

    // ---------------------------------------------------------------
    // Fail-closed: a well-formed, correct-type id that does not exist.
    // ---------------------------------------------------------------
    @IsTest
    static void test_report_nonexistentCase() {
        String prefix = Audit_Case__c.SObjectType.getDescribe().getKeyPrefix();
        Id ghost = Id.valueOf(prefix + '000000000001');
        AuditEvidenceReportController ctrl = buildFor(ghost);
        System.assert(!ctrl.reportReady, 'A non-existent case must not produce a report.');
        System.assertNotEquals(null, ctrl.errorMessage, 'A "not found" error must be set.');
    }

    // ---------------------------------------------------------------
    // SECURITY (the point of the feature): a user without access to the
    // audit objects must get a fail-closed error from the report — never a
    // partial / admin-visible document. WITH USER_MODE enforces this.
    // (User DML isolated in its own runAs block to avoid MIXED_DML.)
    // ---------------------------------------------------------------
    @IsTest
    static void test_report_enforcesUserModeForRestrictedUser() {
        Audit_Case__c c = newCase('Restricted Probe');
        insert c;
        AuditEventService.logEvent(c.Id, 'Case_Created', UserInfo.getUserId(), '{"k":"v"}', null);

        User restricted;
        System.runAs(new User(Id = UserInfo.getUserId())) {
            Profile p = [SELECT Id FROM Profile WHERE Name = 'Minimum Access - Salesforce' LIMIT 1];
            Long stamp = Datetime.now().getTime();
            restricted = new User(
                FirstName = 'Rpt', LastName = 'Probe',
                Email = 'rpt.probe@example.com.invalid',
                Username = 'rpt.probe.' + stamp + '@example.com.invalid',
                Alias = 'rptp', ProfileId = p.Id,
                TimeZoneSidKey = 'America/New_York', LocaleSidKey = 'en_US',
                EmailEncodingKey = 'UTF-8', LanguageLocaleKey = 'en_US');
            insert restricted;
        }

        AuditEvidenceReportController ctrl;
        System.runAs(restricted) {
            ctrl = buildFor(c.Id);
        }

        System.assert(!ctrl.reportReady,
            'A user without access to the audit objects must NOT get a ready evidence report.');
        System.assert(ctrl.auditCase == null,
            'No case data should be exposed to an unauthorised user.');
        System.assertNotEquals(null, ctrl.errorMessage,
            'A fail-closed permission error must be shown instead of evidence.');
    }
}
