/**
 * AdminController — read-only data source for the Admin / settings screen
 * (the c-audit-admin LWC). Surfaces a small, at-a-glance org summary: how many
 * policy versions and policy rules exist, and how many versions are active.
 *
 * FLS/sharing: `with sharing` + AccessLevel.USER_MODE on every count (through
 * the shared AuditSoql helper), so an auditor only ever counts records they can
 * see — the same posture as every other audit-UI controller.
 *
 * Write surface: NONE. The Admin screen is presentational; this method only
 * returns counts.
 *
 * @group Admin
 * @see AuditQueueController, PolicyVersionsController, AuditSoql
 */
public with sharing class AdminController {

    // ── Public API ──────────────────────────────────────────────────────

    /**
     * Return a small org summary (3 COUNT() queries) for the Admin screen.
     */
    @AuraEnabled(cacheable=true)
    public static OrgSummary getOrgSummary() {
        OrgSummary s = new OrgSummary();
        s.policyVersionCount = AuditSoql.count(
            'SELECT COUNT() FROM Policy_Version__c', new Map<String, Object>());
        s.activeVersionCount = AuditSoql.count(
            'SELECT COUNT() FROM Policy_Version__c WHERE Is_Active__c = :active',
            new Map<String, Object>{ 'active' => true });
        s.policyRuleCount = AuditSoql.count(
            'SELECT COUNT() FROM Policy_Rule__c', new Map<String, Object>());
        return s;
    }

    // ── DTO ─────────────────────────────────────────────────────────────

    public class OrgSummary {
        @AuraEnabled public Integer policyVersionCount = 0;
        @AuraEnabled public Integer activeVersionCount = 0;
        @AuraEnabled public Integer policyRuleCount = 0;
    }
}
