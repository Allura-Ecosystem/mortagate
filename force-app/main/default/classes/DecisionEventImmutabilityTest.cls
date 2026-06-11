/**
 * Proves the append-only invariant: insert allowed, update blocked, delete blocked —
 * in bulk. This is the test Brooks reserved confidence for: the audit trail's
 * permanence must be enforced, not asserted in prose.
 */
@IsTest
private class DecisionEventImmutabilityTest {

    @TestSetup
    static void setup() {
        Loan_Application__c app = PolicyEngineTestFactory.application();
        insert app;

        List<Decision_Event__c> events = new List<Decision_Event__c>();
        for (Integer i = 0; i < 5; i++) {
            events.add(new Decision_Event__c(
                Application__c = app.Id,
                Outcome__c = 'APPROVED',
                Rule_Results_JSON__c = '[]',
                Evaluated_Rule_Count__c = 0,
                Hard_Decline_Count__c = 0,
                Decision_Timestamp__c = Datetime.now(),
                Triggered_By__c = 'SYSTEM'
            ));
        }
        insert events; // insert is allowed
    }

    @IsTest
    static void insert_isAllowed() {
        System.assertEquals(5, [SELECT COUNT() FROM Decision_Event__c]);
    }

    @IsTest
    static void update_isBlocked() {
        List<Decision_Event__c> events = [SELECT Id, Outcome__c FROM Decision_Event__c];
        for (Decision_Event__c e : events) { e.Outcome__c = 'HARD_DECLINED'; }

        Test.startTest();
        Database.SaveResult[] results = Database.update(events, false);
        Test.stopTest();

        for (Database.SaveResult sr : results) {
            System.assert(!sr.isSuccess(), 'Update must be rejected');
            System.assert(sr.getErrors()[0].getMessage().contains('append-only'));
        }
        // Confirm nothing actually changed.
        System.assertEquals(5, [SELECT COUNT() FROM Decision_Event__c WHERE Outcome__c = 'APPROVED']);
    }

    @IsTest
    static void delete_isBlocked() {
        List<Decision_Event__c> events = [SELECT Id FROM Decision_Event__c];

        Test.startTest();
        Database.DeleteResult[] results = Database.delete(events, false);
        Test.stopTest();

        for (Database.DeleteResult dr : results) {
            System.assert(!dr.isSuccess(), 'Delete must be rejected');
            System.assert(dr.getErrors()[0].getMessage().contains('append-only'));
        }
        System.assertEquals(5, [SELECT COUNT() FROM Decision_Event__c], 'Records must survive');
    }
}
