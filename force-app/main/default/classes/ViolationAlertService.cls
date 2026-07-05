/**
 * ViolationAlertService — the governed "alert the assigned auditor about the rule
 * violations on this case" action behind the Veridact Auditor Copilot (Agentforce)
 * and an @AuraEnabled fallback.
 *
 * THE ONE ACTION WITH A SIDE EFFECT (ADR-16): the auditor copilot MAY create
 * *controlled internal tasks* — it MUST NOT send external comms autonomously. So
 * this action, when a case's LATEST replay carries Fail checks, creates a single
 * Salesforce Task assigned to the case's assigned auditor (Audit_Case__c.Auditor__c,
 * measured on-org; falls back to the running user if the case has no auditor),
 * WhatId-linked back to the case, whose Description lists the failing rules in plain
 * words (RuleNarration). It is NOT an email and NOT an external message — it is an
 * internal follow-up task. If the latest replay has no Fails, no Task is created and
 * the action returns a graceful 'no violations to alert' Partial.
 *
 * READ-then-act, never decides (ADR-21): the deterministic replay kernel already
 * computed the truth into Replay_Check__c; this service only READS the latest batch
 * and, if it failed, raises a follow-up task for a human. It never re-runs replay,
 * never links evidence, never closes a case, never decides compliance.
 *
 * Idempotency guard (deterministic, testable): if an OPEN Task with the same Subject
 * already exists against the case, no duplicate is created — the action reports
 * 'already alerted' as a Partial. Re-invoking is safe.
 *
 * Governance (ADR-26 log-before-execute dual-write): Phase 1 intent
 * Agent_Action_Log__c ('Initiated', Action_Name__c = 'Send_Violation_Alert') +
 * 'phase:initiated' Audit_Event__c; Phase 2 hoisted reads + the controlled Task
 * insert; Phase 3 appended 'phase:outcome' Audit_Event__c. Never updates the intent
 * row. A ghost case fails closed at the Phase-1 insert with zero orphan trail.
 *
 * Bulk-safe: constant SOQL/DML regardless of request count; at most one Task per case.
 *
 * @group Agentforce
 */
public with sharing class ViolationAlertService {

    private static final String ACTION = 'Send_Violation_Alert';
    private static final String CLOSER =
        'A human auditor must review and act; the copilot only raised this follow-up.';

    // ── Invocable entry point (Agentforce GenAiFunction / Flow) ─────────
    @InvocableMethod(
        label='Send Violation Alert'
        description='Creates an internal follow-up Task for the case\'s assigned auditor about the rule violations found on an audit case. It never emails or contacts anyone externally. If the case has no violations, no task is created. Read-then-act; a human decides.'
        category='Veridact Audit'
    )
    public static List<Response> sendAlert(List<Request> requests) {
        List<Id> caseIds = new List<Id>();
        for (Request req : requests) {
            caseIds.add(req?.auditCaseId);
        }
        return runAlerts(caseIds);
    }

    // ── LWC / anonymous-apex fallback ───────────────────────────────────
    @AuraEnabled(cacheable=false)
    public static Response sendAlertForCase(Id auditCaseId) {
        return runAlerts(new List<Id>{ auditCaseId })[0];
    }

    // ── Core orchestrator (log-before-execute dual-write) ────────────────
    private static List<Response> runAlerts(List<Id> caseIds) {
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

        // ── Phase 2: EXECUTE (hoisted reads, then per-case decision) ─────
        Set<Id> caseIdSet = new Set<Id>(caseIds);

        Map<Id, Audit_Case__c> caseById = new Map<Id, Audit_Case__c>([
            SELECT Id, Name, Auditor__c
            FROM Audit_Case__c
            WHERE Id IN :caseIdSet WITH USER_MODE
        ]);                                                          // SOQL 1

        // Latest replay batch only (append-only trail; R-11 supersede-by-query).
        Map<Id, List<Replay_Check__c>> checksByCase =
            AuditSoql.latestChecksFor(caseIdSet);                    // SOQL 2 + 3

        // Idempotency read: open Tasks already raised against these cases, keyed by
        // case -> set of open Subjects. One query for any request count.
        Map<Id, Set<String>> openSubjectsByCase = new Map<Id, Set<String>>();
        for (Task t : [
            SELECT Id, WhatId, Subject
            FROM Task
            WHERE WhatId IN :caseIdSet AND IsClosed = false
            WITH USER_MODE
        ]) {                                                         // SOQL 4
            if (!openSubjectsByCase.containsKey(t.WhatId)) {
                openSubjectsByCase.put(t.WhatId, new Set<String>());
            }
            openSubjectsByCase.get(t.WhatId).add(t.Subject);
        }

        List<Task> tasksToInsert = new List<Task>();
        List<Audit_Event__c> outcomeEvents = new List<Audit_Event__c>();
        for (Integer i = 0; i < caseIds.size(); i++) {
            Id caseId = caseIds[i];
            Response r;
            try {
                r = decide(
                    caseById.get(caseId),
                    checksByCase.containsKey(caseId) ? checksByCase.get(caseId) : new List<Replay_Check__c>(),
                    openSubjectsByCase.containsKey(caseId) ? openSubjectsByCase.get(caseId) : new Set<String>(),
                    tasksToInsert
                );
            } catch (Exception e) {
                r = errorResponse(e);
            }
            responses.add(r);
            outcomeEvents.add(buildActionEvent(
                caseId, intentLogs[i].Id, 'outcome', r.actionStatus, r.actionError, r.summary));
        }

        // The one controlled side effect — batched, outside the loop.
        if (!tasksToInsert.isEmpty()) {
            Database.insert(tasksToInsert, AccessLevel.USER_MODE);   // DML 3 (only when a Task is warranted)
        }

        // ── Phase 3: APPEND OUTCOME ──────────────────────────────────────
        AuditEventService.logEvents(outcomeEvents);                 // DML (final)
        return responses;
    }

    // ── Per-case decision (stages at most one Task; no SOQL/DML) ─────────

    private static Response decide(
        Audit_Case__c ac,
        List<Replay_Check__c> checks,
        Set<String> openSubjects,
        List<Task> tasksToInsert) {

        Response res = new Response();
        res.alertCreated = false;
        res.alreadyAlerted = false;
        res.violationCount = 0;

        if (ac == null) {
            res.summary = 'Audit case not found or not accessible. ' + CLOSER;
            res.actionStatus = 'Failed';
            return res;
        }

        // Collect the failing rules from the LATEST replay batch, in plain words.
        List<String> failLines = new List<String>();
        for (Replay_Check__c rc : checks) {
            if (rc.Result__c != 'Fail') { continue; }
            failLines.add(RuleNarration.plainName(rc.Rule_Name__c) + ' (' + rc.Rule_Name__c + ')');
        }
        res.violationCount = failLines.size();

        // No violations → no Task, graceful Partial.
        if (failLines.isEmpty()) {
            res.summary = 'No rule violations were found on the latest replay of case '
                + ac.Name + ', so there is nothing to alert anyone about. ' + CLOSER;
            res.actionStatus = 'Partial';
            return res;
        }

        String subject = 'Violation alert: ' + ac.Name;

        // Idempotency: an open Task with this Subject already exists → no duplicate.
        if (openSubjects != null && openSubjects.contains(subject)) {
            res.alreadyAlerted = true;
            res.summary = 'Case ' + ac.Name + ' already has an open violation-alert task, '
                + 'so no duplicate was created. It still has ' + failLines.size()
                + ' rule violation' + plural(failLines.size()) + '. ' + CLOSER;
            res.actionStatus = 'Partial';
            return res;
        }

        // Assignee: the case's assigned auditor, else the running user (measured
        // field: Audit_Case__c.Auditor__c is the only auditor-role User lookup).
        Id ownerId = (ac.Auditor__c != null) ? ac.Auditor__c : UserInfo.getUserId();

        String description = 'The automated audit replay found ' + failLines.size()
            + ' rule violation' + plural(failLines.size()) + ' on case ' + ac.Name + ':\n'
            + '- ' + String.join(failLines, '\n- ') + '\n\n'
            + 'This is an internal follow-up task created by the Veridact auditor copilot. '
            + 'No borrower or external party was contacted. ' + CLOSER;

        tasksToInsert.add(new Task(
            Subject     = subject,
            Description = description,
            WhatId      = ac.Id,
            OwnerId     = ownerId,
            Status      = 'Open',
            Priority    = 'High',
            ActivityDate = Date.today()
        ));

        res.alertCreated = true;
        res.summary = 'Raised an internal follow-up task for the assigned auditor on case '
            + ac.Name + ' about ' + failLines.size() + ' rule violation'
            + plural(failLines.size()) + ': ' + String.join(failLines, ', ') + '. ' + CLOSER;
        res.actionStatus = 'Success';
        return res;
    }

    private static String plural(Integer n) { return (n == 1) ? '' : 's'; }

    private static Response errorResponse(Exception e) {
        Response res = new Response();
        res.summary = 'We hit an unexpected problem while raising the violation alert. ' + CLOSER;
        res.alertCreated = false;
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
            Input_Summary__c = 'alert the assigned auditor about violations (case ' + auditCaseId + ')',
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
        @InvocableVariable(required=true label='Audit Case Id' description='The 15- or 18-character Salesforce record Id of the Audit_Case__c the auditor wants to alert about (Audit Case Ids start with a05). Extract it directly from the user request, e.g. "alert the assigned auditor about the violations on audit case a05gL00000JtZ74QAF".')
        public Id auditCaseId;
    }

    public class Response {
        @InvocableVariable(label='Alert summary') public String summary;
        @InvocableVariable(label='Alert task created') public Boolean alertCreated;
        @InvocableVariable(label='Already alerted') public Boolean alreadyAlerted;
        @InvocableVariable(label='Violation count') public Integer violationCount;

        // Internal governance carriers (NOT @InvocableVariable).
        public String actionStatus;   // 'Success' | 'Partial' | 'Failed'
        public String actionError;
    }
}
