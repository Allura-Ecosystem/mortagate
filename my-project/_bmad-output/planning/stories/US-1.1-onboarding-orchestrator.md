# US-1.1: Build `c-onboarding-orchestrator` Host Component

**Epic:** EP-1 — Journey Orchestration + UX Hardening
**FRs:** FR-1, FR-2, FR-3, FR-4, FR-6, FR-7, FR-8
**ADRs:** ADR-5 (three-layer engine), ADR-7 (pre-check same kernel), ADR-8 (no pre-filled answers)
**Priority:** P0
**Depends on:** US-1.0 (brand tokens must be settled before CSS is authored)

## Acceptance Criteria

- Component manages a 6-screen state machine: Welcome → Intent → PreCheck → Evidence → DecisionRoom → Outcome
- Captures events: `start`, `intentcaptured`, `emailcaptured`, `evidencecomplete`
- Creates `Loan_Application__c` via Apex at the PreCheck → Evidence boundary
- Passes application record ID downstream to `evidenceQueue` and `decisionRoom` as `@api` property
- Back navigation works on screens that permit it (Intent ← PreCheck, Evidence ← DecisionRoom blocked)
- Fires `LoanDecisionService.decide()` after `evidencecomplete`
- `npm run test:unit` passes for orchestrator Jest suite

## Files to Create/Modify

- `force-app/main/default/lwc/onboardingOrchestrator/onboardingOrchestrator.html` (NEW)
- `force-app/main/default/lwc/onboardingOrchestrator/onboardingOrchestrator.js` (NEW)
- `force-app/main/default/lwc/onboardingOrchestrator/onboardingOrchestrator.css` (NEW)
- `force-app/main/default/lwc/onboardingOrchestrator/__tests__/onboardingOrchestrator.test.js` (NEW)
- `force-app/main/default/lwc/onboardingOrchestrator/onboardingOrchestrator.js-meta.xml` (NEW)
- Apex controller (NEW or extend existing) to create `Loan_Application__c`

## Test Plan

- Jest: state machine transitions — assert `currentScreen` index advances on each event
- Jest: back navigation — assert `currentScreen` decrements where allowed, stays put where blocked
- Jest: `intentcaptured` payload stored in component state (`loanPurpose`, `propertyValue`, `annualIncome`)
- Jest: Apex createLoanApplication wire/imperative mock called with correct payload
- Jest: error path — Apex failure shows error message, does not advance screen
- All tests at 375px viewport via jsdom

## Context

Event contract (child → orchestrator):

| Child component | Event name | Payload |
|---|---|---|
| `welcomeGate` | `start` | `{}` |
| `intentCapture` | `intentcaptured` | `{ loanPurpose, propertyValue, annualIncome }` |
| `preCheckResult` | `emailcaptured` | `{ email }` |
| `evidenceQueue` | `evidencecomplete` | `{}` |

Data flow:
1. `intentcaptured` payload stored in JS state
2. `PreFlightController.getBand()` called before record creation (pass income + value)
3. `Loan_Application__c` created with `Purpose__c`, `Property_Value__c`, `Annual_Income__c`
4. Record ID passed as `@api applicationId` to `evidenceQueue`, `decisionRoom`, `outcomeView`
5. `LoanDecisionService.decide(applicationId)` called after `evidencecomplete`

ADR-8: orchestrator must NOT pre-populate any form field from previous sessions or URL params.
