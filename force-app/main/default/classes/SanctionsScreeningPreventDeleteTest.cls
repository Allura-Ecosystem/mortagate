/**
 * SanctionsScreeningPreventDeleteTest — Coverage for the append-only guards on
 * Sanctions_Screening__c: the SanctionsScreeningPreventDelete trigger
 * (before update + before delete) and the Prevent_Edit_After_Creation
 * validation rule (defense in depth).
 *
 * Mirrors PreventDeleteTriggerTest. Proves: insert is allowed; bulk update (200)
 * is blocked; bulk delete (200) is blocked; every row survives unchanged.
 *
 * @see ADR-24 in RISKS-AND-DECISIONS.md
 * @see AD-01 in RISKS-AND-DECISIONS.md
 */
@IsTest
private class SanctionsScreeningPreventDeleteTest {

    @TestSetup
    static void setup() {
        Loan__c loan = new Loan__c(
            Borrower_Name__c  = 'KYC Guard Borrower',
            Loan_Amount__c    = 300000,
            Property_Value__c = 375000,
            Loan_Type__c      = 'Conventional',
            Purpose__c        = 'Purchase',
            Approval_Date__c  = Date.today()
        );
        insert loan;

        // Insert IS allowed on the append-only object.
        insert new Sanctions_Screening__c(
            Loan__c         = loan.Id,
            Result__c       = 'Clear',
            List_Source__c  = 'OFAC_SDN',
            List_Version__c = 'OFAC-SDN-2026-06-18',
            Screened_At__c  = Datetime.now()
        );
    }

    @IsTest
    static void insert_isAllowed() {
        System.assertEquals(
            1,
            [SELECT COUNT() FROM Sanctions_Screening__c],
            'A Sanctions_Screening__c must insert successfully (append is allowed)'
        );
    }

    @IsTest
    static void update_isBlocked() {
        Sanctions_Screening__c scr =
            [SELECT Id, Result__c FROM Sanctions_Screening__c LIMIT 1];
        scr.Result__c = 'Confirmed_Match';

        Test.startTest();
        Boolean blocked = false;
        try {
            update scr;
        } catch (DmlException e) {
            blocked = true;
            System.assert(
                e.getMessage().contains('append-only'),
                'Expected append-only block message, got: ' + e.getMessage()
            );
        }
        Test.stopTest();

        System.assert(blocked, 'Updating a Sanctions_Screening__c must throw a DmlException');
        System.assertEquals(
            1,
            [SELECT COUNT() FROM Sanctions_Screening__c WHERE Result__c = 'Clear'],
            'The record must be unchanged after the blocked update'
        );
    }

    @IsTest
    static void delete_isBlocked() {
        Sanctions_Screening__c scr = [SELECT Id FROM Sanctions_Screening__c LIMIT 1];

        Test.startTest();
        Boolean blocked = false;
        try {
            delete scr;
        } catch (DmlException e) {
            blocked = true;
            System.assert(
                e.getMessage().contains('append-only'),
                'Expected append-only block message, got: ' + e.getMessage()
            );
        }
        Test.stopTest();

        System.assert(blocked, 'Deleting a Sanctions_Screening__c must throw a DmlException');
        System.assertEquals(
            1,
            [SELECT COUNT() FROM Sanctions_Screening__c],
            'Sanctions_Screening__c record must survive the blocked delete'
        );
    }

    @IsTest
    static void bulkUpdate_isBlocked() {
        Loan__c loan = [SELECT Id FROM Loan__c LIMIT 1];

        List<Sanctions_Screening__c> screens = new List<Sanctions_Screening__c>();
        for (Integer i = 0; i < 200; i++) {
            screens.add(new Sanctions_Screening__c(
                Loan__c         = loan.Id,
                Result__c       = 'Clear',
                List_Source__c  = 'Consolidated',
                List_Version__c = 'BULK-2026-06-18',
                Screened_At__c  = Datetime.now()
            ));
        }
        insert screens; // insert is allowed

        for (Sanctions_Screening__c s : screens) { s.Result__c = 'Confirmed_Match'; }

        Test.startTest();
        Database.SaveResult[] results = Database.update(screens, false);
        Test.stopTest();

        for (Database.SaveResult sr : results) {
            System.assert(!sr.isSuccess(), 'Bulk update must be rejected');
            System.assert(
                sr.getErrors()[0].getMessage().contains('append-only'),
                'Expected append-only block message'
            );
        }
        System.assertEquals(
            200,
            [SELECT COUNT() FROM Sanctions_Screening__c
             WHERE List_Version__c = 'BULK-2026-06-18' AND Result__c = 'Clear'],
            'All 200 records must survive the blocked bulk update unchanged'
        );
    }

    @IsTest
    static void bulkDelete_isBlocked() {
        Loan__c loan = [SELECT Id FROM Loan__c LIMIT 1];

        List<Sanctions_Screening__c> screens = new List<Sanctions_Screening__c>();
        for (Integer i = 0; i < 200; i++) {
            screens.add(new Sanctions_Screening__c(
                Loan__c         = loan.Id,
                Result__c       = 'Clear',
                List_Source__c  = 'OFAC_SDN',
                List_Version__c = 'BULKDEL-2026-06-18',
                Screened_At__c  = Datetime.now()
            ));
        }
        insert screens; // insert is allowed

        Test.startTest();
        Database.DeleteResult[] results = Database.delete(screens, false);
        Test.stopTest();

        for (Database.DeleteResult dr : results) {
            System.assert(!dr.isSuccess(), 'Bulk delete must be rejected');
            System.assert(
                dr.getErrors()[0].getMessage().contains('append-only'),
                'Expected append-only block message'
            );
        }
        System.assertEquals(
            200,
            [SELECT COUNT() FROM Sanctions_Screening__c
             WHERE List_Version__c = 'BULKDEL-2026-06-18'],
            'All 200 records must survive the blocked bulk delete'
        );
    }
}
