/**
 * FindingService -- Generates and manages findings from audit rule check results.
 *
 * Provides auto-generation of Finding__c records from Rule_Check__c outcomes,
 * exception approval workflow, and exception validation for sign-off readiness.
 *
 * @group Audit Findings
 * @see PolicyRuleEvaluator
 * @see AuditCommitService
 * @see AuditEventService
 */
public with sharing class FindingService {

    /**
     * Auto-generate findings from rule check results.
     * - Violation -> Finding with Category=Eligibility, Severity=High, Disposition=Open
     * - Unverifiable -> Finding with Category=Documentation, Severity=Medium, Disposition=Open
     * - Exception with blank Exception_Reason__c -> Finding with Category=Process, Severity=High
     * - Pass -> no finding
     *
     * Returns unsaved Finding__c list. Caller commits via AuditCommitService.
     *
     * @param auditCaseId The parent Audit_Case__c Id
     * @param checks      List of Rule_Check__c results to evaluate
     * @return Unsaved Finding__c records (caller is responsible for DML)
     */
    public static List<Finding__c> createFromRuleChecks(Id auditCaseId, List<Rule_Check__c> checks) {
        List<Finding__c> findings = new List<Finding__c>();
        for (Rule_Check__c check : checks) {
            if (check.Outcome__c == 'Violation') {
                findings.add(new Finding__c(
                    Audit_Case__c = auditCaseId,
                    Category__c = 'Eligibility',
                    Severity__c = 'High',
                    Disposition__c = 'Open'
                ));
            } else if (check.Outcome__c == 'Unverifiable') {
                findings.add(new Finding__c(
                    Audit_Case__c = auditCaseId,
                    Category__c = 'Documentation',
                    Severity__c = 'Medium',
                    Disposition__c = 'Open'
                ));
            } else if (check.Outcome__c == 'Exception' && String.isBlank(check.Exception_Reason__c)) {
                findings.add(new Finding__c(
                    Audit_Case__c = auditCaseId,
                    Category__c = 'Process',
                    Severity__c = 'High',
                    Disposition__c = 'Open'
                ));
            }
        }
        return findings;
    }

    /**
     * Approve an exception on a rule check.
     * Sets Exception_Reason__c and Exception_Approver__c on the Rule_Check__c.
     * Logs an Audit_Event__c for the approval action.
     *
     * @param ruleCheckId The Rule_Check__c Id to approve
     * @param reason      The documented reason for the exception
     * @param approver    The name or Id of the approving authority
     */
    public static void approveException(Id ruleCheckId, String reason, String approver) {
        Rule_Check__c check = [
            SELECT Id, Audit_Case__c, Outcome__c
            FROM Rule_Check__c
            WHERE Id = :ruleCheckId
            WITH USER_MODE
            LIMIT 1
        ];
        check.Exception_Reason__c = reason;
        check.Exception_Approver__c = approver;
        update check;

        AuditEventService.logEvent(
            check.Audit_Case__c,
            'Finding_Created',
            UserInfo.getUserId(),
            JSON.serialize(new Map<String, Object>{
                'action' => 'exception_approved',
                'ruleCheckId' => ruleCheckId,
                'reason' => reason,
                'approver' => approver
            }),
            ruleCheckId
        );
    }

    /**
     * Check if all exceptions have been approved for an audit case.
     * Used by submitForSignoff validation.
     *
     * @param auditCaseId The Audit_Case__c to check
     * @return True if no unapproved exceptions exist, false otherwise
     */
    public static Boolean allExceptionsApproved(Id auditCaseId) {
        Integer unapproved = [
            SELECT COUNT()
            FROM Rule_Check__c
            WHERE Audit_Case__c = :auditCaseId
              AND Outcome__c = 'Exception'
              AND Exception_Reason__c = null
            WITH USER_MODE
        ];
        return unapproved == 0;
    }
}