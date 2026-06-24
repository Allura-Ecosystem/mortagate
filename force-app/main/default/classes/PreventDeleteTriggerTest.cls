/**
 * PreventDeleteTriggerTest — Focused coverage for the append-only delete guards
 * AuditEventPreventDelete and AgentActionLogPreventDelete.
 *
 * Each guard is a before-delete trigger that calls addError() to block deletion.
 * These tests insert a single guarded record, attempt a delete inside
 * Test.startTest/stopTest, and assert the DML is rejected (DmlException / failed
 * Database.DeleteResult) and the record survives.
 *
 * @see AD-01 in RISKS-AND-DECISIONS.md
 */
@IsTest
private class PreventDeleteTriggerTest {

    @TestSetup
    static void setup() {
        Loan__c loan = new Loan__c(
            Borrower_Name__c  = 'Guard Test Borrower',
            Loan_Amount__c    = 200000,
            Property_Value__c = 250000,
            Loan_Type__c      = 'Conventional',
            Purpose__c        = 'Purchase',
            Approval_Date__c  = Date.today()
        );
        insert loan;

        Audit_Case__c auditCase = new Audit_Case__c(
            Loan__c             = loan.Id,
            Loan_Application__c = 'a0000000000GRD1',
            Status__c           = 'In_Review',
            Risk_Tier__c        = 'High',
            Due_At__c           = Datetime.now().addDays(30)
        );
        insert auditCase;

        insert new Audit_Event__c(
            Audit_Case__c = auditCase.Id,
            Event_Type__c = 'Case_Created',
            Actor__c      = 'GuardTestUser',
            Timestamp__c  = Datetime.now()
        );

        insert new Agent_Action_Log__c(
            Audit_Case__c  = auditCase.Id,
            Action_Name__c = 'Log_Agent_Action',
            Subagent__c    = 'Auditor_Assistant',
            Status__c      = 'Success',
            Actor__c       = 'GuardTestAgent',
            Timestamp__c   = Datetime.now()
        );
    }

    @IsTest
    static void auditEventDelete_isBlocked() {
        Audit_Event__c evt = [SELECT Id FROM Audit_Event__c LIMIT 1];

        Test.startTest();
        Boolean blocked = false;
        try {
            delete evt;
        } catch (DmlException e) {
            blocked = true;
            System.assert(
                e.getMessage().contains('append-only'),
                'Expected append-only block message, got: ' + e.getMessage()
            );
        }
        Test.stopTest();

        System.assert(blocked, 'Deleting an Audit_Event__c must throw a DmlException');
        System.assertEquals(
            1,
            [SELECT COUNT() FROM Audit_Event__c],
            'Audit_Event__c record must survive the blocked delete'
        );
    }

    @IsTest
    static void agentActionLogDelete_isBlocked() {
        Agent_Action_Log__c log = [SELECT Id FROM Agent_Action_Log__c LIMIT 1];

        Test.startTest();
        Boolean blocked = false;
        try {
            delete log;
        } catch (DmlException e) {
            blocked = true;
            System.assert(
                e.getMessage().contains('append-only'),
                'Expected append-only block message, got: ' + e.getMessage()
            );
        }
        Test.stopTest();

        System.assert(blocked, 'Deleting an Agent_Action_Log__c must throw a DmlException');
        System.assertEquals(
            1,
            [SELECT COUNT() FROM Agent_Action_Log__c],
            'Agent_Action_Log__c record must survive the blocked delete'
        );
    }
}
