# CaseFile Simulated Beta Test Report

**Date:** 2026-08-03
**Tester:** Gilliam (AI agent simulation)
**Method:** Dogfood browser QA + Adversarial UX persona (Margaret) + Edge case hunter
**Org:** mortagate-de (00DgL00000SseMyUAJ)

---

## EXECUTIVE SUMMARY

| Track | Findings | Critical | High | Medium | Low |
|-------|----------|----------|------|--------|-----|
| Browser QA (dogfood) | 7 | 1 | 3 | 2 | 1 |
| Adversarial UX (Margaret) | 9 | 5 RED | 0 | 2 YELLOW | 2 WHITE |
| Edge case hunter | 59 | 8 | 20 | 18 | 13 |
| **Total** | **75** | **14** | **23** | **22** | **16** |

The synchronous audit path works. Evidence creates, decisions produce, replay runs. But there are 14 critical findings that would block a real beta tester.

---

## TRACK 1: BROWSER QA (DOGFOOD)

### Screen 1: Audit Queue
- Console errors: 0 (clean)
- Visual issues found:
  1. CRITICAL: Product name mismatch — header says "Mortgage Audit", case IDs say "VERIDACT-AC-0001", product is "CaseFile"
  2. HIGH: Inconsistent case ID format — row 1 uses "VERIDACT-AC-0001", rows 2-6 use "LA-558823"
  3. HIGH: "OrgFarm EPIC" as approver name (test data in production view)
  4. MEDIUM: SLA column shows "Overdue 47d" as plain text, no visual urgency (red/amber)
  5. MEDIUM: Metric card says "1 QC window at risk" but 5 rows show "Window exceeded" — count mismatch
  6. LOW: "Assigned to me" (card) vs "My cases" (toggle) — inconsistent terminology

### Screen 2: Audit Case Record (AC-000624)
- Console errors: 0 (clean)
- Visual issues found:
  1. CRITICAL: Policy Version field shows raw 18-char ID (a0GgL00000FN1qnUAD) instead of human-readable name
  2. HIGH: Borrower name "Sabir Asheed Sr." not visible on record page header
  3. MEDIUM: Multiple empty fields (Approval Timestamp, Assigned At, Signed Off At) create visual clutter
  4. MEDIUM: No Case Review LWC on record page — custom review UI is on separate FlexiPage, not the record

### Screens not reached: Case Review LWC, Sign-off Receipt, Analytics Dashboard, Policy Versions, Admin
(Record page navigation did not load the custom Case Review FlexiPage)

---

## TRACK 2: ADVERSARIAL UX (MARGARET, 58-YEAR-OLD QC ANALYST)

### RED — REAL UX BUGS (Must fix before beta)

R1: App name mismatch blocks discovery — searching "CaseFile" in App Launcher returns nothing
R2: No progress indicator during "Run Decision" — screen appears frozen for several seconds
R3: Decision result and replay result shown separately with no auto-comparison
R4: No clear post-sign-off workflow — "what do I do next?"
R5: Inconsistent button labels: "Run Decision" / "Evaluate" / "Replay" for same operation

### YELLOW — VALID BUT LOW PRIORITY

Y1: MFA verification code UX (security requirement, not a product choice)
Y2: Analytics dashboard competes with case queue for attention on landing

### WHITE — PERSONA NOISE

W1: "Filing cabinet is faster" (resistance to digital)
W2: "Yellow legal pad doesn't make me compare" (the comparison IS the feature)
W4: "Font is too small" (browser zoom, not app bug)
W5: "MFA is annoying" (security requirement)

### GREEN — FEATURE REQUESTS

G1: Auto-compare decision vs replay
G2: Post-sign-off workflow confirmation
G3: Role-based landing pages
G4: First-run guided tour
G5: Progress indicator for async operations

Full rant at: my-project/_bmad-output/planning/beta-test-margaret-rant.md

---

## TRACK 3: EDGE CASE HUNTER (59 findings across 18 Apex classes)

### Most Critical Edge Cases (top 8):

1. ReplayService.cls:47 — NullPointerException if Loan__r is null when accessing Approval_Date__c
2. ReplayService.cls:82-96 — NullPointerException if no active policy version for approval date
3. PolicyRuleEvaluator.cls:85-89 — Null Decimal silently evaluates as false for all operators (masks data issues)
4. PolicyRuleEvaluator.cls:90-93 — BETWEEN with null threshold always fails silently
5. PolicyRuleEvaluator.cls:97-99 — NOT_IN_LIST with null allowedValues always returns true silently
6. PolicyRuleEvaluator.cls:100-102 — Null operator throws NullPointerException, not PolicyEngineException
7. PolicyRuleEvaluator.cls:119-131 — Boolean/Date fact values throw PolicyEngineException (only handles Decimal/String)
8. LoanDecisionService.cls:27 — Null context from missing appId causes NullPointerException

Full findings at: /home/ronin704/edge-case-findings.json (59 items, JSON array)

### Pattern: Silent failures are the dominant risk
23 of 59 findings involve null values being silently swallowed instead of throwing. The evaluator returns INDETERMINATE or false instead of surfacing the data problem. For an audit product, silent wrong answers are worse than crashes.

---

## WHAT PASSED

- Audit Queue loads with 6 cases, zero console errors
- Case record page loads, zero console errors
- All 6 metric cards render (Assigned, High risk, Evidence needed, Ready for signoff, SLA at risk, QC window at risk)
- Filter bar renders (Status, Product, Risk Tier, All/My cases toggle)
- Data table renders all 6 rows with correct data
- Evidence creation works (SC-6a verified)
- Decision production works (SC-6b verified — HARD_DECLINED, DTI 44.8% > 43%)
- Audit Replay works (SC-7 verified — 10 checks, 8 pass / 2 fail)
- Bulk benchmark: 6 cases in 550ms, 86% governor headroom
- LWC Jest: 13 suites, 63 tests, 100% pass
- Apex: 204 tests, 100% pass, 83% coverage

---

## WHAT FAILED

- Browser navigation from queue to Case Review LWC (click did not trigger page change)
- Product name consistency (Veridact vs CaseFile vs Mortgage Audit — three names)
- Policy Version display (raw ID instead of name)
- No progress indicator during decision execution
- Silent null handling in 23 code paths
- Case Review LWC not on record page

---

## RECOMMENDATION

Fix the 5 RED UX issues and the top 8 edge cases before putting a real analyst in front of the system. The app works technically — the audit loop is solid — but a real person would get stuck at the name mismatch (can't find the app) and the frozen screen during decision execution (thinks it's broken).

The edge case findings are the most valuable output. 59 unhandled paths across 18 classes is real engineering work. The silent-null pattern (23 instances) is the one I'd fix first — for an audit product, silent wrong answers are the worst possible failure mode.