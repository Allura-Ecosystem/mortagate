/**
 * EvidenceRequestService — the governed "draft a request for the missing papers"
 * action behind the Veridact Auditor Copilot (Agentforce) and an @AuraEnabled
 * fallback.
 *
 * Given an audit case, it DRAFTS a professional evidence-request message the
 * auditor can send to the borrower or branch, listing every required document
 * that is not yet linked (required-missing first, optional-missing second). It
 * reuses the missing-evidence read idiom from MissingEvidenceService: list every
 * Evidence_Item__c that is not yet Linked, required documents first.
 *
 * CRITICAL BOUNDARY: this action DRAFTS TEXT ONLY. It never SENDS anything, never
 * creates a record beyond the ADR-26 governance trail, and never updates
 * Evidence_Item__c. The human auditor reviews the draft and sends it.
 *
 * READ-ONLY over domain data (it only writes the governance dual-write). Guardrails
 * (ADR-16/21): professional tone, never says "denied" or any decision language,
 * always defers the final determination and the send to the human auditor, and the
 * draft carries a polite deadline placeholder ([DATE]) for the auditor to fill in.
 *
 * Governance (ADR-26 log-before-execute dual-write): Phase 1 intent
 * Agent_Action_Log__c ('Initiated', Action_Name__c = 'Draft_Evidence_Request') +
 * 'phase:initiated' Audit_Event__c; Phase 2 pure compute over hoisted reads;
 * Phase 3 appended 'phase:outcome' Audit_Event__c with the log Id back-linked via
 * Related_Record_Id__c. Never updates the intent row. Fail-closed: a ghost case
 * cannot be logged-before-execute, so the Phase-1 insert rejects and no orphan
 * trail is left behind.
 *
 * Bulk-safe: constant SOQL/DML regardless of request count.
 *
 * @group Agentforce
 */
public with sharing class EvidenceRequestService {

    private static final String ACTION = 'Draft_Evidence_Request';
    private static final String DATE_PLACEHOLDER = '[DATE]';
    private static final String FINAL_AUTHORITY =
        'This is a request for documentation only and is not a decision on the loan. ' +
        'The human auditor reviews this draft and decides whether to send it.';

    // ── Invocable entry point ───────────────────────────────────────────
    @InvocableMethod(
        label='Draft Evidence Request'
        description='Drafts a professional message asking the borrower or branch for the documents still needed to complete an audit case (required documents first). Draft only — it never sends anything and never creates or changes evidence records. A human auditor reviews and sends it.'
        category='Veridact Audit'
    )
    public static List<Response> draft(List<Request> requests) {
        List<Id> caseIds = new List<Id>();
        for (Request req : (requests == null ? new List<Request>() : requests)) {
            caseIds.add(req?.auditCaseId);
        }
        return runRequests(caseIds);
    }

    // ── LWC / anonymous-apex fallback ───────────────────────────────────
    @AuraEnabled(cacheable=false)
    public static Response draftForCase(Id auditCaseId) {
        return runRequests(new List<Id>{ auditCaseId })[0];
    }

    // ── Core orchestrator (log-before-execute dual-write) ────────────────
    private static List<Response> runRequests(List<Id> caseIds) {
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

        // ── Phase 2: EXECUTE (hoisted reads, then pure drafting) ─────────
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

        List<Audit_Event__c> outcomeEvents = new List<Audit_Event__c>();
        for (Integer i = 0; i < caseIds.size(); i++) {
            Id caseId = caseIds[i];
            Response r;
            try {
                r = assemble(
                    caseById.get(caseId),
                    evByCase.containsKey(caseId) ? evByCase.get(caseId) : new List<Evidence_Item__c>()
                );
            } catch (Exception e) {
                r = errorResponse(e);
            }
            responses.add(r);
            outcomeEvents.add(buildActionEvent(
                caseId, intentLogs[i].Id, 'outcome', r.actionStatus, r.actionError, r.draftText));
        }

        // ── Phase 3: APPEND OUTCOME ──────────────────────────────────────
        AuditEventService.logEvents(outcomeEvents);                 // DML 3
        return responses;
    }

    // ── Assembly (pure) ──────────────────────────────────────────────────

    private static Response assemble(Audit_Case__c ac, List<Evidence_Item__c> evidence) {
        Response res = new Response();

        if (ac == null) {
            res.draftText = 'Audit case not found or not accessible, so there is nothing '
                + 'to request yet. ' + FINAL_AUTHORITY;
            res.actionStatus = 'Failed';
            return res;
        }

        res.caseName = ac.Name;

        // Split missing evidence: required-missing first, then optional-missing.
        List<String> requiredMissing = new List<String>();
        List<String> optionalMissing = new List<String>();
        for (Evidence_Item__c ei : evidence) {
            if (ei.Status__c == 'Linked') { continue; }
            String docLabel = RuleNarration.label(ei.Document_Type__c);
            if (ei.Required__c == true) { requiredMissing.add(docLabel); }
            else { optionalMissing.add(docLabel); }
        }

        res.requiredMissingCount = requiredMissing.size();
        res.missingCount = requiredMissing.size() + optionalMissing.size();

        // Nothing outstanding → graceful, no draft to chase.
        if (res.missingCount == 0) {
            res.draftText = 'Every tracked document for case ' + ac.Name
                + ' is already on file, so there is nothing to request right now. '
                + FINAL_AUTHORITY;
            res.actionStatus = 'Partial';
            return res;
        }

        // Build the professional request draft.
        List<String> lines = new List<String>();
        lines.add('DRAFT EVIDENCE REQUEST — AI-drafted, auditor review required. Not sent.');
        lines.add('');
        lines.add('Subject: Documents needed to complete audit case ' + ac.Name);
        lines.add('');
        lines.add('Dear Borrower / Branch Team,');
        lines.add('');
        lines.add('To complete our review of audit case ' + ac.Name + ', we still need '
            + 'the following document' + plural(res.missingCount) + '.');

        if (!requiredMissing.isEmpty()) {
            lines.add('');
            lines.add('Required document' + plural(requiredMissing.size()) + ':');
            for (String doc : requiredMissing) {
                lines.add('  - ' + doc);
            }
        }
        if (!optionalMissing.isEmpty()) {
            lines.add('');
            lines.add('Additional document' + plural(optionalMissing.size())
                + ' that would help us complete the file:');
            for (String doc : optionalMissing) {
                lines.add('  - ' + doc);
            }
        }

        lines.add('');
        lines.add('Please provide ' + (res.missingCount == 1 ? 'this document' : 'these documents')
            + ' by ' + DATE_PLACEHOLDER + '. If you have any questions about what is '
            + 'needed, your auditor can help.');
        lines.add('');
        lines.add('Thank you for your prompt attention.');
        lines.add('');
        lines.add(FINAL_AUTHORITY);

        res.draftText = String.join(lines, '\n');
        res.actionStatus = 'Success';
        return res;
    }

    private static String plural(Integer n) { return (n == 1) ? '' : 's'; }

    private static Response errorResponse(Exception e) {
        Response res = new Response();
        res.draftText = 'We hit an unexpected problem while drafting this evidence request. '
            + FINAL_AUTHORITY;
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
            Input_Summary__c = 'draft evidence request (case ' + auditCaseId + ')',
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
        @InvocableVariable(required=true label='Audit Case Id' description='The 15- or 18-character Salesforce record Id of the Audit_Case__c the auditor wants an evidence-request drafted for (Audit Case Ids start with a05). Extract it directly from the user request, e.g. "draft an evidence request for audit case a05gL00000JtZ74QAF".')
        public Id auditCaseId;
    }

    public class Response {
        @InvocableVariable(label='Draft evidence-request text') public String draftText;
        @InvocableVariable(label='Case name') public String caseName;
        @InvocableVariable(label='Missing document count') public Integer missingCount;
        @InvocableVariable(label='Required missing count') public Integer requiredMissingCount;

        public String actionStatus;
        public String actionError;
    }
}
