/**
 * AuditQueueController -- Thin @AuraEnabled wrapper over AuditCaseService.
 *
 * Serves the auditQueue LWC with filtered queue data and dashboard metrics.
 * All heavy lifting delegates to AuditCaseService; this class exists only
 * to expose the service layer to Lightning components.
 *
 * @group Audit LWC Controllers
 * @see AuditCaseService
 */
public with sharing class AuditQueueController {

    /**
     * Get filtered audit queue for the table. Thin passthrough to the service,
     * which owns the bind-variable WHERE builder.
     *
     * @param filterStatus         Optional status (e.g. 'In_Review')
     * @param filterRiskTier       Optional risk tier (e.g. 'High')
     * @param filterApproverId     Optional original-approver User Id
     * @param filterSamplingReason Optional sampling reason (e.g. 'Risk_Based')
     * @param filterApprovalDays   Optional approval-recency window in days ('7','30','90')
     * @param filterAuditorId      Optional assigned-auditor User Id ('mine' is resolved to the user Id in the LWC)
     * @param filterDueBefore      Optional due-date upper bound (inclusive)
     * @return Filtered list of Audit_Case__c records
     */
    @AuraEnabled(cacheable=true)
    public static List<Audit_Case__c> getQueue(
        String filterStatus,
        String filterRiskTier,
        String filterApproverId,
        String filterSamplingReason,
        String filterApprovalDays,
        String filterAuditorId,
        Date filterDueBefore
    ) {
        return AuditCaseService.getQueue(
            filterStatus,
            filterRiskTier,
            filterApproverId,
            filterSamplingReason,
            filterApprovalDays,
            filterAuditorId,
            filterDueBefore
        );
    }

    /**
     * Get metric counts for the dashboard summary cards.
     * Five independent COUNT() queries -- no SOQL in loops.
     *
     * @return Map with keys: assignedToMe, highRisk, evidenceNeeded,
     *         readyForSignoff, slaAtRisk
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, Integer> getMetrics() {
        Id currentUser = UserInfo.getUserId();

        // FLS/CRUD enforced on every metric query (restored — goal C2).
        Integer assignedToMe = [
            SELECT COUNT()
            FROM Audit_Case__c
            WHERE Auditor__c = :currentUser
              AND Status__c != 'Closed'
            WITH USER_MODE
        ];

        Integer highRisk = [
            SELECT COUNT()
            FROM Audit_Case__c
            WHERE Risk_Tier__c IN ('High', 'Critical')
              AND Status__c != 'Closed'
            WITH USER_MODE
        ];

        Integer evidenceNeeded = [
            SELECT COUNT()
            FROM Audit_Case__c
            WHERE Status__c = 'Evidence_Needed'
            WITH USER_MODE
        ];

        Integer readyForSignoff = [
            SELECT COUNT()
            FROM Audit_Case__c
            WHERE Status__c = 'Ready_For_Signoff'
            WITH USER_MODE
        ];

        Integer slaAtRisk = [
            SELECT COUNT()
            FROM Audit_Case__c
            WHERE Due_At__c <= NEXT_N_DAYS:2
              AND Status__c != 'Closed'
            WITH USER_MODE
        ];

        return new Map<String, Integer>{
            'assignedToMe'     => assignedToMe,
            'highRisk'         => highRisk,
            'evidenceNeeded'   => evidenceNeeded,
            'readyForSignoff'  => readyForSignoff,
            'slaAtRisk'        => slaAtRisk
        };
    }

    /**
     * Get the distinct original approvers present on open audit cases, used to
     * populate the queue's Approver filter (audit finding F1 — the control was
     * inert because the LWC had no source for approver options).
     *
     * @return List of {id, name} maps, ordered by name
     */
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getApprovers() {
        return AuditCaseService.getApprovers();
    }

    /**
     * Create a new audit case from a loan application.
     *
     * @param loanApplicationId   The Loan_Application__c Id (as String)
     * @param samplingReason      Why this loan was selected
     * @param originalApproverId  The User Id who approved the original loan
     * @param approvalTimestamp   When the original loan was approved
     * @return The created Audit_Case__c with Id populated
     */
    @AuraEnabled
    public static Audit_Case__c createAuditCase(
        String loanApplicationId,
        String samplingReason,
        String originalApproverId,
        Datetime approvalTimestamp
    ) {
        // Loan_Application__c is Text(18) — pass string directly
        // Original_Approver__c is a User Lookup — needs Id conversion
        Id approverId = String.isNotBlank(originalApproverId)
            ? Id.valueOf(originalApproverId) : null;
        return AuditCaseService.createFromLoan(
            loanApplicationId,
            samplingReason,
            approverId,
            approvalTimestamp
        );
    }
}