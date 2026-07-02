/**
 * MissingEvidenceService — the governed "what's still missing to clear this case?"
 * action behind the Veridact Auditor Copilot (Agentforce) and an @AuraEnabled
 * fallback. This is the stip-clearance story: it lists every Evidence_Item__c that
 * is not yet Linked (Missing / Unverifiable), surfacing Required documents first,
 * plus the replay checks that came back Unverifiable because a supporting fact has
 * no evidence.
 *
 * READ-ONLY narrator (ADR-21): it reports what the kernel already recorded; it
 * never links evidence, never re-runs replay, never decides compliance. Ranking
 * is deterministic — required-missing evidence, then optional-missing evidence,
 * then unverifiable replay checks.
 *
 * Governance (ADR-26 log-before-execute dual-write): Phase 1 intent
 * Agent_Action_Log__c ('Initiated', Action_Name__c = 'List_Missing_Evidence') +
 * 'phase:initiated' Audit_Event__c; Phase 2 pure compute over hoisted reads;
 * Phase 3 appended 'phase:outcome' Audit_Event__c. Never updates the intent row.
 *
 * Bulk-safe: constant SOQL/DML regardless of request count.
 *
 * @group Agentforce
 */
public with sharing class MissingEvidenceService {

    private static final String ACTION = 'List_Missing_Evidence';
    private static final String CLOSER =
        'A human auditor decides whether these items are cleared.';

    // ── Invocable entry point ───────────────────────────────────────────
    @InvocableMethod(
        label='List Missing Evidence'
        description='Lists the documents still needed to clear an audit case (required first) plus any replay checks that could not be verified. Read only.'
        category='Veridact Audit'
    )
    public static List<Response> listMissing(List<Request> requests) {
        List<Id> caseIds = new List<Id>();
        for (Request req : requests) {
            caseIds.add(req?.auditCaseId);
        }
        return runListings(caseIds);
    }

    // ── LWC / anonymous-apex fallback ───────────────────────────────────
    @AuraEnabled(cacheable=false)
    public static Response listMissingForCase(Id auditCaseId) {
        return runListings(new List<Id>{ auditCaseId })[0];
    }

    // ── Core orchestrator (log-before-execute dual-write) ────────────────
    private static List<Response> runListings(List<Id> caseIds) {
        List<Response> responses = new List<Response>();
        if (caseIds == null || caseIds.isEmpty()) {
            return responses;
        }

        // ── Phase 1: LOG-BEFORE-EXECUTE ──────────────────────────────────
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

        // ── Phase 2: EXECUTE (hoisted reads, then pure ranking) ──────────
        Set<Id> caseIdSet = new Set<Id>(caseIds);
        Map<Id, Audit_Case__c> caseById = new Map<Id, Audit_Case__c>([
            SELECT Id, Name FROM Audit_Case__c
            WHERE Id IN :caseIdSet WITH USER_MODE
        ]);                                                          // SOQL 1

        Map<Id, List<Evidence_Item__c>> evByCase = new Map<Id, List<Evidence_Item__c>>();
        for (Evidence_Item__c ei : [
            SELECT Audit_Case__c, Document_Type__c, Status__c, Required__c
            FROM Evidence_Item__c
            WHERE Audit_Case__c IN :caseIdSet
            WITH USER_MODE
            ORDER BY Document_Type__c ASC
        ]) {                                                         // SOQL 2
            if (!evByCase.containsKey(ei.Audit_Case__c)) {
                evByCase.put(ei.Audit_Case__c, new List<Evidence_Item__c>());
            }
            evByCase.get(ei.Audit_Case__c).add(ei);
        }

        Map<Id, List<Replay_Check__c>> checksByCase =
            AuditSoql.latestChecksFor(caseIdSet);                    // SOQL 3 (+4)

        List<Audit_Event__c> outcomeEvents = new List<Audit_Event__c>();
        for (Integer i = 0; i < caseIds.size(); i++) {
            Id caseId = caseIds[i];
            Response r;
            try {
                r = assemble(
                    caseById.get(caseId),
                    evByCase.containsKey(caseId) ? evByCase.get(caseId) : new List<Evidence_Item__c>(),
                    checksByCase.containsKey(caseId) ? checksByCase.get(caseId) : new List<Replay_Check__c>()
                );
            } catch (Exception e) {
                r = errorResponse(e);
            }
            responses.add(r);
            outcomeEvents.add(buildActionEvent(
                caseId, intentLogs[i].Id, 'outcome', r.actionStatus, r.actionError, r.summary));
        }

        // ── Phase 3: APPEND OUTCOME ──────────────────────────────────────
        AuditEventService.logEvents(outcomeEvents);                 // DML 3
        return responses;
    }

    // ── Assembly (pure) ──────────────────────────────────────────────────

    private static Response assemble(
        Audit_Case__c ac, List<Evidence_Item__c> evidence, List<Replay_Check__c> checks) {
        Response res = new Response();
        res.items = new List<MissingItem>();

        if (ac == null) {
            res.summary = 'Audit case not found or not accessible. ' + CLOSER;
            res.actionStatus = 'Failed';
            return res;
        }

        // Split evidence: required-missing first, then optional-missing.
        List<MissingItem> requiredMissing = new List<MissingItem>();
        List<MissingItem> optionalMissing = new List<MissingItem>();
        for (Evidence_Item__c ei : evidence) {
            if (ei.Status__c == 'Linked') { continue; }
            MissingItem mi = new MissingItem();
            mi.kind         = 'Evidence';
            mi.documentType = RuleNarration.label(ei.Document_Type__c);
            mi.status       = ei.Status__c;                 // Missing | Unverifiable
            mi.required     = (ei.Required__c == true);
            if (mi.required) { requiredMissing.add(mi); } else { optionalMissing.add(mi); }
        }

        // Unverifiable replay checks: a fact with no evidence to stand on.
        List<MissingItem> unverifiableChecks = new List<MissingItem>();
        for (Replay_Check__c rc : checks) {
            if (rc.Result__c != 'Unverifiable') { continue; }
            MissingItem mi = new MissingItem();
            mi.kind     = 'Unverifiable check';
            mi.ruleName = RuleNarration.plainName(rc.Rule_Name__c);
            mi.ruleCode = rc.Rule_Name__c;
            mi.required = false;
            unverifiableChecks.add(mi);
        }

        // Ranked output: required evidence, optional evidence, unverifiable checks.
        res.items.addAll(requiredMissing);
        res.items.addAll(optionalMissing);
        res.items.addAll(unverifiableChecks);

        res.requiredMissingCount = requiredMissing.size();
        res.missingEvidenceCount = requiredMissing.size() + optionalMissing.size();
        res.unverifiableCount = unverifiableChecks.size();

        // Plain-language summary.
        List<String> parts = new List<String>();
        if (res.items.isEmpty()) {
            parts.add('Good news: every tracked document for case ' + ac.Name
                + ' is linked and every check could be verified. Nothing is outstanding.');
        } else {
            if (!requiredMissing.isEmpty()) {
                parts.add('Case ' + ac.Name + ' is still missing '
                    + requiredMissing.size() + ' required document'
                    + plural(requiredMissing.size()) + ': ' + joinDocs(requiredMissing) + '.');
            }
            if (!optionalMissing.isEmpty()) {
                parts.add((requiredMissing.isEmpty() ? 'Case ' + ac.Name + ' is ' : 'It is also ')
                    + 'missing ' + optionalMissing.size() + ' optional document'
                    + plural(optionalMissing.size()) + ': ' + joinDocs(optionalMissing) + '.');
            }
            if (!unverifiableChecks.isEmpty()) {
                List<String> names = new List<String>();
                for (MissingItem mi : unverifiableChecks) {
                    names.add(mi.ruleName + ' (' + mi.ruleCode + ')');
                }
                parts.add(unverifiableChecks.size() + ' check' + plural(unverifiableChecks.size())
                    + ' could not be verified because the papers are missing: '
                    + String.join(names, '; ') + '.');
            }
        }
        parts.add(CLOSER);
        res.summary = String.join(parts, ' ');
        res.actionStatus = 'Success';
        return res;
    }

    private static String joinDocs(List<MissingItem> items) {
        List<String> docs = new List<String>();
        for (MissingItem mi : items) {
            docs.add(mi.documentType + (mi.status == 'Unverifiable' ? ' (unverifiable)' : ''));
        }
        return String.join(docs, ', ');
    }

    private static String plural(Integer n) { return (n == 1) ? '' : 's'; }

    private static Response errorResponse(Exception e) {
        Response res = new Response();
        res.items = new List<MissingItem>();
        res.summary = 'We hit an unexpected problem while listing missing evidence. ' + CLOSER;
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
            Input_Summary__c = 'list missing evidence (case ' + auditCaseId + ')',
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

    // ── DTOs ─────────────────────────────────────────────────────────────

    public class Request {
        @InvocableVariable(required=true label='Audit Case Id')
        public Id auditCaseId;
    }

    public class Response {
        @InvocableVariable(label='Missing-evidence summary') public String summary;
        @InvocableVariable(label='Missing evidence count') public Integer missingEvidenceCount;
        @InvocableVariable(label='Required missing count') public Integer requiredMissingCount;
        @InvocableVariable(label='Unverifiable check count') public Integer unverifiableCount;
        @InvocableVariable(label='Outstanding items (ranked)') public List<MissingItem> items;

        public String actionStatus;
        public String actionError;
    }

    public class MissingItem {
        @InvocableVariable(label='Kind') public String kind;           // Evidence | Unverifiable check
        @InvocableVariable(label='Document type') public String documentType;
        @InvocableVariable(label='Status') public String status;       // Missing | Unverifiable
        @InvocableVariable(label='Required') public Boolean required;
        @InvocableVariable(label='Rule name') public String ruleName;
        @InvocableVariable(label='Rule code') public String ruleCode;
    }
}
