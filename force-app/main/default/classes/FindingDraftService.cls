/**
 * FindingDraftService — the governed "draft the finding text for me" action
 * behind the Veridact Auditor Copilot (Agentforce) and an @AuraEnabled fallback.
 *
 * Given an audit case plus a specific replay check (by Id, or resolved from a
 * rule code against the latest batch), it assembles a DRAFT finding narrative
 * from the stored Replay_Check__c — rule label, expected vs. actual, evidence
 * linkage — suitable for pasting into Finding__c.Description__c (FR-27, the
 * AI-drafted-then-accepted flow).
 *
 * CRITICAL BOUNDARY: this action DRAFTS TEXT ONLY. It does NOT insert or update a
 * Finding__c — the human accepts/edits the draft through the existing findingDetail
 * UI, which stamps AI_Drafted__c / AI_Draft_Accepted__c. No LLM here either: the
 * text is deterministic assembly; the Agentforce layer may rephrase on top.
 *
 * READ-ONLY over domain data (it only writes the governance dual-write). Guardrails
 * (ADR-16/21): never says "denied", always defers the final determination to the
 * human auditor.
 *
 * Governance (ADR-26 log-before-execute dual-write): Phase 1 intent
 * Agent_Action_Log__c ('Initiated', Action_Name__c = 'Draft_Finding_Text') +
 * 'phase:initiated' Audit_Event__c; Phase 2 pure compute over hoisted reads;
 * Phase 3 appended 'phase:outcome' Audit_Event__c. Never updates the intent row.
 *
 * Bulk-safe: constant SOQL/DML regardless of request count.
 *
 * @group Agentforce
 */
public with sharing class FindingDraftService {

    private static final String ACTION = 'Draft_Finding_Text';
    private static final String FINAL_AUTHORITY =
        'The human auditor accepts or edits this text and makes the final determination.';

    // ── Invocable entry point ───────────────────────────────────────────
    @InvocableMethod(
        label='Draft Finding Text'
        description='Drafts finding narrative text from a failing replay check (rule, expected vs actual, evidence). Draft only — it does not create a finding record. A human auditor accepts or edits it.'
        category='Veridact Audit'
    )
    public static List<Response> draft(List<Request> requests) {
        return runDrafts(requests == null ? new List<Request>() : requests);
    }

    // ── LWC / anonymous-apex fallback ───────────────────────────────────
    @AuraEnabled(cacheable=false)
    public static Response draftFromCheck(Id auditCaseId, Id replayCheckId) {
        Request req = new Request();
        req.auditCaseId = auditCaseId;
        req.replayCheckId = replayCheckId;
        return runDrafts(new List<Request>{ req })[0];
    }

    @AuraEnabled(cacheable=false)
    public static Response draftFromRuleCode(Id auditCaseId, String ruleCode) {
        Request req = new Request();
        req.auditCaseId = auditCaseId;
        req.ruleCode = ruleCode;
        return runDrafts(new List<Request>{ req })[0];
    }

    // ── Core orchestrator (log-before-execute dual-write) ────────────────
    private static List<Response> runDrafts(List<Request> requests) {
        List<Response> responses = new List<Response>();
        if (requests.isEmpty()) {
            return responses;
        }

        // ── Phase 1: LOG-BEFORE-EXECUTE ──────────────────────────────────
        List<Agent_Action_Log__c> intentLogs = new List<Agent_Action_Log__c>();
        for (Request req : requests) {
            intentLogs.add(buildIntentLog(req?.auditCaseId));
        }
        Database.insert(intentLogs, AccessLevel.USER_MODE);          // DML 1

        List<Audit_Event__c> intentEvents = new List<Audit_Event__c>();
        for (Integer i = 0; i < requests.size(); i++) {
            intentEvents.add(buildActionEvent(
                requests[i]?.auditCaseId, intentLogs[i].Id, 'initiated', 'Initiated', null, null));
        }
        AuditEventService.logEvents(intentEvents);                   // DML 2

        // ── Phase 2: EXECUTE (hoisted reads, then pure assembly) ─────────
        Set<Id> checkIds = new Set<Id>();
        Set<Id> ruleCodeCaseIds = new Set<Id>();
        for (Request req : requests) {
            if (req?.replayCheckId != null) {
                checkIds.add(req.replayCheckId);
            } else if (req?.auditCaseId != null && String.isNotBlank(req.ruleCode)) {
                ruleCodeCaseIds.add(req.auditCaseId);
            }
        }

        // Checks addressed directly by Id.
        Map<Id, Replay_Check__c> checkById = new Map<Id, Replay_Check__c>();
        if (!checkIds.isEmpty()) {
            for (Replay_Check__c rc : queryChecks('Id IN :ids',
                    new Map<String, Object>{ 'ids' => checkIds })) {   // SOQL 1
                checkById.put(rc.Id, rc);
            }
        }

        // Checks resolved by rule code against the LATEST batch (newest row per
        // (case, code) wins — a re-run re-inserts every rule, so the newest
        // timestamp is the current batch's version).
        Map<Id, Map<String, Replay_Check__c>> codeByCase = new Map<Id, Map<String, Replay_Check__c>>();
        if (!ruleCodeCaseIds.isEmpty()) {
            for (Replay_Check__c rc : queryChecks(
                    'Audit_Case__c IN :ids ORDER BY Replay_Timestamp__c DESC',
                    new Map<String, Object>{ 'ids' => ruleCodeCaseIds })) {   // SOQL 2
                if (!codeByCase.containsKey(rc.Audit_Case__c)) {
                    codeByCase.put(rc.Audit_Case__c, new Map<String, Replay_Check__c>());
                }
                String key = (rc.Rule_Name__c == null) ? null : rc.Rule_Name__c.toUpperCase();
                // DESC order: keep the first (newest) row seen for each code.
                if (key != null && !codeByCase.get(rc.Audit_Case__c).containsKey(key)) {
                    codeByCase.get(rc.Audit_Case__c).put(key, rc);
                }
            }
        }

        List<Audit_Event__c> outcomeEvents = new List<Audit_Event__c>();
        for (Integer i = 0; i < requests.size(); i++) {
            Request req = requests[i];
            Response r;
            try {
                r = assemble(req, resolveCheck(req, checkById, codeByCase));
            } catch (Exception e) {
                r = errorResponse(e);
            }
            responses.add(r);
            outcomeEvents.add(buildActionEvent(
                req?.auditCaseId, intentLogs[i].Id, 'outcome', r.actionStatus, r.actionError, r.draftText));
        }

        // ── Phase 3: APPEND OUTCOME ──────────────────────────────────────
        AuditEventService.logEvents(outcomeEvents);                 // DML 3
        return responses;
    }

    private static Replay_Check__c resolveCheck(
        Request req,
        Map<Id, Replay_Check__c> checkById,
        Map<Id, Map<String, Replay_Check__c>> codeByCase) {
        if (req == null) { return null; }
        if (req.replayCheckId != null) {
            Replay_Check__c rc = checkById.get(req.replayCheckId);
            // Defend the case↔check relationship if a caller passed both.
            if (rc != null && req.auditCaseId != null && rc.Audit_Case__c != req.auditCaseId) {
                return null;
            }
            return rc;
        }
        if (req.auditCaseId != null && String.isNotBlank(req.ruleCode)
            && codeByCase.containsKey(req.auditCaseId)) {
            return codeByCase.get(req.auditCaseId).get(req.ruleCode.toUpperCase());
        }
        return null;
    }

    private static List<Replay_Check__c> queryChecks(String whereClause, Map<String, Object> binds) {
        return (List<Replay_Check__c>) AuditSoql.query(
            'SELECT Id, Audit_Case__c, Rule_Name__c, Result__c, Expected_Value__c, ' +
            'Actual_Value__c, Rationale__c, Replay_Timestamp__c, ' +
            'Evidence_Item__r.Document_Type__c, Evidence_Item__r.Status__c ' +
            'FROM Replay_Check__c WHERE ' + whereClause,
            binds);
    }

    // ── Assembly (pure) ──────────────────────────────────────────────────

    private static Response assemble(Request req, Replay_Check__c rc) {
        Response res = new Response();

        if (req == null || req.auditCaseId == null) {
            res.draftText = 'An audit case is required to draft a finding. ' + FINAL_AUTHORITY;
            res.found = false;
            res.actionStatus = 'Failed';
            return res;
        }
        if (rc == null) {
            res.draftText = 'No matching replay check was found for this case, so there '
                + 'is nothing to draft yet. Run the check first, then pick the rule to '
                + 'document. ' + FINAL_AUTHORITY;
            res.found = false;
            res.actionStatus = 'Partial';
            return res;
        }

        res.found = true;
        res.ruleCode = rc.Rule_Name__c;
        res.ruleName = RuleNarration.plainName(rc.Rule_Name__c);
        res.ruleResult = rc.Result__c;

        List<String> lines = new List<String>();
        lines.add('DRAFT FINDING — AI-drafted, auditor review required.');
        lines.add('Rule: ' + res.ruleName + ' (' + rc.Rule_Name__c + ') — result: '
            + resultPhrase(rc.Result__c) + '.');
        lines.add('What the rule expects: ' + RuleNarration.directionPhrase(rc.Rule_Name__c)
            + ' ' + RuleNarration.prettyNum(rc.Expected_Value__c)
            + '. What this loan shows: ' + RuleNarration.prettyNum(rc.Actual_Value__c) + '.');
        if (String.isNotBlank(rc.Rationale__c)) {
            lines.add('Why it matters: ' + rc.Rationale__c);
        }
        lines.add(evidenceLine(rc));
        lines.add(FINAL_AUTHORITY);

        res.draftText = String.join(lines, '\n');
        res.actionStatus = 'Success';
        return res;
    }

    /** Result → plain phrase, never an alarm/verdict word ("denied"). */
    private static String resultPhrase(String result) {
        if (result == 'Fail') { return 'did not pass'; }
        if (result == 'Pass') { return 'passed'; }
        if (result == 'Unverifiable') { return 'could not be verified'; }
        return String.isBlank(result) ? 'not recorded' : result;
    }

    private static String evidenceLine(Replay_Check__c rc) {
        if (rc.Evidence_Item__r == null) {
            return 'Supporting evidence: no document is linked to this check.';
        }
        String docType = RuleNarration.label(rc.Evidence_Item__r.Document_Type__c);
        String status = rc.Evidence_Item__r.Status__c;
        return 'Supporting evidence: ' + (String.isBlank(docType) ? 'a document' : docType)
            + ' is ' + (String.isBlank(status) ? 'on file' : status.toLowerCase()) + '.';
    }

    private static Response errorResponse(Exception e) {
        Response res = new Response();
        res.draftText = 'We hit an unexpected problem while drafting this finding. ' + FINAL_AUTHORITY;
        res.found = false;
        res.actionStatus = 'Failed';
        res.actionError = (e == null) ? null : e.getMessage();
        return res;
    }

    // ── Governance builders ──────────────────────────────────────────────

    private static Agent_Action_Log__c buildIntentLog(Id auditCaseId) {
        return new Agent_Action_Log__c(
            Audit_Case__c    = auditCaseId,
            Action_Name__c   = ACTION,
            Subagent__c      = 'Auditor_Assistant',
            Status__c        = 'Initiated',
            Actor__c         = UserInfo.getName(),
            Input_Summary__c = 'draft finding text (case ' + auditCaseId + ')',
            Timestamp__c     = Datetime.now()
        );
    }

    private static Audit_Event__c buildActionEvent(
        Id auditCaseId, Id logId, String phase, String status, String error, String draftText) {
        Map<String, Object> payload = new Map<String, Object>{
            'action' => ACTION, 'phase' => phase, 'status' => status
        };
        if (String.isNotBlank(error))     { payload.put('error', error); }
        if (String.isNotBlank(draftText)) { payload.put('summary', draftText); }
        return new Audit_Event__c(
            Audit_Case__c        = auditCaseId,
            Event_Type__c        = 'Agent_Action',
            Actor__c             = UserInfo.getName(),
            Timestamp__c         = Datetime.now(),
            Payload__c           = JSON.serialize(payload),
            Related_Record_Id__c = (logId == null) ? null : String.valueOf(logId)
        );
    }

    // ── DTOs ─────────────────────────────────────────────────────────────

    public class Request {
        @InvocableVariable(required=true label='Audit Case Id')
        public Id auditCaseId;
        @InvocableVariable(label='Replay Check Id (optional)')
        public Id replayCheckId;
        @InvocableVariable(label='Rule code (optional, resolved against latest batch)')
        public String ruleCode;
    }

    public class Response {
        @InvocableVariable(label='Draft finding text') public String draftText;
        @InvocableVariable(label='Check found') public Boolean found;
        @InvocableVariable(label='Rule name') public String ruleName;
        @InvocableVariable(label='Rule code') public String ruleCode;
        @InvocableVariable(label='Rule result') public String ruleResult;

        public String actionStatus;
        public String actionError;
    }
}
