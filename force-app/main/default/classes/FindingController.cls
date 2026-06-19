/**
 * FindingController — data source + sole write path for the Finding Detail
 * screen (the c-finding-detail LWC), screen 4 of the auditor 5-screen flow.
 *
 * A Finding__c is the auditor's recorded outcome for a single rule context:
 * a documented Violation, an approved Exception (with reason), or a Pass /
 * missing-evidence note. Findings may be AI-drafted (Agentforce sets
 * AI_Drafted__c); when the auditor edits or accepts a draft this controller
 * stamps AI_Draft_Accepted__c (the SM-C2 counter-metric).
 *
 * FLS/sharing: `with sharing`; every read runs USER_MODE via AuditSoql, every
 * write runs USER_MODE via Database DML — an auditor can never read or write a
 * finding (or field) they lack access to.
 *
 * Write surface: exactly ONE method (saveFinding) writes, and only when the
 * auditor explicitly clicks Save. Reads are cacheable and never write.
 *
 * @group Finding Detail
 * @see AuditSoql, CaseReviewController, SignoffController
 */
public with sharing class FindingController {

    // ── Reads ────────────────────────────────────────────────────────────

    /**
     * Every finding recorded against one audit case (newest first). Cacheable,
     * never writes. 1 SOQL.
     *
     * @param auditCaseId the parent Audit_Case__c
     * @return the case's findings as flat DTOs (empty list if none / not visible)
     */
    @AuraEnabled(cacheable=true)
    public static List<FindingDto> getFindings(Id auditCaseId) {
        List<FindingDto> rows = new List<FindingDto>();
        if (auditCaseId == null) {
            return rows;
        }
        for (Finding__c f : (List<Finding__c>) AuditSoql.query(
            findingSelect() + ' WHERE Audit_Case__c = :auditCaseId ' +
            'ORDER BY CreatedDate DESC',
            new Map<String, Object>{ 'auditCaseId' => auditCaseId })) {
            rows.add(toDto(f));
        }
        return rows;
    }

    /**
     * One finding by id (the full edit context). Cacheable, never writes. 1 SOQL.
     *
     * @param findingId the Finding__c to load
     * @return the finding DTO, or null if not visible / not found
     */
    @AuraEnabled(cacheable=true)
    public static FindingDto getFinding(Id findingId) {
        if (findingId == null) {
            return null;
        }
        List<Finding__c> findings = (List<Finding__c>) AuditSoql.query(
            findingSelect() + ' WHERE Id = :findingId LIMIT 1',
            new Map<String, Object>{ 'findingId' => findingId });
        return findings.isEmpty() ? null : toDto(findings[0]);
    }

    // ── Write (the ONLY one) ─────────────────────────────────────────────

    /**
     * Create or update one finding for the case. Strictly user-triggered (the
     * LWC Save action). NOT cacheable.
     *
     * Behaviour:
     *   - findingId null  → INSERT a new finding under auditCaseId;
     *   - findingId set   → UPDATE that finding.
     *   - If the finding was AI_Drafted__c, any save through this auditor surface
     *     stamps AI_Draft_Accepted__c = true (accepted, edited or not — the
     *     SM-C2 "auditor stood behind the AI draft" signal).
     *
     * Severity__c is required by the schema; the LWC enforces it, and we surface
     * a friendly error if it is missing.
     *
     * @param input a flat FindingInput from the LWC
     * @return the freshly re-read FindingDto (so the UI repaints in one round trip)
     */
    @AuraEnabled
    public static FindingDto saveFinding(FindingInput input) {
        if (input == null) {
            throw new AuraHandledException('Nothing to save.');
        }
        if (String.isBlank(input.severity)) {
            throw new AuraHandledException('Severity is required to record a finding.');
        }

        try {
            Finding__c f;
            Boolean wasAiDrafted = false;

            if (input.recordId != null) {
                // Load the current row to know whether it was AI-drafted.
                List<Finding__c> existing = [
                    SELECT Id, AI_Drafted__c, AI_Draft_Accepted__c
                    FROM Finding__c
                    WHERE Id = :input.recordId
                    WITH USER_MODE
                    LIMIT 1
                ];
                if (existing.isEmpty()) {
                    throw new AuraHandledException('This finding is no longer available.');
                }
                f = existing[0];
                wasAiDrafted = (f.AI_Drafted__c == true);
            } else {
                if (input.auditCaseId == null) {
                    throw new AuraHandledException('An audit case is required to create a finding.');
                }
                f = new Finding__c(Audit_Case__c = input.auditCaseId);
            }

            f.Severity__c          = input.severity;
            f.Category__c          = input.category;
            f.Disposition__c       = input.disposition;
            f.Description__c       = input.description;
            f.Exception_Reason__c  = input.exceptionReason;
            f.Exception_Approver__c = input.exceptionApprover;
            f.Closed_Reason__c     = input.closedReason;
            f.Remediation_Notes__c = input.remediationNotes;
            f.Remediation_Due_At__c = input.remediationDueAt;
            if (input.replayCheckId != null) {
                f.Replay_Check__c = input.replayCheckId;
            }

            // If the AI drafted this finding and the auditor saved it through the
            // review surface, record that the draft was accepted (SM-C2).
            if (wasAiDrafted) {
                f.AI_Draft_Accepted__c = true;
            }

            if (f.Id == null) {
                insert as user f;   // 1 DML, USER_MODE
            } else {
                update as user f;   // 1 DML, USER_MODE
            }

            return getFinding(f.Id);
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    // ── Helpers ──────────────────────────────────────────────────────────

    private static String findingSelect() {
        return
            'SELECT Id, Name, Audit_Case__c, Replay_Check__c, ' +
            'Replay_Check__r.Rule_Name__c, Replay_Check__r.Result__c, ' +
            'Replay_Check__r.Expected_Value__c, Replay_Check__r.Actual_Value__c, ' +
            'Replay_Check__r.Rationale__c, ' +
            'Category__c, Severity__c, Disposition__c, Description__c, ' +
            'Exception_Reason__c, Exception_Approver__c, Closed_Reason__c, ' +
            'Remediation_Owner__c, Remediation_Owner__r.Name, Remediation_Due_At__c, ' +
            'Remediation_Notes__c, AI_Drafted__c, AI_Draft_Accepted__c, ' +
            'CreatedDate, LastModifiedDate ' +
            'FROM Finding__c';
    }

    private static FindingDto toDto(Finding__c f) {
        FindingDto d = new FindingDto();
        d.recordId          = f.Id;
        d.name              = f.Name;
        d.auditCaseId       = f.Audit_Case__c;
        d.replayCheckId     = f.Replay_Check__c;
        d.category          = f.Category__c;
        d.severity          = f.Severity__c;
        d.disposition       = f.Disposition__c;
        d.description       = f.Description__c;
        d.exceptionReason   = f.Exception_Reason__c;
        d.exceptionApprover = f.Exception_Approver__c;
        d.closedReason      = f.Closed_Reason__c;
        d.remediationOwnerId = f.Remediation_Owner__c;
        d.remediationOwner  = (f.Remediation_Owner__r != null) ? f.Remediation_Owner__r.Name : null;
        d.remediationDueAt  = f.Remediation_Due_At__c;
        d.remediationNotes  = f.Remediation_Notes__c;
        d.aiDrafted         = (f.AI_Drafted__c == true);
        d.aiDraftAccepted   = (f.AI_Draft_Accepted__c == true);
        d.isViolation       = (f.Severity__c == 'Violation');
        d.isException       = (f.Severity__c == 'Exception');

        // Rule context from the source replay check (null for manual findings).
        if (f.Replay_Check__r != null) {
            d.ruleName       = f.Replay_Check__r.Rule_Name__c;
            d.ruleResult     = f.Replay_Check__r.Result__c;
            d.expectedValue  = f.Replay_Check__r.Expected_Value__c;
            d.actualValue    = f.Replay_Check__r.Actual_Value__c;
            d.ruleRationale  = f.Replay_Check__r.Rationale__c;
        }
        return d;
    }

    // ── DTOs ─────────────────────────────────────────────────────────────

    public class FindingDto {
        @AuraEnabled public Id recordId;
        @AuraEnabled public String name;
        @AuraEnabled public Id auditCaseId;
        @AuraEnabled public Id replayCheckId;
        @AuraEnabled public String category;
        @AuraEnabled public String severity;
        @AuraEnabled public String disposition;
        @AuraEnabled public String description;
        @AuraEnabled public String exceptionReason;
        @AuraEnabled public String exceptionApprover;
        @AuraEnabled public String closedReason;
        @AuraEnabled public Id remediationOwnerId;
        @AuraEnabled public String remediationOwner;
        @AuraEnabled public Date remediationDueAt;
        @AuraEnabled public String remediationNotes;
        @AuraEnabled public Boolean aiDrafted = false;
        @AuraEnabled public Boolean aiDraftAccepted = false;
        @AuraEnabled public Boolean isViolation = false;
        @AuraEnabled public Boolean isException = false;
        // Rule context (from the source Replay_Check__c, null for manual findings).
        @AuraEnabled public String ruleName;
        @AuraEnabled public String ruleResult;
        @AuraEnabled public String expectedValue;
        @AuraEnabled public String actualValue;
        @AuraEnabled public String ruleRationale;
    }

    public class FindingInput {
        @AuraEnabled public Id recordId;        // null => create
        @AuraEnabled public Id auditCaseId;     // required on create
        @AuraEnabled public Id replayCheckId;   // optional source check
        @AuraEnabled public String category;
        @AuraEnabled public String severity;    // required
        @AuraEnabled public String disposition;
        @AuraEnabled public String description;
        @AuraEnabled public String exceptionReason;
        @AuraEnabled public String exceptionApprover;
        @AuraEnabled public String closedReason;
        @AuraEnabled public String remediationNotes;
        @AuraEnabled public Date remediationDueAt;
    }
}
