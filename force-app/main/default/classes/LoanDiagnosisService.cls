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

    private static final String FINAL_AUTHORITY =
        'A human auditor must make the final determination.';

    // ── Invocable entry point (Agentforce GenAiFunction / Flow) ─────────

    @InvocableMethod(
        label='Diagnose Loan Audit'
        description='Explains what is wrong with an already-approved loan, read only, from stored replay checks.'
        category='Veridact Audit'
    )
    public static List<Response> diagnose(List<Request> requests) {
        List<Response> responses = new List<Response>();
        for (Request req : requests) {
            responses.add(diagnoseOne(req.auditCaseId));
        }
        return responses;
    }

    // ── LWC / anonymous-apex fallback (no Agentforce required) ──────────

    @AuraEnabled(cacheable=false)
    public static Response diagnoseCase(Id auditCaseId) {
        return diagnoseOne(auditCaseId);
    }

    // ── Core ────────────────────────────────────────────────────────────

    private static Response diagnoseOne(Id auditCaseId) {
        Response res = new Response();
        res.findings = new List<String>();

        // Case + loan freshness context (read-only).
        List<Audit_Case__c> cases = [
            SELECT Id, Borrower_Name_Snapshot__c, Loan__r.LastModifiedDate
            FROM Audit_Case__c
            WHERE Id = :auditCaseId
            WITH USER_MODE
            LIMIT 1
        ];
        if (cases.isEmpty()) {
            res.summary = 'Audit case not found or not accessible.';
            res.hasViolations = false;
            logAction(auditCaseId, res.summary, 'Failed');
            return res;
        }
        Audit_Case__c ac = cases[0];

        List<Replay_Check__c> checks = [
            SELECT Rule_Name__c, Result__c, Expected_Value__c, Actual_Value__c,
                   Rationale__c, Replay_Timestamp__c, Sort_Order__c
            FROM Replay_Check__c
            WHERE Audit_Case__c = :auditCaseId
            WITH USER_MODE
            ORDER BY Sort_Order__c ASC
        ];

        if (checks.isEmpty()) {
            res.summary = 'Replay has not been run for this case yet, so there are no '
                + 'checks to diagnose. Run the audit replay first. ' + FINAL_AUTHORITY;
            res.hasViolations = false;
            res.violationCount = 0;
            res.passCount = 0;
            res.unverifiableCount = 0;
            res.stale = false;
            logAction(auditCaseId, res.summary, 'Partial');
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
        List<String> violationLines = new List<String>();
        for (Replay_Check__c rc : checks) {
            String line = rc.Rule_Name__c + ': ' + rc.Result__c
                + ' — expected ' + safe(rc.Expected_Value__c)
                + ', actual ' + safe(rc.Actual_Value__c)
                + (String.isBlank(rc.Rationale__c) ? '' : ' (' + rc.Rationale__c + ')');
            res.findings.add(line);
            if (rc.Result__c == 'Fail') {
                fails++;
                violationLines.add(line);
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

        // Build the guardrailed natural-language summary.
        List<String> parts = new List<String>();
        if (res.stale) {
            parts.add('Replay results may be stale — the loan was modified after the '
                + 'last replay; re-run replay before final sign-off.');
        }
        if (fails > 0) {
            parts.add('This loan has ' + fails + ' rule violation'
                + (fails == 1 ? '' : 's') + ':');
            parts.addAll(violationLines);
        } else {
            parts.add('No rule violations were found in the stored replay checks ('
                + passes + ' passed'
                + (unver > 0 ? ', ' + unver + ' unverifiable' : '') + ').');
        }
        if (unver > 0 && fails == 0) {
            parts.add(unver + ' check'
                + (unver == 1 ? ' is' : 's are') + ' unverifiable due to missing evidence.');
        }
        parts.add(FINAL_AUTHORITY);
        res.summary = String.join(parts, ' ');

        logAction(auditCaseId, res.summary, 'Success');
        return res;
    }

    private static String safe(String v) {
        return String.isBlank(v) ? 'n/a' : v;
    }

    private static void logAction(Id auditCaseId, String output, String status) {
        Agent_Action_Log__c log = new Agent_Action_Log__c(
            Audit_Case__c   = auditCaseId,
            Action_Name__c  = 'Summarize_Case',
            Subagent__c     = 'Auditor_Assistant',
            Status__c       = status,
            Actor__c        = UserInfo.getName(),
            Input_Summary__c  = 'what is wrong with this loan? (case ' + auditCaseId + ')',
            Output_Summary__c = output,
            Timestamp__c    = Datetime.now()
        );
        // Append-only governed write path.
        Database.insert(log, AccessLevel.USER_MODE);
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
    }
}
