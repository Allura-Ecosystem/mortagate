# EPICS AND STORIES — Mortgate

> [!NOTE]
> **AI-Assisted Documentation**
> Portions of this document were drafted with the assistance of an AI language model.
> Content has not yet been fully reviewed — this is a working design reference, not a final specification.
>
> Generated 2026-06-07 by Brooks (Party Mode: Knuth + Scout + Pike) from REQUIREMENTS-MATRIX.md,
> ENTERPRISE-READINESS-ROADMAP.md, and the verified codebase. ADR-11 records the planning decision.

---

## Epic Structure

This document decomposes the 26 requirements (FR-1..19, NFR-1..7, CR-1..5) into **6 epics**
across two horizons: **P0 (verify what exists)** and **P1–P5 (build what doesn't)**.

The P0 epic verifies the built codebase against a live org. P1–P5 are forward-looking —
their stories become actionable only after P0 closes.

| # | Epic | Phase | FRs Covered | Status |
|---|------|-------|-------------|--------|
| EP-0 | **Verify — Core Slice** | P0 | FR-1..19, NFR-1..7, CR-1..4 | 🟡 All code built; needs org verification |
| EP-1 | **Journey Orchestration + UX Hardening** | P0 | FR-1,2,3,4,6,7,8, NFR-2,5 | ⬜ Partially built (components exist, no orchestrator) |
| EP-2 | **Compliance** | P1 | CR-1..5, FR-19 | 🟡 Code built for CR-1..4; ⚖️ counsel sign-off pending |
| EP-3 | **Security & PII** | P2 | NFR-1,5,6 | ⬜ Not started |
| EP-4 | **Integrations** | P3 | CR-4, NFR-1,6 | ⬜ Requires vendor contracts |
| EP-5 | **Operational Readiness** | P4–P5 | NFR-1,2,6 | ⬜ Not started |

---

## EP-0: Verify — Core Slice

> **Goal:** Prove the existing build works end-to-end on `mortgate-de`. Every 🟡 flips to ✅.
> **Gate:** R-1 (`sf org login + deploy + apex run test`). Already green as of 2026-06-07 (53/53 Apex, 94% coverage, clean deploy preview).
> **Exit:** All stories below pass verification. The vertical slice is real.

### US-0.1: Verify Apex kernel runs clean against org
- **FRs:** FR-4,5,10,11,12,13,14,15,17
- **NFRs:** NFR-1,6,7
- **Acceptance:** `sf apex run test -l RunLocalTests --wait 30 --target-org mortgate-de` → 100% pass, coverage ≥ 85%
- **Evidence:** `PolicyRuleEvaluatorTest` (8), `LoanDecisionServiceTest` (bulk 200), `PreFlightEvaluatorTest`, `DecisionEventImmutabilityTest` (3), `PolicyRuleVersionHandlerTest` (7)
- **Dependency:** 🔑 org authenticated (DONE)
- **Status:** 🟡 → verify

### US-0.2: Verify LWC components render correctly
- **FRs:** FR-2,3,9
- **NFRs:** NFR-3,4
- **Acceptance:** `npm test -- --runInBand` → 10/10 pass (DONE). Manual: each screen renders on a real 375px device.
- **Evidence:** `intentCapture.test.js` (3), `outcomeView.test.js` (7)
- **Status:** ✅ Jest green; 🟡 manual device check pending

### US-0.3: Verify Decision Receipt PDF generates
- **FRs:** FR-18
- **Acceptance:** `DecisionReceiptControllerTest` (3) passes. Manual: PDF renders with Veridact branding, rule results table, "Every decision has a receipt" footer.
- **Evidence:** `DecisionReceiptControllerTest`, `DecisionReceipt.page`
- **Status:** 🟡

### US-0.4: Verify Adverse Action Notice PDF generates
- **FRs:** FR-19, CR-1..4
- **Acceptance:** `AdverseActionServiceTest` (13) and `AdverseActionNoticeControllerTest` (5) pass. Manual: notice includes specific reasons, ECOA §701(a), FCRA block.
- **Evidence:** `AdverseActionServiceTest`, `AdverseActionNoticeControllerTest`, `AdverseActionNotice.page`
- **Status:** 🟡 (code built; ⚖️ counsel sign-off is P1)

### US-0.5: Verify pre-check flow on device
- **FRs:** FR-4,5,6
- **Acceptance:** Tap through Welcome → Intent → Pre-Check on a real phone. Band displays. Email capture works. No Loan_Application__c created.
- **Evidence:** Manual walkthrough
- **Status:** 🟡

### US-0.6: Verify brand skin in Experience Cloud
- **NFRs:** NFR-3,5
- **Acceptance:** Zero Salesforce chrome visible in borrower flow. Veridact branding (Indigo Depth #1b2b5e, Proof Amber #d4920a, Source Serif 4 / Inter) applied. Semantic color chips pass WCAG ≥ 4.5:1.
- **Evidence:** `veridactTokens.css`, manual audit
- **Status:** 🟡

---

## EP-1: Journey Orchestration + UX Hardening

> **Goal:** Wire the 6 standalone LWC screens into one cohesive borrower journey with progress visibility,
> mobile-first verification, and test coverage. Addresses Pike's ❌ gate findings.
> **Source:** Pike UX Audit 2026-06-07; BLUEPRINT §B8; DESIGN-onboarding-ux.md
> **Dev harness:** See `EP-1-dev-context.md` and `stories/US-1.*.md` for full story files.

### US-1.0: Migrate brand to Figma Kit v1.0.1 (ADR-13)
- **NFRs:** NFR-3, NFR-5
- **Acceptance:** veridactTokens.css updated to v2.0.0 (Cream/Charcoal/Orange/Outfit). All 6 LWC CSS files migrated from dark to light paradigm. WCAG AA re-verified. `npm run test:unit` passes.
- **Evidence:** WCAG contrast ratios documented in DESIGN-onboarding-ux.md § Visual Direction
- **Dependency:** None — blocks all other EP-1 visual work
- **Status:** ✅ Executed 2026-06-11

### US-1.1: Build `c-onboarding-orchestrator` host component
- **FRs:** FR-1,2,3,4,6,7,8
- **Acceptance:**
  - Manages 6-screen state machine: Welcome → Intent → PreCheck → EvidenceQueue → DecisionRoom → Outcome
  - Captures `intentcaptured` event → creates Loan_Application__c via Apex → passes ID to downstream components
  - Tracks current step; exposes step index to child components for progress indicator
  - Handles email capture at PreCheck → triggers account creation
  - Fires LoanDecisionService on EvidenceQueue completion
- **Evidence:** Jest tests for state transitions, error paths, and event propagation
- **Status:** ⬜

### US-1.2: Add progress indicator to all screens
- **FRs:** FR-1,2,4,7,8
- **NFRs:** NFR-2
- **Acceptance:** Every screen shows "Step X of 6: {Step Name}" or visual track (Intent → Documents → Review → Decision). At 375px, indicator is visible without scroll. Uses SLDS tokens (no hardcoded colors).
- **Evidence:** Jest snapshot tests for each screen; manual at 375px
- **Status:** ⬜

### US-1.3: Write Jest tests for untested LWCs
- **Components:** `welcomeGate`, `preCheckResult`, `evidenceQueue`, `decisionRoom`
- **Acceptance:** Minimum: renders with correct title, calls Apex and displays results (wire mock), dispatches event on button click, shows error state on Apex failure. 3-4 tests per component.
- **Evidence:** `welcomeGate.test.js`, `preCheckResult.test.js`, `evidenceQueue.test.js`, `decisionRoom.test.js`
- **Status:** ⬜

### US-1.4: Verify mobile-first at 375px
- **NFRs:** NFR-2
- **Acceptance:** All 6 screens render correctly at 375px viewport. No horizontal scroll. Touch targets ≥ 44px. Text readable without zoom. Tested on Chrome DevTools + one real device.
- **Evidence:** Screenshot set; manual audit notes
- **Status:** ⬜

### US-1.5: Audit Experience Cloud chrome removal
- **NFRs:** NFR-5
- **Acceptance:** Zero Salesforce header, footer, or branding visible in the borrower site. Only Veridact tokens. Guest user sees Welcome Gate without login wall.
- **Evidence:** Screenshots of guest and authenticated views
- **Status:** ⬜

### US-1.6: Build `Mortagate_Borrower_Journey` Screen Flow
- **FRs:** FR-1..9 (orchestration)
- **Acceptance:** Screen Flow wraps the 6 LWC screens in sequence. Fault connectors on every DML element. Validated at 200-record bulk. Activates without errors.
- **Evidence:** Flow XML deployed; manual walkthrough; 200-record bulk test
- **Status:** ⬜

### US-1.7: Build HITL Decision-Promotion Flow
- **FRs:** FR-14,15
- **Acceptance:** Internal Flow for underwriter/loan officer to promote a PENDING_REVIEW to APPROVED or HARD_DECLINED. Creates new Decision_Event__c (Triggered_By__c = UNDERWRITER), never edits existing. Fault connectors on all DML. Validated at 200 records.
- **Evidence:** Flow XML deployed; bulk test
- **Status:** ⬜

---

## EP-2: Compliance (P1)

> **Goal:** Close the compliance surface so the system can legally deliver a decision to a real applicant.
> **Critical path:** ⚖️ counsel sign-off (CR-5 + review of CR-1..4 wording). Code half is built; legal half is not.
> **Do NOT deliver to real applicants before all ⚖️ gates clear.**

### US-2.1: Counsel review of adverse action wording
- **CRs:** CR-1,2,3,5
- **Acceptance:** Qualified lending counsel signs off that: (a) specific reasons from `Rule_Explanation__c` satisfy 12 CFR 1002.9(b)(2); (b) ECOA §701(a) notice wording is correct; (c) creditor name/address/statement format meets 1002.9(a)(2)(i).
- **Evidence:** Signed review document; any required wording changes applied to `Adverse_Action_Config__mdt`
- **Dependency:** ⚖️ legal
- **Status:** ⬜

### US-2.2: Implement delivery + proof-of-delivery for adverse action
- **CRs:** CR-5
- **Acceptance:** Adverse Action Notice is delivered (email + portal) within 30 days of a decline decision. Delivery timestamp, method, and recipient recorded on Decision_Event__c or a new Delivery_Receipt__c custom object. Proof is retrievable for audit.
- **Evidence:** Delivery record visible in Decision Room timeline; audit query returns delivery proof
- **Dependency:** 🔑 HITL step; ⚖️ counsel sign-off on delivery method
- **Status:** ⬜

### US-2.3: Integrate consumer reporting agency identity
- **CRs:** CR-4
- **Acceptance:** `Adverse_Action_Config__mdt` populated with the CRA's name, address, and toll-free number. `buildScoreDisclosure()` renders the complete FCRA-required text. Config is editable by legal without a deployment.
- **Evidence:** Controller test updated with real CRA identity; rendered notice includes correct CRA block
- **Dependency:** 🤝 vendor contract (credit bureau); ⚖️ legal approval of CRA listing
- **Status:** ⬜

### US-2.4: Fair lending / disparate-impact review
- **Acceptance:** The rule set (`Policy_Rule_Version__c`) is reviewed; no rule uses a prohibited basis (race, color, religion, national origin, sex, marital status, age, receipt of public assistance). Documented in a compliance memo.
- **Evidence:** Review memo; rule set annotated with compliance notes
- **Dependency:** ⚖️ legal
- **Status:** ⬜

### US-2.5: HMDA data capture fields
- **Acceptance:** Required HMDA fields (property location, loan purpose, applicant demographics, action taken, etc.) are added to Loan_Application__c or a new HMDA_Record__c object. Fields align with CFPB filing requirements.
- **Evidence:** Updated DATA-DICTIONARY.md; field deployment
- **Dependency:** ⚖️ legal (specification of required fields)
- **Status:** ⬜

### US-2.6: GLBA safeguards + consent capture
- **Acceptance:** Privacy notice displayed; borrower consent captured before PII collection. Record retention schedule documented. Safeguards policy exists.
- **Evidence:** Consent record on Loan_Application__c; privacy notice page; safeguards document
- **Dependency:** ⚖️ legal (policy + wording)
- **Status:** ⬜

### US-2.7: State lending licensing review
- **Acceptance:** Applicability review determines which state licenses are required for the platform's lending model. Documented in RISKS-AND-DECISIONS.md (ADR).
- **Evidence:** Licensing memo; ADR entry
- **Dependency:** ⚖️ legal
- **Status:** ⬜

---

## EP-3: Security & PII (P2)

> **Goal:** Harden the system for production. Permission sets, encryption, FLS audit, secrets management.
> **Cannot begin until P0 exits (verified codebase).**

### US-3.1: Implement least-privilege permission model
- **Acceptance:** Permission sets for: Borrower (Community), Loan Officer, Underwriter, Admin, Guest (unauthenticated). Each has minimum CRUD + FLS for its role. Guest can only read welcome page + invoke PreFlightController. No profile grants more than needed.
- **Evidence:** Permission set XMLs deployed; access tested per role
- **Dependency:** 🧱 code
- **Status:** ⬜

### US-3.2: Encrypt PII at rest
- **Acceptance:** SSN, income, asset fields encrypted via Shield Platform Encryption (or equivalent). Key management documented.
- **Evidence:** Encryption enabled and verified on target fields
- **Dependency:** 🤝 Shield licensing (paid SKU)
- **Status:** ⬜

### US-3.3: FLS/CRUD audit across all Apex
- **Acceptance:** Every Apex class that reads or writes SObjects enforces FLS/CRUD (not just `with sharing`). Audit report produced. Gaps closed.
- **Evidence:** Audit report; updated Apex with explicit `Schema.sObjectType` checks or `WITH USER_MODE`
- **Dependency:** 🧱 code
- **Status:** ⬜

### US-3.4: Configure Named Credentials for callouts
- **Acceptance:** All external callouts use Named Credentials (not hardcoded endpoints or secrets in Apex). Secrets managed via Salesforce's secure store.
- **Evidence:** Named Credential records; Apex updated to use `callout:` prefix
- **Dependency:** 🧱 code
- **Status:** ⬜

---

## EP-4: Integrations (P3)

> **Goal:** Connect the engine to real data sources. Today facts are seeded; real systems fetch them.
> **Critical path:** 🤝 vendor contracts. All stories in this epic are blocked until vendors are selected and contracted.

### US-4.1: Credit bureau pull
- **CRs:** CR-4
- **Acceptance:** `FactAssemblerService` (or a new `CreditBureauService`) fetches FICO score + tradeline data from Experian/Equifax/TransUnion via API. Facts populate `Extracted_Facts__c` automatically. Error handling for bureau unavailability.
- **Dependency:** 🤝 vendor contract; 🧱 callout code
- **Status:** ⬜

### US-4.2: Income/asset verification
- **Acceptance:** Income + asset data fetched from Plaid/AccountChek/The Work Number. Populates `Extracted_Facts__c` (Annual_Income__c, Asset_Value__c, Employment_Months__c).
- **Dependency:** 🤝 vendor contract; 🧱 callout code
- **Status:** ⬜

### US-4.3: Document extraction (OCR/AI)
- **NFRs:** NFR-1,6
- **Acceptance:** Uploaded paystubs, W-2s, bank statements auto-extract facts. Extraction_Confidence__c recorded per fact. Failed extractions route to manual review.
- **Dependency:** 🤝 vendor contract (OCR/AI); 🧱 integration code
- **Status:** ⬜

### US-4.4: E-Sign integration
- **Acceptance:** Borrower signs disclosures and final loan documents via DocuSign/Adobe Sign. Signature status tracked on a new ESign_Event__c object.
- **Dependency:** 🤝 vendor contract; 🧱 API integration
- **Status:** ⬜

### US-4.5: LOS / core integration
- **Acceptance:** Loan_Application__c, Decision_Event__c, and Evidence__c sync to/from the core Loan Origination System (nCino in-org or Fiserv via API/ETL). Bidirectional sync with conflict resolution.
- **Dependency:** 🤝 vendor contract; 🧱 integration code
- **Status:** ⬜

---

## EP-5: Operational Readiness (P4–P5)

> **Goal:** Make the system observable, recoverable, and shippable through a gated pipeline.

### US-5.1: CI/CD pipeline
- **Acceptance:** GitHub Actions (or equivalent) pipeline: lint → scratch-org create → deploy → apex run test → gate check. Branch strategy: feature/ → main. Unlocked package packaging.
- **Evidence:** Pipeline YAML; successful pipeline run
- **Dependency:** 🧱 code
- **Status:** ⬜

### US-5.2: Logging and error framework
- **Acceptance:** Nebula Logger or platform-event logging framework deployed. All Apex catches log errors with correlation IDs. Errors surface in a monitoring dashboard. No silent failures.
- **Evidence:** Logger deployment; error event visible in monitoring
- **Dependency:** 🧱 code
- **Status:** ⬜

### US-5.3: Accessibility audit (axe + screen reader)
- **NFRs:** NFR-2
- **Acceptance:** Full axe-core audit of all 6 screens. Screen reader (VoiceOver/NVDA) walkthrough. All violations at WCAG 2.1 AA fixed.
- **Evidence:** axe report; screen reader audit notes
- **Dependency:** 🧱 code
- **Status:** ⬜

### US-5.4: Disaster recovery plan
- **Acceptance:** DR plan documented: backup schedule, RPO/RTO targets, restoration procedure. Runbook exists for common failure scenarios.
- **Evidence:** DR document; one successful DR drill
- **Dependency:** 🔑 human (runbook approval)
- **Status:** ⬜

---

## Traceability Matrix

Every requirement traces to at least one story.

| ID | Story | Epic |
|----|-------|------|
| FR-1 | US-0.2, US-1.1, US-1.2, US-1.6 | EP-0, EP-1 |
| FR-2 | US-0.2, US-1.1, US-1.2, US-1.6 | EP-0, EP-1 |
| FR-3 | US-0.2, US-1.1, US-1.6 | EP-0, EP-1 |
| FR-4 | US-0.1, US-0.5, US-1.1, US-1.6 | EP-0, EP-1 |
| FR-5 | US-0.1, US-0.5 | EP-0 |
| FR-6 | US-0.5, US-1.1, US-1.6 | EP-0, EP-1 |
| FR-7 | US-1.1, US-1.2, US-1.6 | EP-1 |
| FR-8 | US-1.1, US-1.2, US-1.6 | EP-1 |
| FR-9 | US-0.2, US-1.6 | EP-0, EP-1 |
| FR-10 | US-0.1 | EP-0 |
| FR-11 | US-0.1 | EP-0 |
| FR-12 | US-0.1 | EP-0 |
| FR-13 | US-0.1 | EP-0 |
| FR-14 | US-0.1, US-1.7 | EP-0, EP-1 |
| FR-15 | US-0.1 | EP-0 |
| FR-16 | (starter rules, verified at JSON) | EP-0 |
| FR-17 | US-0.1 | EP-0 |
| FR-18 | US-0.3 | EP-0 |
| FR-19 | US-0.4, US-2.1, US-2.2, US-2.3 | EP-0, EP-2 |
| NFR-1 | US-0.1, US-4.3 | EP-0, EP-4 |
| NFR-2 | US-1.2, US-1.4, US-5.3 | EP-1, EP-5 |
| NFR-3 | US-0.2, US-0.6 | EP-0 |
| NFR-4 | US-0.2 | EP-0 |
| NFR-5 | US-0.6, US-1.5 | EP-0, EP-1 |
| NFR-6 | US-0.1, US-4.3 | EP-0, EP-4 |
| NFR-7 | US-0.1 | EP-0 |
| CR-1 | US-0.4, US-2.1 | EP-0, EP-2 |
| CR-2 | US-0.4, US-2.1 | EP-0, EP-2 |
| CR-3 | US-0.4, US-2.1 | EP-0, EP-2 |
| CR-4 | US-0.4, US-2.3, US-4.1 | EP-0, EP-2, EP-4 |
| CR-5 | US-2.1, US-2.2 | EP-2 |

---

## Cross-References

- [BLUEPRINT](BLUEPRINT.md) — B#/F# requirements and screen specifications
- [REQUIREMENTS-MATRIX](REQUIREMENTS-MATRIX.md) — FR/CR/NFR status and traceability
- [SOLUTION-ARCHITECTURE](SOLUTION-ARCHITECTURE.md) — Layered view and component topology
- [RISKS-AND-DECISIONS](RISKS-AND-DECISIONS.md) — ADR-11 (this planning decision) and R-1..7
- [DATA-DICTIONARY](DATA-DICTIONARY.md) — SObject field reference
- [ENTERPRISE-READINESS-ROADMAP](ENTERPRISE-READINESS-ROADMAP.md) — P0–P5 phase breakdown
- [DESIGN-onboarding-ux](DESIGN-onboarding-ux.md) — Screen designs and UX principles
- [DESIGN-policy-engine](DESIGN-policy-engine.md) — Three-layer kernel architecture
- [DESIGN-adverse-action](DESIGN-adverse-action.md) — ECOA/Reg B composition design

---

## Dependencies by Phase

| Phase | Theme | Hardest Dependency | Rough Size |
|-------|-------|--------------------|------------|
| EP-0 | Verify the slice | 🔑 org authenticated (DONE) | Days (verification) |
| EP-1 | Journey + UX | 🧱 orchestrator build | 1–2 weeks |
| EP-2 | Compliance | ⚖️ counsel sign-off | Weeks–months |
| EP-3 | Security | 🤝 Shield licensing | Weeks |
| EP-4 | Integrations | 🤝 vendor contracts | Months |
| EP-5 | Operations | 🧱 CI/CD + DR | Weeks |

---

## Appendix: Pike UX Audit Findings (2026-06-07)

Incorporated into EP-1 stories. Summary of ❌ gate failures:

1. **No progress indicator** — violates B8 Principle 4. → US-1.2
2. **No journey orchestrator** — 6 standalone LWCs, no host to manage state transitions. → US-1.1
3. **Only 2/6 LWCs tested** — welcomeGate, preCheckResult, evidenceQueue, decisionRoom have zero Jest tests. → US-1.3
4. **Mobile-first unverified** — no responsive testing at 375px. → US-1.4
5. **Salesforce chrome not audited** — can't verify from LWC source alone. → US-1.5

6. **No Screen Flow** — the borrower journey has no Flow wrapping the LWCs. → US-1.6
7. **No HITL Flow** — underwriter promotion path not built. → US-1.7
