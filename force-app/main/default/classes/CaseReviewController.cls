/**
 * CaseReviewController -- Orchestrates the audit replay flow for the caseReview LWC.
 *
 * Provides case detail retrieval, audit replay execution (fact reconstruction +
 * policy evaluation + commit), timeline access, and sign-off submission.
 *
 * @group Audit LWC Controllers
 * @see FactAssembler
 * @see PolicyRuleEvaluator
 * @see AuditCommitService
 * @see AuditEventService
 */
public with sharing class CaseReviewController {

    /**
     * Wrapper class returned to the LWC with all case-related data
     * in a single wire call.
     */
    public class CaseReviewData {
        @AuraEnabled public Audit_Case__c caseRecord;
        @AuraEnabled public List<Evidence_Item__c> evidenceItems;
        @AuraEnabled public List<Reconstructed_Fact__c> facts;
        @AuraEnabled public List<Rule_Check__c> ruleChecks;
        @AuraEnabled public List<Finding__c> findings;
        @AuraEnabled public List<Audit_Event__c> timeline;
    }

    /**
     * Get case detail with all related data for the review screen.
     *
     * @param auditCaseId The Audit_Case__c Id
     * @return CaseReviewData wrapper with all sections populated
     */
    @AuraEnabled(cacheable=true)
    public static CaseReviewData getCaseReview(Id auditCaseId) {
        CaseReviewData data = new CaseReviewData();

        // Case record
        List<Audit_Case__c> cases = [
            SELECT Id, Name, Loan_Application__c, Status__c,
                   Auditor__c, Auditor__r.Name,
                   Original_Approver__c, Original_Approver__r.Name,
                   Sampling_Reason__c, Risk_Tier__c, Scope__c,
                   Approval_Timestamp__c, Assigned_At__c, Due_At__c,
                   Policy_Version__c,
                   Signed_Off_At__c, Signed_Off_By__c,
                   CreatedDate
            FROM Audit_Case__c
            WHERE Id = :auditCaseId
            WITH USER_MODE
            LIMIT 1
        ];
        data.caseRecord = cases.isEmpty() ? null : cases[0];

        // Evidence items
        data.evidenceItems = [
            SELECT Id, Name, Document_Type__c, Status__c,
                   CreatedDate
            FROM Evidence_Item__c
            WHERE Audit_Case__c = :auditCaseId
            WITH USER_MODE
            ORDER BY Document_Type__c ASC
        ];

        // Reconstructed facts
        data.facts = [
            SELECT Id, Name, Fact_Type__c, Value__c,
                   CreatedDate
            FROM Reconstructed_Fact__c
            WHERE Audit_Case__c = :auditCaseId
            WITH USER_MODE
            ORDER BY Fact_Type__c ASC
        ];

        // Rule checks
        data.ruleChecks = [
            SELECT Id, Name, Rule_Name__c, Outcome__c,
                   Policy_Rule_Version__c,
                   CreatedDate
            FROM Rule_Check__c
            WHERE Audit_Case__c = :auditCaseId
            WITH USER_MODE
            ORDER BY Rule_Name__c ASC
        ];

        // Findings
        data.findings = [
            SELECT Id, Name, Category__c, Severity__c, Disposition__c,
                   Rationale__c, Remediation_Due_At__c,
                   CreatedDate
            FROM Finding__c
            WHERE Audit_Case__c = :auditCaseId
            WITH USER_MODE
            ORDER BY Severity__c ASC
        ];

        // Timeline
        data.timeline = AuditEventService.getEventsForCase(auditCaseId);

        return data;
    }

    /**
     * Run the audit replay pipeline:
     * 1. Reconstruct facts from evidence
     * 2. Look up the historical policy version from the case
     * 3. Replay policy rules against facts
     * 4. Commit results (facts, checks, events) atomically
     * 5. Return refreshed case data
     *
     * @param auditCaseId The Audit_Case__c Id
     * @return CaseReviewData with refreshed data after replay
     */
    @AuraEnabled
    public static CaseReviewData runReplay(Id auditCaseId) {
        try {
            // 1. Reconstruct facts
            List<Reconstructed_Fact__c> facts = FactAssembler.reconstructFacts(auditCaseId);

            // 2. Get the historical policy version — always auto-select via
            //    PolicyVersionSelector to avoid querying org-missing fields.
            Audit_Case__c auditCase = [
                SELECT Id, Approval_Timestamp__c
                FROM Audit_Case__c
                WHERE Id = :auditCaseId
                WITH USER_MODE
                LIMIT 1
            ];

            String policyVersionStr = PolicyVersionSelector.selectByApprovalDate(auditCase.Approval_Timestamp__c);
            // Write it back so downstream code can reference it
            if (policyVersionStr != null) {
                update new Audit_Case__c(Id = auditCaseId, Policy_Version__c = policyVersionStr);
            }
            Policy_Rule_Version__c policy = PolicyVersionSelector.loadPolicyVersion(policyVersionStr);

            if (policy == null) {
                throw new AuraHandledException('No policy version found for this audit case. Please assign a policy version before running replay.');
            }

            // 3. Replay rules
            List<Rule_Check__c> checks = PolicyRuleEvaluator.replayRules(facts, policy, auditCaseId);

            // 4. Commit atomically
            AuditCommitService.commitReplayResults(auditCaseId, facts, checks);

            // 5. Return refreshed data
            return getCaseReview(auditCaseId);
        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * Get audit event timeline for a case.
     *
     * @param auditCaseId The Audit_Case__c Id
     * @return Ordered list of Audit_Event__c records (oldest first)
     */
    @AuraEnabled(cacheable=true)
    public static List<Audit_Event__c> getTimeline(Id auditCaseId) {
        return AuditEventService.getEventsForCase(auditCaseId);
    }

    /**
     * Submit an audit case for sign-off.
     * Updates status to Ready_For_Signoff and logs a Signoff_Submitted event.
     *
     * @param auditCaseId The Audit_Case__c Id
     */
    @AuraEnabled
    public static void submitForSignoff(Id auditCaseId) {
        try {
            if (!FindingService.allExceptionsApproved(auditCaseId)) {
                throw new AuraHandledException(
                    'Cannot submit for sign-off: unapproved exceptions exist. All rule check exceptions must have documented approval.'
                );
            }

            Audit_Case__c auditCase = new Audit_Case__c(
                Id = auditCaseId,
                Status__c = 'Ready_For_Signoff'
            );
            update auditCase;

            AuditEventService.logEvent(
                auditCaseId,
                'Signoff_Completed',
                UserInfo.getUserId(),
                null,
                null
            );
        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * Update evidence item status and log an audit event.
     *
     * @param evidenceItemId The Evidence_Item__c Id to update
     * @param newStatus      The new Status__c value (e.g. 'Available', 'Missing')
     */
    @AuraEnabled
    public static void updateEvidenceStatus(Id evidenceItemId, String newStatus) {
        Evidence_Item__c item = new Evidence_Item__c(
            Id = evidenceItemId,
            Status__c = newStatus
        );
        update item;

        // Get the parent case for event logging
        Evidence_Item__c full = [
            SELECT Audit_Case__c
            FROM Evidence_Item__c
            WHERE Id = :evidenceItemId
            WITH USER_MODE
            LIMIT 1
        ];
        AuditEventService.logEvent(
            full.Audit_Case__c,
            'Evidence_Linked',
            UserInfo.getUserId(),
            JSON.serialize(new Map<String, Object>{
                'evidenceItemId' => evidenceItemId,
                'newStatus' => newStatus
            }),
            evidenceItemId
        );
    }
}