/**
 * CaseSummaryService — the governed "give me the picture of this case" action
 * behind the Veridact Auditor Copilot (Agentforce) and an @AuraEnabled fallback.
 *
 * Like LoanDiagnosisService, this is a READ-ONLY narrator: the deterministic
 * replay kernel already computed the truth (Replay_Check__c / Borrower_Snapshot__c
 * / Evidence_Item__c) and this service only assembles those stored facts into a
 * plain-English briefing. It never re-runs replay and never decides compliance.
 *
 * The text is a DETERMINISTIC template built from data — the Agentforce layer may
 * rephrase on top, but the numbers and rule names come straight from the kernel.
 * Guardrails (ADR-16/21): never says a loan is "denied"/"approved invalidly",
 * always defers the final determination to the human auditor, and prints a
 * staleness notice when the loan changed after the last replay.
 *
 * Governance (ADR-26 log-before-execute dual-write): Phase 1 inserts an
 * Agent_Action_Log__c ('Initiated', Action_Name__c = 'Summarize_Case') plus a
 * 'phase:initiated' Audit_Event__c; Phase 2 is pure compute over hoisted reads;
 * Phase 3 appends a 'phase:outcome' Audit_Event__c. The intent row is never
 * updated — the outcome is a NEW appended event (append-only, ADR-1).
 *
 * Bulk-safe by construction: constant SOQL/DML regardless of request count (all
 * reads hoisted out of the per-case loop, all writes batched).
 *
 * @group Agentforce
 */
public with sharing class CaseSummaryService {

    private static final String ACTION = 'Summarize_Case';
    private static final String FINAL_AUTHORITY =
        'A human auditor must make the final call on this loan.';

    // ── Invocable entry point (Agentforce GenAiFunction / Flow) ─────────
    @InvocableMethod(
        label='Summarize Case'
        description='Assembles a plain-English briefing of an audit case (loan snapshot, replay results, evidence status, SLA) from stored data. Read only. A human auditor makes the final call.'
        category='Veridact Audit'
    )
    public static List<Response> summarize(List<Request> requests) {
        List<Id> caseIds = new List<Id>();
        for (Request req : requests) {
            caseIds.add(req?.auditCaseId);
        }
        return runSummaries(caseIds);
    }

    // ── LWC / anonymous-apex fallback ───────────────────────────────────
    @AuraEnabled(cacheable=false)
    public static Response summarizeCase(Id auditCaseId) {
        return runSummaries(new List<Id>{ auditCaseId })[0];
    }

    // ── Core orchestrator (log-before-execute dual-write) ────────────────
    private static List<Response> runSummaries(List<Id> caseIds) {
        List<Response> responses = new List<Response>();
        if (caseIds == null || caseIds.isEmpty()) {
            return responses;
        }

        // ── Phase 1: LOG-BEFORE-EXECUTE (dual-write intent) ──────────────
        List<Agent_Action_Log__c> intentLogs = new List<Agent_Action_Log__c>();
        for (Id caseId : caseIds) {
            intentLogs.add(buildIntentLog(caseId));
        }
        Database.insert(intentLogs, AccessLevel.USER_MODE);          // DML 1

        List<Audit_Event__c> intentEvents = new List<Audit_Event__c>();
        for (Integer i = 0; i < caseIds.size(); i++) {
            intentEvents.add(buildActionEvent(
                caseIds[i], intentLogs[i].Id, 'initiated', 'Initiated', null, null));
        }
        AuditEventService.logEvents(intentEvents);                   // DML 2

        // ── Phase 2: EXECUTE (bulk read once, then pure assembly) ────────
        Set<Id> caseIdSet = new Set<Id>(caseIds);
        Map<Id, Audit_Case__c> caseById = new Map<Id, Audit_Case__c>([
            SELECT Id, Name, Status__c, Risk_Tier__c, Due_At__c,
                   Borrower_Name_Snapshot__c, Loan_Amount__c,
                   Loan__r.LOS_Loan_Id__c, Loan__r.Loan_Amount__c,
                   Loan__r.Property_Value__c, Loan__r.LastModifiedDate
            FROM Audit_Case__c
            WHERE Id IN :caseIdSet
            WITH USER_MODE
        ]);                                                          // SOQL 1

        Map<Id, Facts> factsByCase = loadFacts(caseIdSet);          // SOQL 2
        Map<Id, List<Replay_Check__c>> checksByCase =
            AuditSoql.latestChecksFor(caseIdSet);                    // SOQL 3 (+4)
        Map<Id, EvidenceRollup> evByCase = loadEvidence(caseIdSet);  // SOQL 5

        List<Audit_Event__c> outcomeEvents = new List<Audit_Event__c>();
        for (Integer i = 0; i < caseIds.size(); i++) {
            Id caseId = caseIds[i];
            Response r;
            try {
                r = narrate(
                    caseById.get(caseId),
                    factsByCase.get(caseId),
                    checksByCase.containsKey(caseId)
                        ? checksByCase.get(caseId) : new List<Replay_Check__c>(),
                    evByCase.get(caseId)
                );
            } catch (Exception e) {
                r = errorResponse(e);
            }
            responses.add(r);
            outcomeEvents.add(buildActionEvent(
                caseId, intentLogs[i].Id, 'outcome', r.actionStatus, r.actionError, r.summary));
        }

        // ── Phase 3: APPEND OUTCOME (never an update to the intent row) ──
        AuditEventService.logEvents(outcomeEvents);                 // DML 3
        return responses;
    }

    // ── Hoisted reads (pure map builders) ────────────────────────────────

    /**
     * Fold the case's Borrower_Snapshot__c rows into one Facts holder per case,
     * taking the newest non-null value of each fact (facts are split across
     * category rows: DTI/income on Income, FICO on Credit, LTV on Collateral).
     * A re-extracted snapshot batch simply supplies newer values.
     */
    private static Map<Id, Facts> loadFacts(Set<Id> caseIds) {
        Map<Id, Facts> byCase = new Map<Id, Facts>();
        for (Borrower_Snapshot__c s : [
            SELECT Audit_Case__c, DTI_Ratio__c, LTV_Ratio__c, FICO_Score__c
            FROM Borrower_Snapshot__c
            WHERE Audit_Case__c IN :caseIds
            WITH USER_MODE
            ORDER BY CreatedDate ASC
        ]) {
            Facts f = byCase.get(s.Audit_Case__c);
            if (f == null) { f = new Facts(); byCase.put(s.Audit_Case__c, f); }
            // ASC order => later rows overwrite earlier, so newest non-null wins.
            if (s.DTI_Ratio__c  != null) { f.dti  = s.DTI_Ratio__c; }
            if (s.LTV_Ratio__c  != null) { f.ltv  = s.LTV_Ratio__c; }
            if (s.FICO_Score__c != null) { f.fico = s.FICO_Score__c; }
        }
        return byCase;
    }

    /** Roll up evidence into linked/missing counts + the required-missing doc types. */
    private static Map<Id, EvidenceRollup> loadEvidence(Set<Id> caseIds) {
        Map<Id, EvidenceRollup> byCase = new Map<Id, EvidenceRollup>();
        for (Evidence_Item__c ei : [
            SELECT Audit_Case__c, Document_Type__c, Status__c, Required__c
            FROM Evidence_Item__c
            WHERE Audit_Case__c IN :caseIds
            WITH USER_MODE
            ORDER BY Document_Type__c ASC
        ]) {
            EvidenceRollup r = byCase.get(ei.Audit_Case__c);
            if (r == null) { r = new EvidenceRollup(); byCase.put(ei.Audit_Case__c, r); }
            r.total++;
            if (ei.Status__c == 'Linked') {
                r.linked++;
            } else {
                r.missing++;
                if (ei.Required__c == true) {
                    r.requiredMissing++;
                    r.requiredMissingDocs.add(RuleNarration.label(ei.Document_Type__c));
                }
            }
        }
        return byCase;
    }

    // ── Assembly (pure: no SOQL, no DML) ─────────────────────────────────

    private static Response narrate(
        Audit_Case__c ac, Facts f, List<Replay_Check__c> checks, EvidenceRollup ev) {
        Response res = new Response();

        if (ac == null) {
            res.summary = 'Audit case not found or not accessible. ' + FINAL_AUTHORITY;
            res.actionStatus = 'Failed';
            return res;
        }

        List<String> parts = new List<String>();

        // ── Header line: who / status / risk / SLA ──
        String borrower = String.isBlank(ac.Borrower_Name_Snapshot__c)
            ? 'this borrower' : ac.Borrower_Name_Snapshot__c;
        String loanNo = (ac.Loan__r != null && String.isNotBlank(ac.Loan__r.LOS_Loan_Id__c))
            ? ' (loan ' + ac.Loan__r.LOS_Loan_Id__c + ')' : '';
        parts.add('Case ' + ac.Name + ' for ' + borrower + loanNo + '. '
            + 'Status: ' + RuleNarration.label(ac.Status__c) + '. '
            + 'Risk tier: ' + (String.isBlank(ac.Risk_Tier__c) ? 'not set' : ac.Risk_Tier__c) + '. '
            + slaPhrase(ac.Due_At__c));

        // ── Loan snapshot facts ──
        parts.add(loanSnapshot(ac, f));

        // ── Replay results ──
        Integer fails = 0, passes = 0, unver = 0;
        List<String> failLines = new List<String>();
        for (Replay_Check__c rc : checks) {
            if (rc.Result__c == 'Fail') {
                fails++;
                failLines.add(RuleNarration.plainName(rc.Rule_Name__c) + ' (' + rc.Rule_Name__c + ')');
            } else if (rc.Result__c == 'Pass') {
                passes++;
            } else {
                unver++;
            }
        }
        res.violationCount = fails;
        res.passCount = passes;
        res.unverifiableCount = unver;
        res.hasViolations = (fails > 0);

        if (checks.isEmpty()) {
            parts.add('Replay: the check has not been run on this loan yet, so there '
                + 'are no results to report. Run the check first.');
        } else {
            String replayLine = 'Replay: ' + passes + ' check' + plural(passes) + ' passed, '
                + fails + ' did not pass, and ' + unver + ' could not be checked.';
            if (fails > 0) {
                replayLine += ' Rules not passed: ' + String.join(failLines, '; ') + '.';
            }
            parts.add(replayLine);
        }

        // ── Freshness ──
        Datetime newestReplay = null;
        for (Replay_Check__c rc : checks) {
            if (newestReplay == null || rc.Replay_Timestamp__c > newestReplay) {
                newestReplay = rc.Replay_Timestamp__c;
            }
        }
        res.stale = (ac.Loan__r != null && ac.Loan__r.LastModifiedDate != null
            && newestReplay != null && ac.Loan__r.LastModifiedDate > newestReplay);
        if (res.stale) {
            parts.add('Note: this loan changed after the last check. '
                + 'Run the check again before sign-off.');
        }

        // ── Evidence status ──
        parts.add(evidenceLine(ev));

        parts.add(FINAL_AUTHORITY);
        res.summary = String.join(parts, ' ');
        res.actionStatus = 'Success';
        return res;
    }

    private static String loanSnapshot(Audit_Case__c ac, Facts f) {
        List<String> bits = new List<String>();
        Decimal amount = (ac.Loan__r != null && ac.Loan__r.Loan_Amount__c != null)
            ? ac.Loan__r.Loan_Amount__c : ac.Loan_Amount__c;
        if (amount != null) {
            bits.add('loan amount $' + amount.stripTrailingZeros().toPlainString());
        }
        if (ac.Loan__r != null && ac.Loan__r.Property_Value__c != null) {
            bits.add('property value $' + ac.Loan__r.Property_Value__c.stripTrailingZeros().toPlainString());
        }
        if (f != null && f.dti != null)  { bits.add('DTI ' + RuleNarration.pct(f.dti)); }
        if (f != null && f.ltv != null)  { bits.add('LTV ' + RuleNarration.pct(f.ltv)); }
        if (f != null && f.fico != null) { bits.add('FICO ' + f.fico.stripTrailingZeros().toPlainString()); }
        return bits.isEmpty()
            ? 'Loan snapshot: no borrower facts have been captured for this case yet.'
            : 'Loan snapshot: ' + String.join(bits, ', ') + '.';
    }

    private static String evidenceLine(EvidenceRollup ev) {
        if (ev == null || ev.total == 0) {
            return 'Evidence: no documents are tracked for this case yet.';
        }
        String line = 'Evidence: ' + ev.linked + ' of ' + ev.total
            + ' document' + plural(ev.total) + ' linked; ' + ev.missing + ' still missing';
        if (ev.requiredMissing > 0) {
            line += ' (' + ev.requiredMissing + ' required'
                + (ev.requiredMissingDocs.isEmpty()
                    ? '' : ', including: ' + String.join(ev.requiredMissingDocs, ', '))
                + ')';
        }
        return line + '.';
    }

    /** SLA phrase from Due_At__c relative to now (no "overdue" alarm words for a clean case). */
    private static String slaPhrase(Datetime dueAt) {
        if (dueAt == null) { return 'No due date is set.'; }
        Long ms = dueAt.getTime() - Datetime.now().getTime();
        Long days = Math.abs(ms) / (1000L * 60L * 60L * 24L);
        if (ms < 0) {
            return 'This case is past its due date by about ' + days + ' day' + plural((Integer) days) + '.';
        }
        return 'This case is due in about ' + days + ' day' + plural((Integer) days) + '.';
    }

    private static String plural(Integer n) { return (n == 1) ? '' : 's'; }

    private static Response errorResponse(Exception e) {
        Response res = new Response();
        res.summary = 'We hit an unexpected problem while summarizing this case. ' + FINAL_AUTHORITY;
        res.actionStatus = 'Failed';
        res.actionError = (e == null) ? null : e.getMessage();
        return res;
    }

    // ── Governance builders (mirror LoanDiagnosisService / ADR-26) ───────

    private static Agent_Action_Log__c buildIntentLog(Id auditCaseId) {
        return new Agent_Action_Log__c(
            Audit_Case__c    = auditCaseId,
            Action_Name__c   = ACTION,
            Subagent__c      = 'Auditor_Assistant',
            Status__c        = 'Initiated',
            Actor__c         = UserInfo.getName(),
            Input_Summary__c = 'summarize this case (case ' + auditCaseId + ')',
            Timestamp__c     = Datetime.now()
        );
    }

    private static Audit_Event__c buildActionEvent(
        Id auditCaseId, Id logId, String phase, String status, String error, String summary) {
        Map<String, Object> payload = new Map<String, Object>{
            'action' => ACTION, 'phase' => phase, 'status' => status
        };
        if (String.isNotBlank(error))   { payload.put('error', error); }
        if (String.isNotBlank(summary)) { payload.put('summary', summary); }
        return new Audit_Event__c(
            Audit_Case__c        = auditCaseId,
            Event_Type__c        = 'Agent_Action',
            Actor__c             = UserInfo.getName(),
            Timestamp__c         = Datetime.now(),
            Payload__c           = JSON.serialize(payload),
            Related_Record_Id__c = (logId == null) ? null : String.valueOf(logId)
        );
    }

    // ── Internal holders + DTOs ──────────────────────────────────────────

    private class Facts { Decimal dti; Decimal ltv; Decimal fico; }

    private class EvidenceRollup {
        Integer total = 0;
        Integer linked = 0;
        Integer missing = 0;
        Integer requiredMissing = 0;
        List<String> requiredMissingDocs = new List<String>();
    }

    public class Request {
        @InvocableVariable(required=true label='Audit Case Id')
        public Id auditCaseId;
    }

    public class Response {
        @InvocableVariable(label='Case summary') public String summary;
        @InvocableVariable(label='Has violations') public Boolean hasViolations;
        @InvocableVariable(label='Violation count') public Integer violationCount;
        @InvocableVariable(label='Pass count') public Integer passCount;
        @InvocableVariable(label='Unverifiable count') public Integer unverifiableCount;
        @InvocableVariable(label='Replay stale') public Boolean stale;

        // Governance carriers (NOT surfaced to Agentforce/Flow).
        public String actionStatus;
        public String actionError;
    }
}
