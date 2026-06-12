/**
 * AuditCommitService — Persists audit replay results in a single transaction.
 *
 * Stage 3 of the 3-layer audit replay kernel.
 * Inserts Reconstructed_Fact__c, Rule_Check__c, and Audit_Event__c records.
 * Single transaction boundary for atomicity.
 *
 * @group Audit Replay Kernel
 * @see DESIGN.md — AuditCommitService
 */
public with sharing class AuditCommitService {

    /**
     * Result of a commit operation.
     */
    public class CommitResult {
        public List<Id> factIds;
        public List<Id> ruleCheckIds;
        public List<Id> eventIds;
        public Integer totalRecords;

        public CommitResult() {
            this.factIds = new List<Id>();
            this.ruleCheckIds = new List<Id>();
            this.eventIds = new List<Id>();
            this.totalRecords = 0;
        }
    }

    /**
     * Commit reconstructed facts, rule checks, and audit events in one transaction.
     * Also updates the Audit_Case__c status to In_Review.
     *
     * @param auditCaseId  The audit case being processed
     * @param facts        Reconstructed_Fact__c records to insert
     * @param ruleChecks   Rule_Check__c records to insert
     * @return CommitResult with all inserted record IDs
     */
    public static CommitResult commitReplayResults(
        Id auditCaseId,
        List<Reconstructed_Fact__c> facts,
        List<Rule_Check__c> ruleChecks
    ) {
        CommitResult result = new CommitResult();

        // 1. Insert facts
        if (!facts.isEmpty()) {
            insert facts;
            for (Reconstructed_Fact__c f : facts) {
                result.factIds.add(f.Id);
            }
        }

        // 2. Insert rule checks
        if (!ruleChecks.isEmpty()) {
            insert ruleChecks;
            for (Rule_Check__c rc : ruleChecks) {
                result.ruleCheckIds.add(rc.Id);
            }
        }

        // 3. Log audit events for the replay
        String actor = UserInfo.getUserId();
        Datetime now = Datetime.now();
        List<Audit_Event__c> events = new List<Audit_Event__c>();

        events.add(new Audit_Event__c(
            Audit_Case__c = auditCaseId,
            Event_Type__c = 'Facts_Reconstructed',
            Actor__c = actor,
            Timestamp__c = now
        ));

        events.add(new Audit_Event__c(
            Audit_Case__c = auditCaseId,
            Event_Type__c = 'Replay_Executed',
            Actor__c = actor,
            Timestamp__c = now
        ));

        AuditEventService.logEvents(events);
        for (Audit_Event__c evt : events) {
            result.eventIds.add(evt.Id);
        }

        // 4. Update case status
        Audit_Case__c auditCase = new Audit_Case__c(
            Id = auditCaseId,
            Status__c = 'In_Review'
        );
        update auditCase;

        result.totalRecords = result.factIds.size()
            + result.ruleCheckIds.size()
            + result.eventIds.size();

        return result;
    }

    /**
     * Commit findings for an audit case.
     * Inserts Finding__c records and logs audit events.
     *
     * @param auditCaseId  The audit case
     * @param findings     Finding__c records to insert
     * @return CommitResult with inserted IDs
     */
    public static CommitResult commitFindings(
        Id auditCaseId,
        List<Finding__c> findings
    ) {
        CommitResult result = new CommitResult();

        if (!findings.isEmpty()) {
            insert findings;

            String actor = UserInfo.getUserId();
            Datetime now = Datetime.now();
            List<Audit_Event__c> events = new List<Audit_Event__c>();

            for (Finding__c f : findings) {
                events.add(new Audit_Event__c(
                    Audit_Case__c = auditCaseId,
                    Event_Type__c = 'Finding_Created',
                    Actor__c = actor,
                    Timestamp__c = now
                ));
            }

            AuditEventService.logEvents(events);
            for (Audit_Event__c evt : events) {
                result.eventIds.add(evt.Id);
            }
        }

        result.totalRecords = findings.size() + result.eventIds.size();
        return result;
    }
}