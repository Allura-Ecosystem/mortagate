# REQUIREMENTS MATRIX

> [!NOTE]
> **AI-Assisted Documentation**
> Portions of this document were drafted with the assistance of an AI language model.

Traceability from requirement → implementation → verification. Status legend: ✅ built & verified · 🟡 built, verification in progress · ⬜ not built.

> **Last verified:** 2026-06-23 — Full source deployed to `mortagate-de` (DevHub). Apex `RunLocalTests` = **140/140 PASS (100%)**. LWC Jest = **53/53 PASS (12 suites)**. All auditor screens verified on-org. Agentforce Copilot agent activated. Piecewise deploy strategy documented in `DEPLOY-REPORT.md`.

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
| FR-10 | Policy evaluation against versioned rules | B5 | `PolicyRuleEvaluator` | `PolicyRuleEvaluatorTest` — RunLocalTests 140/140 on `mortagate-de` | ✅ |
| FR-11 | All 8 operators supported | B5 | `PolicyRuleEvaluator.evaluateOperator` | `PolicyRuleEvaluatorTest.everyOperator_isExercised` — 140/140 on `mortagate-de` | ✅ |
| FR-12 | Verdict precedence worst-wins | ADR-2 | `PolicyRuleEvaluator.deriveVerdict` | 4 verdict-tier tests — 140/140 on `mortagate-de` | ✅ |
| FR-13 | Missing fact → INDETERMINATE, never decline | ADR-3 | `PolicyRuleEvaluator` | `missingFact_isIndeterminate_notDecline` — 140/140 on `mortagate-de` | ✅ |
| FR-14 | Decision events append-only | B4, ADR-1 | `DecisionEventImmutabilityTrigger` | `DecisionEventImmutabilityTest` (insert/update/delete) — 140/140 on `mortagate-de` | ✅ |
| FR-15 | Full receipt persisted (`Rule_Results_JSON__c`) | B4 | `DecisionCommitService` | `LoanDecisionServiceTest` — 140/140 on `mortagate-de` | ✅ |
| FR-16 | Starter kernel rule set exists | — | `data/Policy_Rule_Version__c.json` (6 rules) | JSON validated | ✅ |
| FR-17 | Rules maintainable by non-developers (versioning) | B5 | `PolicyRuleVersionHandler` + `PolicyRuleVersionTrigger` (auto-version, supersession, immutability-after-reference, no-delete) | `PolicyRuleVersionHandlerTest` (7 tests) — 140/140 on `mortagate-de` | ✅ |
| FR-18 | "Every decision has a receipt" — human-readable, printable/emailable audit doc | brand tagline | `DecisionReceipt.page` (renderAs=pdf) + `DecisionReceiptController` (pure read, FLS/CRUD, bind-var); `outcomeView` `viewreceipt` link | `DecisionReceiptControllerTest` (3 tests), `outcomeView` Jest (2 tests) | 🟡 |
| FR-19 | Adverse Action Notice on decline — specific reasons (ECOA / Reg B 12 CFR 1002.9) + FCRA score disclosure | P1 / ENTERPRISE-READINESS-ROADMAP §3, DESIGN-adverse-action | `AdverseActionService` (pure compose), `AdverseActionNoticeController` (pure read, FLS/CRUD, bind-var), `AdverseActionNotice.page` (renderAs=pdf), `Adverse_Action_Config__mdt` Default; `outcomeView` `viewnotice` link | `AdverseActionServiceTest` (13), `AdverseActionNoticeControllerTest` (5), `outcomeView` Jest (2) | 🟡 |
| FR-20 | Auditor Audit Queue screen: queue-first, 5 metric cards, filter bar, case table (Loan · Borrower · Risk · Status · Approver · SLA · Review ›) | Figma node 1:2, ADR-20, locked UX principle "queue-first" | `AuditQueueController.getQueue` (FLS-safe, USER_MODE, bound binds, sort allowlist, LIMIT 100/200) + `lwc/auditQueue`+`auditMetricCards`+`auditQueueFilters` (reuse `auditQueueDatatable`/`riskBadge`) + `Veridact_Audit_Queue` FlexiPage/tab/app | `AuditQueueControllerTest` (6) + Jest (9) + on-org screenshot (`veridact-af`/`mortagate-scratch`) | ✅ |
| FR-21 | Queue dashboard metrics: Assigned to me · High risk · Evidence needed · Ready for signoff · SLA at risk | Figma node 1:2 | `AuditQueueController.getMetrics` | `getMetrics_countsEachCardCorrectly` + on-org render (2·2·1·1·3) | ✅ |
| FR-22 | Agent answers "what's wrong with this loan?" read-only from stored replay checks, guardrailed, with staleness notice | Jobs intent gate, Penasoto underwriting-validator, ADR-21 | `LoanDiagnosisService` (`@InvocableMethod` + `@AuraEnabled` fallback; reads `Replay_Check__c`, never re-runs replay) | `LoanDiagnosisServiceTest` (3) + live on `veridact-af` (DTI_MAX surfaced, no "denied") | ✅ |
| FR-23 | Every agent action logs **before execution** with dual-write: append-only `Agent_Action_Log__c` (`Initiated`) + `Audit_Event__c` `Agent_Action` intent/outcome pair (outcome appended, never edited) | Notion governance grid, ADR-1, ADR-26 (log-before-execute delta) | `LoanDiagnosisService.runDiagnoses` (Phase 1 dual-write → Phase 2 pure narrate → Phase 3 outcome event); `AgentActionLogPreventDelete` (before update+delete) | `LoanDiagnosisServiceTest` (dual-write, bulk-200 ≤3 SOQL/3 DML) + `PreventDeleteTriggerTest` (update-block single+bulk) — 11/11 on `mortagate-de` | ✅ |
| FR-24 | Conversational Agentforce agent (Veridact Auditor Copilot) over the diagnosis action | Part 2 / Penasoto → Agentforce | agent `Veridact_Auditor_Copilot_v4` **created + activated** on `veridact-af` (Agentforce enabled in Setup; Einstein PSLs freed); `genAiPlannerBundle`/`bots`/`genAiPlugins` (2 topics) in source; topics rewritten plain-language (6th-grade) | ✅ created/activated; **action-wiring to `LoanDiagnosisService` = R-10 (Agent Builder 3-click handoff)** | 🟡 |
| FR-25 | Case Review (two-pane: evidence left, replay checks right), staleness guard, user-triggered re-run | Notion 5-screen flow, locked two-pane principle | `CaseReviewController` (USER_MODE via `AuditSoql`, `latestChecksFor`) + `lwc/caseReview` + `Veridact_Case_Review` record page | `CaseReviewControllerTest` + Jest; on-org | ✅ |
| FR-26 | Sign-off Receipt — immutable `Audit_Receipt__c` at sign-off (single guarded write, illustrative hash, append-only event) | Notion sign-off stage, brand "every audit has a receipt" | `SignoffController.signOff` (guards: Ready-only, no 2nd receipt) + `lwc/signoffReceipt` | `SignoffControllerTest` + Jest; on-org | ✅ |
| FR-27 | Finding Detail — document violation/exception/missing-evidence; accept/edit AI-drafted | Notion finding stage | `FindingController` (getFindings/getFinding/saveFinding; marks `AI_Draft_Accepted__c`) + `lwc/findingDetail` + `Veridact_Finding_Detail` record page | `FindingControllerTest` (11) + Jest; on-org | ✅ |
| FR-28 | Analytics — exception/violation/missing-evidence rates + approver drift (latest replay batch) | Notion analytics, qc-reporting-analyst | `AnalyticsController` (bulk-safe, `latestChecksFor`) + `lwc/auditAnalytics` (reuses `auditMetricCards`) + `Veridact_Analytics` tab | `AnalyticsControllerTest` (5) + Jest; on-org | ✅ |
| FR-29 | Policy Versions + Admin screens; full app nav (Queue·Cases·Evidence·Policies·Analytics·Admin) | Notion 7-nav | `PolicyVersionsController`/`AdminController` + `lwc/policyVersions`/`auditAdmin` + flexiPage tabs | `PolicyVersionsControllerTest`/`AdminControllerTest` (8) + Jest (8); on-org | ✅ |
| FR-30 | Plain-language (~6th grade) across diagnosis + agent topics + screen jargon (the "Leo" rule) | UX-panel iteration-10 Leo finding | plain diagnosis copy; plain agent topic scope/instructions; `c-glossary-term` tooltips (DTI/LTV/FICO/rule codes) wired into Case Review | Jest (glossaryTerm 7) + on-org; **Leo persona re-test pending (`ux-persona-panel`)** | 🟡 |
| FR-31 | R-11: replay re-run idempotency — readers show only the latest batch (append-only preserved) | found 2026-06-16 | `AuditSoql.latestChecksFor` used by Case Review, diagnosis, Sign-off, Analytics | double-replay tests (10/2 not 20/4) on `veridact-af` | ✅ |

**Pilot-ready status (2026-06-23):** 6/6 auditor screens built + wired + verified on `mortagate-de` (DevHub). **Full RunLocalTests = 140/140 (100%); LWC Jest 53/53 (12 suites).** Borrower surface deprecated. Plain language applied. Deploy confirmed via piecewise strategy (see `DEPLOY-REPORT.md`). Agentforce Copilot agent activated. Remaining: R-10 agent action-wiring (Builder 3-click handoff in Setup UI) + Leo persona re-test (UX panel).

## Non-Functional Requirements

| ID | Requirement | Source | Implementation | Verification | Status |
|----|-------------|--------|----------------|--------------|--------|
| NFR-1 | Bulk safe: 3 SOQL + 1 DML for N apps | B7 | three-layer engine | `bulk_200Applications_withinGovernorLimits` — 140/140 on `mortagate-de` | ✅ |
| NFR-2 | Mobile-first 375px, 100dvh per screen | B8 | all LWC CSS | manual | 🟡 |
| NFR-3 | WCAG 2.1 AA contrast; semantic colors as chips | ADR-9 | `veridactTokens.css`, chip classes | contrast math verified | ✅ |
| NFR-4 | Honor `prefers-reduced-motion` | DESIGN | token = 0s + component media queries | code review | ✅ |
| NFR-5 | No Salesforce chrome; full Veridact skin | B8 | brand tokens + component styling | manual | 🟡 |
| NFR-6 | Kernel unit-testable without an org | ADR-5 | pure `PolicyRuleEvaluator` | tests use in-memory rules, no DML — 140/140 on `mortagate-de` | ✅ |
| NFR-7 | Deterministic audit output | ADR-6 | `RuleCodeComparator` sort | code review + 140/140 on `mortagate-de` | ✅ |

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

## Gate Resolution Log

**R-1 (RESOLVED 2026-06-23):** `mortagate-de` authenticated, source deployed (piecewise strategy — see `DEPLOY-REPORT.md`), `RunLocalTests` = **140/140 Apex (100%)**, LWC Jest 53/53 (12 suites). FR-10–15,17 and NFR-1,6,7 now verified against the canonical `mortagate-de` org. Status flipped 🟡 → ✅.

**R-10 (OPEN):** Agentforce Copilot agent `Veridact_Auditor_Copilot_v4` is created and activated. Final action-wiring to `LoanDiagnosisService` requires Agent Builder 3-click handoff in Salesforce Setup UI. No code change required — configuration only.

**R-Leo (OPEN):** Plain-language (6th-grade) diagnosis copy, agent topic scope/instructions, and `c-glossary-term` tooltips are deployed. Leo persona re-test by UX panel pending.

**R-Compliance (PARTIAL):** CR-1 through CR-4 built and unit-tested. CR-5 (Adverse Action delivery + 30-day proof) is not built — requires HITL delivery mechanism and legal sign-off.
