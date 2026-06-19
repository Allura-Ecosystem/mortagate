/**
 * PolicyVersionsControllerTest — proves the Policy Versions data source returns
 * versions newest-first with correct rule counts, returns a version's rules in
 * a stable grouped order, de-underscores severity labels, and is bulkData-safe.
 *
 * PNB: Positive (versions + rules), Negative (null id), Bulk (200+ versions
 * and rules in a single getVersions call — no governor violations).
 */
@IsTest
private class PolicyVersionsControllerTest {

    @TestSetup
    static void seed() {
        // Two named versions plus a child rule set on v1 (the canonical demo).
        Policy_Version__c v1 = new Policy_Version__c(
            Version_Label__c  = 'Q1 2025 Conventional',
            Version_Number__c = 1,
            Effective_Date__c = Date.newInstance(2025, 1, 1),
            Is_Active__c      = true,
            Policy_Type__c    = 'Conventional'
        );
        Policy_Version__c v2 = new Policy_Version__c(
            Version_Label__c  = 'Q2 2025 Conventional',
            Version_Number__c = 2,
            Effective_Date__c = Date.newInstance(2025, 4, 1),
            Expiration_Date__c = Date.newInstance(2025, 6, 30),
            Is_Active__c      = false,
            Policy_Type__c    = 'Conventional'
        );
        insert new List<Policy_Version__c>{ v1, v2 };

        insert new List<Policy_Rule__c>{
            rule(v1.Id, 'DTI_MAX',  'Max DTI Ratio',  'Income',     'LTE', 43,  'Hard_Decline'),
            rule(v1.Id, 'FICO_MIN', 'Min FICO Score', 'Credit',     'GTE', 620, 'Hard_Decline'),
            rule(v1.Id, 'LTV_MAX',  'Max LTV Ratio',  'Collateral', 'LTE', 80,  'Warning')
        };
    }

    private static Policy_Rule__c rule(Id pvId, String code, String label, String cat,
                                       String op, Decimal threshold, String sev) {
        return new Policy_Rule__c(
            Policy_Version__c = pvId, Rule_Code__c = code, Rule_Label__c = label,
            Rule_Category__c = cat, Operator__c = op, Threshold_Value__c = threshold,
            Fact_Field__c = 'DTI_Ratio__c', Severity__c = sev
        );
    }

    private static Id v1Id() {
        return [SELECT Id FROM Policy_Version__c WHERE Version_Number__c = 1 LIMIT 1].Id;
    }

    // ── Positive: getVersions returns rows newest-first with rule counts ──

    @IsTest
    static void getVersions_returnsNewestFirst_withRuleCounts() {
        Test.startTest();
        List<PolicyVersionsController.PolicyVersionRow> rows =
            PolicyVersionsController.getVersions();
        Test.stopTest();

        System.assertEquals(2, rows.size(), 'Both versions returned');
        System.assertEquals(2, rows[0].versionNumber, 'Newest (v2) first — DESC order');
        System.assertEquals(1, rows[1].versionNumber, 'v1 second');
        System.assertEquals('Q2 2025 Conventional', rows[0].versionLabel);
        System.assertEquals(0, rows[0].ruleCount, 'v2 has no rules');
        System.assertEquals(3, rows[1].ruleCount, 'v1 has 3 rules');
        System.assertEquals(true, rows[1].isActive, 'v1 is active');
        System.assertEquals(false, rows[0].isActive, 'v2 inactive');
        System.assertEquals('Conventional', rows[0].policyType);
        System.assertEquals(Date.newInstance(2025, 1, 1), rows[1].effectiveDate);
        System.assertEquals(Date.newInstance(2025, 6, 30), rows[0].expirationDate);
    }

    // ── Positive: getRules returns a version's rules, severity de-underscored ──

    @IsTest
    static void getRules_returnsRules_severityDeUnderscored() {
        Id pvId = v1Id();

        Test.startTest();
        List<PolicyVersionsController.PolicyRuleRow> rules =
            PolicyVersionsController.getRules(pvId);
        Test.stopTest();

        System.assertEquals(3, rules.size(), '3 rules on v1');

        Map<String, PolicyVersionsController.PolicyRuleRow> byCode =
            new Map<String, PolicyVersionsController.PolicyRuleRow>();
        for (PolicyVersionsController.PolicyRuleRow r : rules) {
            byCode.put(r.ruleCode, r);
        }
        System.assertEquals('Max DTI Ratio', byCode.get('DTI_MAX').ruleLabel);
        System.assertEquals('LTE', byCode.get('DTI_MAX').operator);
        System.assertEquals(43, byCode.get('DTI_MAX').threshold);
        System.assertEquals('Income', byCode.get('DTI_MAX').category);
        System.assertEquals('Hard Decline', byCode.get('DTI_MAX').severity,
            'Severity de-underscored for display');
        System.assertEquals('Hard_Decline', byCode.get('DTI_MAX').severityApi,
            'Raw severity preserved');

        // Ordered by Rule_Category__c ASC — a picklist, so SOQL sorts by the
        // picklist's DEFINED order (Income, Credit, Collateral, …), not
        // alphabetically. Seed categories: DTI_MAX=Income, FICO_MIN=Credit,
        // LTV_MAX=Collateral.
        System.assertEquals('Income', rules[0].category, 'Income first (picklist order)');
        System.assertEquals('Credit', rules[1].category);
        System.assertEquals('Collateral', rules[2].category);
    }

    // ── Negative: null id => empty list (no exception) ──

    @IsTest
    static void getRules_nullId_returnsEmpty() {
        List<PolicyVersionsController.PolicyRuleRow> rules =
            PolicyVersionsController.getRules(null);
        System.assertEquals(0, rules.size(), 'Null id yields an empty list, not an error');
    }

    // ── Bulk: 200+ versions and 200+ rules in one getVersions call ──

    @IsTest
    static void getVersions_bulkSafe() {
        List<Policy_Version__c> bulkData = new List<Policy_Version__c>();
        for (Integer i = 0; i < 220; i++) {
            bulkData.add(new Policy_Version__c(
                Version_Label__c  = 'Bulk ' + i,
                Version_Number__c = 100 + i,
                Effective_Date__c = Date.today(),
                Is_Active__c      = false,
                Policy_Type__c    = 'Conventional'
            ));
        }
        insert bulkData;

        List<Policy_Rule__c> bulkRules = new List<Policy_Rule__c>();
        for (Integer i = 0; i < 220; i++) {
            bulkRules.add(rule(bulkData[i].Id, 'R' + i, 'Rule ' + i, 'Income', 'GTE', i, 'Info'));
        }
        insert bulkRules;

        Test.startTest();
        List<PolicyVersionsController.PolicyVersionRow> rows =
            PolicyVersionsController.getVersions();
        Test.stopTest();

        // Capped at DEFAULT_LIMIT — proves the clamp holds at scale (no governor hit).
        System.assertEquals(PolicyVersionsController.DEFAULT_LIMIT, rows.size(),
            'getVersions clamps to DEFAULT_LIMIT under bulkData load');
        // Newest number first.
        System.assertEquals(319, rows[0].versionNumber, 'Highest version number first');
        System.assertEquals(1, rows[0].ruleCount, 'Each bulkData version has its one rule counted');
    }
}
