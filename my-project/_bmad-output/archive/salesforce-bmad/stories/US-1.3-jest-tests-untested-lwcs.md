# US-1.3: Write Jest Tests for 4 Untested LWCs

**Epic:** EP-1 — Journey Orchestration + UX Hardening
**FRs:** Supports verification of FR-1, FR-4, FR-7, FR-8
**ADRs:** None
**Priority:** P0
**Depends on:** None — can run in parallel with all other EP-1 stories

## Acceptance Criteria

- `welcomeGate`, `preCheckResult`, `evidenceQueue`, `decisionRoom` each have a `__tests__/` file
- Minimum 3 tests per component; 4+ preferred
- Required test coverage per component:
  - Renders with correct heading/title text
  - Wire adapter mock resolves and component displays result data
  - Button click dispatches correct CustomEvent with expected detail payload
  - Error/empty state renders error message element
- All 4 suites pass via `npm run test:unit` with zero failures

## Files to Create/Modify

- `force-app/main/default/lwc/welcomeGate/__tests__/welcomeGate.test.js` (NEW)
- `force-app/main/default/lwc/preCheckResult/__tests__/preCheckResult.test.js` (NEW)
- `force-app/main/default/lwc/evidenceQueue/__tests__/evidenceQueue.test.js` (NEW)
- `force-app/main/default/lwc/decisionRoom/__tests__/decisionRoom.test.js` (NEW)

## Test Plan

Follow the existing patterns in:
- `intentCapture/__tests__/intentCapture.test.js` — 3 tests: renders question, fires event with answers, disabled state
- `outcomeView/__tests__/outcomeView.test.js` — 7 tests: renders each outcome variant, fires events, receipt/notice links

Test structure to copy:

```js
import { createElement } from 'lwc';
import ComponentName from 'c/componentName';
import { registerApexTestWireAdapter } from '@salesforce/sfdx-lwc-jest';
import getXxx from '@salesforce/apex/XxxController.getXxx';

const mockGetXxx = require('./data/getXxx.json');
const getXxxAdapter = registerApexTestWireAdapter(getXxx);

describe('c-component-name', () => {
    afterEach(() => { while (document.body.firstChild) document.body.removeChild(document.body.firstChild); });

    it('renders correct title', () => { ... });
    it('displays wire data', () => { ... });
    it('dispatches event on button click', () => { ... });
    it('shows error on wire failure', () => { ... });
});
```

- Mock data factories go inline in each test file — no shared utils module
- Wire mock JSON files go in `__tests__/data/` beside each test

## Context

Read `intentCapture.test.js` and `outcomeView.test.js` before writing — match their import style, describe/it nesting, and cleanup pattern exactly. The CI config runs `@salesforce/sfdx-lwc-jest` not plain `@lwc/jest`, so use `registerApexTestWireAdapter` (not `registerLdsTestWireAdapter`) for Apex wire mocks.
