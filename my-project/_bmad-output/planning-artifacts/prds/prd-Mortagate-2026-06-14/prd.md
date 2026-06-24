---
title: "Veridact — Mortgage Audit Replay & QC"
status: draft
created: 2026-06-14
updated: 2026-06-14
---

# PRD: Veridact — Mortgage Audit Replay & QC

## 0. Document Purpose

This PRD defines the requirements for Veridact, an internal mortgage audit replay and QC tool. It is written for the development team (Brooks orchestrating Team RAM), the product owner (Sabir Asheed), and downstream workflow owners (architecture, UX, epics). The document builds on the product brief (`product-brief.md`), the canonical Notion page, Figma wireframes, and 13 existing ADRs. Functional requirements are globally numbered (FR-1 through FR-N) and grouped by feature. Glossary terms are used verbatim throughout. Assumptions are tagged inline and indexed in section 9.

## 1. Vision

Veridact gives bank mortgage auditors a tool to verify whether already-approved loans should have been approved. The auditor takes a closed loan, replays the exact policy rules that were in force at the time of approval, maps each rule to its supporting evidence, and records pass, exception, or violation findings — producing an immutable audit receipt ready for regulators.

The product is built on four layers that each do one job: React renders the auditor's cockpit, Salesforce manages enterprise workflow and records, Agentforce assists the auditor in-platform (summarizing, drafting, requesting), and Allura provides governed audit reasoning (historical replay, evidence mapping, exception detection). The human auditor is the final decision-maker at every step.

The tagline is the architecture: **"Every decision has a receipt."**

## 2. Target User

### 2.1 Jobs To Be Done

- **Verify loan approval correctness** — "I need to check whether this loan was approved according to the rules that were in force at the time, not today's rules."
- **Document findings with evidence** — "I need to link each rule check to the specific document that proves it, and flag when evidence is missing."
- **Catch unjustified exemptions** — "I need to find cases where a loan officer approved a loan that violated guidelines without documented approval for the exception."
- **Produce a defensible audit trail** — "I need a permanent record of what I checked, what I found, and who signed off, so I can hand it to an examiner."
- **Review faster without cutting corners** — "I do 10-30 reviews a day. I need to be thorough but not spend 45 minutes per loan."

### 2.2 Non-Users (v1)

- **Borrowers** — no borrower-facing portal in v1 (frozen per ADR-15)
- **Loan officers** — they receive evidence requests but do not use the audit tool
- **External regulators** — they receive audit receipts as exports, not as app users

### 2.3 Key User Journeys

**UJ-1. Fatima triages her morning queue.**
- **Persona + context:** Fatima, QC analyst at a regional bank, starts her shift with 15 assigned cases.
- **Entry state:** Authenticated in the React cockpit, lands on Audit Queue.
- **Path:** Scans the queue sorted by SLA urgency. Sees risk-tier badges (High/Medium/Low). Filters by "Evidence Needed" status. Spots a high-risk case 2 days from SLA breach. Clicks to open Case Review.
- **Climax:** She has prioritized her work in under 2 minutes without opening any individual case.
- **Resolution:** Case Review loads with evidence pack on the left, replay checklist on the right.

**UJ-2. Fatima replays a high-risk case and drafts a finding.**
- **Persona + context:** Same Fatima, now inside Case Review for a $380K conventional loan.
- **Entry state:** Two-pane view loaded. Evidence items listed. Replay not yet run.
- **Path:** Asks Agentforce "summarize this case" — gets a natural-language overview (loan amount, DTI, FICO, evidence status). Runs replay — each rule shows pass/exception/violation against the historical policy version. Sees DTI_MAX violation (44.8% actual vs 43% threshold). Checks evidence — pay stub linked, but no documented exception approval. Asks Agentforce "draft a finding for the DTI violation" — gets a draft citing the rule, threshold, actual value, and policy version. Reviews the draft, edits one sentence, accepts.
- **Climax:** Finding is recorded with specific evidence linkage, rule citation, and severity (Violation).
- **Resolution:** Case status updates to "Ready for Sign-off." Finding is visible in the case timeline.
- **Edge case:** If the evidence item for income is missing, the replay check shows "Unverifiable" and the finding draft notes the gap. Fatima can trigger an evidence request to the loan officer.

**UJ-3. Fatima's manager signs off on the case.**
- **Persona + context:** Derek, audit manager, reviews Fatima's completed case.
- **Entry state:** Case is in "Ready for Sign-off" status. Derek opens the Sign-off Receipt screen.
- **Path:** Asks Agentforce "prepare the sign-off summary" — gets a structured summary of all findings, evidence status, and replay results. Reviews each finding. Approves. Signs the receipt.
- **Climax:** An immutable audit receipt is created. It cannot be edited or deleted after sign-off.
- **Resolution:** Case moves to "Closed." Receipt is available for export. The entire chain of custody is preserved in `Audit_Event__c`.

## 3. Glossary

- **Audit Case** — A single loan under review. Tracks status, risk tier, SLA, assigned auditor, and related evidence, findings, and events. (`Audit_Case__c`)
- **Replay** — Re-execution of the exact policy rules that governed the loan at approval time, applied to the loan's evidence.
- **Policy Version** — A versioned record of a lending policy rule with effective dates, thresholds, and operators. Rules are data, not code. (`Policy_Version__c`)
- **Policy Rule** — A specific rule within a policy version (e.g., DTI_MAX, FICO_MIN). (`Policy_Rule__c`)
- **Replay Check** — The result of applying one policy rule to one audit case's evidence. Shows expected value, actual value, result (Pass/Fail/Unverifiable), and linked evidence. (`Replay_Check__c`)
- **Finding** — An auditor's documented judgment on a replay check result: Pass, Exception (rule bent with approval), or Violation (rule broken). Includes severity, remediation, and evidence linkage. (`Finding__c`)
- **Evidence Item** — A document or record linked to an audit case (pay stub, appraisal, credit report). Has a status: Linked, Missing, Unverifiable. (`Evidence_Item__c`)
- **Audit Receipt** — The immutable sign-off record created when a manager approves the completed review. Append-only. (`Audit_Receipt__c`)
- **Audit Event** — An immutable log entry in the case's chain of custody. Appended whenever something material happens. Never edited, never deleted. (`Audit_Event__c`)
- **Exception** — A rule was bent, with documented approval. Distinguished from a Violation.
- **Violation** — A rule was broken without documented approval.
- **Agent Action Log** — A record of every Agentforce action taken, for auditing the auditor's AI assistant. (`Agent_Action_Log__c`)
- **Subagent** — An Agentforce agent module (formerly "topic") that handles a specific domain of work.

## 4. Features

### 4.1 Audit Queue

**Description:** The auditor's landing screen. A filterable, sortable work queue showing all assigned audit cases with risk-tier badges, SLA status, case status, and key loan details. Queue-first, not dashboard-first. Realizes UJ-1.

#### FR-1: Queue display
Auditor can view all assigned audit cases in a tabular queue with columns: Case Name, Loan Amount, Risk Tier, Status, SLA Due Date, Assigned Auditor, Branch, Product Type.

**Consequences (testable):**
- Queue loads within 2 seconds for up to 500 cases
- Risk-tier badges render as colored chips (High=Red, Medium=Amber, Low=Green)
- Cases sorted by SLA Due Date ascending by default

#### FR-2: Queue filtering
Auditor can filter the queue by Status (`In Review`, `Evidence Needed`, `Ready for Sign-off`, `Closed`), Risk Tier, Branch, Product Type, and Assigned Approver.

**Consequences (testable):**
- Filters are reactive — queue updates without page reload
- Multiple filters combine with AND logic
- Filter state persists within the session

#### FR-3: Queue metrics
Auditor can view summary metrics above the queue: total cases, by-status counts (In Review, Evidence Needed, Ready for Sign-off, Closed), and SLA-at-risk count.

**Consequences (testable):**
- Metrics update when filters change
- SLA-at-risk count shows cases where SLA Due Date <= today + 2 days

#### FR-4: Case navigation
Auditor can click a queue row to navigate to Case Review for that case.

**Consequences (testable):**
- Navigation preserves queue filter state for back-navigation

### 4.2 Case Review

**Description:** The two-pane review screen. Evidence pack on the left (documents, status, linked facts), replay checklist on the right (each rule check with result, evidence link, and action buttons). Progressive disclosure — summary first, drill into policy and evidence on demand. Realizes UJ-2.

#### FR-5: Evidence panel
Auditor can view all evidence items linked to the audit case, with document type, status (Linked/Missing/Unverifiable), and upload date.

**Consequences (testable):**
- Missing evidence items are visually distinct (amber badge)
- Auditor can open/preview the evidence document

#### FR-6: Replay execution
Auditor can trigger a replay of the audit case against its governing policy version.

**Consequences (testable):**
- Replay uses the exact Policy_Version__c and Policy_Rule__c records that were effective at the loan's approval date
- Each rule produces a Replay_Check__c with: rule name, expected value, actual value, result (Pass/Fail/Unverifiable), and linked evidence item
- Replay results appear in the right panel ordered by rule code
- [ASSUMPTION: Replay is triggered manually, not automatically on case open]

#### FR-7: Replay check detail
Auditor can expand any replay check to see the full rule definition, threshold, operator, policy version, and evidence linkage.

**Consequences (testable):**
- Expanding a check shows the Policy_Rule__c fields: Rule_Code, Threshold, Operator, Severity, Fact_Field, Rule_Explanation
- Evidence linkage shows which Evidence_Item__c supports this check, or "No evidence linked"

#### FR-8: Evidence status update
Auditor can update an evidence item's status (Linked, Missing, Unverifiable) from the evidence panel.

**Consequences (testable):**
- Status change creates an Audit_Event__c with Event_Type `Evidence_Status_Changed`
- Parent Audit_Case__c status recalculates based on evidence completeness

#### FR-9: Create finding from replay check
Auditor can create a Finding from any replay check result.

**Consequences (testable):**
- Finding captures: rule name, severity (Pass/Exception/Violation), description, evidence linkage, remediation notes
- Finding is linked to both the Audit_Case__c and the Replay_Check__c
- Creation logs an Audit_Event__c with Event_Type `Finding_Created`

### 4.3 Finding Detail

**Description:** A dedicated screen or modal for documenting a finding in detail. The auditor specifies severity, writes or accepts AI-drafted description text, links evidence, and adds remediation notes. Realizes UJ-2.

#### FR-10: Finding creation form
Auditor can fill in finding fields: Rule Name (pre-populated from replay check), Severity (Pass/Exception/Violation), Description (free text or AI draft), Evidence Items (multi-select from case evidence), Remediation Notes.

**Consequences (testable):**
- Severity is a required field
- Description field accepts plain text up to 32,000 characters
- At least one evidence item must be linked, or auditor must explicitly mark "No evidence available"

#### FR-11: AI-drafted finding text
Auditor can request Agentforce to draft finding text based on the replay check result.

**Consequences (testable):**
- Draft cites the specific rule, threshold, actual value, and policy version
- Draft is presented for auditor review — auditor must accept, edit, or override
- Agentforce cannot create findings autonomously
- Action is logged to Agent_Action_Log__c

### 4.4 Sign-off Receipt

**Description:** The immutable audit receipt generated when a manager approves a completed review. Once signed, the receipt cannot be edited or deleted. Realizes UJ-3.

#### FR-12: Sign-off workflow
Auditor can submit a case for sign-off when all replay checks have findings and all mandatory evidence is linked or explicitly marked.

**Consequences (testable):**
- Case status changes to "Ready for Sign-off"
- Submission creates an Audit_Event__c with Event_Type `Submitted_For_Signoff`
- [ASSUMPTION: Self-audit prevention — auditor cannot sign off on their own case]

#### FR-13: Manager sign-off
Manager can review a case in "Ready for Sign-off" status and approve or return it.

**Consequences (testable):**
- Approval creates an Audit_Receipt__c record with: reviewer, timestamp, all findings snapshot, all evidence snapshot, replay results snapshot
- Audit_Receipt__c is immutable — UPDATE and DELETE are blocked by validation rule + trigger
- Case status changes to "Closed"
- Sign-off creates an Audit_Event__c with Event_Type `Case_Signed_Off`

#### FR-14: Receipt PDF export
Auditor or manager can export the audit receipt as a PDF document.

**Consequences (testable):**
- PDF includes: case name, loan details, all findings with severity and evidence, replay results, reviewer name and timestamp, immutability disclosure
- PDF renders via Visualforce `renderAs="pdf"`
- [ASSUMPTION: PDF uses Veridact brand styling]

### 4.5 Analytics Dashboard

**Description:** Monitoring screen showing audit program metrics: exception rate, violation rate, missing evidence patterns, approver drift, branch risk, and SLA compliance. Realizes the manager's need for operational visibility.

#### FR-15: Aggregate metrics display
Manager can view aggregate metrics across all audit cases: total cases reviewed, exception rate, violation rate, missing evidence rate, average review time.

**Consequences (testable):**
- Metrics are filterable by date range, branch, product type, and approver
- [ASSUMPTION: Analytics are read from Salesforce aggregate queries, not a separate analytics engine in v1]

#### FR-16: Approver drift detection
Manager can view per-approver exception and violation rates to identify outliers.

**Consequences (testable):**
- Approvers with exception rates > 2x the branch average are flagged
- Drill-down shows the specific cases and findings for any flagged approver

### 4.6 Agentforce Assistance

**Description:** Agentforce provides in-platform AI assistance through 4 subagents and 8 safe actions. Every action logs to the audit trail. Agentforce assists; humans decide. Realizes UJ-2 and UJ-3.

#### FR-17: Case summarization
Auditor can ask Agentforce to summarize an audit case.

**Consequences (testable):**
- Summary includes: loan amount, DTI, FICO, evidence status (X of Y linked), findings count, risk tier
- Action calls `getAuditCaseSummary` Apex invocable method
- Action logged to Agent_Action_Log__c and Audit_Event__c

#### FR-18: Missing evidence listing
Auditor can ask Agentforce to list missing or unverifiable evidence.

**Consequences (testable):**
- Returns each missing item with document type and reason (Missing vs Unverifiable)
- Action calls `getMissingEvidence` Apex invocable method
- Action logged

#### FR-19: Finding text drafting
Auditor can ask Agentforce to draft finding text for a replay check.

**Consequences (testable):**
- Draft cites: rule name, threshold, actual value, policy version, evidence status
- Draft uses the Prompt Template `Draft_Finding_Text`
- Auditor must accept, edit, or override — Agentforce cannot create findings directly
- Action logged

#### FR-20: Evidence request drafting
Auditor can ask Agentforce to draft an evidence request for missing items.

**Consequences (testable):**
- Draft is a professional internal email listing missing items and SLA deadline
- Draft uses the Prompt Template `Draft_Evidence_Request`
- Auditor must review and approve before sending
- Action logged

#### FR-21: Manager review summary
Manager can ask Agentforce to prepare a sign-off summary.

**Consequences (testable):**
- Summary includes: all findings, evidence status, replay results, recommendation (Ready/Needs review)
- Uses Prompt Template `Prepare_Manager_Summary`
- Action logged

#### FR-22: Violation notification
When a replay detects a rule violation (severity = HARD_DECLINE or SOFT_DECLINE), Agentforce proactively sends a notification to the assigned auditor and their manager.

**Consequences (testable):**
- Notification fires automatically after replay execution completes, not on auditor request
- Notification includes: case name, rule name, expected vs actual value, severity, and a link to the case
- Notification is delivered via Salesforce in-app notification and email [ASSUMPTION: notification channels are in-app + email; Slack/Teams deferred]
- If no auditor is assigned, notification goes to the queue manager
- Notification itself is logged as an Audit_Event__c with Event_Type `Violation_Alert_Sent`
- Notification does NOT approve, close, or take any action on the case — it only alerts

#### FR-23: Agent action governance
Every Agentforce action must log to Agent_Action_Log__c with: action name, subagent, actor, timestamp, audit case ID, and action details.

**Consequences (testable):**
- Agent_Action_Log__c records are append-only
- Audit_Event__c also receives a corresponding event for each action
- No Agentforce action can execute without calling `logAgentAction`

### 4.7 Audit Trail Immutability

**Description:** The append-only audit trail is the product's core integrity guarantee. Every material action creates an Audit_Event__c record. These records cannot be edited or deleted. Enforced by code, not convention. Cross-cuts all features.

#### FR-24: Append-only events
Every material action (case creation, evidence status change, replay execution, finding creation, sign-off, agent action, violation alert) creates an Audit_Event__c record.

**Consequences (testable):**
- Audit_Event__c has fields: Audit_Case__c (lookup), Event_Type__c, Actor__c, Timestamp__c, Payload__c (JSON), Related_Record_Id__c
- All event types are documented in the Data Dictionary

#### FR-25: Immutability enforcement
Audit_Event__c and Audit_Receipt__c records cannot be updated or deleted.

**Consequences (testable):**
- UPDATE on Audit_Event__c is blocked by validation rule `Prevent_Edit_After_Creation`
- DELETE on Audit_Event__c is blocked by before-delete trigger `AuditEventPreventDelete`
- UPDATE and DELETE on Audit_Receipt__c are blocked similarly
- Bulk test: 200 update attempts on existing events — all blocked, all records unchanged

### 4.8 Historical Policy Replay Engine

**Description:** The replay engine reconstructs the exact rules that governed a loan at approval time and evaluates them against the loan's evidence. The engine is a pure kernel — zero SOQL, zero DML in the evaluator. Cross-cuts Case Review and Finding Detail.

#### FR-26: Policy version resolution
System resolves the governing Policy_Version__c and Policy_Rule__c records based on the loan's approval date and the rule's effective date range.

**Consequences (testable):**
- Resolution returns only rules whose effective date <= loan approval date
- If multiple versions exist for the same rule code, the latest effective version is selected
- Resolution is deterministic and reproducible

#### FR-27: Pure evaluation
PolicyRuleEvaluator evaluates rules against reconstructed facts with zero SOQL and zero DML.

**Consequences (testable):**
- Evaluator is a pure function: facts in, results out
- Supports operators: GTE, LTE, GT, LT, EQ, NEQ, IN, BETWEEN
- Missing facts produce INDETERMINATE result, not a failure (per ADR-3)
- Evaluation is bulk-safe: 3 SOQL + 1 DML for N cases

#### FR-28: Deterministic rule ordering
Replay checks are returned in deterministic order sorted by Rule_Code__c.

**Consequences (testable):**
- Same inputs produce byte-identical output ordering across runs (per ADR-6)

## 5. Non-Goals (Explicit)

- **Not a borrower portal** — no borrower-facing features in v1 (frozen per ADR-15)
- **Not a loan origination system** — Veridact does not originate, process, or approve loans
- **Not a document extraction tool** — no OCR, no AI-powered document parsing in v1
- **Not a vector search / semantic engine** — no embeddings or similarity search in v1
- **Not multi-tenant** — single org deployment for demo and pilot
- **Not a replacement for the LOS** — no Encompass/ICE/Blend integration in v1
- **Not autonomous AI** — Agentforce assists, it does not decide

## 6. MVP Scope

### 6.1 In Scope

- 5-screen auditor workflow (Queue, Case Review, Finding Detail, Sign-off Receipt, Analytics)
- Historical policy replay against versioned rules
- Evidence-to-rule mapping with Missing/Unverifiable as explicit states
- 4 Agentforce subagents with 8 safe actions
- 3 Prompt Templates (Draft Finding, Evidence Request, Manager Summary)
- Append-only audit receipt with code-enforced immutability
- React cockpit + Salesforce workflow + Agentforce sidebar
- 11 Salesforce objects (see Glossary)
- Veridact brand (Cream/Charcoal/Orange/Outfit)
- Fictional demo data (Kaggle-sourced, 5 personas + 200 bulk records)
- Single vertical slice demoable end-to-end (Sabir Sr. case, DTI 44.8%)

### 6.2 Out of Scope for MVP

- Real LOS integration (Encompass/ICE/Blend) — deferred to v2 [NOTE FOR PM: this is the #1 production dependency]
- Borrower-facing portal — frozen per ADR-15
- OCR / document extraction — deferred to v3
- Vector search / embeddings — deferred to v3
- Production borrower data in AI prompts — requires legal approval
- Multi-org / multi-tenant deployment — deferred to v3
- Agentforce controlled write actions beyond task creation — deferred to v2 (read-only and draft-only first)

## 7. Success Metrics

**Primary**
- **SM-1:** Review time per loan < 10 minutes (from 45 min baseline). Validates FR-1 through FR-14.
- **SM-2:** Evidence linkage rate > 95% of replay checks have evidence linked. Validates FR-5, FR-7, FR-8.
- **SM-3:** Exception documentation rate = 100% of exceptions have documented approval or flagged as unjustified. Validates FR-9, FR-10.

**Secondary**
- **SM-4:** Audit receipt completeness = 100% of closed cases have an immutable receipt. Validates FR-12, FR-13, FR-25.
- **SM-5:** Agentforce draft acceptance rate > 90% of summaries/drafts accepted without major edits. Validates FR-17 through FR-21.
- **SM-6:** False positive rate < 5% of replay violations overturned on human review. Validates FR-27.

**Counter-metrics (do not optimize)**
- **SM-C1:** Review thoroughness — reducing review time must not reduce findings-per-case below the baseline. Counterbalances SM-1.
- **SM-C2:** AI over-reliance — auditors must edit or override > 10% of AI drafts to demonstrate active judgment. Counterbalances SM-5.

## 8. Cross-Cutting NFRs

### Performance
- Queue loads within 2 seconds for up to 500 cases
- Replay execution completes within 5 seconds for a single case
- Bulk replay: 3 SOQL + 1 DML for N cases (per ADR-5)

### Security
- All Apex classes declare `with sharing`
- SOQL uses `WITH USER_MODE` for user-context queries
- No user input concatenated into SOQL strings
- CRUD/FLS enforced on all data access
- Agentforce actions use the same sharing model as the invoking user

### Accessibility
- WCAG 2.1 AA compliance on all screens
- Keyboard navigable queue and review screens
- Color is never the sole indicator of status (paired with text labels)
- SLDS 2 design tokens for theming support

### Auditability
- Every material action creates an Audit_Event__c
- Audit_Event__c and Audit_Receipt__c are immutable (code-enforced)
- Agent_Action_Log__c records every Agentforce action
- All audit events include actor, timestamp, and payload

## 9. Constraints and Guardrails

### AI Safety
- Agentforce may: summarize, draft, recommend, create controlled tasks
- Agentforce must NOT: approve audits, close cases, override policy, delete findings, modify signed receipts
- Every Agentforce action logs to Agent_Action_Log__c + Audit_Event__c
- Human auditor is the final authority on every judgment call

### Compliance
- No real customer data in demos — all demo data is fictional
- Policy rules are data, not code — analysts version rules without deployment (ADR-4)
- Append-only audit trail enforced by code (ADR-1)
- ECOA/Reg B adverse action notices cite specific rule explanations, not generic language (ADR-10)

### Data
- Demo data sourced from Kaggle `Loan_approval_data_2025.csv`, transformed via `transform_kaggle_to_seed.py`
- 5 demo personas (Karim, Maria, James, Sabir Sr., Test Borrower)
- 200 bulk records for governor limit testing
- [ASSUMPTION: production data integration deferred to v2 with LOS integration]

## 10. Integration and Dependencies

| System | Integration | Status |
|--------|-------------|--------|
| Salesforce (mortagate-de) | Primary record layer, org authenticated | Partial — 7 of 11 objects deployed |
| Agentforce | Subagents + actions via Agent Builder | Confirmed available, not yet built |
| Allura Brain | Governed memory via MCP (`allura-mortgage`) | Active — 24 memories stored |
| React (Next.js) | Auditor cockpit at `apps/veridact-frontend` | Shipped — Iteration 10 + ruleId hardening |
| Figma | Design source of truth | Locked — 5 screens, brand kit v1.0.1 |
| GitHub | `Allura-Ecosystem/mortagate` monorepo | Active — PRs #1-4, 3 branches |

## 11. ROI / Business Case

| Metric | Current | With Veridact | Impact |
|--------|---------|---------------|--------|
| Review time per loan | 45 minutes | 8 minutes | 82% reduction |
| Reviews per auditor per day | 10 | 45+ | 4.5x throughput |
| At 10,000 audits/year | 7,500 hours | 1,333 hours | 6,167 hours saved |
| Exception miss rate | Unknown (no systematic detection) | < 5% false positive | Measurable compliance coverage |
| Audit trail completeness | Spreadsheet-based, inconsistent | 100% append-only receipts | Regulator-ready |

## 12. Open Questions

1. **Schema reconciliation** — Should existing codebase names (`Rule_Check__c`, `Policy_Rule_Version__c`) be renamed to match Notion canonical names (`Replay_Check__c`, `Policy_Version__c` + `Policy_Rule__c`), or should Notion be updated to match code?
2. **Policy lifecycle ownership** — Who creates, approves, publishes, and retires policy versions? Candidate: Compliance manager owns approval, admin manages upload.
3. **Production LOS decision** — Which LOS will be the v2 integration target? (Encompass, ICE, Blend, or hybrid import)
4. **Agentforce controlled writes** — When does Agentforce move from draft-only to controlled write actions? What approval gate is needed?
5. **Real data approval** — What legal/compliance approval is needed before production borrower data enters AI prompts?

## 13. Assumptions Index

- **[ASSUMPTION: FR-6]** — Replay is triggered manually by the auditor, not automatically on case open.
- **[ASSUMPTION: FR-12]** — Self-audit prevention: an auditor cannot sign off on a case they reviewed. Manager role required.
- **[ASSUMPTION: FR-14]** — Receipt PDF uses Veridact brand styling (Cream/Charcoal/Orange/Outfit).
- **[ASSUMPTION: FR-15]** — Analytics in v1 are read from Salesforce aggregate SOQL queries, not a separate analytics engine.
- **[ASSUMPTION: D-3]** — Schema names from Notion are canonical; code will be reconciled to match. User has not explicitly confirmed.
- **[ASSUMPTION: FR-22]** — Violation notification channels are in-app + email; Slack/Teams integration deferred.
- **[ASSUMPTION: §9 Data]** — Production data integration is deferred to v2 alongside LOS integration.

---

## Phased Roadmap (from Notion)

| Phase | Focus | Deliverable |
|-------|-------|-------------|
| 1 | Frontend verification | React routes, mock data, unit tests, Figma visual QA |
| 2 | Local backend | Postgres, API routes, audit_events, receipt snapshots |
| 3 | Replay foundation | Policy versions, rules, replay checks, finding contract, evidence mapping |
| 4 | Salesforce sync | SF objects, audit case sync, finding sync, receipt sync, workflow status |
| 5 | Allura reasoning | Policy replay assistance, evidence mapping, governed memory, receipt intelligence |
| 6 | Agentforce | Read-only Auditor Assistant first, draft-only second, controlled writes third |
| 7 | Analytics & Data 360 | Audit metrics, event sync, approver drift, branch risk, policy failure rates |

**Execution methodology:** Vertical slice, demo-first. Each phase delivers a demoable increment using one audit case (Sabir Sr., DTI 44.8%) end-to-end across all active layers. Stories executed via BMad Ralph Loop (dev → code review → test → ship).
