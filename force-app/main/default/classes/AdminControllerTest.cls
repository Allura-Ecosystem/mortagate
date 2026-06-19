/**
 * AdminControllerTest — proves the Admin org-summary counts are correct with
 * seeded data, correct (zero) with no data, and bulkData-safe at scale.
 *
 * PNB: Positive (counts match seed), Negative (empty org => zeros),
 * Bulk (200+ versions counted in one call without governor violations).
 */
@IsTest
private class AdminControllerTest {

    // ── Positive: counts reflect seeded versions + rules ──

    @IsTest
    static void getOrgSummary_countsMatchSeed() {
        Policy_Version__c v1 = new Policy_Version__c(
            Version_Label__c = 'Active V', Version_Number__c = 1,
            Effective_Date__c = Date.today(), Is_Active__c = true, Policy_Type__c = 'Conventional');
        Policy_Version__c v2 = new Policy_Version__c(
            Version_Label__c = 'Inactive V', Version_Number__c = 2,
            Effective_Date__c = Date.today(), Is_Active__c = false, Policy_Type__c = 'FHA');
        insert new List<Policy_Version__c>{ v1, v2 };

        insert new List<Policy_Rule__c>{
            new Policy_Rule__c(Policy_Version__c = v1.Id, Rule_Code__c = 'A', Rule_Label__c = 'A',
                Rule_Category__c = 'Income', Operator__c = 'GTE', Threshold_Value__c = 1,
                Fact_Field__c = 'DTI_Ratio__c', Severity__c = 'Info'),
            new Policy_Rule__c(Policy_Version__c = v1.Id, Rule_Code__c = 'B', Rule_Label__c = 'B',
                Rule_Category__c = 'Credit', Operator__c = 'GTE', Threshold_Value__c = 2,
                Fact_Field__c = 'FICO_Score__c', Severity__c = 'Warning')
        };

        Test.startTest();
        AdminController.OrgSummary s = AdminController.getOrgSummary();
        Test.stopTest();

        System.assertEquals(2, s.policyVersionCount, 'Two versions');
        System.assertEquals(1, s.activeVersionCount, 'One active version');
        System.assertEquals(2, s.policyRuleCount, 'Two rules');
    }

    // ── Negative: empty org => all zeros (no nulls, no error) ──

    @IsTest
    static void getOrgSummary_emptyOrg_returnsZeros() {
        Test.startTest();
        AdminController.OrgSummary s = AdminController.getOrgSummary();
        Test.stopTest();

        System.assertEquals(0, s.policyVersionCount);
        System.assertEquals(0, s.activeVersionCount);
        System.assertEquals(0, s.policyRuleCount);
    }

    // ── Bulk: 200+ versions counted in a single call ──

    @IsTest
    static void getOrgSummary_bulkSafe() {
        List<Policy_Version__c> bulkData = new List<Policy_Version__c>();
        for (Integer i = 0; i < 210; i++) {
            bulkData.add(new Policy_Version__c(
                Version_Label__c = 'Bulk ' + i, Version_Number__c = i,
                Effective_Date__c = Date.today(),
                Is_Active__c = (Math.mod(i, 2) == 0), Policy_Type__c = 'Conventional'));
        }
        insert bulkData;

        Test.startTest();
        AdminController.OrgSummary s = AdminController.getOrgSummary();
        Test.stopTest();

        System.assertEquals(210, s.policyVersionCount, 'COUNT() is unaffected by row caps');
        System.assertEquals(105, s.activeVersionCount, 'Half are active');
    }
}
