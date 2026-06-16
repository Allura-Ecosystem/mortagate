/**
 * CaseReviewController — read-only data source for the Case Review screen
 * (the c-case-review LWC). This is the two-pane drill-in an auditor reaches
 * via the queue's "Review ›": LEFT = evidence pack, RIGHT = replay
 * checks/findings, plus a staleness banner and a single user-triggered
 * "Re-run replay" action.
 *
 * FLS/sharing: `with sharing` + AccessLevel.USER_MODE on every read (through
 * the shared AuditSoql helper), mirroring AuditQueueController — an auditor can
 * never see a case (or field) they lack access to.
 *
 * Write surface: exactly ONE method (rerunReplay) writes, and only when the
 * auditor explicitly clicks. getCaseDetail is cacheable and never writes.
 *
 * @group Case Review
 * @see AuditQueueController, AuditSoql, ReplayService
 */
public with sharing class CaseReviewController {

    // ── Public API ──────────────────────────────────────────────────────

    /**
     * Assemble the full Case Review DTO for one audit case (1 SOQL).
     *
     * @param auditCaseId the Audit_Case__c under review
     * @return a CaseDetail (header + replay checks + evidence + staleness),
     *         or null if the case is not visible / not found.
     */
    @AuraEnabled(cacheable=true)
    public static CaseDetail getCaseDetail(Id auditCaseId) {
        if (auditCaseId == null) {
            return null;
        }

        String soql =
            'SELECT Id, Name, Status__c, Risk_Tier__c, Borrower_Name_Snapshot__c, ' +
            'Original_Approver__r.Name, ' +
            'Loan__r.LOS_Loan_Id__c, Loan__r.Approver_Name__c, Loan__r.LastModifiedDate, ' +
            '(SELECT Id, Rule_Name__c, Result__c, Expected_Value__c, Actual_Value__c, ' +
            'Rationale__c, Sort_Order__c, Replay_Timestamp__c ' +
            'FROM Replay_Checks__r ORDER BY Sort_Order__c ASC NULLS LAST), ' +
            '(SELECT Id, Document_Type__c, Status__c FROM Evidence_Items__r ORDER BY Document_Type__c ASC) ' +
            'FROM Audit_Case__c WHERE Id = :auditCaseId LIMIT 1';

        List<Audit_Case__c> cases = (List<Audit_Case__c>) AuditSoql.query(
            soql, new Map<String, Object>{ 'auditCaseId' => auditCaseId });

        if (cases.isEmpty()) {
            return null;
        }
        return toDetail(cases[0]);
    }

    /**
     * Re-run the historical policy replay for this case. The ONLY write path on
     * this controller, and strictly user-triggered (the LWC "Re-run replay"
     * button). NOT cacheable.
     *
     * @param auditCaseId the Audit_Case__c to replay
     * @return the freshly assembled CaseDetail (so the UI repaints in one round trip)
     */
    @AuraEnabled
    public static CaseDetail rerunReplay(Id auditCaseId) {
        if (auditCaseId == null) {
            throw new AuraHandledException('An audit case id is required to re-run the replay.');
        }
        try {
            ReplayService.replay(auditCaseId);
            return getCaseDetail(auditCaseId);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    // ── Helpers ─────────────────────────────────────────────────────────

    private static CaseDetail toDetail(Audit_Case__c ac) {
        CaseDetail d = new CaseDetail();

        // ── Header ──
        CaseHeader h = new CaseHeader();
        h.recordId    = ac.Id;
        h.caseNumber  = ac.Name;
        h.loanNumber  = (ac.Loan__r != null) ? ac.Loan__r.LOS_Loan_Id__c : null;
        h.borrowerName = ac.Borrower_Name_Snapshot__c;
        h.riskTier    = ac.Risk_Tier__c;
        h.statusApi   = ac.Status__c;
        h.status      = (ac.Status__c == null) ? null : ac.Status__c.replace('_', ' ');
        h.approverName = (ac.Original_Approver__r != null)
            ? ac.Original_Approver__r.Name
            : (ac.Loan__r != null ? ac.Loan__r.Approver_Name__c : null);
        d.header = h;

        // ── Replay checks (RIGHT pane) ──
        Datetime latestReplay = null;
        Integer failCount = 0;
        for (Replay_Check__c rc : ac.Replay_Checks__r) {
            ReplayCheckRow row = new ReplayCheckRow();
            row.recordId      = rc.Id;
            row.ruleName      = rc.Rule_Name__c;
            row.result        = rc.Result__c;
            row.expectedValue = rc.Expected_Value__c;
            row.actualValue   = rc.Actual_Value__c;
            row.rationale     = rc.Rationale__c;
            row.sortOrder     = (rc.Sort_Order__c == null) ? null : rc.Sort_Order__c.intValue();
            row.isFail        = (rc.Result__c == 'Fail');
            if (row.isFail) { failCount++; }
            d.checks.add(row);

            if (rc.Replay_Timestamp__c != null &&
                (latestReplay == null || rc.Replay_Timestamp__c > latestReplay)) {
                latestReplay = rc.Replay_Timestamp__c;
            }
        }
        d.failCount = failCount;
        d.hasReplay = !d.checks.isEmpty();

        // ── Evidence pack (LEFT pane) ──
        for (Evidence_Item__c ei : ac.Evidence_Items__r) {
            EvidenceRow er = new EvidenceRow();
            er.recordId     = ei.Id;
            er.documentType = ei.Document_Type__c;
            er.status       = ei.Status__c;
            d.evidence.add(er);
        }

        // ── Staleness: the loan changed after the last replay ──
        Datetime loanModified = (ac.Loan__r != null) ? ac.Loan__r.LastModifiedDate : null;
        d.replayStale = d.hasReplay
            && latestReplay != null
            && loanModified != null
            && loanModified > latestReplay;

        return d;
    }

    // ── DTOs ────────────────────────────────────────────────────────────

    public class CaseDetail {
        @AuraEnabled public CaseHeader header;
        @AuraEnabled public List<ReplayCheckRow> checks = new List<ReplayCheckRow>();
        @AuraEnabled public List<EvidenceRow> evidence = new List<EvidenceRow>();
        @AuraEnabled public Boolean replayStale = false;
        @AuraEnabled public Boolean hasReplay = false;
        @AuraEnabled public Integer failCount = 0;
    }

    public class CaseHeader {
        @AuraEnabled public Id recordId;
        @AuraEnabled public String caseNumber;
        @AuraEnabled public String loanNumber;
        @AuraEnabled public String borrowerName;
        @AuraEnabled public String riskTier;
        @AuraEnabled public String status;     // display label (de-underscored)
        @AuraEnabled public String statusApi;  // raw picklist value
        @AuraEnabled public String approverName;
    }

    public class ReplayCheckRow {
        @AuraEnabled public Id recordId;
        @AuraEnabled public String ruleName;
        @AuraEnabled public String result;        // Pass | Fail | Unverifiable
        @AuraEnabled public String expectedValue;
        @AuraEnabled public String actualValue;
        @AuraEnabled public String rationale;
        @AuraEnabled public Integer sortOrder;
        @AuraEnabled public Boolean isFail;
    }

    public class EvidenceRow {
        @AuraEnabled public Id recordId;
        @AuraEnabled public String documentType;
        @AuraEnabled public String status;
    }
}
