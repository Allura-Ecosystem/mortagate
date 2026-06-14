/**
 * ImmutabilityEnforcementTest — Bulk proof that the three append-only audit
 * objects (Audit_Event__c, Audit_Receipt__c, Agent_Action_Log__c) reject
 * updates and deletes at volume. 200 records per object, every operation
 * must fail, every original record must survive unchanged.
 *
 * Enforcement mechanisms under test:
 *   UPDATE  -> Prevent_Edit_After_Creation validation rule (all 3 objects)
 *   DELETE  -> before-delete triggers (AuditEventPreventDelete,
 *              AuditReceiptPreventDelete, AgentActionLogPreventDelete)
 *
 * @see US-0.5, AD-01 in RISKS-AND-DECISIONS.md
 */
@IsTest
private class ImmutabilityEnforcementTest {

    private static final Integer BULK_SIZE = 200;

    /* -----------------------------------------------------------
     * Test Setup — one Audit_Case parent, 200 records per object
     * ----------------------------------------------------------- */
    @TestSetup
    static void setup() {
        // Loan -> Audit Case chain
        Loan__c loan = new Loan__c(
            Borrower_Name__c = 'Test Borrower',
            Loan_Amount__c = 250000
        );
        insert loan;

        Audit_Case__c auditCase = new Audit_Case__c(
            Loan__c = loan.Id,
            Status__c = 'In_Review'
        );
        insert auditCase;

        // Audit Events
        List<Audit_Event__c> events = new List<Audit_Event__c>();
        for (Integer i = 0; i < BULK_SIZE; i++) {
            events.add(new Audit_Event__c(
                Audit_Case__c = auditCase.Id,
                Event_Type__c = 'Case_Created',
                Actor__c = 'TestUser',
                Timestamp__c = Datetime.now()
            ));
        }
        insert events;

        // Audit Receipts
        List<Audit_Receipt__c> receipts = new List<Audit_Receipt__c>();
        for (Integer i = 0; i < BULK_SIZE; i++) {
            receipts.add(new Audit_Receipt__c(
                Audit_Case__c = auditCase.Id
            ));
        }
        insert receipts;

        // Agent Action Logs
        List<Agent_Action_Log__c> logs = new List<Agent_Action_Log__c>();
        for (Integer i = 0; i < BULK_SIZE; i++) {
            logs.add(new Agent_Action_Log__c(
                Audit_Case__c = auditCase.Id,
                Action_Name__c = 'Log_Agent_Action',
                Status__c = 'Success',
                Actor__c = 'TestAgent',
                Timestamp__c = Datetime.now()
            ));
        }
        insert logs;
    }

    /* -----------------------------------------------------------
     * Audit_Event__c
     * ----------------------------------------------------------- */

    @IsTest
    static void auditEvent_insert_isAllowed() {
        System.assertEquals(
            BULK_SIZE,
            [SELECT COUNT() FROM Audit_Event__c],
            'All 200 Audit Events should exist after insert'
        );
    }

    @IsTest
    static void auditEvent_update_isBlocked() {
        Profile stdProfile = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User testUser = createTestUser(stdProfile.Id, 'aevtupd');

        List<Audit_Event__c> events = [SELECT Id, Actor__c FROM Audit_Event__c];
        System.assertEquals(BULK_SIZE, events.size());

        for (Audit_Event__c e : events) {
            e.Actor__c = 'Tampered';
        }

        Test.startTest();
        Database.SaveResult[] results;
        System.runAs(testUser) {
            results = Database.update(events, false);
        }
        Test.stopTest();

        for (Database.SaveResult sr : results) {
            System.assert(!sr.isSuccess(), 'Update must be rejected for Audit_Event__c');
        }
        // Confirm originals unchanged
        System.assertEquals(
            BULK_SIZE,
            [SELECT COUNT() FROM Audit_Event__c WHERE Actor__c = 'TestUser'],
            'Original Audit Event records must be unchanged'
        );
    }

    @IsTest
    static void auditEvent_delete_isBlocked() {
        Profile stdProfile = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User testUser = createTestUser(stdProfile.Id, 'aevtdel');

        List<Audit_Event__c> events = [SELECT Id FROM Audit_Event__c];
        System.assertEquals(BULK_SIZE, events.size());

        Test.startTest();
        Database.DeleteResult[] results;
        System.runAs(testUser) {
            results = Database.delete(events, false);
        }
        Test.stopTest();

        for (Database.DeleteResult dr : results) {
            System.assert(!dr.isSuccess(), 'Delete must be rejected for Audit_Event__c');
        }
        System.assertEquals(
            BULK_SIZE,
            [SELECT COUNT() FROM Audit_Event__c],
            'All Audit Event records must survive delete attempt'
        );
    }

    /* -----------------------------------------------------------
     * Audit_Receipt__c
     * ----------------------------------------------------------- */

    @IsTest
    static void auditReceipt_insert_isAllowed() {
        System.assertEquals(
            BULK_SIZE,
            [SELECT COUNT() FROM Audit_Receipt__c],
            'All 200 Audit Receipts should exist after insert'
        );
    }

    @IsTest
    static void auditReceipt_update_isBlocked() {
        Profile stdProfile = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User testUser = createTestUser(stdProfile.Id, 'arcupd');

        List<Audit_Receipt__c> receipts = [SELECT Id, Receipt_Hash__c FROM Audit_Receipt__c];
        System.assertEquals(BULK_SIZE, receipts.size());

        for (Audit_Receipt__c r : receipts) {
            r.Receipt_Hash__c = 'tampered_hash_value';
        }

        Test.startTest();
        Database.SaveResult[] results;
        System.runAs(testUser) {
            results = Database.update(receipts, false);
        }
        Test.stopTest();

        for (Database.SaveResult sr : results) {
            System.assert(!sr.isSuccess(), 'Update must be rejected for Audit_Receipt__c');
        }
        System.assertEquals(
            BULK_SIZE,
            [SELECT COUNT() FROM Audit_Receipt__c WHERE Receipt_Hash__c = null],
            'Original Audit Receipt records must be unchanged'
        );
    }

    @IsTest
    static void auditReceipt_delete_isBlocked() {
        Profile stdProfile = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User testUser = createTestUser(stdProfile.Id, 'arcdel');

        List<Audit_Receipt__c> receipts = [SELECT Id FROM Audit_Receipt__c];
        System.assertEquals(BULK_SIZE, receipts.size());

        Test.startTest();
        Database.DeleteResult[] results;
        System.runAs(testUser) {
            results = Database.delete(receipts, false);
        }
        Test.stopTest();

        for (Database.DeleteResult dr : results) {
            System.assert(!dr.isSuccess(), 'Delete must be rejected for Audit_Receipt__c');
        }
        System.assertEquals(
            BULK_SIZE,
            [SELECT COUNT() FROM Audit_Receipt__c],
            'All Audit Receipt records must survive delete attempt'
        );
    }

    /* -----------------------------------------------------------
     * Agent_Action_Log__c
     * ----------------------------------------------------------- */

    @IsTest
    static void agentActionLog_insert_isAllowed() {
        System.assertEquals(
            BULK_SIZE,
            [SELECT COUNT() FROM Agent_Action_Log__c],
            'All 200 Agent Action Logs should exist after insert'
        );
    }

    @IsTest
    static void agentActionLog_update_isBlocked() {
        Profile stdProfile = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User testUser = createTestUser(stdProfile.Id, 'aalupd');

        List<Agent_Action_Log__c> logs = [SELECT Id, Actor__c FROM Agent_Action_Log__c];
        System.assertEquals(BULK_SIZE, logs.size());

        for (Agent_Action_Log__c l : logs) {
            l.Actor__c = 'Tampered';
        }

        Test.startTest();
        Database.SaveResult[] results;
        System.runAs(testUser) {
            results = Database.update(logs, false);
        }
        Test.stopTest();

        for (Database.SaveResult sr : results) {
            System.assert(!sr.isSuccess(), 'Update must be rejected for Agent_Action_Log__c');
        }
        System.assertEquals(
            BULK_SIZE,
            [SELECT COUNT() FROM Agent_Action_Log__c WHERE Actor__c = 'TestAgent'],
            'Original Agent Action Log records must be unchanged'
        );
    }

    @IsTest
    static void agentActionLog_delete_isBlocked() {
        Profile stdProfile = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User testUser = createTestUser(stdProfile.Id, 'aaldel');

        List<Agent_Action_Log__c> logs = [SELECT Id FROM Agent_Action_Log__c];
        System.assertEquals(BULK_SIZE, logs.size());

        Test.startTest();
        Database.DeleteResult[] results;
        System.runAs(testUser) {
            results = Database.delete(logs, false);
        }
        Test.stopTest();

        for (Database.DeleteResult dr : results) {
            System.assert(!dr.isSuccess(), 'Delete must be rejected for Agent_Action_Log__c');
        }
        System.assertEquals(
            BULK_SIZE,
            [SELECT COUNT() FROM Agent_Action_Log__c],
            'All Agent Action Log records must survive delete attempt'
        );
    }

    /* -----------------------------------------------------------
     * Helper — create a test user with Standard User profile
     * ----------------------------------------------------------- */
    private static User createTestUser(Id profileId, String alias) {
        return new User(
            Alias = alias,
            Email = alias + '@immutability.test',
            EmailEncodingKey = 'UTF-8',
            LastName = 'ImmutabilityTest',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = profileId,
            TimeZoneSidKey = 'America/New_York',
            Username = alias + '@immutability.test.' + Datetime.now().getTime()
        );
    }
}
