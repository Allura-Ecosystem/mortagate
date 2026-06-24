/**
 * AnalyticsController — read-only portfolio analytics for the auditor home/app
 * page (the c-audit-analytics LWC), screen 5 of the auditor flow.
 *
 * It answers three portfolio questions over the OPEN (non-Closed) cases:
 *   • exceptionRate / violationRate — share of CURRENT replay checks that the
 *     replay flagged (Fail) versus passed, computed over the LATEST batch per
 *     case only (R-11) so a re-run case is never double-counted;
 *   • missingEvidenceCount — Finding__c rows the auditor recorded as missing
 *     evidence (Disposition Open + Documentation category);
 *   • approver-drift rows — grouped by the loan's Original Approver, the share
 *     of that approver's current checks that failed (who keeps shipping loans
 *     that don't replay clean).
 *
 * FLS/sharing: `with sharing`; every read runs USER_MODE (via AuditSoql or
 * WITH USER_MODE). Bulk-safe: a fixed, small number of SOQL regardless of how
 * many cases are open — NO SOQL/DML inside loops. The per-case latest-batch
 * resolution is delegated to AuditSoql.latestChecksFor(Set<Id>), the single
 * definition of "current checks".
 *
 * @group Analytics
 * @see AuditSoql, CaseReviewController, SignoffController
 */
public with sharing class AnalyticsController {

    @TestVisible private static final String STATUS_CLOSED = 'Closed';

    /**
     * Assemble the analytics DTO across all open cases. Cacheable, never writes.
     *
     * SOQL budget (fixed, bulk-safe):
     *   1 — open cases (id + approver),
     *   2 — latest-batch checks (inside AuditSoql.latestChecksFor),
     *   1 — missing-evidence finding count.
     *
     * @return an AnalyticsView (rates + missing-evidence count + drift rows)
     */
    @AuraEnabled(cacheable=true)
    public static AnalyticsView getAnalytics() {
        AnalyticsView v = new AnalyticsView();

        // 1) Open cases + their original approver (one query, no loop SOQL).
        List<Audit_Case__c> openCases = (List<Audit_Case__c>) AuditSoql.query(
            'SELECT Id, Original_Approver__c, Original_Approver__r.Name ' +
            'FROM Audit_Case__c WHERE Status__c != :closed',
            new Map<String, Object>{ 'closed' => STATUS_CLOSED });

        v.openCaseCount = openCases.size();
        if (openCases.isEmpty()) {
            return v;
        }

        // Map each open case → its approver display name (default for null lookup).
        Map<Id, String> approverByCase = new Map<Id, String>();
        Set<Id> caseIds = new Set<Id>();
        for (Audit_Case__c ac : openCases) {
            caseIds.add(ac.Id);
            String approver = (ac.Original_Approver__r != null && ac.Original_Approver__r.Name != null)
                ? ac.Original_Approver__r.Name
                : 'Unassigned';
            approverByCase.put(ac.Id, approver);
        }

        // 2) Latest-batch checks across ALL open cases in one shot (R-11).
        Map<Id, List<Replay_Check__c>> latestByCase = AuditSoql.latestChecksFor(caseIds);

        // Tally totals + per-approver drift in memory (no SOQL in the loop).
        Integer totalChecks = 0;
        Integer totalFails  = 0;
        Integer totalPasses = 0;
        Map<String, Integer> approverChecks = new Map<String, Integer>();
        Map<String, Integer> approverFails  = new Map<String, Integer>();

        for (Id caseId : caseIds) {
            List<Replay_Check__c> checks = latestByCase.get(caseId);
            if (checks == null) {
                continue;
            }
            String approver = approverByCase.get(caseId);
            if (!approverChecks.containsKey(approver)) {
                approverChecks.put(approver, 0);
                approverFails.put(approver, 0);
            }
            for (Replay_Check__c rc : checks) {
                totalChecks++;
                approverChecks.put(approver, approverChecks.get(approver) + 1);
                if (rc.Result__c == 'Fail') {
                    totalFails++;
                    approverFails.put(approver, approverFails.get(approver) + 1);
                } else if (rc.Result__c == 'Pass') {
                    totalPasses++;
                }
            }
        }

        v.totalChecks   = totalChecks;
        v.violationRate = pct(totalFails, totalChecks);
        // "Exception" rate here = the share of current checks that did NOT pass
        // outright (fails + unverifiable) — the slice needing auditor judgment.
        v.exceptionRate = pct(totalChecks - totalPasses, totalChecks);

        // Build approver-drift rows, highest fail-rate first.
        for (String approver : approverChecks.keySet()) {
            Integer c = approverChecks.get(approver);
            Integer f = approverFails.get(approver);
            ApproverDriftRow row = new ApproverDriftRow();
            row.approverName = approver;
            row.totalChecks  = c;
            row.failCount    = f;
            row.failRate     = pct(f, c);
            row.tone         = toneFor(row.failRate);
            v.approverDrift.add(row);
        }
        sortByFailRateDesc(v.approverDrift);

        // 3) Missing-evidence findings on open cases (one COUNT query).
        v.missingEvidenceCount = [
            SELECT COUNT()
            FROM Finding__c
            WHERE Audit_Case__c IN :caseIds
              AND Category__c = 'Documentation'
              AND Disposition__c = 'Open'
            WITH USER_MODE
        ];

        return v;
    }

    // ── Helpers ──────────────────────────────────────────────────────────

    /** Whole-number percentage (0–100), 0 when the denominator is 0. */
    private static Integer pct(Integer numerator, Integer denominator) {
        if (denominator == null || denominator == 0) {
            return 0;
        }
        return (Integer) Math.round((numerator * 100.0) / denominator);
    }

    /** riskBadge-style tone for a fail rate (reused by the UI table). */
    private static String toneFor(Integer failRate) {
        if (failRate >= 50) { return 'High'; }
        if (failRate >= 20) { return 'Medium'; }
        return 'Low';
    }

    /** Simple in-memory sort, fail rate desc then name asc (no SOQL). */
    private static void sortByFailRateDesc(List<ApproverDriftRow> rows) {
        for (Integer i = 0; i < rows.size(); i++) {
            for (Integer j = i + 1; j < rows.size(); j++) {
                Boolean swap = rows[j].failRate > rows[i].failRate
                    || (rows[j].failRate == rows[i].failRate
                        && rows[j].approverName < rows[i].approverName);
                if (swap) {
                    ApproverDriftRow tmp = rows[i];
                    rows[i] = rows[j];
                    rows[j] = tmp;
                }
            }
        }
    }

    // ── DTOs ─────────────────────────────────────────────────────────────

    public class AnalyticsView {
        @AuraEnabled public Integer openCaseCount = 0;
        @AuraEnabled public Integer totalChecks = 0;
        @AuraEnabled public Integer exceptionRate = 0;   // % of current checks not passing
        @AuraEnabled public Integer violationRate = 0;   // % of current checks failing
        @AuraEnabled public Integer missingEvidenceCount = 0;
        @AuraEnabled public List<ApproverDriftRow> approverDrift = new List<ApproverDriftRow>();
    }

    public class ApproverDriftRow {
        @AuraEnabled public String approverName;
        @AuraEnabled public Integer totalChecks;
        @AuraEnabled public Integer failCount;
        @AuraEnabled public Integer failRate;   // %
        @AuraEnabled public String tone;        // High | Medium | Low (riskBadge tone)
    }
}
