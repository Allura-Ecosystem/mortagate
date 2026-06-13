/**
 * AuditEvidenceReportController — backing controller for the printable
 * Audit Evidence Report (Visualforce, renderAs="pdf").
 *
 * SECURITY POSTURE (V5.1):
 *   • `with sharing` — record visibility honours the running user's sharing.
 *   • Every query runs `WITH USER_MODE`, so object/field-level security is
 *     enforced by the platform; a user without FLS/CRUD on the audit objects
 *     gets a fail-closed error, never a partial document.
 *   • The case Id arrives as a page parameter and is bound as a typed `Id`
 *     bind variable (`:caseId`) — never string-concatenated — so there is no
 *     SOQL-injection surface.
 *   • The page renders read-only (`readOnly="true"`) and performs NO DML.
 *
 * EVIDENTIARY ANCHORS (chain of custody):
 *   • Identity: the write-once `Borrower_Name_Snapshot__c` (ADR-001) — the
 *     borrower name as captured at sampling time, not a live lookup.
 *   • Trail: append-only `Audit_Event__c` records ordered by `Timestamp__c`
 *     ascending (oldest first), retrieved via the proven
 *     `AuditEventService.getEventsForCase` USER_MODE read path.
 *
 * @group Audit Trail
 * @see AuditEvidenceReport.page
 */
public with sharing class AuditEvidenceReportController {

    /** The audit case being reported on (null until a valid, accessible case loads). */
    public Audit_Case__c auditCase { get; private set; }

    /** Append-only event trail, oldest-first. Never null. */
    public List<Audit_Event__c> events { get; private set; }

    /** True only when a case loaded and the user is authorised to see it. */
    public Boolean reportReady { get; private set; }

    /** Human-readable reason the report could not be produced (else null). */
    public String errorMessage { get; private set; }

    /** Report generation stamp + actor — printed in the footer for provenance. */
    public Datetime generatedAt { get; private set; }
    public String generatedBy { get; private set; }

    public AuditEvidenceReportController() {
        reportReady = false;
        events = new List<Audit_Event__c>();
        generatedAt = Datetime.now();
        generatedBy = UserInfo.getName();

        String raw = ApexPages.currentPage() != null
            ? ApexPages.currentPage().getParameters().get('id')
            : null;

        if (String.isBlank(raw)) {
            errorMessage = 'No audit case was specified for this evidence report.';
            return;
        }

        Id caseId;
        try {
            caseId = Id.valueOf(raw);
        } catch (Exception e) {
            errorMessage = 'The audit case identifier is not valid.';
            return;
        }
        if (caseId.getSObjectType() != Audit_Case__c.SObjectType) {
            errorMessage = 'The supplied identifier does not reference an audit case.';
            return;
        }

        try {
            loadEvidence(caseId);
        } catch (System.QueryException qe) {
            // WITH USER_MODE raises QueryException on a CRUD/FLS denial — fail
            // closed with a generic message (no detail that could leak schema).
            errorMessage = 'You do not have permission to view this audit evidence record.';
        }
    }

    private void loadEvidence(Id caseId) {
        List<Audit_Case__c> cases = [
            SELECT Id, Name, Borrower_Name_Snapshot__c, Loan_Application__c,
                   Status__c, Risk_Tier__c, Sampling_Reason__c,
                   Auditor__r.Name, Original_Approver__r.Name,
                   Approval_Timestamp__c, Assigned_At__c, Due_At__c,
                   Sampled_At__c, CreatedDate
            FROM Audit_Case__c
            WHERE Id = :caseId
            WITH USER_MODE
            LIMIT 1
        ];

        if (cases.isEmpty()) {
            // Either it doesn't exist or sharing hides it — same message either way.
            errorMessage = 'Audit case not found, or you do not have access to it.';
            return;
        }

        auditCase = cases[0];
        // Reuse the proven, USER_MODE-enforced chain-of-custody read path.
        events = AuditEventService.getEventsForCase(caseId);
        reportReady = true;
    }
}
