---
stepsCompleted: ['step-01-document-discovery', 'step-02-prd-analysis', 'step-03-epic-coverage-validation', 'step-04-ux-alignment', 'step-05-epic-quality-review', 'step-06-final-assessment']
documentsIncluded:
  prd:
    - BLUEPRINT.md
    - REQUIREMENTS-MATRIX.md
  architecture:
    - SOLUTION-ARCHITECTURE.md
    - DESIGN-policy-engine.md
    - DESIGN-adverse-action.md
    - DATA-DICTIONARY.md
    - RISKS-AND-DECISIONS.md
  ux:
    - DESIGN-onboarding-ux.md
  epics_stories: []
---

# Implementation Readiness Assessment Report

**Date:** 2026-06-06
**Project:** Mortage (Salesforce Community Mortgage Approval Engine)

---

## Step 1 — Document Discovery

> **Note on document standard:** This project follows the **Carlos documentation standard**
> (BLUEPRINT / SOLUTION-ARCHITECTURE / DESIGN-* / REQUIREMENTS-MATRIX / RISKS-AND-DECISIONS /
> DATA-DICTIONARY), not the BMAD PRD/Epics format. The BMAD planning-artifacts and docs/
> folders are empty. The inventory below maps the Carlos artifacts onto the four document
> types this assessment validates.

### A. PRD (Product Requirements) — mapped from Carlos requirements docs
**Whole Documents:**
- `BLUEPRINT.md` — product vision, business requirements, B-series stories, screen specs
- `REQUIREMENTS-MATRIX.md` — FR-1..19, NFR-1..7, CR-1..5 traceability → implementation → verification

**Sharded Documents:** none

### B. Architecture
**Whole Documents:**
- `SOLUTION-ARCHITECTURE.md` — topology, layering, interfaces
- `DESIGN-policy-engine.md` — three-layer kernel design (FactAssembler → PolicyRuleEvaluator → DecisionCommitService)
- `DESIGN-adverse-action.md` — ECOA/Reg B + FCRA notice composition design
- `DATA-DICTIONARY.md` — object/field-level definitions
- `RISKS-AND-DECISIONS.md` — ADR-1..10 + Risk register R-1..7

**Sharded Documents:** none

### C. Epics & Stories
**Whole Documents:** ⚠️ **NONE FOUND**
**Sharded Documents:** none

### D. UX Design
**Whole Documents:**
- `DESIGN-onboarding-ux.md` — onboarding/intake UX design
- (UX requirements also embedded in `BLUEPRINT.md` B3 screen specs)

**Sharded Documents:** none

---

### Critical Issues

⚠️ **WARNING — No Epics & Stories document exists.**
This is the central artifact this readiness check validates (epic/story coverage of PRD,
UX, and Architecture before Phase-4 implementation). The project tracks work via
requirement IDs (FR/NFR/CR) and the ENTERPRISE-READINESS-ROADMAP phases (P0–P5) rather
than a formal epic/story backlog. The assessment can proceed using requirement IDs and
roadmap phases as a proxy backlog, but **true epic/story-level readiness cannot be scored**
until an epics document is created.

⚠️ **WARNING — Verification gate R-1 is open.** Per REQUIREMENTS-MATRIX and
RISKS-AND-DECISIONS, ~30 Apex tests are written but never executed against an org; only the
10 LWC Jest tests run green. This caps any "ready to implement → verified" claim.

✅ **No duplicate (whole + sharded) document conflicts found.**

---

## Step 2 — PRD Analysis

> Source: `REQUIREMENTS-MATRIX.md` (authoritative numbered list) + `BLUEPRINT.md`
> (vision, B1–B9 screen/journey/engine specs). The matrix is the canonical FR/NFR/CR registry.

### Functional Requirements (from REQUIREMENTS-MATRIX)

- **FR-1** Welcome gate: one sentence, one button, no login wall — `lwc/welcomeGate` (🟡 manual)
- **FR-2** Intent capture: 3 questions, one-at-a-time, slide animation — `lwc/intentCapture` (✅ Jest)
- **FR-3** No fake default answers; Continue gated on real input — `intentCapture` touched-flags (✅ Jest)
- **FR-4** Soft pre-check produces eligibility band, no record created — `PreFlightEvaluator/Controller`, `lwc/preCheckResult` (🟡)
- **FR-5** Pre-check uses the same kernel as the full decision — `PreFlightEvaluator` (🟡)
- **FR-6** Progressive identity: email only after value shown — `preCheckResult` emailcaptured (🟡 manual)
- **FR-7** Evidence queue: one document at a time, human messages — `lwc/evidenceQueue` (🟡 manual)
- **FR-8** Decision room timeline; pending is not a bare empty — `lwc/decisionRoom` (🟡 manual)
- **FR-9** Outcome: approved shows amount; declined never says "denied" + reason — `lwc/outcomeView` (✅ Jest)
- **FR-10** Policy evaluation against versioned rules — `PolicyRuleEvaluator` (🟡)
- **FR-11** All 8 operators supported — `PolicyRuleEvaluator.evaluateOperator` (🟡)
- **FR-12** Verdict precedence worst-wins — `PolicyRuleEvaluator.deriveVerdict` (🟡)
- **FR-13** Missing fact → INDETERMINATE, never decline — `PolicyRuleEvaluator` (🟡)
- **FR-14** Decision events append-only — `DecisionEventImmutabilityTrigger` (🟡)
- **FR-15** Full receipt persisted (`Rule_Results_JSON__c`) — `DecisionCommitService` (🟡)
- **FR-16** Starter kernel rule set exists — `data/Policy_Rule_Version__c.json` (6 rules) (✅)
- **FR-17** Rules maintainable by non-developers (versioning) — `PolicyRuleVersionHandler` + trigger (🟡)
- **FR-18** "Every decision has a receipt" — `DecisionReceipt.page` (pdf) + controller; `outcomeView` viewreceipt (🟡)
- **FR-19** Adverse Action Notice on decline — `AdverseActionService` + controller + page + CMDT; `outcomeView` viewnotice (🟡)

**Total FRs: 19** (✅ verified: 4 — FR-2,3,9,16 · 🟡 built-not-run: 15)

### Non-Functional Requirements

- **NFR-1** Bulk safe: 3 SOQL + 1 DML for N apps — three-layer engine (🟡)
- **NFR-2** Mobile-first 375px, 100dvh per screen — all LWC CSS (🟡 manual)
- **NFR-3** WCAG 2.1 AA contrast; semantic colors as chips — `veridactTokens.css` (✅)
- **NFR-4** Honor `prefers-reduced-motion` — token + media queries (✅)
- **NFR-5** No Salesforce chrome; full Veridact skin — brand tokens (🟡 manual)
- **NFR-6** Kernel unit-testable without an org — pure `PolicyRuleEvaluator` (🟡)
- **NFR-7** Deterministic audit output — `RuleCodeComparator` sort (🟡)

**Total NFRs: 7** (✅ verified: 2 — NFR-3,4 · 🟡: 5)

### Compliance Requirements (P1)

- **CR-1** Specific principal reasons (not boilerplate) — 12 CFR 1002.9(b)(2) (🟡)
- **CR-2** Verbatim ECOA §701(a) notice + oversight agency — 12 CFR 1002.9(b)(1) (🟡)
- **CR-3** Creditor name+address; statement of action — 12 CFR 1002.9(a)(2)(i) (🟡)
- **CR-4** FCRA score disclosure when consumer report used — 15 U.S.C. 1681m (🟡)
- **CR-5** Delivery + proof within 30 days; legal sign-off — 12 CFR 1002.9(a)(1) (⬜ not built)

**Total CRs: 5** (🟡: 4 · ⬜ not built: 1)

### Additional Requirements & Constraints (from BLUEPRINT)

- **B2 Design Principles** (7): mobile-first; one-thing-per-screen; three-states; no-SF-chrome; append-only audit; rules-as-data; structured-facts-not-EAV.
- **B4 Data invariants:** Decision_Event__c no UPDATE/DELETE; Policy_Rule_Version__c immutable after reference; only one active version per Rule_Code__c.
- **B6 schema:** Policy_Rule_Version__c has 17 fields incl. `Regulatory_Citation__c`, `Override_Permitted__c`, `Supersedes__c`.
- **B7 Bulk contract:** 3 SOQL + 1 DML for N applications (→ NFR-1).
- **B8 UX non-negotiables** (7): one-thing-per-screen; mobile-first; no chrome; progress always visible (4 steps); every-error-human; zero dead ends; status always visible.

### Open Questions (B9 — unresolved, block full readiness)

- **OQ-1** Decision latency: sync vs async? (Owner: Brooks)
- **OQ-2** Document extraction: Apex OCR / external AI / manual? (Owner: Woz)
- **OQ-3** Platform Events feasible in Dev Edition? (Owner: Hightower)
- **OQ-4** FSC availability in Dev Edition? (Owner: Sabir)

### PRD Completeness Assessment

**Strengths:** The PRD is unusually rigorous for a POC — every requirement is numbered,
traced to a named implementation artifact, and carries a verification method and a status
flag. Compliance requirements are grounded in cited regulation. Data invariants and the
bulk-safety contract are explicit and testable.

**Gaps for implementation readiness:**
1. **No epic/story decomposition** — requirements exist but are not organized into
   implementable, sequenced units of work with acceptance criteria. (Carried from Step 1.)
2. **4 open questions (OQ-1..4)** remain unresolved; OQ-1/OQ-2 materially affect
   architecture (latency model, extraction pipeline) and are not yet decided.
3. **Verification is aspirational** — 15 of 19 FRs and 5 of 7 NFRs are 🟡 "built, not run"
   pending Gate R-1 (org auth + Apex test execution).
4. **CR-5 (delivery + proof + legal sign-off) is ⬜ not built** and is a hard regulatory
   blocker for a real lending decision.

---

## Step 3 — Epic Coverage Validation

> **Structural finding:** There is **no Epics & Stories document** in this project, so there
> is no FR→Epic→Story mapping to extract. Epic-level coverage is therefore **0% by the BMAD
> definition**. However, the project maintains direct **FR→Implementation→Verification**
> traceability in `REQUIREMENTS-MATRIX.md`, which is the proxy used below. Read every "Epic
> Coverage" cell as "NOT FOUND (no epics doc)"; the value lives in the Implementation column.

### FR Coverage Analysis (epic vs. implementation-proxy)

| FR | Epic Coverage | Implementation (proxy) | Status |
|----|---------------|------------------------|--------|
| FR-1 | ❌ NOT FOUND | `lwc/welcomeGate` | 🟡 impl, no epic |
| FR-2 | ❌ NOT FOUND | `lwc/intentCapture` (Jest ✅) | 🟡 impl, no epic |
| FR-3 | ❌ NOT FOUND | `intentCapture` touched-flags (Jest ✅) | 🟡 impl, no epic |
| FR-4 | ❌ NOT FOUND | `PreFlightEvaluator/Controller`, `lwc/preCheckResult` | 🟡 impl, no epic |
| FR-5 | ❌ NOT FOUND | `PreFlightEvaluator` | 🟡 impl, no epic |
| FR-6 | ❌ NOT FOUND | `preCheckResult` emailcaptured | 🟡 impl, no epic |
| FR-7 | ❌ NOT FOUND | `lwc/evidenceQueue` | 🟡 impl, no epic |
| FR-8 | ❌ NOT FOUND | `lwc/decisionRoom` | 🟡 impl, no epic |
| FR-9 | ❌ NOT FOUND | `lwc/outcomeView` (Jest ✅) | 🟡 impl, no epic |
| FR-10 | ❌ NOT FOUND | `PolicyRuleEvaluator` | 🟡 impl, no epic |
| FR-11 | ❌ NOT FOUND | `PolicyRuleEvaluator.evaluateOperator` | 🟡 impl, no epic |
| FR-12 | ❌ NOT FOUND | `PolicyRuleEvaluator.deriveVerdict` | 🟡 impl, no epic |
| FR-13 | ❌ NOT FOUND | `PolicyRuleEvaluator` (INDETERMINATE) | 🟡 impl, no epic |
| FR-14 | ❌ NOT FOUND | `DecisionEventImmutabilityTrigger` | 🟡 impl, no epic |
| FR-15 | ❌ NOT FOUND | `DecisionCommitService` | 🟡 impl, no epic |
| FR-16 | ❌ NOT FOUND | `data/Policy_Rule_Version__c.json` (✅) | 🟡 impl, no epic |
| FR-17 | ❌ NOT FOUND | `PolicyRuleVersionHandler` + trigger | 🟡 impl, no epic |
| FR-18 | ❌ NOT FOUND | `DecisionReceipt.page` + controller | 🟡 impl, no epic |
| FR-19 | ❌ NOT FOUND | `AdverseActionService` + controller + page + CMDT | 🟡 impl, no epic |

### Missing Requirements

**Critical structural gap — ALL 19 FRs lack an epic/story home.**
- **Impact:** Without epics/stories, there is no sequenced, acceptance-criteria-bearing plan
  of work. New contributors cannot pick up a unit of work; "done" is defined per-FR by the
  matrix's verification column rather than by story-level acceptance criteria; and there is
  no dependency ordering for the unbuilt items (e.g. CR-5 delivery, P3 integrations).
- **Recommendation:** Generate an epics/stories document (e.g. via
  `bmad-create-epics-and-stories`) that groups the 19 FRs + 7 NFRs + 5 CRs into epics aligned
  to the existing `ENTERPRISE-READINESS-ROADMAP` phases (P0 verify · P1 compliance ·
  P2 security/PII · P3 integrations · P4 data model · P5 ops), with acceptance criteria.

**No orphan epics** (FRs in epics but not PRD): N/A — no epics exist.

### Coverage Statistics

- Total PRD FRs: **19**
- FRs covered in an epic/story: **0** → **Epic coverage: 0%**
- FRs with a traceable implementation artifact (proxy): **19** → **Implementation traceability: 100%**
- FRs with executed verification: **4** (FR-2, FR-3, FR-9, FR-16 via Jest) → **Verified: ~21%**

> Interpretation: this is a codebase that is **implementation-complete on the vertical slice
> but planning-incomplete** — the work was built directly from a requirements matrix without
> an intervening epic/story layer. That inverts the usual readiness question: the risk is not
> "will it get built" but "is the built thing planned, sequenced, and verifiable as discrete
> units."

---

## Step 4 — UX Alignment Assessment

### UX Document Status

**FOUND.** `DESIGN-onboarding-ux.md` (component-level specs for `c-intent-capture`,
`c-evidence-queue`, `c-pre-check-result`; screen-flow summary; Glaser visual direction;
error-state table) + UX requirements embedded in `BLUEPRINT.md` B3 (6 screens) and B8
(7 non-negotiables). This is a user-facing application — UX is required, and it is present
and unusually detailed for a POC.

### UX ↔ PRD Alignment

| UX element | PRD anchor | Aligned? |
|---|---|---|
| 6-screen flow (Welcome→Intent→Pre-Check→Evidence→Decision Room→Outcome) | B3 + FR-1,2,4,7,8,9 | ✅ |
| Intent capture 3-question slide flow + `intentcaptured` event | FR-2, FR-3 | ✅ |
| Pre-check band, email after value, no record | FR-4, FR-5, FR-6 | ✅ |
| Evidence queue one-at-a-time + human messages | FR-7 | ✅ |
| Decision Room timeline + pending heartbeat | FR-8 | ✅ |
| Outcome: approved amount / declined never "denied" + reason | FR-9 | ✅ |
| WCAG chip colors, amber discipline, reduced-motion | NFR-3, NFR-4, ADR-9 | ✅ |
| "Document 2 of 4" orientation, amber accent bar | B8 (progress always visible) | ✅ |

**UX requirements NOT in PRD FRs (additive — candidate new FRs):**
- **Confirm/correct extracted facts inline** ("We found: Annual income $120,000" + confirm)
  — `c-evidence-queue` spec, not a numbered FR.
- **Resilience error states** — session timeout resume, network-offline auto-sync,
  extraction-failure re-upload — specified in the UX error table but not tracked as FRs/NFRs.
- These match the "4 UX gaps" surfaced in the prior product review (silent save-and-return,
  progress affordance, quiet human touchpoint, promise-bearing welcome copy) — **partially
  designed, not yet promoted to requirements or stories.**

### UX ↔ Architecture Alignment

| UX assumption | Architecture support | Status |
|---|---|---|
| `PreFlightEvaluator.evaluate(List<PreFlightRequest>)` invocable | B5 Pre-Flight Evaluator (INCOME+COLLATERAL subset, no record) | ✅ matches |
| Evidence extraction via Platform Event / after-save Flow → `Extracted_Facts__c` | **OQ-2 undecided** (Apex OCR vs external AI vs manual) | ⚠️ assumes an unbuilt pipeline |
| `c-evidence-queue` polls/subscribes for facts | **OQ-2 / OQ-3** | ⚠️ depends on extraction + event model |
| Decision Room "updates in real time" | **OQ-3 undecided** (Platform Events in Dev Edition); fallback = polling (R-2 mitigated) | ⚠️ degrades gracefully but real-time not guaranteed |
| Locked Figma brand kit `pObIwaZXpTy5cL57uzF7Ta` | referenced; brand tokens implemented in `veridactTokens.css` | ✅ (asset external) |

### Alignment Issues

1. **Two UX flows ride on undecided architecture (OQ-2, OQ-3).** The Evidence Queue's
   "extract → show facts → confirm" loop and the Decision Room's "real-time timeline" are
   designed as if the extraction pipeline and Platform-Event delivery exist. They are open
   questions. UX should not be considered implementation-ready for those two screens until
   OQ-2/OQ-3 are resolved (or the polling/manual fallbacks are explicitly adopted as the v1 path).
2. **Additive UX behaviors lack requirement IDs.** Fact-confirmation and the resilience
   error states are real, valuable, and designed — but invisible to the FR/NFR matrix, so
   they have no verification path and no story.

### Warnings

- ⚠️ UX is **design-ready** but **not story-ready**: no acceptance criteria exist for any
  screen (same root cause as Step 3 — no epics/stories doc).
- ⚠️ The Evidence Queue and Decision Room screens are **blocked on OQ-2/OQ-3**; building
  them now risks rework when the extraction/event decisions land.

---

## Step 5 — Epic Quality Review

> **Cannot perform the standard review:** there are no epics or stories to validate against
> the create-epics-and-stories standards (no user-value check, no independence test, no AC
> review, no dependency map are possible without artifacts). Below, the *de facto* structure
> the project uses in place of epics — the `ENTERPRISE-READINESS-ROADMAP` phases P0–P5 — is
> assessed against the same best-practice rules, so the finding is actionable.

### De facto "epics" = roadmap phases — best-practice assessment

| Phase (as proxy epic) | User value? | Independent? | Verdict |
|---|---|---|---|
| **P0 Verify what exists** | ❌ none (it's a verification milestone) | n/a | 🔴 Not a valid epic — technical milestone |
| **P1 Compliance (Adverse Action, Fair Lending, HMDA, GLBA)** | ✅ (applicant gets a lawful decision + notice) | partial — needs P0 verified slice | 🟠 Valid value, but entangled with P0 + external legal |
| **P2 Security & PII** | 🟠 indirect (trust/safety, not a feature the borrower "does") | needs P0 | 🟠 Borderline — enabling, not user-facing |
| **P3 Integrations (bureau, income, docs, e-sign)** | ✅ (decision on real fetched facts) | needs P0–P2 | 🟠 Valid value, heavy vendor dependency |
| **P4 Data model depth (co-borrower, joint)** | ✅ (a household can apply together) | needs P0, P3 | ✅ Closest to a clean user-value epic |
| **P5 Ops / CI-CD / monitoring** | ❌ none (operational) | needs all | 🔴 Not a valid epic — infrastructure |

### Findings by severity

#### 🔴 Critical
- **No epics/stories exist** — the artifact this entire workflow validates is absent.
  Implementation-readiness in the BMAD sense **cannot be certified**.
- **The proxy structure is phase/technical-milestone-oriented, not user-value-oriented.**
  P0 (verify) and P5 (ops) are pure technical milestones; if promoted to epics as-is they
  would violate the user-value rule. The roadmap is a good *program plan* but a poor
  *epic backlog* — it sequences engineering work, not shippable user outcomes.
- **Forward/aggregate dependencies are pervasive in the proxy.** Nearly every phase depends
  on P0 (the R-1 org gate). That single unmet dependency makes the whole chain blocked —
  exactly the "Epic N requires Epic N+1" anti-pattern, here as "everything requires P0."

#### 🟠 Major
- **No acceptance criteria anywhere.** Requirements have verification *methods* (Jest /
  Apex test names) but no story-level Given/When/Then ACs, so "done" is defined at the test
  level, not the user-outcome level.
- **UX additive behaviors (fact confirmation, resilience states) have no story or AC** (from Step 4).
- **CR-5 (delivery + proof + legal sign-off)** has no owning story and is a release blocker.

#### 🟡 Minor
- The starter rule set (FR-16) and the pure kernel exist, so an eventual "Epic 1" would
  *not* be a from-scratch project-setup story — this is **brownfield**: epics should be
  framed as integration/extension of the existing slice, not greenfield bootstrapping.
- Doc drift (repo vs Notion taxonomy; `allura-mortgage` vs `allura-mortagate`) noted in the
  governance sync; cosmetic to readiness but worth fixing before formal backlog creation.

### Remediation (to make this project implementation-ready)

1. **Generate an epics/stories document** (`bmad-create-epics-and-stories`) that re-cuts the
   work into **user-value epics** (e.g. "Borrower gets an instant soft pre-qualification",
   "Borrower receives a lawful decision + notice", "Household applies jointly"), each
   pulling the relevant FR/NFR/CR, with Given/When/Then ACs — rather than copying the P0–P5
   engineering phases.
2. **Keep the roadmap as the program/dependency plan**, but stop treating it as the backlog.
3. **Close Gate R-1 first** (org auth + Apex run) so the verified baseline (currently only
   ~21% of FRs) is real before new stories are committed.
4. **Promote the two undecided architecture questions (OQ-1, OQ-2) and OQ-3** to explicit
   decisions before writing Evidence-Queue / Decision-Room stories.

---

## Step 6 — Summary and Recommendations

### Overall Readiness Status

## 🔴 NOT READY (for the BMAD Phase-4 / epic-driven implementation gate)

This is **not** a verdict on code quality — the built slice is well-architected and the PRD
is exceptionally rigorous. It is a verdict on **planning readiness**: the one artifact this
gate exists to validate — an epics & stories backlog with acceptance criteria — **does not
exist**, and the verification baseline it would build on is unconfirmed (Gate R-1 open).

| Dimension | Status |
|---|---|
| PRD completeness & traceability | 🟢 Strong (19 FR / 7 NFR / 5 CR, all traced) |
| Architecture documentation | 🟢 Strong (3-layer kernel, ADRs, data dictionary) |
| UX documentation | 🟢 Strong (design-ready) |
| Epics & stories | 🔴 **Absent** |
| Acceptance criteria | 🔴 **None at story level** |
| Verification baseline | 🟠 ~21% (4/19 FR via Jest); rest gated on R-1 |
| Open architecture decisions | 🟠 OQ-1..4 unresolved (2 block UX screens) |
| Compliance to ship a real decision | 🔴 CR-5 not built; R-7 legal sign-off pending |

### Critical Issues Requiring Immediate Action

1. **No epics/stories + no acceptance criteria** — implementation cannot be tracked,
   sequenced, or "done"-defined at the user-outcome level. (Steps 1, 3, 5)
2. **Gate R-1 open** — ~30 Apex tests written, never executed; only 10 Jest tests run.
   The 🟡 baseline is unconfirmed, so any new work builds on unverified foundations. (Step 2)
3. **Proxy backlog is engineering-phase-shaped, not user-value-shaped** — P0/P5 are technical
   milestones; everything depends on P0. (Step 5)
4. **UX screens Evidence Queue & Decision Room are blocked on OQ-2/OQ-3** (extraction
   pipeline + Platform Events). Building them now risks rework. (Step 4)
5. **Compliance hard-stops for a real applicant:** CR-5 (delivery + proof + legal sign-off,
   ⬜) and R-7 (notice not legally reviewed). Do not deliver a real decision/notice. (Steps 2, 5)

### Recommended Next Steps (in order)

1. **Close Gate R-1.** `sf org login web --alias mortagate-de` → `sf project deploy start`
   → `sf apex run test -l RunLocalTests`. Converts ~15 FR/NFR from 🟡 to ✅ or logged defects.
   This is the single highest-leverage action and unblocks the proxy dependency chain.
2. **Generate a user-value epics & stories doc** (`bmad-create-epics-and-stories`): re-cut the
   FR/NFR/CR into shippable user outcomes with Given/When/Then ACs. Keep the P0–P5 roadmap as
   the program/dependency plan, not the backlog.
3. **Resolve OQ-1 (latency), OQ-2 (extraction), OQ-3 (Platform Events)** before writing
   Evidence-Queue / Decision-Room stories. Adopt polling/manual fallbacks as the explicit v1
   path if the richer options aren't available in Dev Edition.
4. **Promote the additive UX behaviors** (fact confirmation, resilience error states) to
   numbered requirements so they get stories and verification.
5. **Quarantine the live-applicant path** behind compliance: CR-5 + R-7 (counsel sign-off,
   HITL delivery + proof) before any real decision or notice leaves the system.

### Final Note

This assessment identified **5 critical issues** across **6 categories** (document
discovery, requirements, epic coverage, UX alignment, epic quality, verification). The root
cause of most is singular: **the project jumped from a rigorous requirements matrix straight
to implementation, skipping the epic/story layer.** The fix is not more code — it's (a)
verifying the existing slice (R-1) and (b) creating the missing backlog. Address the critical
issues before proceeding; or proceed as-is with eyes open, treating the requirements matrix +
roadmap as an informal backlog and accepting that story-level readiness is uncertified.

---

**Assessor:** Implementation Readiness workflow (bmad-check-implementation-readiness)
**Date:** 2026-06-06
**Governance:** group_id `allura-mortgage` · advisory/read-only assessment, no source artifacts modified
