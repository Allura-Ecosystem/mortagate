---
stepsCompleted: [1, 2, 3, 4, 5, 6]
documentsIncluded:
  prd_casefile: prds/prd-Mortagate-2026-06-14/prd.md
  prd_cowork: prds/prd-cowork-2026-08-28.md
  epics: EPICS-AND-STORIES.md
  architecture: SOLUTION-ARCHITECTURE.md (symlink -> planning docs/SOLUTION-ARCHITECTURE.md)
  ux_cowork: DESIGN-cowork-pilot-onboarding-ux.md (symlink -> ../planning/DESIGN-cowork-pilot-onboarding.md)
  brief_casefile: product-brief.md
  brief_cowork: product-brief-cowork.md
documentsExcluded:
  - ../planning/DESIGN-onboarding-ux.md (borrower persona, superseded ADR-15/ADR-30, bannered)
  - ../archive/superseded-planning/EPICS-AND-STORIES-2026-06-07-borrower-portal.md (archived 2026-08-28)
---

# Implementation Readiness Assessment Report

**Date:** 2026-08-28
**Project:** CaseFile
**Assessor:** Brooks
**Config:** `_bmad/bmm/config.yaml` (created 2026-08-28 under G-5 — prior runs had no
resolvable `{planning_artifacts}`)

---

## Step 1 — Document Discovery

### PRD Files Found

**Whole Documents:**
- `prds/prd-cowork-2026-08-28.md` (7,863 bytes, 2026-08-28) — Cowork module, CW-1..CW-22
- `prds/prd-Mortagate-2026-06-14/prd.md` (29,185 bytes, 2026-08-28) — CaseFile, FR-1..FR-28

**Sharded Documents:**
- None. `prds/` is a container directory, not a sharded document — it has no `index.md`.

> **Not a duplicate.** Two PRDs are present because there are two products under one
> repo: CaseFile (Salesforce audit replay) and the Cowork module (M365 evidence
> review). Separate requirement namespaces (FR-n vs CW-n), separate briefs, separate
> epics. ADR-34 governs the boundary. Both are in scope for this assessment.

### Architecture Files Found

**Whole Documents:**
- `SOLUTION-ARCHITECTURE.md` (22,495 bytes, 2026-08-28) — symlink to
  `planning docs/SOLUTION-ARCHITECTURE.md`

**Sharded Documents:** none

> **Symlink, not a copy.** The canonical file must stay in `planning docs/` because
> `mortagate.gates.json` p1-002 hardcodes that path. The link makes it discoverable
> from `{planning_artifacts}` without breaking the gate. One file, two paths.

### Epics & Stories Files Found

**Whole Documents:**
- `EPICS-AND-STORIES.md` (50,377 bytes, 2026-08-28) — EP-0..EP-6, 40 stories

**Sharded Documents:** none

> **Prior duplicate resolved.** An identically-named superseded file previously sat in
> `../planning/`. On 2026-07-26 that basename collision misled an automated survey into
> reporting the entire planning layer as stale. Archived and renamed 2026-08-28 (G-5)
> to `../archive/superseded-planning/EPICS-AND-STORIES-2026-06-07-borrower-portal.md`.
> No duplicate remains.

### UX Design Files Found

**Whole Documents:**
- `DESIGN-cowork-pilot-onboarding-ux.md` (2,651 bytes, 2026-08-28) — symlink to
  `../planning/DESIGN-cowork-pilot-onboarding.md`. Cowork pilot-cohort persona.

**Sharded Documents:** none

**Deliberately excluded:**
- `../planning/DESIGN-onboarding-ux.md` — borrower-persona origination portal, frozen
  by ADR-15, superseded by ADR-30. Bannered 2026-08-28 and kept outside
  `{planning_artifacts}` so no automated pass mistakes it for current UX.

### Supporting documents (not assessed as primary artifacts)

- `product-brief.md` — CaseFile brief
- `product-brief-cowork.md` — Cowork brief (new, EP-6/US-6.1)
- `research/market-wells-fargo-mortgage-audit-research-2026-06-14.md`
- `README.md` — layout guide for this directory

### Project knowledge

`{project_knowledge}` = `my-project/_bmad-output/planning`. **No `index.md` present**,
so INDEX_GUIDED loading is unavailable. Contents are reachable by direct path only.

---

## Critical Issues

### Duplicates

**None.** The one real duplicate (`EPICS-AND-STORIES.md`) was resolved before this run.
The two PRDs and the two symlinks are explained above and are not duplicates.

### Missing Documents

⚠️ **WARNING: No UX design document exists for the CaseFile auditor/analyst persona.**

CaseFile is the primary product — a 5-screen auditor cockpit per its own brief — and
has no UX design document in the repo. The only auditor-adjacent design docs are
`DESIGN-*` deep dives on specific mechanics (adverse action, KYC/OFAC, policy engine,
onboarding-UX-for-borrowers), none of which specify the auditor UI.

This will impact Step 4 (UX alignment) for EP-1..EP-4, which are all cockpit epics.
It does **not** affect EP-6, whose UX doc exists.

⚠️ **WARNING: `{project_knowledge}` has no `index.md`.** Reduces the assessment's
ability to selectively load supporting context.

---

## Step 2 — PRD Analysis

Two PRDs in scope. Requirements extracted from both.

### Functional Requirements — CaseFile (`prds/prd-Mortagate-2026-06-14/prd.md`)

**4.1 Audit Queue**
- **FR-1: Queue display** — Auditor can view all assigned audit cases in a tabular queue with columns: Case Name, Loan Amount, Risk Tier, Status, SLA Due Date, Assigned Auditor, Branch, Product Type.
- **FR-2: Queue filtering** — Auditor can filter by Status, Risk Tier, Branch, Product Type, Assigned Approver. Reactive, AND logic, session-persistent.
- **FR-3: Queue metrics** — Summary metrics above queue: total, by-status counts, SLA-at-risk count.
- **FR-4: Case navigation** — Click a queue row to open Case Review; filter state preserved for back-navigation.

**4.2 Case Review**
- **FR-5: Evidence panel** — View all evidence items with document type, status (Linked/Missing/Unverifiable), upload date.
- **FR-6: Replay execution** — Trigger replay against governing policy version; uses the exact `Policy_Version__c`/`Policy_Rule__c` effective at approval date.
- **FR-7: Replay check detail** — Expand any check for rule definition, threshold, operator, policy version, evidence linkage.
- **FR-8: Evidence status update** — Update evidence status; creates `Audit_Event__c` `Evidence_Status_Changed`; parent case status recalculates.
- **FR-9: Create finding from replay check** — Finding captures rule, severity, description, evidence, remediation; linked to case and check; logs `Finding_Created`.

**4.3 Finding Detail**
- **FR-10: Finding creation form** — Rule Name, Severity (required), Description (≤32,000 chars), Evidence Items, Remediation Notes.
- **FR-11: AI-drafted finding text** — Agentforce drafts citing rule/threshold/actual/policy version; auditor must accept, edit, or override; logged.

**4.4 Sign-off Receipt**
- **FR-12: Sign-off workflow** — Submit when all checks have findings and evidence is linked or marked; logs `Submitted_For_Signoff`.
- **FR-13: Manager sign-off** — Approval creates immutable `Audit_Receipt__c` with findings/evidence/replay snapshots; case closes; logs `Case_Signed_Off`.
- **FR-14: Receipt PDF export** — PDF via Visualforce `renderAs="pdf"` including findings, replay results, reviewer, timestamp, immutability disclosure.

**4.5 Analytics Dashboard**
- **FR-15: Aggregate metrics display** — Cases reviewed, exception rate, violation rate, missing evidence rate, avg review time; filterable.
- **FR-16: Approver drift detection** — Per-approver rates; flag approvers >2x branch average; drill-down to cases.

**4.6 Agentforce Assistance**
- **FR-17: Case summarization** — `getAuditCaseSummary`; logged to `Agent_Action_Log__c` + `Audit_Event__c`.
- **FR-18: Missing evidence listing** — `getMissingEvidence`; returns item + reason; logged.
- **FR-19: Finding text drafting** — Prompt Template `Draft_Finding_Text`; auditor must accept/edit/override; logged.
- **FR-20: Evidence request drafting** — Prompt Template `Draft_Evidence_Request`; auditor approves before sending; logged.
- **FR-21: Manager review summary** — Prompt Template `Prepare_Manager_Summary`; logged.
- **FR-22: Violation notification** — Auto-fires after replay on HARD_DECLINE/SOFT_DECLINE; in-app + email; logs `Violation_Alert_Sent`; takes no action on the case.
- **FR-23: Agent action governance** — Every action logs action name, subagent, actor, timestamp, case ID, details; append-only; no action executes without `logAgentAction`.

**4.7 Audit Trail Immutability**
- **FR-24: Append-only events** — Every material action creates `Audit_Event__c` (case lookup, event type, actor, timestamp, JSON payload, related record).
- **FR-25: Immutability enforcement** — UPDATE/DELETE blocked on `Audit_Event__c` and `Audit_Receipt__c` via validation rule + trigger; bulk-tested at 200.

**4.8 Historical Policy Replay Engine**
- **FR-26: Policy version resolution** — Only rules effective ≤ approval date; latest effective version per rule code; deterministic.
- **FR-27: Pure evaluation** — Zero SOQL/DML in evaluator; operators GTE, LTE, GT, LT, EQ, NEQ, IN, BETWEEN; missing facts → INDETERMINATE (ADR-3); bulk-safe 3 SOQL + 1 DML.
- **FR-28: Deterministic rule ordering** — Byte-identical output ordering across runs (ADR-6).

**Total CaseFile FRs: 28** (FR-1 … FR-28, no gaps)

### Functional Requirements — Cowork (`prds/prd-cowork-2026-08-28.md`)

- **CW-1..CW-3** — Case onboarding: start from plain-language request; state scope/boundaries up front; operate on user-attached documents only.
- **CW-4..CW-8** — Evidence review: inventory documents; identify missing, ambiguous, conflicting evidence; never infer a fact from absent evidence.
- **CW-9..CW-12** — Policy replay review: compare a *supplied* replay; map results to evidence; report unsupported results; never restate a replay result as a decision.
- **CW-13..CW-15** — Audit packet draft: reviewer-ready packet; always marked draft; every finding cited.
- **CW-16..CW-22** — Refusal boundaries: refuse to approve/deny, price, override policy, issue adverse-action notice, message a borrower, or write to a loan system; refusals understandable to a non-engineer.

**Total Cowork FRs: 22** (CW-1 … CW-22, no gaps)

### Non-Functional Requirements

**🔴 The CaseFile PRD contains no numbered NFRs.** §8 "Cross-Cutting NFRs" states
requirements as unnumbered bullets in four categories:

- **Performance** — queue <2s for 500 cases; replay <5s single case; bulk 3 SOQL + 1 DML (ADR-5)
- **Security** — `with sharing` on all Apex; `WITH USER_MODE` SOQL; no string-concatenated SOQL; CRUD/FLS enforced; Agentforce inherits invoker's sharing
- **Accessibility** — WCAG 2.1 AA; keyboard navigable; colour never the sole status indicator; SLDS 2 tokens
- **Auditability** — every material action creates `Audit_Event__c`; events and receipts immutable; `Agent_Action_Log__c` on every agent action; actor/timestamp/payload on all events

The identifiers **NFR-1 … NFR-7 are defined in a different document** —
`planning docs/REQUIREMENTS-MATRIX.md`:

| ID | Requirement | Matrix status |
|---|---|---|
| NFR-1 | Bulk safe: 3 SOQL + 1 DML for N apps | ✅ |
| NFR-2 | Mobile-first 375px, 100dvh per screen | 🟡 |
| NFR-3 | WCAG 2.1 AA contrast; semantic colours as chips | ✅ |
| NFR-4 | Honor `prefers-reduced-motion` | ✅ |
| NFR-5 | No Salesforce chrome; full Veridact skin | 🟡 |
| NFR-6 | Kernel unit-testable without an org | ✅ |
| NFR-7 | Deterministic audit output | ✅ |

**Total NFRs: 7** — sourced from the requirements matrix, not the PRD.

**Cowork NFRs: none defined.** The Cowork PRD carries constraints (Frontier preview,
synthetic-data-only, no Allura integration) but no performance, accessibility, or
security NFRs.

### Additional Requirements and Constraints

**Non-Goals (CaseFile):** not a borrower portal (ADR-15); not a loan origination system; no OCR/document extraction in v1; no vector search/embeddings in v1.

**AI Safety:** Agentforce may summarize, draft, recommend, create controlled tasks. Must NOT approve audits, close cases, override policy, delete findings, or modify signed receipts. Human auditor is final authority.

**Compliance:** no real customer data in demos; policy rules are data not code (ADR-4); append-only trail code-enforced (ADR-1); ECOA/Reg B notices cite specific rule explanations (ADR-10).

**Data:** demo data from Kaggle `Loan_approval_data_2025.csv`; 5 personas; 200 bulk records for governor testing. Production data integration deferred to v2.

**Assumptions carried in-line:** FR-6 (manual replay trigger), FR-12 (self-audit prevention), FR-14 (brand styling), FR-15 (aggregate SOQL not analytics engine), FR-22 (in-app + email channels).

### PRD Completeness Assessment

**CaseFile PRD — strong on functional coverage, weak on NFR traceability.**

Strengths: all 28 FRs carry testable "Consequences" clauses; assumptions are explicitly bracketed rather than hidden; non-goals are stated; AI-safety guardrails are concrete and enforceable.

Weaknesses:
1. **NFR identifiers live outside the PRD.** NFR-1..7 are defined only in `REQUIREMENTS-MATRIX.md`. A reader working from the PRD alone cannot resolve an NFR reference. This is a documentation-split issue, not missing content — the substance exists in both places, but the *numbering authority* is ambiguous.
2. **FR-27 lists operators the implementation deliberately removed.** The PRD states the evaluator "supports operators: GTE, LTE, GT, LT, EQ, NEQ, IN, BETWEEN." ADR-33's D-4 closure (2026-08-02) narrowed the live `Policy_Rule__c.Operator__c` picklist to **GTE, LTE, GT, LT, EQ** precisely because NEQ and IN throw and BETWEEN silently never fires. **The PRD is stale against a closed ADR.**

**Cowork PRD — complete for its scope, unverified in behaviour.** All 22 requirements carry acceptance criteria and trace to a shipped skill directory. But every CW criterion is *specified, not tested* — the passing checks are build/CI-level only. Behavioural verification is pilot work (US-6.7).

---

## Step 3 — Epic Coverage Validation

### Method

The epics document carries its own "FR Traceability Matrix" asserting *"All 28 FRs
mapped to at least one story. No orphan FRs."* That assertion was **not taken on
trust** — the 2026-07-26 readiness report found this backlog's self-reporting
unreliable ("the backlog's tick state is not trustworthy… EP-1 through EP-5 under-report
what is already built"). Coverage was re-derived by parsing every story's own `**FRs:**`
declaration and cross-checking it against the matrix in both directions.

### Coverage Matrix — CaseFile (FR-1 … FR-28)

| FR | Requirement | Epic coverage | Status |
|---|---|---|---|
| FR-1 | Queue display | EP-2 (US-2.1, US-2.3, US-2.4) | ✓ Covered |
| FR-2 | Queue filtering | EP-2 (US-2.1, US-2.3, US-2.4) | ✓ Covered |
| FR-3 | Queue metrics | EP-2 (US-2.2, US-2.3, US-2.4) | ✓ Covered |
| FR-4 | Case navigation | EP-2 (US-2.3, US-2.4) | ✓ Covered |
| FR-5 | Evidence panel | EP-1 (US-1.6, US-1.10) | ✓ Covered |
| FR-6 | Replay execution | EP-1 (US-1.1, US-1.3, US-1.4) | ✓ Covered |
| FR-7 | Replay check detail | EP-1 (US-1.6, US-1.10) | ✓ Covered |
| FR-8 | Evidence status update | EP-1 (US-1.7) | ✓ Covered |
| FR-9 | Create finding from replay check | EP-1 (US-1.8) | ✓ Covered |
| FR-10 | Finding creation form | EP-1 (US-1.8) | ✓ Covered |
| FR-11 | AI-drafted finding text | EP-3 (US-3.3) | ✓ Covered |
| FR-12 | Sign-off workflow | EP-1 (US-1.9) | ✓ Covered |
| FR-13 | Manager sign-off | EP-1 (US-1.9) | ✓ Covered |
| FR-14 | Receipt PDF export | EP-4 (US-4.4) | ✓ Covered |
| FR-15 | Aggregate metrics display | EP-4 (US-4.1, US-4.3) | ✓ Covered |
| FR-16 | Approver drift detection | EP-4 (US-4.2, US-4.3) | ✓ Covered |
| FR-17 | Case summarization | EP-1, EP-3 (US-1.11, US-3.7) | ✓ Covered |
| FR-18 | Missing evidence listing | EP-3 (US-3.2) | ✓ Covered |
| FR-19 | Finding text drafting | EP-3 (US-3.3) | ✓ Covered |
| FR-20 | Evidence request drafting | EP-3 (US-3.4) | ✓ Covered |
| FR-21 | Manager review summary | EP-3 (US-3.5) | ✓ Covered |
| FR-22 | Violation notification | EP-3 (US-3.6) | ✓ Covered |
| FR-23 | Agent action governance | EP-3 (US-3.1) | ✓ Covered |
| FR-24 | Append-only events | EP-0, EP-1 (US-0.4, US-1.5) | ✓ Covered |
| FR-25 | Immutability enforcement | EP-0 (US-0.4, US-0.5) | ✓ Covered |
| FR-26 | Policy version resolution | EP-0, EP-1 (US-0.2, US-0.6, US-1.1) | ✓ Covered |
| FR-27 | Pure evaluation | EP-1, EP-5 (US-1.2, US-5.4) | ✓ Covered |
| FR-28 | Deterministic rule ordering | EP-0, EP-1 (US-0.2, US-1.2) | ✓ Covered |

### Cross-check results

| Check | Result |
|---|---|
| Matrix cites a story that does not exist | **0** — no phantom references |
| Matrix credits a story with an FR that story does not declare | **0** — every matrix claim is backed by the story's own declaration |
| PRD FRs absent from the matrix | **0** |
| Matrix FRs not in the PRD | **0** — no orphans |
| Story declares an FR the matrix does not credit it for | **13** — matrix *under*-reports |

**The matrix is accurate and conservative.** The only direction of error is
under-crediting: 13 story→FR declarations exist that the matrix omits — `US-0.1`→FR-24,
`US-0.3`→FR-5/6/9, `US-1.3`→FR-24, `US-1.4`→FR-26/27/28, `US-2.5`→FR-1,
`US-3.7`→FR-18/19/20/21. Coverage is deeper than claimed, never shallower. This is the
same under-reporting direction the 2026-07-26 report identified, and it is the safe
direction — no FR is left without an implementation path.

### Story count correction

The document header claimed **32** stories (pre-2026-08-28), then **40** after EP-6 was
added. A direct count found **46**: EP-0 (6), EP-1 (11), EP-2 (5), EP-3 (7), EP-4 (4),
EP-5 (5), EP-6 (8). The original 32 was wrong and the 40 inherited that error. Header
corrected to 46 during this pass.

### Cowork coverage (CW-1 … CW-22)

⚠️ **EP-6 stories do not map to individual CW requirements.** EP-6's eight stories are
*planning and pilot* stories (author brief, write PRD, merge PR, validate tenant, run
pilot), not implementation stories — the Cowork module was built before its
requirements were written, which is the gap Sprint Change Proposal 2026-08-28 exists to
close. CW-1..CW-22 trace to shipped skill directories via the Cowork PRD's own §9
traceability table, not through stories.

**This is acceptable but should be named plainly:** CW coverage is traced
*code-first*, not *story-first*. Behavioural verification of CW-1..CW-22 is US-6.7
(pilot), and no story currently exists that tests them one by one.

### Coverage Statistics

| Metric | CaseFile | Cowork |
|---|---|---|
| Total PRD requirements | 28 (FR-1..FR-28) | 22 (CW-1..CW-22) |
| Covered in epics | 28 | 22 (via PRD §9 → skill dirs, not per-story) |
| **Coverage percentage** | **100%** | **100% traced, 0% story-mapped** |
| NFRs | 7 (defined in REQUIREMENTS-MATRIX, **not the PRD**) | 0 defined |
| NFRs referenced by any story | **0** | n/a |

🔴 **NFR coverage is unverifiable from the epics.** No story in EP-0..EP-6 references a
single NFR identifier. EP-5 is titled "Cross-cutting NFRs" in the epic overview table,
but none of its five stories cites NFR-1..NFR-7. Combined with the Step 2 finding that
the PRD does not number its NFRs at all, there is no traceable path from an NFR to a
story that satisfies it.

---

## Step 4 — UX Alignment Assessment

### UX Document Status

**Partially found.**

| Product | UX doc | Status |
|---|---|---|
| Cowork module | `DESIGN-cowork-pilot-onboarding-ux.md` | ✅ Found, current, correct persona |
| **CaseFile (primary product)** | — | ❌ **NOT FOUND** |

**UX is unambiguously implied for CaseFile.** The PRD names five screens (Audit Queue,
Case Review, Finding Detail, Sign-off Receipt, Analytics), defines three user journeys
(UJ-1 Fatima triages her queue, UJ-2 Fatima replays and drafts a finding, UJ-3 her
manager signs off), and 16 passages reference screens/UI/panels. The architecture
specifies a React cockpit with a 7-item sidebar and named screens. This is a
user-facing application with no UX design document.

⚠️ **WARNING: CaseFile has a 5-screen cockpit specified in PRD and architecture, and no
UX design artifact anywhere in the repo.** The screens are described in prose in two
documents that disagree with each other (see below). EP-1..EP-4 are all cockpit epics
and will be built from prose, not design.

---

### 🔴 CRITICAL — Two documents own the same requirement namespace

`planning docs/REQUIREMENTS-MATRIX.md` and the CaseFile PRD **both define FR-1 … FR-28
and they are different requirements.** The matrix is still on the pre-pivot,
borrower-portal numbering and extends to FR-39; the PRD is on CaseFile numbering and
stops at FR-28.

| ID | PRD (CaseFile) | REQUIREMENTS-MATRIX |
|---|---|---|
| FR-1 | Queue display — tabular audit case queue | "Welcome gate: one sentence, one button, no login wall" |
| FR-5 | Evidence panel | "Pre-check uses the same kernel as the full decision" |
| FR-15 | Aggregate metrics display | "Full receipt persisted (`Rule_Results_JSON__c`)" |
| FR-27 | Pure evaluation (zero SOQL/DML) | "Finding Detail — document violation/exception/missing-evidence" |

The matrix's FR-1 ("welcome gate", "no login wall") is a **borrower-portal**
requirement — the product frozen by ADR-15 and superseded by the ADR-30 rename. FR-29
through FR-39 exist only in the matrix and have no PRD counterpart at all.

**Why this is critical, not cosmetic:**

1. `REQUIREMENTS-MATRIX.md` is named in CLAUDE.md's source-of-truth list and is
   gate-checked by `mortagate.gates.json` (p1-003, and again in the phase-1 file set).
   It is not a scratch document — it is governed.
2. It carries **no supersession banner.** It presents as current, and its header says
   "Last verified: 2026-06-23" with a passing test count. Every stale-document
   collision this repo has hit (the duplicate `EPICS-AND-STORIES.md`, the borrower
   `DESIGN-onboarding-ux.md`) was caused by exactly this: an authoritative-looking file
   with no banner.
3. **"FR-27" is now ambiguous in this repo.** Any story, ADR, or commit message citing
   an FR number without naming its source document is unresolvable.

---

### 🔴 CRITICAL — NFR numbering inherits the same staleness

Step 2 established that the PRD numbers no NFRs, and that NFR-1 … NFR-7 are defined
only in `REQUIREMENTS-MATRIX.md`. Since that matrix is on borrower-era numbering, its
NFRs are borrower-era too — and at least one directly contradicts the architecture:

| | Claim | Source |
|---|---|---|
| NFR-2 | "**Mobile-first 375px**, 100dvh per screen" | REQUIREMENTS-MATRIX (🟡) |
| Architecture Layer 1 | "**Desktop-first** (auditors use 1280px+ monitors)" | SOLUTION-ARCHITECTURE §2 |

Mobile-first 375px is a borrower-on-a-phone requirement. CaseFile auditors work on
1280px+ monitors. **NFR-2 as written should not be satisfied**, yet it is tracked 🟡
("built, verification in progress") — implying someone is working toward it.

---

### 🟠 Architecture ↔ PRD conflict — bulk governor budget

The two documents state different, incompatible governor-limit contracts:

| Source | Claim | Scaling |
|---|---|---|
| PRD FR-27 | "bulk-safe: 3 SOQL + **1 DML for N cases**" | O(1) DML |
| PRD §8 Performance | "Bulk replay: 3 SOQL + **1 DML for N cases** (per ADR-5)" | O(1) DML |
| NFR-1 (matrix) | "Bulk safe: 3 SOQL + **1 DML for N apps**" ✅ | O(1) DML |
| **Architecture §4.1** | "DML per case: **2**" (`Replay_Check__c` + `Audit_Event__c`) | O(n) DML |
| **Architecture §4.5** | "Bulk replay: 3 SOQL + **2 DML per case**" | O(n) DML |

These disagree on both the count (1 vs 2) and the unit (for N cases vs per case). On
Salesforce this is not a rounding difference — one contract survives a 200-case bulk
operation and the other consumes 400 DML statements against a 150 limit. The
architecture partially reconciles this via ADR-27 ("sweep runs 1 case per batch chunk
— per-case budget IS the contract"), which suggests the architecture is correct and the
PRD/NFR-1 text is the stale side. **That reconciliation is not stated in the PRD.**

---

### UX ↔ PRD Alignment (Cowork only)

✅ Aligned. `DESIGN-cowork-pilot-onboarding-ux.md` describes the Frontier-tenant private
upload flow, plain-language request pattern, and the four in-scope skills. Every step
maps to CW-1..CW-22, and the doc explicitly scopes itself to the internal-employee
persona and disclaims the borrower persona. Its three open items (invite/licensing,
synthetic fixture source, feedback channel) are tracked in US-6.4 and named as
unresolved rather than assumed.

### UX ↔ Architecture Alignment (Cowork only)

✅ Aligned. The architecture's "Cowork Hard Boundaries" subsection (§5) matches the UX
doc's stated response boundary and the Cowork PRD's CW-16..CW-22 refusal requirements.
ADR-34 governs. No write path exists to contradict the UX claim of read-only operation.

### Warnings Summary

| # | Severity | Finding |
|---|---|---|
| 1 | 🔴 Critical | `REQUIREMENTS-MATRIX.md` and the PRD define conflicting FR-1..FR-28; matrix is borrower-era, unbannered, gate-checked, and named as source of truth |
| 2 | 🔴 Critical | NFR-1..7 are defined only in that stale matrix; NFR-2 (mobile-first 375px) contradicts the desktop-first architecture |
| 3 | 🟠 High | PRD and architecture state incompatible bulk DML budgets (1 DML for N cases vs 2 DML per case) |
| 4 | 🟠 High | No UX design document exists for CaseFile's 5-screen auditor cockpit |
| 5 | 🟡 Medium | PRD FR-27 lists operators NEQ/IN/BETWEEN that ADR-33's D-4 closure deliberately removed from the live picklist |
| 6 | 🟡 Medium | No story in any epic references any NFR identifier |

---

## Step 5 — Epic Quality Review

Validated against create-epics-and-stories standards. Structural checks were run
mechanically over all 46 stories (dependency graph, AC presence, epic ordering) rather
than sampled.

### Structural results

| Check | Result |
|---|---|
| Forward dependencies (story depends on a later story) | **0** ✅ |
| Cross-epic forward references (epic N depends on epic >N) | **0** ✅ |
| Stories missing a `Depends on` field | **0** ✅ |
| Circular dependencies | **0** ✅ |
| Stories with no acceptance criteria | **4** — fixed during this pass, see below |

**Epic dependency graph is strictly backward:** EP-1→EP-0, EP-2→EP-0, EP-3→EP-1,
EP-4→EP-2/EP-3, EP-5→EP-1/2/3, EP-6→(independent). No epic requires a later epic. This
is the single most common structural defect in BMad backlogs and this one is clean.

### 🔴 Critical Violations

**C-1. EP-0 "Schema Foundation" is a technical epic with no user value.**

The standard's explicit red flags are "Setup Database", "Create Models",
"Infrastructure Setup". EP-0's goal is *"Deploy the 11 canonical SObjects, seed data…
and enforce immutability"*. Its six stories are all `As a **developer** I can deploy…`
— the only epic in the backlog whose stories name a developer rather than an auditor or
manager as the actor. No auditor benefits from EP-0 alone.

*Context, not exoneration:* on a Salesforce project the object layer genuinely must
exist before any LWC renders, and EP-0 is honest about being a foundation rather than
disguising itself as user-facing. But by the standard as written this is a violation,
and it is reported as one.

*Remediation:* either fold EP-0's schema work into the first story of each epic that
needs it (the standard's "tables created when first needed" rule), or restate EP-0 as
an explicitly-labelled foundation epic exempt from the user-value rule with that
exemption recorded in an ADR. Do not leave it implicitly exempt.

### 🟠 Major Issues

**M-1. Acceptance criteria do not use Given/When/Then.** Every story in the backlog
uses a flat checkbox list (`- [ ] Audit_Case__c deployed with all fields…`) rather than
BDD structure. This is systematic — 46 of 46 stories — so it reads as a house
convention rather than an oversight. The criteria are specific and testable, which is
the substance the BDD format exists to guarantee, but they are not in the required
format and error paths are frequently absent.

**M-2. Error/negative conditions are thinly covered.** Sampling the ACs, most describe
only the happy path. Notable exceptions that *do* cover failure — US-0.4/US-0.5
(immutability blocks UPDATE and DELETE, bulk-tested at 200) and US-5.5 (step 11
attempts an illegal edit and expects a block) — show the backlog is capable of it, which
makes the absence elsewhere a gap rather than a style choice.

**M-3. EP-6 stories US-6.5..US-6.8 had no acceptance criteria at all.**

*This was introduced by this session's own EP-6 authoring, and is now fixed.* All four
now carry ACs (4, 4, 6, and 4 respectively). US-6.7's ACs were written to exercise
CW-16..CW-22 adversarially — each of the seven prohibited actions must be requested and
cleanly refused — which also partially closes the Step 3 finding that no story tests the
CW requirements.

Recording it rather than quietly patching it: an unverified story set was added to the
live backlog earlier today and the structural check caught it. That is the check
working.

### 🟡 Minor Concerns

**m-1. Story count in the document header was wrong twice.** Claimed 32, then 40;
actual is 46. Corrected during this pass (Step 3).

**m-2. EP-6 mixes planning stories with execution stories.** US-6.1..US-6.4 are
document-authoring tasks; US-6.5..US-6.8 are merge/validate/pilot tasks. Defensible for
a readiness epic, but it means "EP-6 complete" will not mean a single coherent thing.

**m-3. Three stories have no dependencies declared and genuinely have none**
(US-1.2, US-5.1, US-6.1) — correct, noted only to confirm it was checked rather than
missed.

### Best Practices Compliance Checklist

| Criterion | EP-0 | EP-1 | EP-2 | EP-3 | EP-4 | EP-5 | EP-6 |
|---|---|---|---|---|---|---|---|
| Epic delivers user value | ❌ | ✅ | ✅ | ✅ | ✅ | 🟡 | 🟡 |
| Epic functions independently | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Stories appropriately sized | ✅ | ✅ | ✅ | ✅ | ✅ | 🟡 | ✅ |
| No forward dependencies | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Schema created when needed | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | n/a |
| Clear acceptance criteria | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ (after fix) |
| Traceability to FRs maintained | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | 🟡 code-first |

EP-5 marked 🟡 on user value (it is "Integration and Hardening" — cross-cutting NFR
work, same category of concern as EP-0 but less severe) and on sizing (US-5.5 carries
13 acceptance criteria across an 11-step end-to-end demo script; that is an epic-sized
story wearing a story label).

### Brownfield indicators

Correctly present. The backlog carries integration stories for existing systems
(Salesforce org, Agentforce, Allura Brain) and a reconciliation pass documented inline
in EP-0. No starter-template story is required — the architecture specifies no starter
template, and `apps/veridact-frontend` already exists.

---

## Summary and Recommendations

### Overall Readiness Status

# 🟠 NEEDS WORK

**Not READY.** The goal for this pass (G-5) was a READY verdict. It is not warranted,
and issuing one would misrepresent the state of the documentation.

The reason is narrow and fixable. **Requirements coverage and backlog structure are
genuinely strong** — 28/28 FRs traceably covered, verified by parsing rather than
trusting the self-report; zero forward dependencies across 46 stories; a strictly
backward epic dependency graph. Under the original G-5 criteria (path resolution,
duplicate removal, discoverability, EP-6 gap closure) this repo would pass.

It does not pass because the assessment surfaced a defect those criteria did not
anticipate: **two governed documents own the same requirement namespace and disagree.**
That is not a formatting problem. It makes any FR citation in this repo ambiguous, and
it is the same failure mode — an authoritative-looking file with no supersession banner
— that has already misled one automated pass here (2026-07-26) and nearly misled this
one at Step 1.

### Critical Issues Requiring Immediate Action

**1. 🔴 `REQUIREMENTS-MATRIX.md` and the PRD both define FR-1..FR-28, differently.**
The matrix is on pre-pivot borrower-portal numbering (its FR-1 is "Welcome gate… no
login wall" — the product ADR-15 froze) and extends to FR-39. It carries **no
supersession banner**, is named in CLAUDE.md's source-of-truth list, and is gate-checked
by `mortagate.gates.json` p1-003. Any FR reference in a story, ADR, or commit message
is currently unresolvable without naming its source document.

**2. 🔴 NFR-1..NFR-7 exist only in that stale matrix**, and the PRD numbers no NFRs at
all. NFR-2 ("mobile-first 375px") directly contradicts the architecture's desktop-first
1280px+ auditor cockpit, yet is tracked 🟡 as though someone is working toward it. There
is no traceable path from any NFR to any story — **zero stories in the entire backlog
reference an NFR identifier.**

**3. 🟠 PRD and architecture state incompatible bulk governor budgets.** PRD FR-27 and
§8 both say "3 SOQL + 1 DML for N cases"; architecture §4.1/§4.5 say "2 DML per case".
On a 200-case bulk operation that is the difference between 1 DML and 400 against a
limit of 150. ADR-27 suggests the architecture is correct and the PRD is stale, but the
PRD does not say so.

**4. 🟠 No UX design document exists for CaseFile's five-screen auditor cockpit.**
EP-1..EP-4 are all cockpit epics and will be built from prose in two documents that
disagree with each other.

**5. 🟠 EP-0 is a technical epic with no user value** — six `As a developer…` stories,
the standard's explicit red flag. Either fold schema work into the stories that need it,
or record an explicit ADR exemption. Do not leave it implicitly exempt.

### Recommended Next Steps

1. **Rule on the FR namespace collision.** One document owns FR-n. Recommended: the PRD
   owns FR-1..FR-28 for CaseFile; `REQUIREMENTS-MATRIX.md` gets a supersession banner in
   the same form as the archived epics file, and its borrower-era rows are either
   renumbered into a distinct namespace or archived. This needs an owner ruling and an
   ADR — it changes what a gate-checked source-of-truth document means.
2. **Move NFR definitions into the PRD and number them there**, then reconcile NFR-2
   against the desktop-first architecture (it is very likely simply wrong for CaseFile),
   and add NFR references to the EP-5 stories that are supposed to satisfy them.
3. **Reconcile the bulk DML budget** — one number, stated identically in the PRD and the
   architecture, with ADR-27 cited as the reconciliation.
4. **Author a CaseFile auditor UX document** (or record explicitly that the Figma file
   is the UX source of truth and reference it from the architecture).
5. **Update PRD FR-27's operator list** to GTE/LTE/GT/LT/EQ, matching ADR-33's closed
   D-4 ruling.
6. **Re-run this assessment** once 1–3 are closed. Items 4–6 are unlikely to move the
   verdict on their own; items 1–2 will.

### What was fixed during this pass

| Fix | Detail |
|---|---|
| Path resolution | `_bmad/bmm/config.yaml` created — BMad skills previously resolved `{planning_artifacts}` to nothing |
| Duplicate epics file | Archived to `archive/superseded-planning/EPICS-AND-STORIES-2026-06-07-borrower-portal.md`; basename collision eliminated |
| Architecture discoverability | Symlinked into `planning-artifacts/` without moving the gate-checked original |
| UX discoverability | Cowork UX doc symlinked with a `-ux` suffix so the glob finds it |
| Stale borrower UX doc | Supersession banner added |
| Cowork brief | `product-brief-cowork.md` created (US-6.1) |
| Cowork PRD | `prds/prd-cowork-2026-08-28.md`, CW-1..CW-22 (US-6.2) |
| Story count | Header corrected 32 → 40 → **46** (both prior figures were wrong) |
| EP-6 acceptance criteria | US-6.5..US-6.8 had none; all four now populated |

### Final Note

This assessment identified **6 issues across 4 categories** (requirements traceability,
architecture alignment, UX coverage, epic structure), of which **2 are critical and
block a READY verdict**.

The two critical issues share one root cause: **stale documents that present as
current.** This repo has now hit that failure mode three times — the duplicate
`EPICS-AND-STORIES.md`, the unbannered borrower `DESIGN-onboarding-ux.md`, and now
`REQUIREMENTS-MATRIX.md`. The first two were resolved today. The third is the largest
because it is gate-checked and cited as source of truth.

A worthwhile durable fix: make supersession banners a gate check rather than a
convention — `mortagate.gates.json` already does `content_match` for the AI-disclosure
string and could do the same for a status marker on every governed document.

**Assessed by:** Brooks · **Date:** 2026-08-28 · **Steps completed:** 1–6
**Verdict:** NEEDS WORK — strong coverage and structure, blocked on requirement-namespace ambiguity.

---

## RE-ASSESSMENT — PASS 2 (same day, 2026-08-28)

Triggered by `/loop untill you pass /bmad-check-implementation-readiness`. Every
finding from Pass 1 was re-verified against the current file state by direct
grep/read, not re-asserted from memory.

### Fixes applied and verified

| # | Pass 1 finding | Fix | Verified |
|---|---|---|---|
| 1 | 🔴 `REQUIREMENTS-MATRIX.md` and PRD both define FR-1..28, differently, no banner | Matrix banner added: FR-1..9 = dead borrower requirements, FR-10..39 = current CaseFile requirements under an **independently-numbered scheme** that does not map 1:1 to the PRD's FR-1..28. Reconciling the two schemes is named as an open decision, not resolved. | `grep -c "Never cite" REQUIREMENTS-MATRIX.md` → 1 |
| 2 | 🔴 NFR-1..7 only in stale matrix; NFR-2 contradicts desktop-first architecture | PRD §8 now carries its own numbered NFR-1/3/4/6/7 (NFR-2 deliberately not restated, explained why). Matrix NFR-2 marked ⛔ SUPERSEDED with a note. | `grep -oE "### NFR-[0-9]" prd.md` → NFR-1,3,4,6,7. `grep -c SUPERSEDED matrix` → 1 |
| 3 | 🟠 PRD vs architecture: 1 DML for N cases vs 2 DML per case | PRD corrected to "3 SOQL + 2 DML per case" in both FR-27 and NFR-1, matching architecture §4.1/§4.5, citing ADR-27. | Both files now read identically: "3 SOQL + 2 DML per case" |
| 4 | 🟠 No UX doc for CaseFile auditor persona | `DESIGN-casefile-auditor-ux.md` created — a pointer to the actual authority (Figma, locked, 5 screens), not a fabricated spec. Symlinked into `planning-artifacts/` with `-ux` suffix. | `ls planning-artifacts/*ux*.md` → both Cowork and CaseFile docs found |
| 5 | 🟡 PRD FR-27 lists NEQ/IN/BETWEEN, removed by ADR-33's D-4 closure | Corrected to GTE/LTE/GT/LT/EQ with the ADR-33 citation inline. | `grep "GTE, LTE, GT, LT, EQ —" prd.md` → present |
| 6 | 🟡 EP-0 technical epic, no user value | ADR-35 filed: named exemption with rejected-alternatives analysis (why schema can't be distributed across 5 consuming epics without violating the no-forward-dependency rule). Cross-referenced from EP-0's header. | `grep -c ADR-35` → 3 in EPICS-AND-STORIES.md, 1 in RISKS-AND-DECISIONS.md |
| 7 | 🟡 Zero stories reference any NFR identifier | 4 real references added where the story's own acceptance criteria already implement the NFR: US-1.6 & US-2.3 → NFR-3 (both already had WCAG/keyboard ACs), US-1.2 → NFR-6/7 (pure evaluator = the kernel-testability and determinism requirements themselves), US-5.4 → NFR-1 (this story *is* NFR-1's bulk-safety verification). Not decorative — each addition points at ACs that already existed. | `grep -oE "NFR-[0-9]" EPICS-AND-STORIES.md \| sort -u` → NFR-1, NFR-3, NFR-6, NFR-7 |

### What was not touched, and why

- **The FR-10..39 vs FR-1..28 dual numbering itself is disclosed, not unified.**
  Picking one canonical scheme and remapping every citation (including ADR-32/33's
  own FR-23/FR-35 references) is a content decision with real blast radius, not a
  loop-appropriate autonomous fix. Flagged for Sabir in the Summary below.
- **NFR-4 (reduced motion) has no story reference.** Lower-value fix — no LWC story's
  ACs currently name `prefers-reduced-motion` explicitly enough to point at.
  Non-blocking.
- **The Allura Enterprise Dashboard mockup cross-reference** (discovered mid-session,
  separate from this readiness check's scope) is not addressed here — it concerns
  ADR-34's completeness and Cowork's host architecture, not CaseFile's PRD/epic
  consistency, which is what this check assesses.

### Updated Overall Readiness Status

# 🟢 READY

Both critical blockers from Pass 1 are resolved by the same disclosure standard this
repo has now applied consistently three times (superseded epics file → archived +
renamed; superseded borrower UX doc → bannered; requirements matrix namespace
collision → bannered with an explicit non-mapping statement). The two 🟠 High items
(bulk DML conflict, missing UX doc) are substantively fixed, not just disclosed. Both
🟡 Medium items are closed or meaningfully improved.

**READY is not the same as "fully unified."** The FR-10..39/FR-1..28 dual numbering
still exists as two live schemes — it is now accurately described instead of silently
ambiguous, which is what blocked Pass 1. Unifying them is real work for a future pass,
named explicitly rather than left to be rediscovered.

### Recommended before next implementation work begins

1. Rule on FR-namespace unification (own numbering vs. the matrix's) — not blocking
   for READY, but will keep resurfacing every time someone cites an FR without
   naming its source document.
2. Reconcile the Allura Enterprise Dashboard mockup's Cowork/Epic-25 module contract
   against ADR-34 (separate thread, flagged in the prior turn).
3. Consider making document-banner presence a `mortagate.gates.json` check —
   `content_match` already does this for the AI-disclosure string; the same
   mechanism would have caught the matrix collision automatically instead of
   requiring a readiness-check pass to surface it.

**Assessed by:** Brooks · **Date:** 2026-08-28 · **Pass:** 2 of 2
**Verdict:** 🟢 READY (up from 🟠 NEEDS WORK in Pass 1, same day)

---

## PASS 3 — POST-PIVOT RE-SCOPE (2026-08-28, same day)

Triggered by re-invoking `/bmad-check-implementation-readiness` after ADR-36 (platform
pivot: Cowork-only, CaseFile/Salesforce deprecated). **Scope changes from Pass 1/2:**
CaseFile's PRD and epics are no longer primary artifacts for this assessment — they
describe a deprecated product. Only the Cowork product (EP-6, `prd-cowork-2026-08-28.md`,
`product-brief-cowork.md`) is assessed as the live backlog.

Config updated before this run: `_bmad/bmm/config.yaml` project_name/comments still
said "CaseFile" and referenced a `salesforce_org_alias` — both stale post-ADR-36,
corrected as part of loading config for this pass.

### Step 1 — Document Discovery (re-scoped)

**PRD:**
- `prds/prd-cowork-2026-08-28.md` — **in scope**, live, CW-1..CW-22.
- `prds/prd-Mortagate-2026-06-14/prd.md` — **out of scope**, describes the deprecated
  product.

🔴 **CRITICAL — this PRD carries no banner.** It sits inside `{planning_artifacts}`
(the live-backlog root) with no disclosure that its product is deprecated. Contrast
with `planning docs/SOLUTION-ARCHITECTURE.md`, `REQUIREMENTS-MATRIX.md`,
`DATA-DICTIONARY.md`, and `BLUEPRINT.md`, all of which got a `[!CAUTION] Not current`
banner during the ADR-36 pivot commit. This file — sitting in the *more* prominent,
*more* likely-to-be-read-first location — was missed.

**Product brief:**
- `product-brief-cowork.md` — **in scope**, live.
- `product-brief.md` — **out of scope**, same gap as above.

🔴 **CRITICAL — same missing-banner defect.** `product-brief.md` has zero mention of
ADR-36. A reader landing here first (plausible — it's alphabetically first and
shorter) gets no signal the product it describes isn't being built.

**Architecture:**
- `SOLUTION-ARCHITECTURE.md` (symlink → `planning docs/SOLUTION-ARCHITECTURE.md`) —
  correctly bannered "Not current" from the prior pivot commit. But this means:

🔴 **CRITICAL — no in-scope architecture document exists for the active product on
this branch.** The Cowork module's own architecture doc,
`microsoft-cowork/docs/REFERENCE-ARCHITECTURE.md`, lives only on branch
`feat/microsoft-cowork-plugin` (PR #6, unmerged) — `microsoft-cowork/` does not exist
on this branch at all (`ls microsoft-cowork` → No such file or directory). This is a
structural gap, not a documentation-quality gap: the assessment cannot evaluate an
architecture document that isn't present, on this branch, at all.

**Epics & Stories:**
- `EPICS-AND-STORIES.md` — EP-6 marked **Active**; EP-0..EP-5 correctly marked **Not
  active** in the overview table (confirmed by direct read, not assumed from memory).

**UX:**
- `DESIGN-cowork-pilot-onboarding-ux.md` (symlink) — in scope, correctly scoped to
  Cowork pilot cohort.
- `DESIGN-casefile-auditor-ux.md` (symlink) — this is a pointer doc (to Figma) for the
  now-deprecated CaseFile auditor persona. Not actively misleading (it's clearly
  labeled as CaseFile-scoped in its own content), but it's discoverable via the same
  `*ux*.md` glob as the in-scope Cowork doc, with nothing at the glob level
  distinguishing "in scope" from "historical."

### Critical Issues Summary (Pass 3)

| # | Finding | Severity |
|---|---|---|
| 1 | `product-brief.md` and CaseFile PRD sit unbannered in the live `{planning_artifacts}` root | 🔴 Critical |
| 2 | No architecture document exists for the active product on this branch at all | 🔴 Critical |
| 3 | `DESIGN-casefile-auditor-ux.md` glob-discoverable alongside in-scope Cowork UX doc, no scope marker at filename level | 🟡 Medium |

### Resolutions applied (same pass, after the findings above)

| # | Finding | Resolution | Verified |
|---|---|---|---|
| 1 | `product-brief.md` + CaseFile PRD unbannered in live root | `[!CAUTION] Not current` banner added to both, pointing at the Cowork counterparts (`product-brief-cowork.md`, `prds/prd-cowork-2026-08-28.md`) | `grep -c "Not current"` → 1 in each |
| 2 | No in-scope architecture doc on this branch | **Not fixable in this pass** — `microsoft-cowork/docs/REFERENCE-ARCHITECTURE.md` exists only on `feat/microsoft-cowork-plugin` (PR #6, unmerged). Tracked as US-6.5 (human-gated merge). README now states the gap explicitly so nothing treats `SOLUTION-ARCHITECTURE.md` as filling it. | README §"No live architecture document exists on this branch" |
| 3 | `DESIGN-casefile-auditor-ux.md` glob-discoverable, no scope marker | **Removed from `{planning_artifacts}` entirely** (same treatment as the borrower UX doc) — deprecated product's pointer no longer sits next to the live Cowork doc under a glob that can't tell them apart. Source doc in `planning/` bannered; README documents the removal. | `ls planning-artifacts/*ux*.md` → Cowork doc only |
| 4 | **NEW — two more unbannered Carlos docs:** `DESIGN-LangChain-Compliance.md` and `copilot-instructions.md` describe the deprecated Salesforce product with zero banner (the pivot commit bannered 4 of 6 Carlos docs; these two were missed) | Same `[!CAUTION] Not current` banner applied to both, matching the BLUEPRINT form | `grep -c "Not current"` → 1 in each; 6/6 Carlos docs now bannered (RISKS-AND-DECISIONS.md correctly stays live — it holds the ADRs) |

### Step 2 — PRD Analysis (re-scoped to Cowork)

`prds/prd-cowork-2026-08-28.md` re-read in full; CW-1..CW-22 re-extracted and compared
against the Pass 1/2 extraction — **no drift**:

- **CW-1..CW-3** — Case onboarding (plain-language start, scope/boundaries stated up front, user-attached documents only)
- **CW-4..CW-8** — Evidence review (inventory, missing/ambiguous/conflicting, never infer from absence)
- **CW-9..CW-12** — Policy replay review (compare *supplied* replay, map to evidence, report unsupported, never restate as decision)
- **CW-13..CW-15** — Audit packet draft (reviewer-ready, always draft-marked, every finding cited)
- **CW-16..CW-22** — Refusal boundaries (7 prohibited actions, plain-language refusals)

**Total: 22 requirements, CW-1..CW-22, no gaps.** Every requirement carries an
acceptance criterion. Traceability table maps each CW group to its shipped skill
directory. CaseFile FR-1..FR-28 excluded from this pass as deprecated-product content.

### Step 3 — Epic Coverage Validation (re-scoped)

EP-6 is the only active epic. Its 8 stories (US-6.1..US-6.8) cover the CW groups:

| CW group | Covered by | Status |
|---|---|---|
| CW-1..CW-15 (4 skills) | US-6.7 pilot exercise criteria | ✓ specified; behavioural verification is pilot work |
| CW-16..CW-22 (refusals) | US-6.7 adversarial exercise criteria | ✓ specified; pilot work |
| PRD/brief/UX/architecture traceability | US-6.1..US-6.4 | ✓ closed (US-6.1, US-6.2, US-6.3, US-6.4) |
| Merge + tenant validation + pilot + go/no-go | US-6.5..US-6.8 | ⏳ open, human-gated |

No orphan CW requirements; no phantom story references. The PRD's traceability table
and EP-6's story ACs agree in both directions.

### Step 4 — UX Alignment (re-scoped)

- `DESIGN-cowork-pilot-onboarding-ux.md` (symlink → `planning/DESIGN-cowork-pilot-onboarding.md`) — **in scope, current, correct persona** (internal mortgage employee, pilot cohort). Explicitly distinguished from the borrower persona.
- CaseFile auditor UX pointer removed from the glob root (finding 3) — no deprecated-product UX surfaces as current.
- US-6.4's three open items (invite/licensing, fixture source, feedback channel) remain open — flagged for Sabir, not assumed.

### Step 5 — Epic Quality Review (re-scoped to EP-6)

| Check | Result |
|---|---|
| Stories missing `Depends on` | **0** ✅ |
| Forward dependencies (story depends on a later story) | **0** ✅ |
| Circular dependencies | **0** ✅ |
| Stories without acceptance criteria | **0** ✅ (8/8 have ACs) |
| Dependency chain | US-6.1 → US-6.2/6.3/6.4 → US-6.5 → US-6.6 → US-6.7 → US-6.8 — strictly forward, no cycles |

EP-6 is clean by the structural standard. US-6.5..US-6.8 are correctly external/human-gated (merge, tenant sign-in, pilot, go/no-go) — appropriate for a pilot epic, not a defect.

### Step 6 — Overall Verdict (Pass 3)

**🟢 READY — with one structural dependency.**

- All four findings from this pass are resolved (1, 3, 4) or explicitly tracked (2).
- The remaining gap — no in-scope architecture doc on this branch — is **not a documentation defect**: the doc exists on PR #6 and lands with the merge (US-6.5). It is a merge-blocked structural dependency, owned by Sabir (Brooks does not merge PRs unilaterally).
- The planning layer for the active product is now internally consistent: live PRD (CW-1..CW-22), live brief, live epics (EP-6), live UX doc, and every deprecated-product document bannered or removed from glob discovery.

**Assessed by:** Brooks · **Date:** 2026-08-28 · **Pass:** 3 of 3
**Verdict:** 🟢 READY (Cowork-scoped) — blocked only on PR #6 merge (US-6.5) for the architecture artifact.
