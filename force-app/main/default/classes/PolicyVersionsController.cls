/**
 * PolicyVersionsController — read-only data source for the Policy Versions
 * screen (the c-policy-versions LWC). LEFT = the list of policy versions
 * (newest first); selecting one shows that version's rules on the RIGHT.
 *
 * FLS/sharing: `with sharing` + AccessLevel.USER_MODE on every read (through
 * the shared AuditSoql helper), mirroring AuditQueueController and
 * CaseReviewController — an auditor can never see a version (or field) they
 * lack access to.
 *
 * Write surface: NONE. Both methods are cacheable reads; policy authoring is
 * out of scope for this screen (governance owns version changes).
 *
 * @group Policy Versions
 * @see AuditQueueController, CaseReviewController, AuditSoql
 */
public with sharing class PolicyVersionsController {

    @TestVisible private static final Integer DEFAULT_LIMIT = 100;

    // ── Public API ──────────────────────────────────────────────────────

    /**
     * Return all policy versions, newest first (Version_Number__c DESC),
     * each with a count of its child rules (1 SOQL via a child subquery).
     */
    @AuraEnabled(cacheable=true)
    public static List<PolicyVersionRow> getVersions() {
        Integer rowLimit = AuditSoql.resolveLimit(null, DEFAULT_LIMIT);

        String soql =
            'SELECT Id, Name, Version_Label__c, Version_Number__c, Policy_Type__c, ' +
            'Is_Active__c, Effective_Date__c, Expiration_Date__c, ' +
            '(SELECT Id FROM Policy_Rules__r) ' +
            'FROM Policy_Version__c ' +
            'ORDER BY Version_Number__c DESC NULLS LAST LIMIT ' + rowLimit;

        List<Policy_Version__c> versions =
            (List<Policy_Version__c>) AuditSoql.query(soql, new Map<String, Object>());

        List<PolicyVersionRow> rows = new List<PolicyVersionRow>();
        for (Policy_Version__c pv : versions) {
            rows.add(toVersionRow(pv));
        }
        return rows;
    }

    /**
     * Return the rules for one policy version (1 SOQL), ordered by category
     * then code so the RIGHT pane reads in a stable, grouped order.
     *
     * @param policyVersionId the Policy_Version__c whose rules to fetch
     * @return the rule rows (empty list if the id is null / not visible)
     */
    @AuraEnabled(cacheable=true)
    public static List<PolicyRuleRow> getRules(Id policyVersionId) {
        if (policyVersionId == null) {
            return new List<PolicyRuleRow>();
        }

        String soql =
            'SELECT Id, Rule_Code__c, Rule_Label__c, Rule_Category__c, ' +
            'Operator__c, Threshold_Value__c, Severity__c ' +
            'FROM Policy_Rule__c WHERE Policy_Version__c = :pvId ' +
            'ORDER BY Rule_Category__c ASC NULLS LAST, Rule_Code__c ASC';

        List<Policy_Rule__c> rules = (List<Policy_Rule__c>) AuditSoql.query(
            soql, new Map<String, Object>{ 'pvId' => policyVersionId });

        List<PolicyRuleRow> rows = new List<PolicyRuleRow>();
        for (Policy_Rule__c r : rules) {
            rows.add(toRuleRow(r));
        }
        return rows;
    }

    // ── Helpers ─────────────────────────────────────────────────────────

    private static PolicyVersionRow toVersionRow(Policy_Version__c pv) {
        PolicyVersionRow r = new PolicyVersionRow();
        r.recordId       = pv.Id;
        r.name           = pv.Name;
        r.versionLabel   = pv.Version_Label__c;
        r.versionNumber  = (pv.Version_Number__c == null) ? null : pv.Version_Number__c.intValue();
        r.policyType     = pv.Policy_Type__c;
        r.isActive       = (pv.Is_Active__c == true);
        r.effectiveDate  = pv.Effective_Date__c;
        r.expirationDate = pv.Expiration_Date__c;
        r.ruleCount      = (pv.Policy_Rules__r == null) ? 0 : pv.Policy_Rules__r.size();
        return r;
    }

    private static PolicyRuleRow toRuleRow(Policy_Rule__c rule) {
        PolicyRuleRow r = new PolicyRuleRow();
        r.recordId  = rule.Id;
        r.ruleCode  = rule.Rule_Code__c;
        r.ruleLabel = rule.Rule_Label__c;
        r.category  = rule.Rule_Category__c;
        r.operator  = rule.Operator__c;
        r.threshold = rule.Threshold_Value__c;
        // Plain (6th-grade) severity label for the UI ("Hard_Decline" -> "Hard Decline").
        r.severityApi = rule.Severity__c;
        r.severity    = (rule.Severity__c == null) ? null : rule.Severity__c.replace('_', ' ');
        return r;
    }

    // ── DTOs ────────────────────────────────────────────────────────────

    public class PolicyVersionRow {
        @AuraEnabled public Id recordId;
        @AuraEnabled public String name;
        @AuraEnabled public String versionLabel;
        @AuraEnabled public Integer versionNumber;
        @AuraEnabled public String policyType;
        @AuraEnabled public Boolean isActive;
        @AuraEnabled public Date effectiveDate;
        @AuraEnabled public Date expirationDate;
        @AuraEnabled public Integer ruleCount;
    }

    public class PolicyRuleRow {
        @AuraEnabled public Id recordId;
        @AuraEnabled public String ruleCode;
        @AuraEnabled public String ruleLabel;
        @AuraEnabled public String category;
        @AuraEnabled public String operator;
        @AuraEnabled public Decimal threshold;
        @AuraEnabled public String severity;     // display label (de-underscored)
        @AuraEnabled public String severityApi;  // raw picklist value
    }
}
