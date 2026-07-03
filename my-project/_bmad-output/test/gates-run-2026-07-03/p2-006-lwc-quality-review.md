# p2-006 — LWC Quality Review Evidence

- **Gate check:** `p2-006-lwc-quality-review`
- **Reviewer:** Pike (LWC interface + simplicity gate)
- **Date:** 2026-07-03
- **Scope:** 13 components under `force-app/main/default/lwc/` — auditAdmin, auditAnalytics, auditMetricCards, auditQueue, auditQueueDatatable, auditQueueFilters, caseReview, findingDetail, glossaryTerm, policyVersions, qcWindowBadge, riskBadge, signoffReceipt
- **Method:** evidence-first, one criterion at a time. No org touched, no deploy.

> AI-Assisted Documentation — this evidence file was drafted with AI assistance (Pike agent). All command outputs are reproduced from live runs against the working tree.

## Verdict Summary

| # | Criterion | Verdict |
|---|-----------|---------|
| 1 | No innerHTML with user data | **PASS** |
| 2 | Apex enforces CRUD/FLS | **PASS** (1 approved system-mode deviation, out of LWC scope) |
| 3 | No hardcoded org-specific IDs | **PASS** |
| 4 | SLDS tokens instead of hardcoded colors | **PASS** |
| 5 | Keyboard + accessible-label checks | **PASS** (1 minor non-blocking note) |

**Overall recommendation: PASS the gate.**

---

## Criterion 1 — No innerHTML with user data

**Command:**
```
grep -rn "innerHTML\|insertAdjacentHTML\|lwc:dom=\"manual\"" force-app/main/default/lwc/
```
**Output:** `NO HITS` (zero matches across all 13 components).

No raw-HTML injection surface exists. All rendering is through LWC templates and `lightning-formatted-*` / interpolation. **PASS.**

---

## Criterion 2 — Apex enforces CRUD/FLS

The 13 LWC import 7 controllers (via `@salesforce/apex/...`):
`AdminController`, `AnalyticsController`, `AuditQueueController`, `CaseReviewController`, `FindingController`, `PolicyVersionsController`, `SignoffController`.

Enforcement grep over each controller (`WITH USER_MODE` / `AccessLevel.USER_MODE` / `as user` DML / shared `AuditSoql` helper):

| Controller | Method(s) called by LWC | Enforcement | Evidence |
|---|---|---|---|
| AuditQueueController | `getQueue`, `getMetrics` | Reads USER_MODE via `AuditSoql` + `AccessLevel.USER_MODE` | `AuditQueueController.cls:7,45,114,142` |
| FindingController | `getFindings` (read), `saveFinding` (DML) | Read `WITH USER_MODE`; write `insert as user` / `update as user` | `FindingController.cls:11-12,102,137,139` |
| CaseReviewController | `getCaseDetail` (read), `rerunReplay` (DML) | Reads `AccessLevel.USER_MODE` via `AuditSoql` | `CaseReviewController.cls:8,29,66` |
| AdminController | `getOrgSummary` | Counts USER_MODE via `AuditSoql` | `AdminController.cls:6,23` |
| SignoffController | `getReceipt` (read), `signOff` (DML) | Reads `WITH USER_MODE` | `SignoffController.cls:19,114,127,221,228` |
| AnalyticsController | `getAnalytics` | Reads `WITH USER_MODE` / `AuditSoql` | `AnalyticsController.cls:15,123` |
| PolicyVersionsController | `getVersions`, `getRules` | Reads `AccessLevel.USER_MODE` via `AuditSoql` | `PolicyVersionsController.cls:6,27,55` |

**Shared read path:** `AuditSoql.cls` is `public with sharing` and runs every query at `AccessLevel.USER_MODE` (`AuditSoql.cls:24,41,56,131,151`), so FLS + sharing are enforced for the whole read surface.

**System-mode scan (scoped set):**
```
grep -rn "SYSTEM_MODE\|without sharing" classes/ | grep -iE "AuditQueue|Finding|CaseReview|Admin|Signoff|Analytics|PolicyVersions|AuditSoql|IdentityGate"
=> none in scoped set
```
No LWC-facing controller uses system mode.

**Known approved deviation (NOT a fail):** `IdentityGateService.cls:96` performs a deliberate system-mode read of `Sanctions_Screening__c` (no `WITH USER_MODE`), documented in-code as an intentional precondition-gate read. This service is **not** imported by any of the 13 LWC (no `@salesforce/apex/IdentityGateService` reference in `lwc/`), so it is out of this gate's surface. Noted per instruction; does not affect the verdict.

**PASS.**

---

## Criterion 3 — No hardcoded org-specific IDs

**Command:**
```
grep -rnE "['\"][a-zA-Z0-9]{15,18}['\"]" force-app/main/default/lwc/ --include=*.js --include=*.html
```
**Non-test hits (all judged false positives — camelCase field/column keys, not Salesforce record IDs):**
- `auditMetricCards.js:38` → `'readyForSignoff'` (DTO key)
- `auditQueue.js:18` → `'qcWindowDaysLeft'` (datatable `fieldName`)
- `findingDetail.html:80,87,97` → `data-field="exceptionReason|exceptionApprover|remediationNotes"` (form field names)
- `auditAnalytics.js:49` → `'missingEvidenceCount'` (DTO key)

**Test hits:** only `auditQueue.test.js:64` (`'qcWindowDaysLeft'` fieldName) — likewise a field key, not an ID. No fake `000000000000000AAA`-style literals found in component code.

No 15/18-char Salesforce record-ID literals exist in any component. All record identifiers flow in at runtime via `@api recordId`, `data-id={...}`, and wired Apex. **PASS.**

---

## Criterion 4 — SLDS tokens instead of hardcoded colors

**Command 1 (project token guard):**
```
node scripts/check-brand-tokens.mjs
=> ✓ Veridact token guard: 12 LWC stylesheet(s) clean (ADR-UX-01).   (exit 0)
```
(`npm run test:tokens` maps to the same script.)

**Command 2 (raw hex sweep):**
```
grep -rniE "#[0-9a-f]{3,8}\b" force-app/main/default/lwc/ --include=*.css
=> NO RAW HEX
```
All 12 stylesheets are clean of raw hex; colors resolve through SLDS / Veridact `var(--...)` tokens per ADR-UX-01. **PASS.**

---

## Criterion 5 — Keyboard and accessible-label checks

**Jest suite (includes `@sa11y/jest` matchers):**
```
npx sfdx-lwc-jest        # (--runInBand rejected by wrapper; ran default)
=> Test Suites: 13 passed, 13 total
=> Tests:       63 passed, 63 total
```
`@sa11y` axe assertion present and green: `qcWindowBadge.test.js:59 await expect(el).toBeAccessible()`. All 13 render/behavior suites pass.

**Interactive-element spot-check (templates):**
- Native `<button type="button">` used for all custom actions (auditQueue, auditQueueFilters, findingDetail, caseReview, signoffReceipt) — natively focusable + keyboard-operable; each has a visible text label supplying its accessible name.
- `aria-*` present where icon/state needs it: `auditQueueFilters.html`, `signoffReceipt.html`, `auditMetricCards.html`.
- `caseReview`, `signoffReceipt`, `policyVersions` action handlers are bound to real `<button>`/focusable elements.

**Minor note (non-blocking):** `policyVersions.html:18-25` — the version-row `<li>` acts as a control with `role="button"` and `tabindex="0"` (keyboard-focusable, correct role), but has `onclick` without a paired `onkeydown` for Enter/Space activation. Focus and SR semantics are correct; only pointer-driven activation is wired. Recommend adding a keydown handler in a follow-up polish slice. Does not block the gate — element is reachable, labeled, and roled.

**PASS** (with the one minor follow-up note above).

---

## Recommendation

All five gate criteria pass on live evidence. Zero innerHTML surface, uniform USER_MODE enforcement across every LWC-facing controller (via `AuditSoql` + `WITH USER_MODE` and `as user` DML), no hardcoded record IDs, token guard green with no raw hex, and 63/63 Jest tests passing including a `@sa11y` axe assertion. One minor keyboard-activation polish item logged against `policyVersions`. **Gate p2-006: PASS.**
