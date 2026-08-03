/**
 * SC-7: Run Audit Replay on a decision.
 * 
 * ReplayService.replay(auditCaseId) should:
 * 1. Assemble facts from Borrower_Snapshot__c and Evidence_Item__c
 * 2. Adapt Policy_Rule__c records to in-memory Policy_Rule_Version__c
 * 3. Evaluate via PolicyRuleEvaluator
 * 4. Commit Replay_Check__c records via ReplayCommitService
 * 
 * Uses the Sabir Asheed Sr. audit case which has seed data.
 */

System.debug('=== SC-7: Audit Replay Test ===');

// Step 1: Check if ReplayService is available
Boolean hasReplayService = Type.forName('ReplayService') != null;
Boolean hasReplayCommitService = Type.forName('ReplayCommitService') != null;
System.debug('ReplayService available: ' + hasReplayService);
System.debug('ReplayCommitService available: ' + hasReplayCommitService);

// Step 2: Find the Sabir Asheed Sr. audit case (has seed data)
List<Audit_Case__c> sabirCases = [
    SELECT Id, Name, Loan__c, Loan__r.Approval_Date__c, Status__c,
           Borrower_Name_Snapshot__c
    FROM Audit_Case__c
    WHERE Borrower_Name_Snapshot__c = 'Sabir Asheed Sr.'
    LIMIT 1
];

if (sabirCases.isEmpty()) {
    System.debug('ERROR: Sabir Asheed Sr. audit case not found.');
} else {
    Audit_Case__c sabirCase = sabirCases[0];
    System.debug('Found Sabir Asheed Sr. case: ' + sabirCase.Id + ' (' + sabirCase.Name + ')');
    System.debug('  Loan__c: ' + sabirCase.Loan__c);
    System.debug('  Approval_Date__c: ' + sabirCase.Loan__r.Approval_Date__c);
    System.debug('  Status__c: ' + sabirCase.Status__c);
    
    // Check child records
    List<Borrower_Snapshot__c> snapshots = [
        SELECT Id, Fact_Category__c, DTI_Ratio__c, FICO_Score__c, 
               Annual_Income__c, LTV_Ratio__c
        FROM Borrower_Snapshot__c
        WHERE Audit_Case__c = :sabirCase.Id
    ];
    System.debug('Borrower_Snapshots__c: ' + snapshots.size());
    for (Borrower_Snapshot__c bs : snapshots) {
        System.debug('  ' + bs.Id + ' | ' + bs.Fact_Category__c + 
                     ' | DTI=' + bs.DTI_Ratio__c + ' | FICO=' + bs.FICO_Score__c +
                     ' | Income=' + bs.Annual_Income__c + ' | LTV=' + bs.LTV_Ratio__c);
    }
    
    List<Evidence_Item__c> evidenceItems = [
        SELECT Id, Document_Type__c, Status__c
        FROM Evidence_Item__c
        WHERE Audit_Case__c = :sabirCase.Id
    ];
    System.debug('Evidence_Items__c: ' + evidenceItems.size());
    for (Evidence_Item__c ei : evidenceItems) {
        System.debug('  ' + ei.Id + ' | ' + ei.Document_Type__c + ' | ' + ei.Status__c);
    }
    
    // Step 3: Run the replay
    if (hasReplayService) {
        System.debug('Running ReplayService.replay()...');
        try {
            List<Replay_Check__c> checks = ReplayService.replay(sabirCase.Id);
            System.debug('SUCCESS: Replay completed. ' + checks.size() + ' Replay_Check__c records created.');
            for (Replay_Check__c rc : checks) {
                System.debug('  ' + rc.Id + ' | Rule=' + rc.Rule_Name__c + 
                             ' | Result=' + rc.Result__c + 
                             ' | Expected=' + rc.Expected_Value__c + 
                             ' | Actual=' + rc.Actual_Value__c +
                             ' | Sort=' + rc.Sort_Order__c);
            }
        } catch (Exception e) {
            System.debug('ERROR: Replay failed: ' + e.getMessage());
            System.debug('  Stack trace: ' + e.getStackTraceString());
        }
    } else {
        System.debug('ReplayService NOT available in org.');
    }
}

System.debug('=== SC-7 Test Complete ===');
