/**
 * Thin @AuraEnabled controller for the c-onboarding-orchestrator LWC.
 * Creates the Loan_Application__c at the PreCheck -> Evidence boundary
 * and triggers the policy decision after evidence is complete.
 *
 * Security: with sharing, USER_MODE DML, explicit FLS via SObjectType.
 */
public with sharing class OnboardingController {

    @AuraEnabled
    public static Id createLoanApplication(String purpose, Decimal propertyValue, Decimal annualIncome) {
        // FLS / CRUD check
        SObjectType appType = Loan_Application__c.SObjectType;
        if (!appType.getDescribe().isCreateable()) {
            throw new AuraHandledException('Insufficient access to create applications.');
        }

        String mappedPurpose = mapPurpose(purpose);

        Loan_Application__c app = new Loan_Application__c(
            Purpose__c = mappedPurpose,
            Property_Value__c = propertyValue,
            Annual_Income__c = annualIncome,
            Status__c = 'DRAFT',
            Current_Stage__c = 'DOCUMENTS'
        );
        insert as user app;
        return app.Id;
    }

    @AuraEnabled
    public static Map<String, Object> runDecision(Id applicationId) {
        if (applicationId == null) {
            throw new AuraHandledException('Application ID is required.');
        }

        // Update stage to REVIEW before evaluation
        Loan_Application__c app = new Loan_Application__c(
            Id = applicationId,
            Current_Stage__c = 'REVIEW',
            Status__c = 'SUBMITTED'
        );
        update as user app;

        Decision_Event__c evt = LoanDecisionService.decideOne(applicationId);

        // Update to DECISION stage after evaluation
        app.Current_Stage__c = 'DECISION';
        app.Status__c = 'DECIDED';
        update as user app;

        return new Map<String, Object>{
            'outcome' => evt.Outcome__c,
            'decisionEventId' => evt.Id,
            'declineReason' => evt.Decline_Reason__c
        };
    }

    private static String mapPurpose(String rawPurpose) {
        if (String.isBlank(rawPurpose)) return 'PURCHASE';
        switch on rawPurpose.toLowerCase() {
            when 'buying', 'purchase' { return 'PURCHASE'; }
            when 'refinancing', 'refinance' { return 'REFINANCE'; }
            when else { return 'PURCHASE'; }
        }
    }
}
