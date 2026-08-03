/**
 * SC-6b: Verify Decision_Event__c can be produced from evidence.
 * 
 * Tests the synchronous decision path:
 * 1. Check if LoanDecisionService, FactAssemblerService, DecisionCommitService
 *    are available in the org (they're quarantined by .forceignore but may still
 *    be deployed from prior deployments).
 * 2. If available, run a decision on an existing Loan_Application__c that has
 *    Evidence__c and Extracted_Facts__c.
 * 3. If not available, test creating Decision_Event__c directly via DML.
 */

System.debug('=== SC-6b: Decision_Event__c Production Test ===');

// Step 1: Check if the quarantined classes are available in-org
Boolean hasLoanDecisionService = Type.forName('LoanDecisionService') != null;
Boolean hasFactAssemblerService = Type.forName('FactAssemblerService') != null;
Boolean hasDecisionCommitService = Type.forName('DecisionCommitService') != null;
Boolean hasPolicyRuleEvaluator = Type.forName('PolicyRuleEvaluator') != null;

System.debug('LoanDecisionService available: ' + hasLoanDecisionService);
System.debug('FactAssemblerService available: ' + hasFactAssemblerService);
System.debug('DecisionCommitService available: ' + hasDecisionCommitService);
System.debug('PolicyRuleEvaluator available: ' + hasPolicyRuleEvaluator);

// Step 2: Check what Loan_Application__c records have evidence and facts
Set<Id> appIdsWithEvidence = new Map<Id, AggregateResult>([
    SELECT Application__c Id FROM Evidence__c GROUP BY Application__c
]).keySet();
Set<Id> appIdsWithFacts = new Map<Id, AggregateResult>([
    SELECT Application__c Id FROM Extracted_Facts__c GROUP BY Application__c
]).keySet();
Set<Id> allAppIds = new Set<Id>();
allAppIds.addAll(appIdsWithEvidence);
allAppIds.addAll(appIdsWithFacts);

List<Loan_Application__c> appsWithData = [
    SELECT Id, Name
    FROM Loan_Application__c
    WHERE Id IN :allAppIds
    ORDER BY Name
];
System.debug('Loan_Application__c records with evidence or facts: ' + appsWithData.size());
for (Loan_Application__c a : appsWithData) {
    System.debug('  ' + a.Id + ' (' + a.Name + ')');
}

// Step 3: Try the decision path
if (hasLoanDecisionService && hasFactAssemblerService && hasDecisionCommitService) {
    System.debug('All decision classes available. Attempting full decision path...');
    
    // Find an app with both evidence and facts
    List<Loan_Application__c> candidates = [
        SELECT Id, Name
        FROM Loan_Application__c
        WHERE Id IN (SELECT Application__c FROM Evidence__c)
          AND Id IN (SELECT Application__c FROM Extracted_Facts__c)
        LIMIT 1
    ];
    
    if (!candidates.isEmpty()) {
        Loan_Application__c app = candidates[0];
        System.debug('Running decision on: ' + app.Id + ' (' + app.Name + ')');
        
        try {
            Decision_Event__c result = LoanDecisionService.decideOne(app.Id);
            System.debug('SUCCESS: Decision_Event__c created: ' + result.Id);
            System.debug('  Outcome: ' + result.Outcome__c);
            System.debug('  Decision_Timestamp__c: ' + result.Decision_Timestamp__c);
            System.debug('  Triggered_By__c: ' + result.Triggered_By__c);
            System.debug('  Evaluated_Rule_Count__c: ' + result.Evaluated_Rule_Count__c);
            System.debug('  Hard_Decline_Count__c: ' + result.Hard_Decline_Count__c);
            System.debug('  Decline_Reason__c: ' + result.Decline_Reason__c);
        } catch (Exception e) {
            System.debug('ERROR: Decision path failed: ' + e.getMessage());
            System.debug('  Stack trace: ' + e.getStackTraceString());
        }
    } else {
        System.debug('No Loan_Application__c has both Evidence__c and Extracted_Facts__c.');
        System.debug('Creating a minimal test scenario...');
        
        // Get any app
        List<Loan_Application__c> anyApp = [SELECT Id, Name FROM Loan_Application__c LIMIT 1];
        if (!anyApp.isEmpty()) {
            Loan_Application__c app = anyApp[0];
            System.debug('Using app: ' + app.Id + ' (' + app.Name + ')');
            
            // Create evidence
            Evidence__c ev = new Evidence__c(
                Application__c = app.Id,
                Document_Type__c = 'Pay_Stub',
                Extraction_Status__c = 'COMPLETED',
                Upload_Date__c = Datetime.now()
            );
            insert ev;
            System.debug('Created Evidence__c: ' + ev.Id);
            
            // Create extracted facts
            Extracted_Facts__c facts = new Extracted_Facts__c(
                Application__c = app.Id,
                DTI_Ratio__c = 35,
                FICO_Score__c = 720,
                Annual_Income__c = 95000,
                Extracted_Date__c = Datetime.now()
            );
            insert facts;
            System.debug('Created Extracted_Facts__c: ' + facts.Id);
            
            try {
                Decision_Event__c result = LoanDecisionService.decideOne(app.Id);
                System.debug('SUCCESS: Decision_Event__c created: ' + result.Id);
                System.debug('  Outcome: ' + result.Outcome__c);
                System.debug('  Decision_Timestamp__c: ' + result.Decision_Timestamp__c);
                System.debug('  Triggered_By__c: ' + result.Triggered_By__c);
                System.debug('  Evaluated_Rule_Count__c: ' + result.Evaluated_Rule_Count__c);
                System.debug('  Hard_Decline_Count__c: ' + result.Hard_Decline_Count__c);
                System.debug('  Decline_Reason__c: ' + result.Decline_Reason__c);
            } catch (Exception e) {
                System.debug('ERROR: Decision path failed: ' + e.getMessage());
                System.debug('  Stack trace: ' + e.getStackTraceString());
            }
        }
    }
} else {
    System.debug('Decision classes NOT available in org (quarantined by ADR-32).');
    System.debug('Testing direct Decision_Event__c creation instead...');
    
    // Find a Loan_Application__c
    List<Loan_Application__c> apps = [SELECT Id, Name FROM Loan_Application__c LIMIT 1];
    if (!apps.isEmpty()) {
        Loan_Application__c app = apps[0];
        
        // Find a Policy_Rule_Version__c
        List<Policy_Rule_Version__c> rules = [SELECT Id, Name FROM Policy_Rule_Version__c LIMIT 1];
        Id ruleVersionId = rules.isEmpty() ? null : rules[0].Id;
        
        Decision_Event__c de = new Decision_Event__c(
            Application__c = app.Id,
            Outcome__c = 'APPROVED',
            Decision_Timestamp__c = Datetime.now(),
            Triggered_By__c = 'SYSTEM',
            Evaluated_Rule_Count__c = 0,
            Hard_Decline_Count__c = 0,
            Rule_Version__c = ruleVersionId
        );
        
        try {
            insert de;
            System.debug('SUCCESS: Decision_Event__c created directly: ' + de.Id);
            System.debug('  Outcome: ' + de.Outcome__c);
            System.debug('  Rule_Version__c: ' + de.Rule_Version__c);
        } catch (DmlException e) {
            System.debug('ERROR: Direct Decision_Event__c creation failed: ' + e.getMessage());
        }
    }
}

System.debug('=== SC-6b Test Complete ===');
