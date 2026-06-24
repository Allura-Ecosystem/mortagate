# Veridact — Solution Architecture

> [!NOTE]
> **AI-Assisted Documentation**
> Portions of this document were drafted with the assistance of an AI language model.
> Content has been reviewed against the PRD, product brief, and codebase but requires stakeholder sign-off.

---

## 1. System Context

Veridact is an internal mortgage audit replay and QC tool. The auditor takes a closed loan, replays the exact policy rules in force at approval time, maps each rule to its supporting evidence, records findings, and produces an immutable audit receipt. The brand is **Veridact** -- "Every decision has a receipt." That tagline is not marketing; it is the architecture (ADR-1).

The system runs on four layers. Each layer does one job.

```
                     Auditor (desktop-first, 1280px+)
                              |
            ┌─────────────────▼──────────────────────┐
            │   LAYER 1: REACT COCKPIT               │
            │   apps/veridact-frontend (Vercel)       │
            │   5 screens, 7 sidebar nav items        │
            │   Veridact brand, WCAG 2.1 AA           │
            └─────────────────┬──────────────────────┘
                              | REST API / fetch
            ┌─────────────────▼──────────────────────┐
            │   LAYER 2: SALESFORCE                   │
            │   mortagate-de (Developer Edition)       │
            │   18 SObjects (11 new + 7 retained),    │
            │   Apex kernel, LWC, Flows               │
            │   Audit workflow, evidence, findings     │
            └────────┬───────────────┬───────────────┘
                     |               |
         ┌───────────▼───┐   ┌───────▼──────────────┐
         │ LAYER 3:       │   │ LAYER 4:              │
         │ AGENTFORCE     │   │ ALLURA BRAIN          │
         │ 4 subagents    │   │ MCP (allura-mortgage)  │
         │ 8 safe actions │   │ Governed audit memory  │
         │ 3 prompt tmpl  │   │ Policy replay assist   │
         │ Agent sidebar  │   │ Evidence mapping       │
         └────────────────┘   └───────────────────────┘
```

---

## 2. Layer Architecture

### Layer 1: React Cockpit

| Attribute | Value |
|-----------|-------|
| **Stack** | React (Next.js), TypeScript, Tailwind CSS |
| **Hosting** | Vercel free tier |
| **Path** | `apps/veridact-frontend` |
| **Screens** | Audit Queue, Case Review, Finding Detail, Sign-off Receipt, Analytics |
| **Nav** | 7-item sidebar: Audit Queue, Case Review, Findings, Receipts, Analytics, Policy Versions, Admin |
| **Brand** | Veridact tokens (Canvas `#F5F0E8`, Ink `#1F1E1C`, Primary `#E25D22`) |
| **Accessibility** | WCAG 2.1 AA, keyboard navigable, color never sole indicator |
| **Auth** | Salesforce OAuth (connected app) |

**Responsibility:** Render the auditor's daily workflow. No business logic. No direct database access. Talks to Salesforce via REST API. Talks to Agentforce via Salesforce embedded sidebar.

**Key constraints:**
- Desktop-first (auditors use 1280px+ monitors)
- No Salesforce chrome in the cockpit -- fully branded
- Queue loads within 2 seconds for up to 500 cases
- Filter state persists within session

### Layer 2: Salesforce

| Attribute | Value |
|-----------|-------|
| **Org** | mortagate-de (Developer Edition) |
| **Objects** | 18 total: 11 Veridact SObjects + 5 retained origination + 2 custom metadata types (see §2.2) |
| **Apex** | Policy replay kernel, invocable actions, controllers |
| **LWC** | Internal-facing components (admin, policy management) |
| **Flows** | Audit workflow automation, notification triggers |
| **Sharing** | `with sharing` on all service classes, `WITH USER_MODE` for SOQL |

**Responsibility:** Enterprise record layer, workflow automation, audit trail enforcement, Agentforce hosting. The replay engine kernel lives here.

#### Apex Kernel -- Three Layers (ADR-5)

| Layer | Class | Responsibility | DB Access |
|-------|-------|----------------|-----------|
| **Fact Assembly** | `FactAssemblerService` | Query evidence and resolve governing policy rules by loan approval date | Read only (3 SOQL) |
| **Rule Evaluation** | `PolicyRuleEvaluator` | Pure evaluation: facts in, results out | Zero SOQL, zero DML |
| **Decision Commit** | `ReplayCommitService` | Write `Replay_Check__c` records and `Audit_Event__c` | Write only (1 DML) |

#### Object Breakdown (18 total)

**Veridact v1 Objects (11 new)**

| # | Object | Layer Role |
|---|--------|-----------|
| 1 | `Audit_Case__c` | Central entity -- loan under review |
| 2 | `Loan__c` | Audit-side loan snapshot (renamed from origination `Loan_Application__c` concept) |
| 3 | `Borrower_Snapshot__c` | Point-in-time borrower data per fact category |
| 4 | `Evidence_Item__c` | Documents linked to a case |
| 5 | `Policy_Version__c` | Versioned policy container with effective dates |
| 6 | `Policy_Rule__c` | Rule within a policy version (child of `Policy_Version__c`) |
| 7 | `Replay_Check__c` | Result of one rule applied to one case |
| 8 | `Finding__c` | Auditor's documented judgment |
| 9 | `Audit_Receipt__c` | Immutable sign-off record (append-only) |
| 10 | `Audit_Event__c` | Chain of custody log (append-only) |
| 11 | `Agent_Action_Log__c` | Agentforce action audit trail (append-only) |

**Retained Origination Objects (5)**

| # | Object | Layer Role |
|---|--------|-----------|
| 12 | `Loan_Application__c` | Borrower mortgage application (origination-side, read-only in audit) |
| 13 | `Evidence__c` | Origination-side uploaded documents (distinct from `Evidence_Item__c`) |
| 14 | `Extracted_Facts__c` | Origination-side fact extraction output |
| 15 | `Decision_Event__c` | Origination-side decision log (append-only, separate from `Audit_Event__c`) |
| 16 | `Policy_Rule_Version__c` | Retired -- split into `Policy_Version__c` + `Policy_Rule__c`; retained for backward compatibility |

**Custom Metadata Types (2)**

| # | Object | Layer Role |
|---|--------|-----------|
| 17 | `Adverse_Action_Config__mdt` | ECOA/Reg B adverse action notice configuration |
| 18 | `PreFlight_Assumption__mdt` | Pre-flight calculation assumptions |

### Layer 3: Agentforce (ADR-16)

| Attribute | Value |
|-----------|-------|
| **Subagents** | 4 (Auditor Assistant, Evidence Request, Manager Review, Compliance Analytics) |
| **Actions** | 8 safe actions, all Apex `@InvocableMethod` |
| **Prompt Templates** | 3 (Draft Finding, Evidence Request, Manager Summary) |
| **Delivery** | Salesforce sidebar panel embedded in React cockpit |
| **Logging** | Every action writes to `Agent_Action_Log__c` + `Audit_Event__c` |

**Responsibility:** AI-assisted workflow. Summarize cases, draft findings, list missing evidence, prepare sign-off summaries, surface compliance metrics. Read-only and draft-only in v1.

**Hard governance rules:**

| Category | Boundary |
|----------|----------|
| MAY do | Summarize, draft, recommend, create controlled tasks |
| MUST NOT do | Approve audits, close cases, override policy, delete findings, modify signed receipts |
| MUST always | Log to `Agent_Action_Log__c` + `Audit_Event__c` before action execution |
| MUST always | Present drafts for human review -- never auto-commit |

#### Action-to-Apex Mapping

| Action | Apex Method | Subagent | Returns |
|--------|------------|----------|---------|
| `getAuditCaseSummary` | `AuditCaseSummaryAction.getSummary` | Auditor Assistant | Natural-language case summary |
| `getMissingEvidence` | `MissingEvidenceAction.getMissing` | Auditor Assistant | List of missing/unverifiable items |
| `draftFindingText` | `DraftFindingAction.draft` | Auditor Assistant | Draft finding description |
| `draftEvidenceRequest` | `EvidenceRequestAction.draft` | Evidence Request | Draft internal email |
| `prepareManagerSummary` | `ManagerSummaryAction.prepare` | Manager Review | Structured sign-off summary |
| `getComplianceMetrics` | `ComplianceMetricsAction.getMetrics` | Compliance Analytics | Aggregate audit metrics |
| `getApproverDriftReport` | `ApproverDriftAction.getReport` | Compliance Analytics | Per-approver exception rates |
| `logAgentAction` | `AgentActionLogger.log` | All | Confirmation record |

### Layer 4: Allura Brain

| Attribute | Value |
|-----------|-------|
| **Protocol** | MCP (Model Context Protocol) |
| **Group** | `allura-mortgage` |
| **Storage** | Governed memory (Postgres + Neo4j) |
| **Role** | Audit reasoning, historical replay assistance, evidence mapping, exception pattern detection |

**Responsibility:** Long-term governed memory for audit reasoning. Stores ADRs, policy replay patterns, evidence mapping heuristics, and exception detection rules. Accessed by Agentforce prompt templates via MCP bridge.

**v1 scope:** Memory read/write for audit context. Pattern storage for replay assistance. No autonomous actions.

---

## 3. Key Flows

### Flow 1: Queue Triage (FR-1 through FR-4)

```
React Audit Queue
  → REST API: GET /audit-cases (filtered, sorted)
  → Salesforce: SOQL on Audit_Case__c with sharing
  → React: render queue with risk-tier badges, SLA status, metrics
  → Auditor clicks row
  → React: navigate to Case Review (preserve filter state)
```

### Flow 2: Policy Replay (FR-6, FR-26, FR-27, FR-28)

```
Auditor clicks "Run Replay" in Case Review
  → React: POST /replay { caseId }
  → Salesforce Controller: invoke ReplayService.replay(caseId)
  → FactAssemblerService:
      1. Query Evidence_Item__c for case (1 SOQL)
      2. Get loan approval date from Audit_Case__c
      3. Resolve governing Policy_Version__c + Policy_Rule__c by approval date (1 SOQL)
      4. Build immutable ReplayContext
  → PolicyRuleEvaluator:
      1. Walk each rule against evidence facts (pure, 0 SOQL/DML)
      2. Missing facts → INDETERMINATE (ADR-3)
      3. Sort results by Rule_Code__c (ADR-6)
      4. Return List<ReplayCheckResult>
  → ReplayCommitService:
      1. Insert Replay_Check__c records (1 DML)
      2. Insert Audit_Event__c with Event_Type 'Replay_Executed'
  → React: render replay checklist in right pane
```

### Flow 3: Finding Creation with AI Draft (FR-9, FR-10, FR-11)

```
Auditor clicks "Create Finding" on a replay check
  → Finding Detail screen loads (rule pre-populated)
  → Auditor optionally asks Agentforce: "draft a finding"
  → Agentforce:
      1. logAgentAction → Agent_Action_Log__c + Audit_Event__c
      2. draftFindingText → Prompt Template 'Draft_Finding_Text'
      3. Return draft citing rule, threshold, actual value, policy version
  → Auditor reviews, edits, accepts
  → React: POST /findings { finding fields }
  → Salesforce: insert Finding__c + Audit_Event__c ('Finding_Created')
```

### Flow 4: Sign-off and Receipt (FR-12, FR-13, FR-14)

```
Auditor submits case for sign-off
  → Salesforce: validate all replay checks have findings, all evidence addressed
  → Audit_Event__c: 'Submitted_For_Signoff'
  → Case status → 'Ready for Sign-off'

Manager opens Sign-off Receipt screen
  → Optionally asks Agentforce: "prepare sign-off summary"
  → Reviews findings, evidence, replay results
  → Approves
  → Salesforce:
      1. Create Audit_Receipt__c with full snapshot (immutable)
      2. Audit_Event__c: 'Case_Signed_Off'
      3. Case status → 'Closed'
  → PDF export available via Visualforce renderAs="pdf"
```

### Flow 5: Violation Notification (FR-22)

```
After replay execution completes:
  → ReplayCommitService checks for HARD_DECLINE or SOFT_DECLINE results
  → If violations found:
      1. Salesforce notification (in-app + email) to assigned auditor + manager
      2. Audit_Event__c: 'Violation_Alert_Sent'
      3. If no auditor assigned, notification goes to queue manager
  → Notification is informational only -- does NOT approve, close, or act on the case
```

---

## 4. Cross-Cutting Concerns

### 4.1 Bulk Safety

| Metric | Budget | Enforcement |
|--------|--------|-------------|
| SOQL per N cases | 3 | `FactAssemblerService` loads all data in bulk queries |
| DML per N cases | 1 | `ReplayCommitService` bulk-inserts all records |
| In-loop SOQL | 0 | `PolicyRuleEvaluator` is pure -- no DB access |
| In-loop DML | 0 | Enforced by code review gate |
| Bulk test threshold | 200+ records | `ReplayServiceTest` with 200 cases |

### 4.2 Auditability

- Every material action creates an `Audit_Event__c` with: Case ID, Event_Type, Actor, Timestamp, Payload (JSON), Related_Record_Id
- `Audit_Event__c` is immutable (validation rule + before-delete trigger)
- `Audit_Receipt__c` is immutable (same enforcement)
- `Agent_Action_Log__c` is append-only (same enforcement)
- Event types documented in DATA-DICTIONARY.md

**Audit Event Types:**
`Case_Created`, `Evidence_Status_Changed`, `Replay_Executed`, `Finding_Created`, `Submitted_For_Signoff`, `Case_Signed_Off`, `Violation_Alert_Sent`, `Agent_Action_Logged`

### 4.3 Security

| Control | Implementation |
|---------|----------------|
| Sharing model | `with sharing` on all Apex service classes |
| SOQL injection | `WITH USER_MODE` for user-context queries; no string concatenation |
| CRUD/FLS | `Security.stripInaccessible()` on all data access |
| Self-audit prevention | Auditor cannot sign off on their own case (validation rule) |
| Connected app | React cockpit authenticates via Salesforce OAuth |
| Demo data only | No real customer data in v1 -- all fictional (Kaggle-sourced) |
| AI governance | Agentforce actions use invoking user's sharing model |

### 4.4 Accessibility

| Standard | Implementation |
|----------|----------------|
| WCAG 2.1 AA | All 5 screens |
| Keyboard navigation | Queue rows, replay checks, finding form, sign-off actions |
| Color independence | Risk-tier badges use color + text label; never color alone |
| Reduced motion | `prefers-reduced-motion` honored |
| Screen reader | Semantic HTML, ARIA labels on interactive elements |

### 4.5 Performance

| Target | Metric |
|--------|--------|
| Queue load | < 2 seconds for 500 cases |
| Single-case replay | < 5 seconds |
| Bulk replay | 3 SOQL + 1 DML for N cases (linear scaling) |
| PDF export | < 10 seconds |

### 4.6 Data Integrity

| Constraint | Enforcement |
|-----------|-------------|
| Append-only audit trail | Apex trigger + validation rule on `Audit_Event__c` |
| Append-only receipts | Apex trigger + validation rule on `Audit_Receipt__c` |
| Append-only agent logs | Apex trigger + validation rule on `Agent_Action_Log__c` |
| Policy version immutability | Trigger blocks edit after referenced by `Replay_Check__c` |
| Historical fidelity | Replay resolves policy version by loan approval date, not current date |
| Deterministic ordering | `Replay_Check__c` results sorted by `Rule_Code__c` (ADR-6) |
| Worst-wins risk tier | Case risk tier set by most severe replay check result (ADR-2) |
| Missing fact handling | INDETERMINATE result, not PASS or FAIL (ADR-3) |

---

## 5. Integration Map

| System | Protocol | Direction | Status |
|--------|----------|-----------|--------|
| React cockpit | REST API (Salesforce Connected App) | React -> Salesforce | Active (Iteration 10+) |
| Agentforce | Agent Builder + Apex `@InvocableMethod` | Embedded sidebar | Confirmed available (ADR-16), not yet built |
| Allura Brain | MCP (`allura-mortgage` group) | Salesforce <-> Allura | Active (24 memories stored) |
| Figma | Design source of truth | Read-only reference | Locked (5 screens, brand kit v1.0.1) |
| GitHub | `Allura-Ecosystem/mortagate` monorepo | Code + CI | Active |
| Vercel | Hosting (free tier) | React deployment | Active |

### Not Integrated (v1)

- No LOS integration (Encompass, ICE, Blend) -- deferred to v2
- No OCR / document extraction -- deferred to v3
- No vector search / embeddings -- deferred to v3
- No Slack/Teams notifications -- deferred to v2

---

## 6. Environments and Gates

| Gate | Command | Status |
|------|---------|--------|
| Org auth | `sf org login web --alias mortagate-de --set-default` | **Active** |
| Metadata deploy | `sf project deploy start -o mortagate-de` | Pending (7 of 11 objects deployed) |
| Apex tests | `sf apex run test -o mortagate-de -l RunLocalTests` | Pending |
| LWC jest tests | `npm run test:unit` | Pending |
| React tests | `npm test` (apps/veridact-frontend) | Active |
| Gate file | `mortagate.gates.json` | Governs phase-0 through phase-2 |

### Environment Matrix

| Environment | Purpose | Org/Host |
|-------------|---------|----------|
| mortagate-de | Salesforce dev + demo | Developer Edition |
| Vercel preview | React cockpit preview deploys | Vercel free tier |
| Vercel production | React cockpit production | Vercel free tier |
| Local dev | Apex + LWC + React development | sf CLI + npm |
| `demo/` | Standalone Next.js demo app for stakeholder walkthroughs. Contains a self-contained replay engine, scenario personas, and Veridact-branded screens. Not connected to Salesforce -- uses mock data. | Vercel preview or `bun dev` |

---

## 7. ADR Reference

| ADR | Title | Impact |
|-----|-------|--------|
| ADR-1 | Append-only audit trail | `Audit_Event__c` and `Audit_Receipt__c` are immutable |
| ADR-2 | Worst-wins | Most severe replay check governs case risk tier |
| ADR-3 | Missing fact = INDETERMINATE | No false PASS or FAIL on missing evidence |
| ADR-4 | Rules as data | `Policy_Rule__c` records, not hardcoded logic |
| ADR-5 | Three-layer pure kernel | Fact assembly / evaluation / commit separation |
| ADR-6 | Deterministic ordering | Replay checks sorted by `Rule_Code__c` |
| ADR-10 | ECOA/Reg B | Adverse action notices cite specific rule explanations |
| ADR-13 | Veridact brand | Canvas/Ink/Orange/Outfit visual identity |
| ADR-15 | Borrower portal frozen | No borrower-facing features in v1 |
| ADR-16 | Agentforce confirmed | Available on org, 4 subagents planned |

---

## 8. Phased Roadmap

| Phase | Focus | Deliverable |
|-------|-------|-------------|
| 1 | Frontend verification | React routes, mock data, unit tests, Figma visual QA |
| 2 | Local backend | Postgres, API routes, audit_events, receipt snapshots |
| 3 | Replay foundation | Policy versions, rules, replay checks, finding contract, evidence mapping |
| 4 | Salesforce sync | SF objects, audit case sync, finding sync, receipt sync, workflow status |
| 5 | Allura reasoning | Policy replay assistance, evidence mapping, governed memory, receipt intelligence |
| 6 | Agentforce | Read-only Auditor Assistant first, draft-only second, controlled writes third |
| 7 | Analytics and data | Audit metrics, event sync, approver drift, branch risk, policy failure rates |

Execution methodology: vertical slice, demo-first. Each phase delivers a demoable increment using one audit case (Sabir Sr., DTI 44.8%) end-to-end across all active layers.

---

## 9. Traceability

- Requirements -> components tracked in `planning docs/REQUIREMENTS-MATRIX.md`
- Decisions and risks in `planning docs/RISKS-AND-DECISIONS.md`
- Data contracts in `planning docs/DATA-DICTIONARY.md`
- PRD with all 28 FRs in `my-project/_bmad-output/planning-artifacts/prds/prd-Mortagate-2026-06-14/prd.md`
- Product brief in `my-project/_bmad-output/planning-artifacts/product-brief.md`
- Market research in `my-project/_bmad-output/planning-artifacts/research/`
