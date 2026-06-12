/**
 * AuditDataIntegrityTest — Guards the audit-trail data-layer invariants (ADR-001).
 *
 * These are not service-logic tests; they assert the org-enforced guarantees that
 * make the audit trail trustworthy as evidence:
 *
 *   1. Audit_Event__c is APPEND-ONLY — no updates (VR Prevent_Edit_After_Creation:
 *      NOT(ISNEW())) and no deletes (trigger AuditEventPreventDelete, before delete).
 *   2. Borrower_Name_Snapshot__c is WRITE-ONCE — a captured value can never change
 *      (VR Snapshot_Write_Once), but the legitimate blank -> value first capture is
 *      still allowed.
 *
 * If any of these protections is ever disabled or weakened, these tests go red here
 * — not silently on a tampered audit record in production.
 *
 * @group Audit Trail
 * @see AD-01 / ADR-001 in RISKS-AND-DECISIONS.md
 */
@isTest
private class AuditDataIntegrityTest {

    // A minimally-valid Audit_Case__c (required: Loan_Application__c, Sampling_Reason__c,
    // Approval_Timestamp__c, Status__c, Risk_Tier__c). Optional snapshot override.
    private static Audit_Case__c newCase(String snapshot) {
        return new Audit_Case__c(
            Loan_Application__c   = 'a0000000INT1',
            Sampling_Reason__c    = 'Random',
            Approval_Timestamp__c = Datetime.now().addDays(-3),
            Status__c             = 'Created',
            Risk_Tier__c          = 'Medium',
            Borrower_Name_Snapshot__c = snapshot
        );
    }

    @isTest
    static void test_auditEvent_isAppendOnly_updateBlocked() {
        Audit_Case__c c = newCase('Evelyn Hart');
        insert c;
        Audit_Event__c evt = AuditEventService.logEvent(
            c.Id, 'Case_Created', UserInfo.getUserId(), '{"k":"v"}', null
        );

        Boolean blocked = false;
        Test.startTest();
        try {
            evt.Payload__c = '{"tampered":true}';
            update evt;                       // VR Prevent_Edit_After_Creation must fire
        } catch (DmlException e) {
            blocked = true;
            System.assert(
                e.getMessage().containsIgnoreCase('append-only'),
                'Expected the append-only validation message, got: ' + e.getMessage()
            );
        }
        Test.stopTest();

        System.assert(blocked, 'Audit_Event__c update must be blocked (append-only invariant).');
    }

    @isTest
    static void test_auditEvent_cannotBeDeleted() {
        Audit_Case__c c = newCase('Marcus Reed');
        insert c;
        Audit_Event__c evt = AuditEventService.logEvent(
            c.Id, 'Case_Created', UserInfo.getUserId(), null, null
        );

        Boolean blocked = false;
        Test.startTest();
        try {
            delete evt;                       // trigger AuditEventPreventDelete must fire
        } catch (DmlException e) {
            blocked = true;
            System.assert(
                e.getMessage().containsIgnoreCase('deleted'),
                'Expected the no-delete message, got: ' + e.getMessage()
            );
        }
        Test.stopTest();

        System.assert(blocked, 'Audit_Event__c delete must be blocked (append-only invariant).');
    }

    @isTest
    static void test_borrowerSnapshot_writeOnce_changeBlocked() {
        Audit_Case__c c = newCase('Original Borrower');
        insert c;

        Boolean blocked = false;
        Test.startTest();
        try {
            update new Audit_Case__c(Id = c.Id, Borrower_Name_Snapshot__c = 'Tampered Borrower');
        } catch (DmlException e) {
            blocked = true;
            System.assert(
                e.getMessage().containsIgnoreCase('write-once'),
                'Expected the write-once message, got: ' + e.getMessage()
            );
        }
        Test.stopTest();

        System.assert(blocked, 'A captured Borrower_Name_Snapshot__c must not be changeable (ADR-001).');

        // And the original value is intact.
        Audit_Case__c reloaded = [
            SELECT Borrower_Name_Snapshot__c FROM Audit_Case__c WHERE Id = :c.Id
        ];
        System.assertEquals('Original Borrower', reloaded.Borrower_Name_Snapshot__c,
            'The original snapshot value must survive the rejected tamper attempt.');
    }

    @isTest
    static void test_borrowerSnapshot_firstCaptureFromBlankAllowed() {
        // The rule must NOT be overzealous: a blank -> value first capture is legitimate.
        Audit_Case__c c = newCase(null);
        insert c;

        Test.startTest();
        update new Audit_Case__c(Id = c.Id, Borrower_Name_Snapshot__c = 'First Capture');
        Test.stopTest();

        Audit_Case__c reloaded = [
            SELECT Borrower_Name_Snapshot__c FROM Audit_Case__c WHERE Id = :c.Id
        ];
        System.assertEquals('First Capture', reloaded.Borrower_Name_Snapshot__c,
            'Setting the snapshot once from blank must be allowed.');
    }

    // ---------------------------------------------------------------
    // FLS / WITH USER_MODE enforcement on the EVIDENCE read surface (v2 P0).
    // AuditEventService.getEventsForCase now carries WITH USER_MODE; this
    // proves it is actually ENFORCED — a user without access to
    // Audit_Event__c must be BLOCKED, not silently handed the
    // chain-of-custody trail. Mirrors test_getQueue_enforcesUserModeForRestrictedUser.
    // (User is a setup object — User DML is isolated in its own runAs block
    //  to avoid MIXED_DML_OPERATION with the Audit_Case__c / Audit_Event__c insert.)
    // ---------------------------------------------------------------
    @isTest
    static void test_getEventsForCase_enforcesUserModeForRestrictedUser() {
        Audit_Case__c c = newCase('Chain Of Custody');
        insert c;
        AuditEventService.logEvent(c.Id, 'Case_Created', UserInfo.getUserId(), '{"k":"v"}', null);

        User restricted;
        System.runAs(new User(Id = UserInfo.getUserId())) {
            Profile p = [SELECT Id FROM Profile WHERE Name = 'Minimum Access - Salesforce' LIMIT 1];
            Long stamp = Datetime.now().getTime();
            restricted = new User(
                FirstName = 'Evt', LastName = 'Probe',
                Email = 'evt.probe@example.com.invalid',
                Username = 'evt.probe.' + stamp + '@example.com.invalid',
                Alias = 'evtp', ProfileId = p.Id,
                TimeZoneSidKey = 'America/New_York', LocaleSidKey = 'en_US',
                EmailEncodingKey = 'UTF-8', LanguageLocaleKey = 'en_US');
            insert restricted;
        }

        Boolean blocked = false;
        System.runAs(restricted) {
            try {
                AuditEventService.getEventsForCase(c.Id);
            } catch (Exception e) {
                blocked = true; // WITH USER_MODE rejects a user lacking Audit_Event__c access
            }
        }
        System.assert(blocked,
            'getEventsForCase WITH USER_MODE must block a user without access to Audit_Event__c — '
            + 'the evidence / chain-of-custody surface enforces FLS, it is not decorative.');
    }
}
