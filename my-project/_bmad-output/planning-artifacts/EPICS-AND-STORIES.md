# Epics and Stories -- Veridact v1 Demo

> **Methodology:** Vertical slice, demo-first. Each epic delivers a demoable increment.
> **PRD reference:** `prds/prd-Mortagate-2026-06-14/prd.md` (28 FRs)
> **Schema:** 11 SObjects per `planning docs/DATA-DICTIONARY.md`
> **Architecture:** 4 layers per `planning docs/SOLUTION-ARCHITECTURE.md`
> **Created:** 2026-06-14 by Woz (builder)

---

## Epic Overview

| Epic | Name | Phase | FRs Covered | Dependencies |
|------|------|-------|-------------|--------------|
| EP-0 | Schema Foundation | 0 | FR-24, FR-25, FR-26, FR-28 | None |
| EP-1 | Vertical Slice -- Sabir Sr. End-to-End | 1 | FR-5, FR-6, FR-7, FR-8, FR-9, FR-10, FR-12, FR-13, FR-17, FR-27 | EP-0 |
| EP-2 | Audit Queue | 2 | FR-1, FR-2, FR-3, FR-4 | EP-0 |
| EP-3 | Agentforce Actions | 3 | FR-11, FR-17, FR-18, FR-19, FR-20, FR-21, FR-22, FR-23 | EP-1 |
| EP-4 | Analytics and Polish | 4 | FR-14, FR-15, FR-16 | EP-2, EP-3 |
| EP-5 | Integration and Hardening | 5 | Cross-cutting NFRs | EP-1, EP-2, EP-3 |

**Total stories:** 32
**FRs covered:** All 28 (FR-1 through FR-28)

---

## EP-0: Schema Foundation

### Deploy the 11 canonical SObjects, seed data for Sabir Sr., and enforce immutability on append-only objects. When this epic is done, you can open the org, query the seed data, and prove that audit events and receipts cannot be edited or deleted.

### Stories

#### US-0.1: Deploy core audit objects (Audit_Case, Loan, Borrower_Snapshot)
- **As a** developer
- **I can** deploy Audit_Case__c, Loan__c, and Borrower_Snapshot__c to the org
- **So that** the central audit entities exist and accept records
- **FRs:** FR-24 (Audit_Case is referenced by events)
- **Acceptance Criteria:**
  - [ ] Audit_Case__c deployed with all fields from DATA-DICTIONARY section 2.1
  - [ ] Loan__c deployed with all fields from DATA-DICTIONARY section 2.2
  - [ ] Borrower_Snapshot__c deployed with all fields from DATA-DICTIONARY section 2.3
  - [ ] Validation rule `Prevent_Self_Audit` active on Audit_Case__c
  - [ ] Validation rule `Snapshot_Write_Once` active on Audit_Case__c
  - [ ] All lookups resolve correctly (Audit_Case -> Loan, Borrower_Snapshot -> Audit_Case)
- **Layer:** Salesforce
- **Depends on:** none

#### US-0.2: Deploy policy objects (Policy_Version, Policy_Rule)
- **As a** developer
- **I can** deploy Policy_Version__c and Policy_Rule__c to the org
- **So that** versioned lending rules exist as data records
- **FRs:** FR-26, FR-28
- **Acceptance Criteria:**
  - [ ] Policy_Version__c deployed with all fields from DATA-DICTIONARY section 2.4
  - [ ] Policy_Rule__c deployed as Master-Detail child of Policy_Version__c
  - [ ] All picklist values match DATA-DICTIONARY (Operator, Severity, Rule_Category)
  - [ ] Sort_Order__c field exists on Policy_Rule__c for deterministic ordering
- **Layer:** Salesforce
- **Depends on:** none

#### US-0.3: Deploy evidence and replay objects (Evidence_Item, Replay_Check, Finding)
- **As a** developer
- **I can** deploy Evidence_Item__c, Replay_Check__c, and Finding__c to the org
- **So that** the case review workflow objects are available
- **FRs:** FR-5, FR-6, FR-9
- **Acceptance Criteria:**
  - [ ] Evidence_Item__c deployed with all fields from DATA-DICTIONARY section 2.6
  - [ ] Replay_Check__c deployed with all fields from DATA-DICTIONARY section 2.7
  - [ ] Finding__c deployed with all fields from DATA-DICTIONARY section 2.8
  - [ ] Replay_Check__c lookups resolve to Audit_Case, Policy_Rule, Evidence_Item, Borrower_Snapshot
  - [ ] Finding__c lookups resolve to Audit_Case and Replay_Check
- **Layer:** Salesforce
- **Depends on:** US-0.1, US-0.2

#### US-0.4: Deploy append-only objects (Audit_Event, Audit_Receipt, Agent_Action_Log)
- **As a** developer
- **I can** deploy Audit_Event__c, Audit_Receipt__c, and Agent_Action_Log__c with immutability enforcement
- **So that** the append-only audit trail is enforced by code
- **FRs:** FR-24, FR-25
- **Acceptance Criteria:**
  - [ ] Audit_Event__c deployed with validation rule `Prevent_Edit_After_Creation` blocking UPDATE
  - [ ] Audit_Event__c has before-delete trigger `AuditEventPreventDelete` blocking DELETE
  - [ ] Audit_Receipt__c deployed with validation rule blocking UPDATE after insert
  - [ ] Audit_Receipt__c has before-delete trigger `AuditReceiptPreventDelete` blocking DELETE
  - [ ] Agent_Action_Log__c deployed with validation rule blocking UPDATE after insert
  - [ ] Agent_Action_Log__c has before-delete trigger `AgentActionLogPreventDelete` blocking DELETE
  - [ ] All picklist values for Event_Type__c match DATA-DICTIONARY (12 values)
  - [ ] All picklist values for Action_Name__c match DATA-DICTIONARY (8 values)
- **Layer:** Salesforce
- **Depends on:** US-0.1

#### US-0.5: Immutability bulk test
- **As a** developer
- **I can** run an Apex test that attempts 200 updates and 200 deletes on Audit_Event__c and Audit_Receipt__c
- **So that** immutability is proven at scale
- **FRs:** FR-25
- **Acceptance Criteria:**
  - [ ] Test class `ImmutabilityEnforcementTest` inserts 200 Audit_Event__c records
  - [ ] Bulk update of 200 records is blocked -- all records unchanged
  - [ ] Bulk delete of 200 records is blocked -- all records still exist
  - [ ] Same tests pass for Audit_Receipt__c (200 insert, 200 update blocked, 200 delete blocked)
  - [ ] Same tests pass for Agent_Action_Log__c
  - [ ] Tests use `System.runAs` with a standard user
- **Layer:** Salesforce
- **Depends on:** US-0.4

#### US-0.6: Seed data -- Sabir Sr. case and policy rules
- **As a** developer
- **I can** import the Sabir Sr. demo case with loan data, borrower snapshot, evidence items, and governing policy version
- **So that** the vertical slice has data to operate on
- **FRs:** FR-26 (policy version resolution depends on seed data)
- **Acceptance Criteria:**
  - [ ] 1 Loan__c record: Sabir Sr., $380K conventional, DTI 44.8%, FICO 710, LTV 80%, Approval_Date 2025-03-15
  - [ ] 1 Audit_Case__c record linked to the loan, Status = In_Review, Risk_Tier = High
  - [ ] 1 Borrower_Snapshot__c with DTI_Ratio = 44.8%, FICO_Score = 710, Annual_Income, Monthly_Debt
  - [ ] 5 Evidence_Item__c records (Pay_Stub=Linked, W2=Linked, Credit_Report=Linked, Appraisal=Missing, Bank_Statement=Linked)
  - [ ] 1 Policy_Version__c (Q1 2025 Conventional, Effective_Date = 2025-01-01)
  - [ ] 10 Policy_Rule__c records including DTI_MAX (43%, LTE), FICO_MIN (620, GTE), LTV_MAX (80%, LTE)
  - [ ] Data importable via `sf data import tree` or Apex script
- **Layer:** Salesforce
- **Depends on:** US-0.3

---

## EP-1: Vertical Slice -- Sabir Sr. End-to-End

### One audit case flows through all 4 layers: the Apex replay kernel evaluates Sabir Sr. against historical policy rules, the Case Review LWC shows the two-pane view, a finding is created from the DTI violation, the case is signed off with an immutable receipt, and Agentforce returns a case summary. When this epic is done, you can demo the complete auditor journey for one case.

### Stories

#### US-1.1: FactAssemblerService -- query evidence and resolve governing policy
- **As a** developer
- **I can** call FactAssemblerService.assemble(caseId) and get back a ReplayContext with evidence, borrower snapshot, and governing policy rules
- **So that** the replay engine has all data it needs in a single bulk-safe load
- **FRs:** FR-6, FR-26
- **Acceptance Criteria:**
  - [ ] Service queries Evidence_Item__c, Borrower_Snapshot__c for the case (1 SOQL)
  - [ ] Service resolves Policy_Version__c by loan Approval_Date (latest effective version <= approval date) (1 SOQL)
  - [ ] Service loads child Policy_Rule__c records for the resolved version (1 SOQL)
  - [ ] Total: exactly 3 SOQL, 0 DML
  - [ ] Returns immutable ReplayContext wrapper
  - [ ] Bulk-safe: works for List<Id> caseIds (no SOQL in loops)
  - [ ] Uses `with sharing` and `WITH USER_MODE`
  - [ ] Test: Sabir Sr. case resolves Q1 2025 Conventional policy with 10 rules
- **Layer:** Salesforce
- **Depends on:** US-0.6

#### US-1.2: PolicyRuleEvaluator -- pure rule evaluation
- **As a** developer
- **I can** call PolicyRuleEvaluator.evaluate(context) and get back a list of ReplayCheckResults
- **So that** rules are evaluated without any database access
- **FRs:** FR-27, FR-28
- **Acceptance Criteria:**
  - [ ] Zero SOQL, zero DML in the evaluator class
  - [ ] Supports operators: GTE, LTE, GT, LT, EQ, NEQ, IN, BETWEEN
  - [ ] Missing facts produce INDETERMINATE result (not Pass or Fail)
  - [ ] Results sorted by Rule_Code__c (deterministic ordering)
  - [ ] Sabir Sr. DTI 44.8% vs DTI_MAX 43% LTE produces Fail
  - [ ] Sabir Sr. FICO 710 vs FICO_MIN 620 GTE produces Pass
  - [ ] Test with 200+ synthetic rules to prove bulk safety
- **Layer:** Salesforce
- **Depends on:** none (pure logic, no schema dependency)

#### US-1.3: ReplayCommitService -- write replay results
- **As a** developer
- **I can** call ReplayCommitService.commit(caseId, results) and have Replay_Check__c records and an Audit_Event__c created
- **So that** replay results are persisted and audited
- **FRs:** FR-6, FR-24
- **Acceptance Criteria:**
  - [ ] Inserts all Replay_Check__c records in a single DML (1 DML total)
  - [ ] Creates 1 Audit_Event__c with Event_Type = Replay_Executed
  - [ ] Replay_Check__c records have Expected_Value, Actual_Value, Result, linked Policy_Rule
  - [ ] Uses `with sharing`
  - [ ] Bulk test: commit results for 200 cases in one transaction
- **Layer:** Salesforce
- **Depends on:** US-0.3, US-0.4

#### US-1.4: ReplayService orchestrator -- end-to-end replay
- **As a** developer
- **I can** call ReplayService.replay(caseId) and have the full pipeline execute (assemble -> evaluate -> commit)
- **So that** the replay is triggered by a single method call
- **FRs:** FR-6, FR-26, FR-27, FR-28
- **Acceptance Criteria:**
  - [ ] Orchestrates FactAssemblerService -> PolicyRuleEvaluator -> ReplayCommitService
  - [ ] Total budget: 3 SOQL + 1 DML for N cases
  - [ ] Sabir Sr. case produces 10 Replay_Check__c records (1 Fail on DTI_MAX, 9 Pass)
  - [ ] Audit_Event__c created with Event_Type = Replay_Executed
  - [ ] Replay completes in < 5 seconds for a single case
- **Layer:** Salesforce
- **Depends on:** US-1.1, US-1.2, US-1.3

#### US-1.5: AuditEventService -- centralized event logging
- **As a** developer
- **I can** call AuditEventService.log(caseId, eventType, actor, payload) to create an append-only event
- **So that** all features use a single service for audit trail entries
- **FRs:** FR-24
- **Acceptance Criteria:**
  - [ ] Service inserts Audit_Event__c with all required fields
  - [ ] Supports all 12 Event_Type values from DATA-DICTIONARY
  - [ ] Payload accepts a Map<String, Object> and serializes to JSON
  - [ ] Bulk-safe: accepts List of events
  - [ ] Uses `with sharing`
- **Layer:** Salesforce
- **Depends on:** US-0.4

#### US-1.6: Case Review LWC -- two-pane view
- **As a** developer
- **I can** open a Case Review screen that shows the evidence panel (left) and replay checklist (right)
- **So that** the auditor can see evidence and replay results side by side
- **FRs:** FR-5, FR-7
- **Acceptance Criteria:**
  - [ ] Left pane: lists all Evidence_Item__c records for the case with Document_Type, Status, badge colors
  - [ ] Missing evidence items show amber badge
  - [ ] Right pane: lists all Replay_Check__c records ordered by Sort_Order
  - [ ] Each replay check shows: Rule_Name, Result (Pass/Fail/Unverifiable), Expected_Value, Actual_Value
  - [ ] Expanding a replay check shows Policy_Rule fields: Rule_Code, Threshold, Operator, Severity, Fact_Field, Rule_Explanation
  - [ ] Evidence linkage shows which Evidence_Item supports each check, or "No evidence linked"
  - [ ] "Run Replay" button triggers ReplayService and refreshes the checklist
  - [ ] SLDS 2 design tokens, keyboard navigable
- **Layer:** Salesforce (LWC)
- **Depends on:** US-1.4

#### US-1.7: Evidence status update
- **As a** developer
- **I can** change an evidence item's status from the evidence panel and have an audit event logged
- **So that** evidence status changes are tracked in the audit trail
- **FRs:** FR-8
- **Acceptance Criteria:**
  - [ ] Auditor can change status to Linked, Missing, or Unverifiable via inline picklist
  - [ ] Status change creates Audit_Event__c with Event_Type = Evidence_Status_Changed
  - [ ] Audit_Case__c status recalculates (if any required evidence is Missing, case shows Evidence_Needed)
- **Layer:** Salesforce (LWC + Apex)
- **Depends on:** US-1.5, US-1.6

#### US-1.8: Create finding from replay check
- **As a** developer
- **I can** click "Create Finding" on a replay check and fill in a finding form
- **So that** the auditor can document their judgment on a replay result
- **FRs:** FR-9, FR-10
- **Acceptance Criteria:**
  - [ ] Finding form pre-populates: Rule_Name from replay check
  - [ ] Severity is required (Pass / Exception / Violation)
  - [ ] Description accepts free text up to 32,000 characters
  - [ ] At least one Evidence_Item must be linked, or auditor explicitly marks "No evidence available"
  - [ ] Finding linked to both Audit_Case__c and Replay_Check__c
  - [ ] Creation logs Audit_Event__c with Event_Type = Finding_Created
  - [ ] Sabir Sr. demo: DTI violation finding with Severity = Violation
- **Layer:** Salesforce (LWC + Apex)
- **Depends on:** US-1.6

#### US-1.9: Sign-off workflow and receipt creation
- **As a** developer
- **I can** submit a case for sign-off and have a manager approve it, creating an immutable receipt
- **So that** the audit case has a permanent, tamper-proof sign-off record
- **FRs:** FR-12, FR-13
- **Acceptance Criteria:**
  - [ ] "Submit for Sign-off" button validates: all replay checks have findings, all required evidence addressed
  - [ ] Submit creates Audit_Event__c with Event_Type = Submitted_For_Signoff
  - [ ] Case status changes to Ready_for_Signoff
  - [ ] Manager can approve or return the case
  - [ ] Approval creates Audit_Receipt__c with: Reviewer, Signed_Off_At, Findings_Snapshot (JSON), Evidence_Snapshot (JSON), Replay_Snapshot (JSON)
  - [ ] Receipt counts: Total_Findings, Violation_Count, Exception_Count, Pass_Count
  - [ ] Self-audit prevention: auditor cannot sign off on their own case
  - [ ] Case status changes to Closed after sign-off
  - [ ] Audit_Event__c created with Event_Type = Case_Signed_Off
- **Layer:** Salesforce (LWC + Apex)
- **Depends on:** US-1.8

#### US-1.10: React cockpit -- Case Review screen
- **As a** developer
- **I can** open the Sabir Sr. case in the React cockpit and see the two-pane Case Review
- **So that** the auditor works in the branded Veridact interface, not Salesforce chrome
- **FRs:** FR-5, FR-7
- **Acceptance Criteria:**
  - [ ] React route `/cases/:caseId` renders Case Review
  - [ ] Fetches evidence and replay data from Salesforce REST API
  - [ ] Left pane: evidence panel with status badges
  - [ ] Right pane: replay checklist with expandable rule details
  - [ ] "Run Replay" button calls Salesforce API and refreshes
  - [ ] Veridact brand: Canvas/Ink/Orange, Outfit font
  - [ ] Responsive for 1280px+ desktop
- **Layer:** React
- **Depends on:** US-1.4, US-1.6

#### US-1.11: Agentforce -- getAuditCaseSummary action
- **As a** developer
- **I can** ask Agentforce "summarize this case" and get a natural-language summary
- **So that** the first Agentforce action works end-to-end
- **FRs:** FR-17
- **Acceptance Criteria:**
  - [ ] `AuditCaseSummaryAction` class with `@InvocableMethod`
  - [ ] Summary includes: loan amount, DTI, FICO, evidence status (X of Y linked), findings count, risk tier
  - [ ] Action logs to Agent_Action_Log__c (Action_Name = Summarize_Case)
  - [ ] Corresponding Audit_Event__c created with Event_Type = Agent_Action
  - [ ] Uses `with sharing`
  - [ ] Sabir Sr. demo: returns summary with DTI 44.8%, 4 of 5 evidence linked
- **Layer:** Salesforce (Agentforce)
- **Depends on:** US-1.5, US-0.6

---

## EP-2: Audit Queue

### The auditor's landing screen with filterable, sortable queue, risk badges, and summary metrics. When this epic is done, you can demo Fatima triaging her morning queue (UJ-1), filtering by status and risk tier, seeing SLA-at-risk cases, and clicking through to Case Review.

### Stories

#### US-2.1: Queue data service
- **As a** developer
- **I can** call AuditQueueService.getQueue(filters) and get back a paginated list of audit cases
- **So that** the queue has a bulk-safe Apex backend
- **FRs:** FR-1, FR-2
- **Acceptance Criteria:**
  - [ ] Service returns Audit_Case__c records with: Name, Loan_Amount, Risk_Tier, Status, Due_At, Auditor, Branch, Product_Type
  - [ ] Supports filters: Status, Risk_Tier, Branch, Product_Type, Assigned Approver
  - [ ] Filters combine with AND logic
  - [ ] Default sort: Due_At ascending (SLA urgency)
  - [ ] Uses `with sharing` and `WITH USER_MODE`
  - [ ] Loads within governor limits for 500 cases
- **Layer:** Salesforce
- **Depends on:** US-0.1

#### US-2.2: Queue metrics service
- **As a** developer
- **I can** call AuditQueueService.getMetrics(filters) and get back aggregate counts
- **So that** the queue summary bar has real data
- **FRs:** FR-3
- **Acceptance Criteria:**
  - [ ] Returns: total cases, In_Review count, Evidence_Needed count, Ready_for_Signoff count, Closed count
  - [ ] Returns SLA-at-risk count (Due_At <= today + 2 days)
  - [ ] Metrics respect the same filters as the queue
  - [ ] Single aggregate SOQL query (no loop counting)
- **Layer:** Salesforce
- **Depends on:** US-2.1

#### US-2.3: Queue LWC component
- **As a** developer
- **I can** view the Audit Queue in a Salesforce LWC with risk-tier badges, filters, and metrics
- **So that** the queue works inside Salesforce before the React cockpit connects
- **FRs:** FR-1, FR-2, FR-3, FR-4
- **Acceptance Criteria:**
  - [ ] Tabular queue with columns: Case Name, Loan Amount, Risk Tier, Status, SLA Due Date, Auditor, Branch, Product Type
  - [ ] Risk-tier badges: High=Red, Medium=Amber, Low=Green (color + text label, never color alone)
  - [ ] Filter bar: Status, Risk_Tier, Branch, Product_Type, Approver
  - [ ] Filters are reactive (no page reload)
  - [ ] Summary metrics bar above the queue
  - [ ] SLA-at-risk count highlighted
  - [ ] Click row navigates to Case Review (preserves filter state)
  - [ ] SLDS 2 tokens, keyboard navigable
- **Layer:** Salesforce (LWC)
- **Depends on:** US-2.1, US-2.2

#### US-2.4: React cockpit -- Audit Queue screen
- **As a** developer
- **I can** view the Audit Queue in the React cockpit with the same filters, badges, and metrics
- **So that** the auditor works in the branded Veridact interface
- **FRs:** FR-1, FR-2, FR-3, FR-4
- **Acceptance Criteria:**
  - [ ] React route `/queue` renders the Audit Queue
  - [ ] Fetches data from Salesforce REST API (AuditQueueService)
  - [ ] Queue loads within 2 seconds for 500 cases
  - [ ] Filter state persists within session (React state or URL params)
  - [ ] Click row navigates to `/cases/:caseId` (Case Review)
  - [ ] Back-navigation restores filter state
  - [ ] Veridact brand: Canvas/Ink/Orange, Outfit font
- **Layer:** React
- **Depends on:** US-2.1, US-2.2

#### US-2.5: Seed data -- 200 bulk cases for queue testing
- **As a** developer
- **I can** import 200 bulk audit cases with varied statuses, risk tiers, and SLA dates
- **So that** the queue can be tested at scale
- **FRs:** FR-1 (queue loads within 2 seconds for 500 cases)
- **Acceptance Criteria:**
  - [ ] 200 Loan__c + 200 Audit_Case__c records with randomized: Status, Risk_Tier, Branch, Product_Type, Due_At
  - [ ] Mix of statuses: ~50 In_Review, ~40 Evidence_Needed, ~30 Ready_for_Signoff, ~80 Closed
  - [ ] ~20 cases with Due_At within 2 days (SLA at risk)
  - [ ] 4 additional demo persona cases (Karim, Maria, James, Test Borrower) beyond Sabir Sr.
  - [ ] Data importable via `sf data import tree` or Apex script
  - [ ] Total pre-seeded records stay under 4.1 MB (DE org limit 5 MB)
- **Layer:** Salesforce
- **Depends on:** US-0.6

---

## EP-3: Agentforce Actions

### All 8 Agentforce actions, 4 subagents, and 3 prompt templates are operational. When this epic is done, you can demo the auditor asking for case summaries, missing evidence lists, finding drafts, evidence request drafts, and manager sign-off summaries. Violation notifications fire automatically. Every action is logged.

### Stories

#### US-3.1: AgentActionLogger -- centralized action logging
- **As a** developer
- **I can** call AgentActionLogger.log(actionName, subagent, actor, caseId, input, output) to create an append-only Agent_Action_Log__c record
- **So that** every Agentforce action is traced
- **FRs:** FR-23
- **Acceptance Criteria:**
  - [ ] Creates Agent_Action_Log__c with all required fields
  - [ ] Also creates Audit_Event__c with Event_Type = Agent_Action
  - [ ] Dual-write: both records created in same transaction
  - [ ] Bulk-safe: accepts List of log entries
  - [ ] No Agentforce action can execute without calling this method first
- **Layer:** Salesforce
- **Depends on:** US-0.4, US-1.5

#### US-3.2: getMissingEvidence action
- **As a** developer
- **I can** ask Agentforce "what evidence is missing?" and get a list of missing/unverifiable items
- **So that** the auditor can quickly identify evidence gaps
- **FRs:** FR-18
- **Acceptance Criteria:**
  - [ ] `MissingEvidenceAction` class with `@InvocableMethod`
  - [ ] Returns each missing item with Document_Type and status (Missing vs Unverifiable)
  - [ ] Action logged to Agent_Action_Log__c + Audit_Event__c
  - [ ] Sabir Sr. demo: returns Appraisal as Missing
- **Layer:** Salesforce (Agentforce)
- **Depends on:** US-3.1

#### US-3.3: draftFindingText action and prompt template
- **As a** developer
- **I can** ask Agentforce "draft a finding for the DTI violation" and get a pre-filled finding description
- **So that** the auditor saves time writing finding text
- **FRs:** FR-11, FR-19
- **Acceptance Criteria:**
  - [ ] `DraftFindingAction` class with `@InvocableMethod`
  - [ ] Prompt Template `Draft_Finding_Text` created
  - [ ] Draft cites: rule name, threshold, actual value, policy version, evidence status
  - [ ] Draft presented for auditor review -- auditor must accept, edit, or override
  - [ ] Agentforce cannot create findings directly
  - [ ] AI_Drafted__c set to true on accepted findings
  - [ ] Action logged to Agent_Action_Log__c + Audit_Event__c
- **Layer:** Salesforce (Agentforce)
- **Depends on:** US-3.1

#### US-3.4: draftEvidenceRequest action and prompt template
- **As a** developer
- **I can** ask Agentforce "draft an evidence request" and get a professional internal email
- **So that** the auditor can request missing evidence from a loan officer
- **FRs:** FR-20
- **Acceptance Criteria:**
  - [ ] `EvidenceRequestAction` class with `@InvocableMethod`
  - [ ] Prompt Template `Draft_Evidence_Request` created
  - [ ] Draft lists missing items and SLA deadline
  - [ ] Auditor must review and approve before sending
  - [ ] Action logged to Agent_Action_Log__c + Audit_Event__c
- **Layer:** Salesforce (Agentforce)
- **Depends on:** US-3.1, US-3.2

#### US-3.5: prepareManagerSummary action and prompt template
- **As a** developer
- **I can** ask Agentforce "prepare the sign-off summary" and get a structured summary of all findings and evidence
- **So that** the manager can review a case efficiently before sign-off
- **FRs:** FR-21
- **Acceptance Criteria:**
  - [ ] `ManagerSummaryAction` class with `@InvocableMethod`
  - [ ] Prompt Template `Prepare_Manager_Summary` created
  - [ ] Summary includes: all findings, evidence status, replay results, recommendation (Ready / Needs review)
  - [ ] Action logged to Agent_Action_Log__c + Audit_Event__c
- **Layer:** Salesforce (Agentforce)
- **Depends on:** US-3.1

#### US-3.6: Violation notification (automatic)
- **As a** developer
- **I can** have the system automatically send a notification when a replay detects a HARD_DECLINE or SOFT_DECLINE violation
- **So that** the auditor and manager are alerted to high-severity findings
- **FRs:** FR-22
- **Acceptance Criteria:**
  - [ ] Notification fires automatically after replay execution completes
  - [ ] Notification includes: case name, rule name, expected vs actual value, severity, link to case
  - [ ] Delivered via Salesforce in-app notification and email
  - [ ] If no auditor assigned, notification goes to queue manager
  - [ ] Notification logged as Audit_Event__c with Event_Type = Violation_Alert_Sent
  - [ ] Notification does NOT approve, close, or act on the case
  - [ ] Action logged to Agent_Action_Log__c
- **Layer:** Salesforce (Agentforce + Flow)
- **Depends on:** US-1.4, US-3.1

#### US-3.7: Subagent configuration in Agent Builder
- **As a** developer
- **I can** configure 4 subagents in Agentforce Agent Builder with their assigned actions
- **So that** the Agentforce sidebar is functional for auditors and managers
- **FRs:** FR-17, FR-18, FR-19, FR-20, FR-21
- **Acceptance Criteria:**
  - [ ] Subagent `Auditor_Assistant`: getAuditCaseSummary, getMissingEvidence, draftFindingText
  - [ ] Subagent `Evidence_Request`: draftEvidenceRequest
  - [ ] Subagent `Manager_Review`: prepareManagerSummary
  - [ ] Subagent `Compliance_Analytics`: getComplianceMetrics, getApproverDriftReport (stubs for EP-4)
  - [ ] Each subagent has description and instructions
  - [ ] Sidebar embeddable in React cockpit
- **Layer:** Salesforce (Agentforce)
- **Depends on:** US-3.2, US-3.3, US-3.4, US-3.5

---

## EP-4: Analytics and Polish

### Analytics dashboard, approver drift detection, and PDF export. When this epic is done, you can demo a manager viewing exception rates, spotting an outlier approver, drilling into their cases, and exporting a receipt as PDF.

### Stories

#### US-4.1: Analytics data service
- **As a** developer
- **I can** call ComplianceMetricsAction.getMetrics(filters) and get aggregate audit metrics
- **So that** the analytics dashboard has real data
- **FRs:** FR-15
- **Acceptance Criteria:**
  - [ ] Returns: total cases reviewed, exception rate, violation rate, missing evidence rate, average review time
  - [ ] Filterable by date range, branch, product type, approver
  - [ ] Uses aggregate SOQL queries (no separate analytics engine)
  - [ ] `@InvocableMethod` for Agentforce access
  - [ ] Action logged to Agent_Action_Log__c
- **Layer:** Salesforce
- **Depends on:** US-3.1

#### US-4.2: Approver drift detection
- **As a** developer
- **I can** call ApproverDriftAction.getReport(filters) and see per-approver exception/violation rates
- **So that** managers can identify approvers who may be bending rules
- **FRs:** FR-16
- **Acceptance Criteria:**
  - [ ] Returns per-approver: exception rate, violation rate, total cases
  - [ ] Flags approvers with exception rate > 2x branch average
  - [ ] Drill-down: returns specific case IDs and findings for any flagged approver
  - [ ] `@InvocableMethod` for Agentforce access
  - [ ] Action logged to Agent_Action_Log__c
- **Layer:** Salesforce
- **Depends on:** US-3.1

#### US-4.3: Analytics dashboard (React)
- **As a** developer
- **I can** view the Analytics screen in the React cockpit with aggregate metrics and approver drift
- **So that** managers get operational visibility
- **FRs:** FR-15, FR-16
- **Acceptance Criteria:**
  - [ ] React route `/analytics` renders the Analytics dashboard
  - [ ] Summary metrics: total cases, exception rate, violation rate, missing evidence rate
  - [ ] Approver drift table with flagged outliers
  - [ ] Filters: date range, branch, product type, approver
  - [ ] Click flagged approver drills into their cases
  - [ ] Veridact brand
- **Layer:** React
- **Depends on:** US-4.1, US-4.2

#### US-4.4: Receipt PDF export
- **As a** developer
- **I can** export an audit receipt as a branded PDF document
- **So that** receipts can be shared with regulators
- **FRs:** FR-14
- **Acceptance Criteria:**
  - [ ] Visualforce page with `renderAs="pdf"`
  - [ ] PDF includes: case name, loan details, all findings with severity and evidence, replay results, reviewer name and timestamp
  - [ ] Immutability disclosure statement included
  - [ ] Veridact brand styling (Canvas/Charcoal/Orange, Outfit font)
  - [ ] PDF renders in < 10 seconds
  - [ ] Accessible from Case Review and Sign-off Receipt screens
- **Layer:** Salesforce (Visualforce)
- **Depends on:** US-1.9

---

## EP-5: Integration and Hardening

### React-Salesforce API connectivity, Allura Brain connection, bulk testing across all layers, and performance validation. When this epic is done, the system is demo-ready across all 4 layers with proven governor limit compliance.

### Stories

#### US-5.1: Salesforce Connected App and OAuth
- **As a** developer
- **I can** authenticate the React cockpit to Salesforce via OAuth
- **So that** the cockpit has secure API access to audit data
- **FRs:** Cross-cutting (security)
- **Acceptance Criteria:**
  - [ ] Connected App configured in mortagate-de org
  - [ ] OAuth flow: authorization code grant
  - [ ] React stores tokens securely (httpOnly cookies or server-side)
  - [ ] Token refresh handled automatically
  - [ ] All API calls use the authenticated user's sharing model
- **Layer:** Cross-layer (React + Salesforce)
- **Depends on:** none

#### US-5.2: REST API controller for React
- **As a** developer
- **I can** call Salesforce REST endpoints from the React cockpit for queue, case review, replay, findings, and sign-off
- **So that** React has a stable API contract
- **FRs:** Cross-cutting
- **Acceptance Criteria:**
  - [ ] `AuditApiController` Apex class with `@RestResource` or `@AuraEnabled(cacheable=true)` methods
  - [ ] Endpoints: getQueue, getMetrics, getCase, runReplay, createFinding, submitForSignoff, approveSignoff
  - [ ] All endpoints use `with sharing` and `Security.stripInaccessible`
  - [ ] Error responses use consistent JSON format
  - [ ] No SOQL injection (parameterized queries only)
- **Layer:** Salesforce
- **Depends on:** US-2.1, US-1.4, US-1.8, US-1.9

#### US-5.3: Allura Brain connection -- audit memory
- **As a** developer
- **I can** read and write audit context to Allura Brain via MCP (group: allura-mortgage)
- **So that** Agentforce prompt templates have governed memory context
- **FRs:** Cross-cutting (Layer 4)
- **Acceptance Criteria:**
  - [ ] MCP connection to Allura Brain active
  - [ ] Prompt templates can read: ADRs, policy replay patterns, evidence mapping heuristics
  - [ ] Audit decisions written back to Brain after sign-off
  - [ ] group_id = allura-mortgage on all operations
- **Layer:** Allura
- **Depends on:** US-3.7

#### US-5.4: Bulk replay test -- 200 cases
- **As a** developer
- **I can** run ReplayService.replay() on 200 cases in a single transaction without hitting governor limits
- **So that** bulk safety is proven
- **FRs:** FR-27 (3 SOQL + 1 DML for N cases)
- **Acceptance Criteria:**
  - [ ] Apex test inserts 200 Audit_Case__c with Loan, Borrower_Snapshot, Evidence_Item, Policy_Version, Policy_Rules
  - [ ] Calls ReplayService.replay(caseIds) for all 200
  - [ ] Total SOQL <= 3, total DML <= 1 (per the ADR-5 budget)
  - [ ] All 200 cases produce correct Replay_Check__c records
  - [ ] Test completes without LimitException
- **Layer:** Salesforce
- **Depends on:** US-1.4, US-2.5

#### US-5.5: End-to-end demo script
- **As a** developer
- **I can** run a scripted demo that walks through Sabir Sr. from queue to receipt across all 4 layers
- **So that** the demo is repeatable and reliable
- **FRs:** All (validation)
- **Acceptance Criteria:**
  - [ ] Script document with numbered steps
  - [ ] Step 1: Open React cockpit, land on Audit Queue
  - [ ] Step 2: Filter by Risk_Tier = High, find Sabir Sr. case
  - [ ] Step 3: Click to Case Review, see evidence panel and empty replay checklist
  - [ ] Step 4: Ask Agentforce "summarize this case" -- get summary
  - [ ] Step 5: Click "Run Replay" -- see 10 checks, DTI_MAX = Fail
  - [ ] Step 6: Ask Agentforce "draft a finding for DTI violation" -- get draft
  - [ ] Step 7: Create finding (Violation severity), link evidence
  - [ ] Step 8: Submit for sign-off
  - [ ] Step 9: Manager signs off -- immutable receipt created
  - [ ] Step 10: Export receipt as PDF
  - [ ] Step 11: Attempt to edit/delete Audit_Event -- blocked
  - [ ] Each step has expected outcome and screenshot placeholder
- **Layer:** Cross-layer
- **Depends on:** US-4.4

---

## FR Traceability Matrix

| FR | Stories | Epic |
|----|---------|------|
| FR-1 | US-2.1, US-2.3, US-2.4 | EP-2 |
| FR-2 | US-2.1, US-2.3, US-2.4 | EP-2 |
| FR-3 | US-2.2, US-2.3, US-2.4 | EP-2 |
| FR-4 | US-2.3, US-2.4 | EP-2 |
| FR-5 | US-1.6, US-1.10 | EP-1 |
| FR-6 | US-1.1, US-1.3, US-1.4 | EP-1 |
| FR-7 | US-1.6, US-1.10 | EP-1 |
| FR-8 | US-1.7 | EP-1 |
| FR-9 | US-1.8 | EP-1 |
| FR-10 | US-1.8 | EP-1 |
| FR-11 | US-3.3 | EP-3 |
| FR-12 | US-1.9 | EP-1 |
| FR-13 | US-1.9 | EP-1 |
| FR-14 | US-4.4 | EP-4 |
| FR-15 | US-4.1, US-4.3 | EP-4 |
| FR-16 | US-4.2, US-4.3 | EP-4 |
| FR-17 | US-1.11, US-3.7 | EP-1, EP-3 |
| FR-18 | US-3.2 | EP-3 |
| FR-19 | US-3.3 | EP-3 |
| FR-20 | US-3.4 | EP-3 |
| FR-21 | US-3.5 | EP-3 |
| FR-22 | US-3.6 | EP-3 |
| FR-23 | US-3.1 | EP-3 |
| FR-24 | US-0.4, US-1.5 | EP-0, EP-1 |
| FR-25 | US-0.4, US-0.5 | EP-0 |
| FR-26 | US-0.2, US-0.6, US-1.1 | EP-0, EP-1 |
| FR-27 | US-1.2, US-5.4 | EP-1, EP-5 |
| FR-28 | US-0.2, US-1.2 | EP-0, EP-1 |

**Coverage:** All 28 FRs mapped to at least one story. No orphan FRs.
