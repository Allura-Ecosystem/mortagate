# US-1.2: Add Progress Indicator to All Screens

**Epic:** EP-1 — Journey Orchestration + UX Hardening
**FRs:** FR-1, FR-2, FR-4, FR-7, FR-8; NFR-2
**ADRs:** None specific
**Priority:** P0
**Depends on:** US-1.1 (step index comes from orchestrator state)

## Acceptance Criteria

- Every screen shows current position — either "Step X of 6" text or a 4-phase visual track
- 4-phase labels: Intent → Documents → Review → Decision
- At 375px viewport, indicator is visible above the fold without scrolling
- All colors use Veridact CSS tokens — no hardcoded hex values
- Orchestrator passes `currentStep` (0-5 integer) to child component as `@api` property
- `npm run test:unit` snapshot tests pass for each screen showing indicator presence

## Files to Create/Modify

- `force-app/main/default/lwc/progressIndicator/progressIndicator.html` (NEW — preferred approach)
- `force-app/main/default/lwc/progressIndicator/progressIndicator.js` (NEW)
- `force-app/main/default/lwc/progressIndicator/progressIndicator.css` (NEW)
- `force-app/main/default/lwc/progressIndicator/__tests__/progressIndicator.test.js` (NEW)
- `force-app/main/default/lwc/onboardingOrchestrator/onboardingOrchestrator.html` — embed `<c-progress-indicator>` in template, pass `current-step={currentScreen}`
- Each of the 6 screen LWC html files — remove any inline step text if replaced by component

## Test Plan

- Jest snapshot: render `progressIndicator` with `currentStep=0`, assert "Intent" is active class
- Jest snapshot: render with `currentStep=3`, assert "Documents" complete, "Review" active
- Jest snapshot: render with `currentStep=5`, assert all phases complete
- Manual: DevTools iPhone SE (375px) — confirm indicator visible without scroll on all 6 screens

## Context

Phase-to-screen mapping (BLUEPRINT §B8 rule 4):

| Screens (index) | Phase label |
|---|---|
| 0 — Welcome, 1 — Intent | Intent |
| 2 — PreCheck, 3 — Evidence | Documents |
| 4 — DecisionRoom | Review |
| 5 — Outcome | Decision |

Component should accept `currentStep` as integer 0-5 and derive active phase internally. Keep the component thin — no Apex, no wire adapters. Pure presentational. Use CSS custom properties from `veridactTokens.css` for active/complete/inactive color states.
