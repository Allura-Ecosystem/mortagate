# REQUIREMENTS MATRIX

> [!NOTE]
> **AI-Assisted Documentation**
> Portions of this document were drafted with the assistance of an AI language model.

Traceability from requirement → implementation → verification. Status legend: ✅ built & verified · 🟡 built, not yet executed against org · ⬜ not built.

---

## Functional Requirements

| ID | Requirement | Source | Implementation | Verification | Status |
|----|-------------|--------|----------------|--------------|--------|
| FR-1 | Welcome gate: one sentence, one button, no login wall | B3 S1 | `lwc/welcomeGate` | manual | 🟡 |
| FR-2 | Intent capture: 3 questions, one-at-a-time, slide animation | B3 S2 | `lwc/intentCapture` | Jest (3 tests) | ✅ |
| FR-3 | No fake default answers; Continue gated on real input | ADR-8 | `intentCapture` touched-flags + disabled CTA | Jest: "shows a prompt, not a fake number" | ✅ |
| FR-4 | Soft pre-check produces eligibility band, no record created | B3 S3 | `PreFlightEvaluator`, `PreFlightController`, `lwc/preCheckResult` | `PreFlightEvaluatorTest`, `PreFlightControllerTest` | 🟡 |
| FR-5 | Pre-check uses the same kernel as the full decision | ADR-7 | `PreFlightEvaluator` reads live INCOME+COLLATERAL rules | `PreFlightEvaluatorTest` | 🟡 |
| FR-6 | Progressive identity: email only after value shown | B3 S3 | `preCheckResult` emailcaptured event | manual | 🟡 |
| FR-7 | Evidence queue: one document at a time, human messages | B3 S4 | `lwc/evidenceQueue` | manual | 🟡 |
| FR-8 | Decision room timeline; pending state is not a bare empty | B3 S5 | `lwc/decisionRoom` heartbeat empty state | manual | 🟡 |
| FR-9 | Outcome: approved shows amount; declined never says "denied" + reason | B3 S6 | `lwc/outcomeView` | Jest (3 tests) | ✅ |
| FR-10 | Policy evaluation against versioned rules | B5 | `PolicyRuleEvaluator` | `PolicyRuleEvaluatorTest` | 🟡 |
| FR-11 | All 8 operators supported | B5 | `PolicyRuleEvaluator.evaluateOperator` | `PolicyRuleEvaluatorTest.everyOperator_isExercised` | 🟡 |
| FR-12 | Verdict precedence worst-wins | ADR-2 | `PolicyRuleEvaluator.deriveVerdict` | 4 verdict-tier tests | 🟡 |
| FR-13 | Missing fact → INDETERMINATE, never decline | ADR-3 | `PolicyRuleEvaluator` | `missingFact_isIndeterminate_notDecline` | 🟡 |
| FR-14 | Decision events append-only | B4, ADR-1 | `DecisionEventImmutabilityTrigger` | `DecisionEventImmutabilityTest` (insert/update/delete) | 🟡 |
| FR-15 | Full receipt persisted (`Rule_Results_JSON__c`) | B4 | `DecisionCommitService` | `LoanDecisionServiceTest` | 🟡 |
| FR-16 | Starter kernel rule set exists | — | `data/Policy_Rule_Version__c.json` (6 rules) | JSON validated | ✅ |
| FR-17 | Rules maintainable by non-developers (versioning) | B5 | `PolicyRuleVersionHandler` + `PolicyRuleVersionTrigger` (auto-version, supersession, immutability-after-reference, no-delete) | `PolicyRuleVersionHandlerTest` (7 tests) | 🟡 |
| FR-18 | "Every decision has a receipt" — human-readable, printable/emailable audit doc | brand tagline | `DecisionReceipt.page` (renderAs=pdf) + `DecisionReceiptController` (pure read, FLS/CRUD, bind-var); `outcomeView` `viewreceipt` link | `DecisionReceiptControllerTest` (3 tests), `outcomeView` Jest (2 tests) | 🟡 |
| FR-19 | Adverse Action Notice on decline — specific reasons (ECOA / Reg B 12 CFR 1002.9) + FCRA score disclosure | P1 / ENTERPRISE-READINESS-ROADMAP §3, DESIGN-adverse-action | `AdverseActionService` (pure compose), `AdverseActionNoticeController` (pure read, FLS/CRUD, bind-var), `AdverseActionNotice.page` (renderAs=pdf), `Adverse_Action_Config__mdt` Default; `outcomeView` `viewnotice` link | `AdverseActionServiceTest` (13), `AdverseActionNoticeControllerTest` (5), `outcomeView` Jest (2) | 🟡 |

## Non-Functional Requirements

| ID | Requirement | Source | Implementation | Verification | Status |
|----|-------------|--------|----------------|--------------|--------|
| NFR-1 | Bulk safe: 3 SOQL + 1 DML for N apps | B7 | three-layer engine | `bulk_200Applications_withinGovernorLimits` | 🟡 |
| NFR-2 | Mobile-first 375px, 100dvh per screen | B8 | all LWC CSS | manual | 🟡 |
| NFR-3 | WCAG 2.1 AA contrast; semantic colors as chips | ADR-9 | `veridactTokens.css`, chip classes | contrast math verified | ✅ |
| NFR-4 | Honor `prefers-reduced-motion` | DESIGN | token = 0s + component media queries | code review | ✅ |
| NFR-5 | No Salesforce chrome; full Veridact skin | B8 | brand tokens + component styling | manual | 🟡 |
| NFR-6 | Kernel unit-testable without an org | ADR-5 | pure `PolicyRuleEvaluator` | tests use in-memory rules, no DML | 🟡 |
| NFR-7 | Deterministic audit output | ADR-6 | `RuleCodeComparator` sort | code review | 🟡 |

## Compliance Requirements (P1 — see DESIGN-adverse-action.md)
| ID | Requirement | Source | Implementation | Verification | Status |
|----|-------------|--------|----------------|--------------|--------|
| CR-1 | Notice states the specific principal reasons (not boilerplate) | 12 CFR 1002.9(b)(2) | `AdverseActionService.selectReasons` (from `Rule_Explanation__c`, HARD-first, capped 4, deduped) | `AdverseActionServiceTest` reasons/forbidden-phrasing tests | 🟡 |
| CR-2 | Verbatim ECOA §701(a) anti-discrimination notice + oversight agency | 12 CFR 1002.9(b)(1) | `Adverse_Action_Config__mdt.ECOA_Notice__c` + `[AGENCY]` resolution | `ecoaNotice_resolvesAgencyToken` | 🟡 |
| CR-3 | Creditor name + address; statement of action taken | 12 CFR 1002.9(a)(2)(i) | config + `Notice.actionStatement` | controller test | 🟡 |
| CR-4 | FCRA score disclosure when a consumer report is used | 15 U.S.C. 1681m | `AdverseActionService.buildScoreDisclosure` (CRA identity pending P3) | `creditScore_producesDisclosure` | 🟡 |
| CR-5 | Delivery + proof within 30 days; legal sign-off | 12 CFR 1002.9(a)(1) | **not built** — HITL delivery + compliance review | — | ⬜ |

## Outstanding (Open Questions → BLUEPRINT §B9)
- OQ-1 decision latency · OQ-2 extraction method · OQ-3 platform events in Dev Edition · OQ-4 FSC availability.

## Top Gate to Flip Status 🟡 → ✅
**R-1:** authenticate `mortagate-de`, deploy, run `sf apex run test -l RunLocalTests`. That single action verifies FR-4,5,7,8,10–15,17 and NFR-1,6,7 against the platform.
