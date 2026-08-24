# US-1.7: Build HITL Decision-Promotion Flow

**Epic:** EP-1 — Journey Orchestration + UX Hardening
**FRs:** FR-14, FR-15
**ADRs:** ADR-1 (append-only audit log), ADR-2 (worst-wins decision model)
**Priority:** P0
**Depends on:** None — independent of borrower journey

## Acceptance Criteria

- Flow named `Mortagate_Decision_Promotion` deploys and activates on `mortagate-de`
- Underwriter or loan officer can promote a `Loan_Application__c` from `PENDING_REVIEW` to `APPROVED` or `HARD_DECLINED`
- Flow **inserts** a new `Decision_Event__c` record — it never updates or deletes the original event
- New event has `Triggered_By__c = UNDERWRITER`
- New event references the same `Policy_Rule_Version__c` as the original evaluation event
- Fault connectors on all DML elements
- Deployed and manually verified: original `Decision_Event__c` record is unchanged after promotion
- Bulk validated: 200 pending applications promotable without governor limit errors

## Files to Create/Modify

- `force-app/main/default/flows/Mortagate_Decision_Promotion.flow-meta.xml` (NEW)

## Test Plan

- Deploy and activate flow
- Manual: create a `Loan_Application__c` in `PENDING_REVIEW` status with an existing `Decision_Event__c`
- Run flow as underwriter, select APPROVED
- Query: `SELECT Id, Status__c FROM Loan_Application__c WHERE Id = :appId` — confirm `APPROVED`
- Query: `SELECT Id, Triggered_By__c FROM Decision_Event__c WHERE Loan_Application__c = :appId ORDER BY CreatedDate` — confirm 2 records, original unchanged, new record has `Triggered_By__c = UNDERWRITER`
- Attempt direct UPDATE on original `Decision_Event__c` via Workbench — confirm `DecisionEventImmutabilityTrigger` blocks it with expected error
- Bulk: insert 200 `Loan_Application__c` in `PENDING_REVIEW`, invoke flow via `sf apex run` script, confirm all 200 promoted

## Context

The append-only invariant (ADR-1) is enforced by `DecisionEventImmutabilityTrigger` on `Decision_Event__c`. This trigger blocks any UPDATE or DELETE DML on existing records. The Flow must only use **Create Records** elements — never Update Records on `Decision_Event__c`.

The `Loan_Application__c.Status__c` field CAN be updated (it is not append-only); the Flow should update it as a separate Create/Update step after inserting the new event.

Flow type: Screen Flow (for underwriter to select outcome + add notes) or Record-Triggered on a helper object. Screen Flow is preferred — it gives the underwriter a confirmation step before committing.

`Policy_Rule_Version__c` lookup: retrieve it from the most recent existing `Decision_Event__c` for this application (Get Records element, sorted by `CreatedDate DESC`, limit 1) and stamp the same lookup on the new event.
