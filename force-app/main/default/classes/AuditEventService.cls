/**
 * AuditEventService — Append-only event writer for the Mortgage Audit Engine.
 *
 * Every action in the audit lifecycle writes an Audit_Event__c record.
 * This service is the single point of entry for creating those records.
 *
 * INVARIANT: Audit events are NEVER updated or deleted. The SObject is
 * protected by a validation rule (ISNEW() = FALSE) and profile permissions.
 *
 * @group Audit Trail
 * @see DESIGN.md — Decision Governance / Append-Only Audit Event Log
 */
public with sharing class AuditEventService {

    /**
     * Insert a single audit event — NEVER update.
     *
     * @param auditCaseId     The parent Audit_Case__c Id
     * @param eventType       One of the canonical event types (CASE_CREATED, CASE_ASSIGNED, etc.)
     * @param actor           Display name or User Id of the actor
     * @param payload         JSON or free-text detail payload
     * @param relatedRecordId Optional Id of a related record (Finding, Rule_Check, etc.)
     * @return The inserted Audit_Event__c with its generated Id
     */
    public static Audit_Event__c logEvent(
        Id auditCaseId,
        String eventType,
        String actor,
        String payload,
        Id relatedRecordId
    ) {
        Audit_Event__c event = new Audit_Event__c(
            Audit_Case__c   = auditCaseId,
            Event_Type__c   = eventType,
            Actor__c         = actor,
            Timestamp__c     = Datetime.now(),
            Payload__c       = payload,
            Related_Record_Id__c = relatedRecordId != null
                ? String.valueOf(relatedRecordId)
                : null
        );
        insert event;
        return event;
    }

    /**
     * Bulk insert audit events — for batch operations.
     * Sets Timestamp__c on any record that does not already have one.
     *
     * @param events List of Audit_Event__c records to insert
     * @return The inserted list (with Ids populated)
     */
    public static List<Audit_Event__c> logEvents(List<Audit_Event__c> events) {
        Datetime now = Datetime.now();
        for (Audit_Event__c evt : events) {
            if (evt.Timestamp__c == null) {
                evt.Timestamp__c = now;
            }
        }
        insert events;
        return events;
    }

    /**
     * Query events for an audit case in chronological order.
     * Uses USER_MODE for FLS/CRUD enforcement.
     *
     * @param auditCaseId The Audit_Case__c to retrieve events for
     * @return Ordered list of Audit_Event__c records (oldest first)
     */
    public static List<Audit_Event__c> getEventsForCase(Id auditCaseId) {
        return [
            SELECT Id, Name, Event_Type__c, Actor__c, Timestamp__c,
                   CreatedDate
            FROM Audit_Event__c
            WHERE Audit_Case__c = :auditCaseId
            WITH USER_MODE
            ORDER BY Timestamp__c ASC
        ];
    }
}