# US-1.6: Build Mortagate_Borrower_Journey Screen Flow

**Epic:** EP-1 — Journey Orchestration + UX Hardening
**FRs:** FR-1, FR-2, FR-3, FR-4, FR-5, FR-6, FR-7, FR-8, FR-9
**ADRs:** ADR-5 (three-layer engine)
**Priority:** P0
**Depends on:** US-1.1 (`onboardingOrchestrator` LWC must exist to embed)

## Acceptance Criteria

- Flow named `Mortagate_Borrower_Journey` deploys and activates without errors on `mortagate-de`
- Flow wraps `c-onboarding-orchestrator` as a single Screen element — the LWC manages all 6 internal screens
- Fault connectors present on every DML element (Create Records, Update Records)
- Manual walkthrough from Welcome to Outcome completes without Flow errors
- Flow API version ≥59.0

## Files to Create/Modify

- `force-app/main/default/flows/Mortagate_Borrower_Journey.flow-meta.xml` (NEW)

## Test Plan

- Deploy: `sf project deploy start --source-dir force-app/main/default/flows/Mortagate_Borrower_Journey.flow-meta.xml --target-org mortagate-de`
- Activate in Setup > Flows
- Manual walkthrough: open borrower site as guest, complete all 6 screens, verify `Loan_Application__c` record created with correct field values
- Fault path: simulate Apex error (e.g., remove field permission) — verify fault connector fires and user sees error message, not blank screen
- Bulk: not applicable (Screen Flow is single-user interactive, not bulk-invoked)

## Context

Recommended architecture (Brooks pattern): embed the orchestrator as a **single Screen element**. The state machine lives entirely in LWC JS — Flow is the container and record-creation bridge only.

```xml
<screens>
    <name>BorrowerJourney</name>
    <fields>
        <fieldType>ComponentInstance</fieldType>
        <componentName>c:onboardingOrchestrator</componentName>
    </fields>
</screens>
```

The alternative (6 separate Screen elements in Flow) duplicates state management that already exists in the LWC and should be avoided.

Flow type: Screen Flow. Entry point: Experience Cloud page or Lightning App page. Do not use Record-Triggered Flow type — there is no triggering record at journey start.
