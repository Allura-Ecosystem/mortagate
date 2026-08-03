/**
 * SC-6a: Verify Evidence__c creation and field structure.
 * 
 * Evidence__c fields (from org describe):
 *   - Application__c (Master-Detail to Loan_Application__c)
 *   - Content_Version_Id__c (Text(18))
 *   - Document_Type__c (Picklist)
 *   - Extraction_Status__c (Picklist)
 *   - Upload_Date__c (Date/Time)
 * 
 * NOTE: No Hash__c or Scan_Status__c fields exist on Evidence__c.
 * The hash/scan concept was planned but not implemented in the schema.
 * 
 * This test creates an Evidence__c record linked to an existing
 * Loan_Application__c and verifies the record is persisted.
 */

System.debug('=== SC-6a: Evidence__c Creation Test ===');

// Find an existing Loan_Application__c
List<Loan_Application__c> apps = [SELECT Id, Name FROM Loan_Application__c LIMIT 1];
if (apps.isEmpty()) {
    System.debug('ERROR: No Loan_Application__c records found. Cannot create Evidence__c.');
} else {
    Loan_Application__c app = apps[0];
    System.debug('Using Loan_Application__c: ' + app.Id + ' (' + app.Name + ')');
    
    // Create an Evidence__c record
    Evidence__c ev = new Evidence__c(
        Application__c = app.Id,
        Document_Type__c = 'Pay_Stub',
        Extraction_Status__c = 'PENDING',
        Upload_Date__c = Datetime.now()
    );
    
    try {
        insert ev;
        System.debug('SUCCESS: Evidence__c created with Id: ' + ev.Id);
        System.debug('  Name: ' + ev.Name);
        System.debug('  Application__c: ' + ev.Application__c);
        System.debug('  Document_Type__c: ' + ev.Document_Type__c);
        System.debug('  Extraction_Status__c: ' + ev.Extraction_Status__c);
        System.debug('  Upload_Date__c: ' + ev.Upload_Date__c);
        
        // Verify by re-querying
        Evidence__c verify = [SELECT Id, Name, Application__c, Document_Type__c, 
                                     Extraction_Status__c, Upload_Date__c,
                                     Content_Version_Id__c
                              FROM Evidence__c WHERE Id = :ev.Id];
        System.debug('VERIFIED: Record re-queried successfully.');
        System.debug('  Content_Version_Id__c (null expected): ' + verify.Content_Version_Id__c);
        
        // Check if Hash__c or Scan_Status__c fields exist
        // (They don't, but let's confirm via describe)
        Schema.DescribeSObjectResult describe = Evidence__c.SObjectType.getDescribe();
        Map<String, Schema.SObjectField> fields = describe.fields.getMap();
        System.debug('Evidence__c fields available: ' + fields.keySet());
        
        Boolean hasHash = fields.containsKey('Hash__c');
        Boolean hasScanStatus = fields.containsKey('Scan_Status__c');
        System.debug('Has Hash__c field: ' + hasHash);
        System.debug('Has Scan_Status__c field: ' + hasScanStatus);
        
        if (!hasHash) {
            System.debug('NOTE: Hash__c field does NOT exist on Evidence__c. Hash/scan status was planned but not implemented.');
        }
        if (!hasScanStatus) {
            System.debug('NOTE: Scan_Status__c field does NOT exist on Evidence__c.');
        }
        
    } catch (DmlException e) {
        System.debug('ERROR: Failed to create Evidence__c: ' + e.getMessage());
    }
}

System.debug('=== SC-6a Test Complete ===');
