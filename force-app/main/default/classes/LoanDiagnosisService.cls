/**
 * LoanDiagnosisService — the governed "what's wrong with this loan?" action
 * behind the Veridact Auditor Copilot (Agentforce) and the LWC fallback.
 *
 * Division of labour (no hallucinated verdicts): the deterministic Apex replay
 * engine (ReplayService / PolicyRuleEvaluator) already computed the truth and
 * stored it in Replay_Check__c. This service ONLY READS those records and
 * narrates them — it never re-runs replay (replay commits DML; a "question"
 * must stay read-only) and never decides compliance.
 *
 * Guardrails (also enforced by the Agentforce topic instructions): the summary
 * states the rule violated, expected threshold, actual value, rationale, and
 * that the human auditor makes the final determination. It never says a loan
 * "should be denied", that an "approval was invalid" (unless replay says Fail),
 * or "I approve/close/override".
 *
 * Every call writes one append-only Agent_Action_Log__c row.
 *
 * @group Agentforce
 */
public with sharing class LoanDiagnosisService {

    // Plain language, about a 6th-grade reading level (the "Leo" rule).
    private static final String FINAL_AUTHORITY =
        'A human auditor must make the final call on this loan.';

    // THE LEO FLIP (mirrors lwc/glossaryTerm): each per-rule line now LEADS WITH
    // the plain NAME and keeps the raw code as a parenthetical badge. Code → plain
    // name. Unknown codes fall back to the raw code itself (never blank).
    private static final Map<String, String> PLAIN_NAME = new Map<String, String>{
        'DTI_MAX'    => 'Debt vs. income too high',
        'DTI_WARN'   => 'Debt vs. income is getting high',
        'FICO_MIN'   => 'Credit score too low',
        'LTV_MAX'    => 'Loan too big vs. home value',
        'INCOME_MIN' => 'Income is below the minimum needed',
        'EMPLOY_MIN' => 'Has not worked at the job long enough',
        'ASSET_MIN'  => 'Not enough savings in the bank',
        'DEBT_MAX'   => 'Total debt is over the limit',
        'FICO_PREF'  => 'Credit score is below the preferred level',
        'LTV_PREF'   => 'Loan is bigger than the preferred level vs. home value'
    };

    // ── Invocable entry point (Agentforce GenAiFunction / Flow) ─────────

    @InvocableMethod(
        label='Diagnose Loan Audit'
        description='Explains what is wrong with an already-approved loan, read only, from stored replay checks.'
        category='Veridact Audit'
    )
    public static List<Response> diagnose(List<Request> requests) {
        List<Id> caseIds = new List<Id>();
        for (Request req : requests) {
            caseIds.add(req?.auditCaseId);
        }
        return runDiagnoses(caseIds);
    }

    // ── LWC / anonymous-apex fallback (no Agentforce required) ──────────

    @AuraEnabled(cacheable=false)
    public static Response diagnoseCase(Id auditCaseId) {
        return runDiagnoses(new List<Id>{ auditCaseId })[0];
    }

    // ── Core orchestrator ────────────────────────────────────────────────
    //
    // Governance (FR-23 / SOLUTION-ARCHITECTURE Flow 3): EVERY agent action must
    // LOG BEFORE it EXECUTES, dual-writing to Agent_Action_Log__c + Audit_Event__c.
    // Because those objects are append-only (validation rule + trigger, ADR-1) the
    // pre-execution row can never be patched with the outcome — a changed state is
    // a NEW appended record, never an edit. So the shape is:
    //   Phase 1 (before execute): insert Agent_Action_Log__c (Status = 'Initiated')
    //                             + Audit_Event__c ('Agent_Action', phase=initiated)
    //   Phase 2 (execute):        pure in-memory narration of stored replay checks
    //   Phase 3 (after execute):  append a NEW Audit_Event__c ('Agent_Action',
    //                             phase=outcome) carrying the result — never an update
    //
    // Bulk-safe by construction: 3 SOQL + 3 DML regardless of request count. All
    // reads are hoisted out of the per-case loop; all writes are batched.
    private static List<Response> runDiagnoses(List<Id> caseIds) {
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

        // ── Phase 2: EXECUTE (bulk read once, then pure narration) ───────
        Set<Id> caseIdSet = new Set<Id>(caseIds);
        Map<Id, Audit_Case__c> caseById = new Map<Id, Audit_Case__c>([
            SELECT Id, Borrower_Name_Snapshot__c, Loan__r.LastModifiedDate
            FROM Audit_Case__c
            WHERE Id IN :caseIdSet
            WITH USER_MODE
        ]);                                                          // SOQL 1
        // R-11: Replay_Check__c is append-only — a re-run stacks a new batch on
        // the old one. Diagnose the LATEST batch only (shared AuditSoql selector)
        // so a duplicate run never double-counts violations. 2 SOQL, bulk-safe.
        Map<Id, List<Replay_Check__c>> checksByCase =
            AuditSoql.latestChecksFor(caseIdSet);                    // SOQL 2 + 3

        List<Audit_Event__c> outcomeEvents = new List<Audit_Event__c>();
        for (Integer i = 0; i < caseIds.size(); i++) {
            Id caseId = caseIds[i];
            Response r;
            try {
                r = narrate(
                    caseById.get(caseId),
                    checksByCase.containsKey(caseId)
                        ? checksByCase.get(caseId)
                        : new List<Replay_Check__c>()
                );
            } catch (Exception e) {
                // A per-case failure becomes a Failed outcome rather than aborting
                // the whole batch; the intent log already persisted (Phase 1).
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

    // ── Narration (pure: no SOQL, no DML) ─────────────────────────────────

    private static Response narrate(Audit_Case__c ac, List<Replay_Check__c> checks) {
        Response res = new Response();
        res.findings = new List<String>();

        if (ac == null) {
            res.summary = 'Audit case not found or not accessible.';
            res.hasViolations = false;
            res.actionStatus = 'Failed';
            return res;
        }

        if (checks == null || checks.isEmpty()) {
            res.summary = 'We have not run the check on this loan yet, so there is '
                + 'nothing to explain. Run the check first, then ask again. ' + FINAL_AUTHORITY;
            res.hasViolations = false;
            res.violationCount = 0;
            res.passCount = 0;
            res.unverifiableCount = 0;
            res.stale = false;
            res.actionStatus = 'Partial';
            return res;
        }

        // Freshness: newest replay vs the loan's last edit.
        Datetime newestReplay = null;
        for (Replay_Check__c rc : checks) {
            if (newestReplay == null || rc.Replay_Timestamp__c > newestReplay) {
                newestReplay = rc.Replay_Timestamp__c;
            }
        }
        res.stale = (ac.Loan__r != null
            && ac.Loan__r.LastModifiedDate != null
            && newestReplay != null
            && ac.Loan__r.LastModifiedDate > newestReplay);

        Integer fails = 0, passes = 0, unver = 0;
        List<String> brokenRuleLines = new List<String>();
        for (Replay_Check__c rc : checks) {
            // THE LEO FLIP: lead with the plain NAME, keep the CODE as a small
            // parenthetical badge, then give clearer numbers with a direction
            // phrase ("the most allowed is" / "the lowest allowed is"). Still
            // names the rule and shows BOTH numbers (guardrail intact).
            //   <PlainName> (<CODE>): <directionPhrase> <expected>, but this loan is <actual>.
            String code = rc.Rule_Name__c;        // Rule_Name__c carries the rule CODE
            String line = plainName(code) + ' (' + code + '): '
                + directionPhrase(code) + ' ' + prettyNum(rc.Expected_Value__c)
                + ', but this loan is ' + prettyNum(rc.Actual_Value__c) + '.'
                + (String.isBlank(rc.Rationale__c) ? '' : ' ' + rc.Rationale__c);
            res.findings.add(line);
            if (rc.Result__c == 'Fail') {
                fails++;
                brokenRuleLines.add(line);
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

        // Plain-language summary (~6th-grade reading level, the "Leo" rule) that
        // still keeps the guardrails: name the rule, give the numbers, and leave
        // the final call to a person. Short words, short sentences.
        List<String> parts = new List<String>();
        if (res.stale) {
            parts.add('Note: this loan changed after the last check. '
                + 'Run the check again before sign-off.');
        }
        if (fails > 0) {
            parts.add('This loan did not pass ' + fails + ' rule'
                + (fails == 1 ? '' : 's') + ':');
            parts.addAll(brokenRuleLines);
        } else {
            parts.add('Good news: this loan passed all ' + passes
                + ' of the checks we could run.');
        }
        if (unver > 0 && fails == 0) {
            parts.add('We could not check ' + unver + ' item'
                + (unver == 1 ? '' : 's') + ' because some papers are missing.');
        }
        parts.add(FINAL_AUTHORITY);
        res.summary = String.join(parts, ' ');

        res.actionStatus = 'Success';
        return res;
    }

    /** Structured failure Response for an unexpected error mid-narration. */
    private static Response errorResponse(Exception e) {
        Response res = new Response();
        res.findings = new List<String>();
        res.summary = 'We hit an unexpected problem while checking this loan. ' + FINAL_AUTHORITY;
        res.hasViolations = false;
        res.actionStatus = 'Failed';
        res.actionError = (e == null) ? null : e.getMessage();
        return res;
    }

    /** Plain NAME for a rule code; unknown code falls back to the raw code. */
    private static String plainName(String code) {
        if (String.isBlank(code)) { return 'A rule'; }
        String key = code.toUpperCase();
        return PLAIN_NAME.containsKey(key) ? PLAIN_NAME.get(key) : code;
    }

    /**
     * Direction phrase derived from the code SUFFIX, so the numbers read
     * clearly to a non-expert (Leo):
     *   *_MAX / *_WARN / DEBT_MAX / DTI_*  → "the most allowed is"   (ceiling)
     *   *_MIN / *_PREF                     → "the lowest allowed is" (floor)
     *   anything else                      → "the limit is"
     */
    private static String directionPhrase(String code) {
        if (String.isBlank(code)) { return 'the limit is'; }
        String key = code.toUpperCase();
        if (key.endsWith('_MAX') || key.endsWith('_WARN')
            || key == 'DEBT_MAX' || key.startsWith('DTI_')) {
            return 'the most allowed is';
        }
        if (key.endsWith('_MIN') || key.endsWith('_PREF')) {
            return 'the lowest allowed is';
        }
        return 'the limit is';
    }

    /**
     * Format a stored numeric string for plain reading: drop trailing zeros so
     * "43.0000" reads as "43" and "44.80" as "44.8". Non-numeric falls back.
     */
    private static String prettyNum(String v) {
        if (String.isBlank(v)) { return 'n/a'; }
        try {
            return Decimal.valueOf(v).stripTrailingZeros().toPlainString();
        } catch (Exception e) {
            return v;
        }
    }

    /**
     * Build the pre-execution intent row (Status = 'Initiated'). Written BEFORE
     * the narration runs; never updated afterwards (append-only). No Output yet —
     * the output is not known at log-before-execute time and is instead carried on
     * the appended outcome Audit_Event__c.
     */
    private static Agent_Action_Log__c buildIntentLog(Id auditCaseId) {
        return new Agent_Action_Log__c(
            Audit_Case__c    = auditCaseId,
            Action_Name__c   = 'Summarize_Case',
            Subagent__c      = 'Auditor_Assistant',
            Status__c        = 'Initiated',
            Actor__c         = UserInfo.getName(),
            Input_Summary__c = 'what is wrong with this loan? (case ' + auditCaseId + ')',
            Timestamp__c     = Datetime.now()
        );
    }

    /**
     * Build one Audit_Event__c for the dual-write trail. Event_Type is
     * 'Agent_Action' — the canonical value in the schema and DATA-DICTIONARY §2.11
     * (SOLUTION-ARCHITECTURE §4.2 lists an out-of-date 'Agent_Action_Logged'; the
     * restricted picklist and data dictionary win). `phase` distinguishes the
     * before-execute (initiated) event from the after-execute (outcome) event;
     * Related_Record_Id__c back-links to the intent Agent_Action_Log__c row.
     */
    private static Audit_Event__c buildActionEvent(
        Id auditCaseId, Id logId, String phase, String status, String error, String summary) {
        Map<String, Object> payload = new Map<String, Object>{
            'action' => 'Summarize_Case',
            'phase'  => phase,
            'status' => status
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

    // ── DTOs ────────────────────────────────────────────────────────────

    public class Request {
        @InvocableVariable(required=true label='Audit Case Id')
        public Id auditCaseId;
    }

    public class Response {
        @InvocableVariable(label='Diagnosis summary') public String summary;
        @InvocableVariable(label='Has violations') public Boolean hasViolations;
        @InvocableVariable(label='Violation count') public Integer violationCount;
        @InvocableVariable(label='Pass count') public Integer passCount;
        @InvocableVariable(label='Unverifiable count') public Integer unverifiableCount;
        @InvocableVariable(label='Replay stale') public Boolean stale;
        @InvocableVariable(label='Findings') public List<String> findings;

        // Internal governance carriers (NOT @InvocableVariable — never surfaced to
        // Agentforce/Flow). Populated by narrate()/errorResponse() so the outcome
        // Audit_Event__c can record the action result without touching the DTO API.
        public String actionStatus;   // 'Initiated' | 'Success' | 'Partial' | 'Failed'
        public String actionError;    // populated only on the Failed path
    }
}
