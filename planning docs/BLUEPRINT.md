# Veridact — Blueprint

> [!NOTE]
> **AI-Assisted Documentation**
> Portions of this document were drafted with the assistance of an AI language model.
> Content has been reviewed against the PRD, product brief, and codebase but requires stakeholder sign-off.

---

## B1. Project Identity

| Field | Value |
|-------|-------|
| **Project** | Veridact — Mortgage Audit Replay & QC |
| **Tagline** | "Every decision has a receipt." |
| **Brand** | Veridact Brand Kit v1.0.1 (Canvas/Ink/Orange/Outfit) |
| **Platform** | React + Salesforce + Agentforce + Allura Brain (4 layers) |
| **Org** | mortagate-de (Developer Edition) |
| **Alias** | mortagate-de |
| **Owner** | Sabir Asheed (sasheed72@gmail.com) |
| **Memory** | allura-mortgage |
| **PRD** | `prd-Mortagate-2026-06-14/prd.md` (28 FRs, 8 features) |
| **Status** | v1 demo build |

### What Veridact Is

An internal mortgage audit tool for bank QC analysts. The auditor takes an already-approved loan, replays the exact policy rules that were in force at approval time, maps each rule to its supporting evidence, records pass/exception/violation findings, and produces an immutable audit receipt ready for regulators.

### What Veridact Is Not

- Not a borrower-facing portal (frozen per ADR-15)
- Not a loan origination system
- Not a document extraction / OCR tool (deferred to v3)
- Not autonomous AI -- Agentforce assists, humans decide
- Not multi-tenant (single org for demo and pilot)

---

## B2. Design Principles

1. **Append-only audit** (ADR-1) -- `Audit_Event__c` and `Audit_Receipt__c` records are immutable. Enforced by Apex trigger and validation rule, not convention.
2. **Worst-wins** (ADR-2) -- When multiple rule checks conflict, the most severe outcome governs the case risk tier.
3. **Missing fact = INDETERMINATE** (ADR-3) -- A missing evidence item does not produce PASS or FAIL. It produces INDETERMINATE / Unverifiable, forcing the auditor to investigate.
4. **Rules are data, not code** (ADR-4) -- Policy rules stored as `Policy_Rule__c` records, versioned with effective dates. Analysts maintain rules without deployment.
5. **Three-layer pure kernel** (ADR-5) -- Fact assembly (read) / Rule evaluation (pure) / Decision commit (write). The evaluator has zero SOQL and zero DML.
6. **Deterministic ordering** (ADR-6) -- Replay checks are returned sorted by `Rule_Code__c`. Same inputs produce byte-identical output ordering across runs.
7. **AI assists, humans decide** -- Agentforce MAY summarize, draft, recommend, and create controlled tasks. Agentforce MUST NOT approve audits, close cases, override policy, delete findings, or modify signed receipts.
8. **Historical fidelity** -- Replay uses the exact policy version effective at the loan's approval date, not today's rules.
9. **Queue-first, not dashboard-first** -- The auditor's landing screen is a work queue, not a metrics dashboard.

---

## B3. User Journey -- Auditor QC Workflow (5 Screens)

### Screen 1: Audit Queue

The auditor's landing page. A filterable, sortable work queue of assigned audit cases.

- Columns: Case Name, Loan Amount, Risk Tier, Status, SLA Due Date, Assigned Auditor, Branch, Product Type
- Risk-tier badges: High (Red `#BE3232`), Medium (Amber `#D39826`), Low (Green `#308357`)
- Default sort: SLA Due Date ascending (most urgent first)
- Filters: Status, Risk Tier, Branch, Product Type, Assigned Approver (AND logic)
- Summary metrics above queue: total cases, by-status counts, SLA-at-risk count (due within 2 days)
- Click a row to navigate to Case Review
- FR-1 through FR-4

### Screen 2: Case Review

Two-pane review screen. Evidence pack on the left, replay checklist on the right.

- **Left pane (Evidence Panel):** All evidence items for the case with document type, status (Linked / Missing / Unverifiable), and upload date. Missing items show amber badge. Auditor can preview documents and update evidence status.
- **Right pane (Replay Checklist):** Each policy rule check with result (Pass / Fail / Unverifiable), expected value, actual value, and linked evidence item. Expandable to show full rule definition, threshold, operator, policy version, and evidence linkage.
- Auditor triggers replay manually (not automatic on open)
- Auditor can create a Finding from any replay check
- Agentforce sidebar available: "summarize this case", "what evidence is missing?", "draft a finding for the DTI violation"
- FR-5 through FR-9

### Screen 3: Finding Detail

Dedicated screen or modal for documenting a finding.

- Pre-populated from replay check: rule name, expected/actual values, evidence linkage
- Severity: Pass / Exception / Violation (required)
- Description: free text up to 32,000 chars, or accept AI-drafted text
- Evidence items: multi-select from case evidence (at least one required, or explicit "No evidence available")
- Remediation notes: free text
- Agentforce can draft finding text citing rule, threshold, actual value, and policy version. Auditor must accept, edit, or override -- Agentforce cannot create findings autonomously.
- FR-10, FR-11

### Screen 4: Sign-off Receipt

Immutable audit receipt generated on manager approval.

- Auditor submits case for sign-off when all replay checks have findings and all mandatory evidence is linked or explicitly marked
- Manager reviews and approves or returns
- Approval creates an `Audit_Receipt__c` record with: reviewer, timestamp, findings snapshot, evidence snapshot, replay results snapshot
- Receipt is immutable -- UPDATE and DELETE blocked by trigger + validation rule
- Case status moves to Closed
- PDF export available (Visualforce `renderAs="pdf"`, Veridact brand styling)
- Self-audit prevention: auditor cannot sign off on their own case
- FR-12 through FR-14

### Screen 5: Analytics

Monitoring screen for audit program operations.

- Aggregate metrics: total cases reviewed, exception rate, violation rate, missing evidence rate, average review time
- Filterable by date range, branch, product type, approver
- Approver drift detection: per-approver exception/violation rates, flagging outliers at 2x branch average
- Drill-down to specific cases and findings for flagged approvers
- v1 reads from Salesforce aggregate SOQL, not a separate analytics engine
- FR-15, FR-16

### Sidebar Navigation (7 items)

Audit Queue | Case Review | Findings | Receipts | Analytics | Policy Versions | Admin

---

## B4. Data Model -- Entity Relationships (11 SObjects)

```
Audit_Case__c (1) ──→ (0..*) Evidence_Item__c
Audit_Case__c (1) ──→ (0..*) Replay_Check__c
Audit_Case__c (1) ──→ (0..*) Finding__c
Audit_Case__c (1) ──→ (0..*) Audit_Event__c    [append-only]
Audit_Case__c (1) ──→ (0..1) Audit_Receipt__c   [append-only]

Policy_Version__c (1) ──→ (1..*) Policy_Rule__c
Replay_Check__c (*) ──→ (1) Policy_Rule__c

Finding__c (*) ──→ (1) Replay_Check__c
Finding__c (*) ──→ (*) Evidence_Item__c

Agent_Action_Log__c  [append-only, logs every Agentforce action]
Audit_Event__c       [append-only, chain of custody]
```

### Core Objects

| Object | Purpose | Immutable? |
|--------|---------|------------|
| `Audit_Case__c` | A single loan under review. Status, risk tier, SLA, assigned auditor. | No (status transitions allowed) |
| `Evidence_Item__c` | Document linked to a case (pay stub, appraisal, credit report). Status: Linked / Missing / Unverifiable. | No (status updates allowed) |
| `Policy_Version__c` | Versioned policy with effective dates. | Yes, after referenced by Replay_Check__c |
| `Policy_Rule__c` | A specific rule within a policy version (DTI_MAX, FICO_MIN). Threshold, operator, severity. | Yes, after referenced by Replay_Check__c |
| `Replay_Check__c` | Result of applying one rule to one case's evidence. Expected value, actual value, result. | Yes (created by replay engine) |
| `Finding__c` | Auditor's judgment: Pass / Exception / Violation. Severity, description, evidence linkage, remediation. | No (editable until case signed off) |
| `Audit_Receipt__c` | Immutable sign-off record with full snapshot. | Yes (trigger + validation rule) |
| `Audit_Event__c` | Chain of custody log entry. Event type, actor, timestamp, payload. | Yes (trigger + validation rule) |
| `Agent_Action_Log__c` | Log of every Agentforce action. Action name, subagent, actor, timestamp, case ID, details. | Yes (append-only) |

### Cardinality Rules

| Relationship | Min | Max | Constraint |
|---|---|---|---|
| Case -> Evidence Item | 0 | unlimited | Zero if evidence not yet gathered |
| Case -> Replay Check | 0 | unlimited | Zero before replay execution |
| Case -> Finding | 0 | unlimited | Zero before auditor review |
| Case -> Audit Event | 1 | unlimited | At least one (case creation event) |
| Case -> Audit Receipt | 0 | 1 | Created on sign-off |
| Policy Version -> Policy Rule | 1 | unlimited | At least one rule per version |
| Replay Check -> Policy Rule | 1 | 1 | Each check tests exactly one rule |

### Invariants

- `Audit_Event__c`: No UPDATE, no DELETE. Enforced by validation rule `Prevent_Edit_After_Creation` + before-delete trigger `AuditEventPreventDelete`.
- `Audit_Receipt__c`: No UPDATE, no DELETE. Same enforcement pattern.
- `Agent_Action_Log__c`: Append-only. No UPDATE, no DELETE.
- `Policy_Version__c` and `Policy_Rule__c`: Immutable after referenced by any `Replay_Check__c`.
- Only ONE `Policy_Version__c` per policy code can have `Is_Active__c = true` and no `Expiration_Date__c`.

---

## B5. Policy Replay Engine -- Three-Layer Architecture (ADR-5)

### Layer 1: Fact Assembly (`FactAssemblerService`)

- Queries `Evidence_Item__c` and extracted facts for a given `Audit_Case__c`
- Resolves governing `Policy_Version__c` and `Policy_Rule__c` records by matching the loan's approval date against rule effective date ranges
- Builds an immutable `ReplayContext` value object
- Only class allowed to query the database on behalf of the engine
- If multiple versions exist for the same rule code, the latest effective version is selected (FR-26)

### Layer 2: Rule Evaluation (`PolicyRuleEvaluator`)

- Pure function: `evaluate(ctx: ReplayContext) -> List<ReplayCheckResult>`
- Walks each rule: compares fact value against operator + threshold
- Operators: GT, GTE, LT, LTE, EQ, NEQ, IN, BETWEEN
- Missing facts produce INDETERMINATE result, not failure (ADR-3)
- Results sorted by `Rule_Code__c` for deterministic ordering (ADR-6)
- Zero database reads. Zero database writes. Zero side effects. Fully unit-testable.

### Layer 3: Decision Commitment (`ReplayCommitService`)

- Receives `List<ReplayCheckResult>`, creates `Replay_Check__c` records
- Populates `Policy_Rule__c` lookup, result fields, evidence linkage
- Creates `Audit_Event__c` with Event_Type `Replay_Executed`
- Only class that writes. Called from controller or invocable Apex -- never from evaluator.

### Bulk Safety Contract (ADR-5)

- Rules loaded ONCE outside loop (1 SOQL)
- Evidence loaded in single bulk query (1 SOQL)
- Policy version resolution in single query (1 SOQL)
- Evaluation is pure in-memory -- zero SOQL per case
- `Replay_Check__c` records bulk-inserted (1 DML)
- Total for N cases: 3 SOQL + 1 DML. Scales linearly.
- Bulk-tested with 200+ records.

---

## B6. Agentforce -- Governed AI Assistance (ADR-16)

### 4 Subagents

| Subagent | Scope | Actions |
|----------|-------|---------|
| **Auditor Assistant** | Case-level summarization and drafting | `getAuditCaseSummary`, `getMissingEvidence`, `draftFindingText` |
| **Evidence Request** | Evidence gap workflow | `draftEvidenceRequest` |
| **Manager Review** | Sign-off preparation | `prepareManagerSummary` |
| **Compliance Analytics** | Operational metrics | `getComplianceMetrics`, `getApproverDriftReport` |

### 8 Safe Actions

1. `getAuditCaseSummary` -- Summarize case (loan amount, DTI, FICO, evidence status, findings count, risk tier)
2. `getMissingEvidence` -- List missing/unverifiable evidence items
3. `draftFindingText` -- Draft finding text citing rule, threshold, actual value, policy version
4. `draftEvidenceRequest` -- Draft internal email for missing evidence items
5. `prepareManagerSummary` -- Structured sign-off summary (findings, evidence, replay results, recommendation)
6. `getComplianceMetrics` -- Aggregate audit metrics
7. `getApproverDriftReport` -- Per-approver exception/violation rates
8. `logAgentAction` -- Log every action to `Agent_Action_Log__c` + `Audit_Event__c`

### 3 Prompt Templates

1. `Draft_Finding_Text` -- Generates finding description from replay check result
2. `Draft_Evidence_Request` -- Generates professional internal email for missing items
3. `Prepare_Manager_Summary` -- Generates structured sign-off summary

### Hard Rules

| MAY | MUST NOT |
|-----|----------|
| Summarize cases | Approve audits |
| Draft findings and requests | Close cases |
| Recommend actions | Override policy |
| Create controlled tasks | Delete findings |
| List missing evidence | Modify signed receipts |

Every action calls `logAgentAction` before execution. No action can execute without logging.

---

## B7. Brand -- Veridact Visual Identity

| Token | Value | Usage |
|-------|-------|-------|
| Canvas | `#F5F0E8` | Background |
| Ink | `#1F1E1C` | Primary text |
| Primary | `#E25D22` | Accent, CTAs |
| Green | `#308357` | Pass / Low risk |
| Red | `#BE3232` | Violation / High risk |
| Amber | `#D39826` | Exception / Medium risk / Missing evidence |
| Blue | `#2B5C83` | Informational / links |
| Display font | Outfit Bold | Headings |
| Body font | Inter | Body text |

Risk-tier badges use color + text label (never color alone, per WCAG 2.1 AA).

---

## B8. Success Metrics

| ID | Metric | Target | Validates |
|----|--------|--------|-----------|
| SM-1 | Review time per loan | < 10 minutes (from 45 min baseline) | FR-1 through FR-14 |
| SM-2 | Evidence linkage rate | > 95% of replay checks have evidence linked | FR-5, FR-7, FR-8 |
| SM-3 | Exception documentation rate | 100% of exceptions documented or flagged | FR-9, FR-10 |
| SM-4 | Audit receipt completeness | 100% of closed cases have immutable receipt | FR-12, FR-13, FR-25 |
| SM-5 | Agentforce draft acceptance rate | > 90% accepted without major edits | FR-17 through FR-21 |
| SM-6 | False positive rate | < 5% of violations overturned on review | FR-27 |

Counter-metrics: SM-C1 (review thoroughness must not drop), SM-C2 (auditors must edit > 10% of AI drafts to demonstrate active judgment).

---

## B9. Open Questions

| ID | Question | Owner | Status |
|----|----------|-------|--------|
| OQ-1 | Schema reconciliation: rename existing code names (`Rule_Check__c`, `Policy_Rule_Version__c`) to match PRD canonical names (`Replay_Check__c`, `Policy_Version__c` + `Policy_Rule__c`), or update PRD to match code? | Brooks | Open |
| OQ-2 | Policy lifecycle ownership: who creates, approves, publishes, and retires policy versions? | Sabir | Open |
| OQ-3 | Production LOS decision: which LOS for v2 integration (Encompass, ICE, Blend)? | Sabir | Open |
| OQ-4 | Agentforce controlled writes: when does Agentforce move from draft-only to controlled write actions? | Brooks | Open |
| OQ-5 | Real data approval: what legal/compliance gate is needed before production borrower data enters AI prompts? | Sabir | Open |
