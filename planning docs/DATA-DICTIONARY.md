# Data Dictionary -- Veridact v1

> **AI-Assisted Documentation**
> Portions of this document were drafted with the assistance of an AI language model.
> Content has been reviewed against the PRD, product brief, and codebase but requires stakeholder sign-off.

> **Canonical schema for the 11-object Veridact Mortgage Audit Replay & QC data model.**
> Reconciles the Notion canonical plan with the existing codebase (feat/audit-queue-mvp).
> PRD reference: `prd-Mortagate-2026-06-14/prd.md`. Glossary terms from `product-brief.md`.
>
> Last updated: 2026-06-14 by Knuth (data architect).

---

## 0. Schema Reconciliation

### 0.1 Object Name Mapping (Old Branch --> Canonical)

The Notion canonical names are adopted. Where an object existed on `feat/audit-queue-mvp` under a different name, the old name is retired and the new name is used going forward. Objects that already match keep their names. New objects that had no old-branch equivalent are marked NEW.

| # | Notion Canonical Name | Old Branch Name | Action | Rationale |
|---|----------------------|----------------|--------|-----------|
| 1 | `Audit_Case__c` | `Audit_Case__c` | KEEP | Names match |
| 2 | `Loan__c` | `Loan_Application__c` | RENAME | Notion uses `Loan__c`; shorter, audit-centric (the loan is the subject of audit, not an application) |
| 3 | `Borrower_Snapshot__c` | `Extracted_Facts__c` | RENAME | Notion name clarifies purpose: a point-in-time borrower data snapshot, not raw extraction output |
| 4 | `Policy_Version__c` | (none -- was a concept within `Policy_Rule_Version__c`) | NEW (split) | Notion separates the policy version container from individual rules. Old branch combined both into `Policy_Rule_Version__c` |
| 5 | `Policy_Rule__c` | `Policy_Rule_Version__c` | RENAME + RESTRUCTURE | Old object carried both version and rule data. Now rules are children of `Policy_Version__c` |
| 6 | `Evidence_Item__c` | `Evidence_Item__c` | KEEP | Names match. Also absorbs the old `Evidence__c` origination-side object (which is retained separately for origination flow) |
| 7 | `Replay_Check__c` | `Rule_Check__c` | RENAME | Notion name is more precise: it is a historical replay, not just a rule check |
| 8 | `Finding__c` | `Finding__c` | KEEP | Names match. Fields expanded per PRD FR-9/FR-10 |
| 9 | `Audit_Receipt__c` | (none) | NEW | Immutable sign-off record. Did not exist on old branch |
| 10 | `Audit_Event__c` | `Audit_Event__c` | KEEP | Names match. Append-only |
| 11 | `Agent_Action_Log__c` | (none) | NEW | Agentforce action audit trail. Did not exist on old branch |

### 0.2 Retained Origination Objects (Not Part of the 11)

These objects remain deployed for the loan origination flow but are NOT part of the Veridact audit schema. They are referenced by lookup from audit objects where needed.

| Object | Purpose | Status |
|--------|---------|--------|
| `Loan_Application__c` | Borrower mortgage application (origination) | Retained; `Loan__c` holds audit-relevant loan data as a snapshot |
| `Evidence__c` | Origination-side uploaded documents | Retained; `Evidence_Item__c` is the audit-side evidence record |
| `Extracted_Facts__c` | Origination-side fact extraction | Retained; `Borrower_Snapshot__c` is the audit-side borrower data |
| `Decision_Event__c` | Origination-side decision log (append-only) | Retained; separate from `Audit_Event__c` |
| `Reconstructed_Fact__c` | Old audit-side fact record | RETIRED -- replaced by `Borrower_Snapshot__c` |
| `Rule_Check__c` | Old audit-side rule check | RETIRED -- replaced by `Replay_Check__c` |
| `Policy_Rule_Version__c` | Old combined policy+rule | RETIRED -- split into `Policy_Version__c` + `Policy_Rule__c` |

### 0.3 Field-Level Mapping (Old --> New)

#### Rule_Check__c --> Replay_Check__c

| Old Field | New Field | Notes |
|-----------|-----------|-------|
| `Audit_Case__c` | `Audit_Case__c` | Unchanged |
| `Rule_Name__c` | `Rule_Name__c` | Unchanged |
| `Policy_Rule_Version__c` (Text 18) | `Policy_Rule__c` (Lookup) | Upgraded from text ID to proper lookup |
| `Outcome__c` | `Result__c` | Renamed for clarity; values: Pass, Fail, Unverifiable |
| `Evidence_References__c` (JSON) | `Evidence_Item__c` (Lookup) | Replaced JSON array with proper lookup |
| `Fact_References__c` (JSON) | `Borrower_Snapshot__c` (Lookup) | Replaced JSON array with proper lookup |
| `Exception_Approver__c` | (moved to Finding__c) | Exception data belongs on Finding, not replay check |
| `Exception_Reason__c` | (moved to Finding__c) | Exception data belongs on Finding, not replay check |
| `Rationale__c` | `Rationale__c` | Unchanged |
| (new) | `Expected_Value__c` | Added per PRD FR-6: show expected threshold |
| (new) | `Actual_Value__c` | Added per PRD FR-6: show actual borrower value |

#### Reconstructed_Fact__c --> Borrower_Snapshot__c

| Old Field | New Field | Notes |
|-----------|-----------|-------|
| `Audit_Case__c` | `Audit_Case__c` | Unchanged |
| `Fact_Type__c` | `Fact_Category__c` | Renamed for clarity |
| `Value__c` (Text) | Typed fields (see object spec) | Replaced generic value with typed fields per Philosophy #4 |
| `Source_Evidence__c` | `Evidence_Item__c` | Renamed to match canonical object |
| `Confidence__c` | `Confidence__c` | Unchanged |
| `Verified__c` | `Verified__c` | Unchanged |
| `Verified_At__c` | `Verified_At__c` | Unchanged |
| `Verified_By__c` | `Verified_By__c` | Unchanged |
| `Is_Unverifiable__c` | `Is_Unverifiable__c` | Unchanged |
| `Unverifiable_Reason__c` | `Unverifiable_Reason__c` | Unchanged |
| `Extractor_Version__c` | `Extractor_Version__c` | Unchanged |

#### Policy_Rule_Version__c --> Policy_Version__c + Policy_Rule__c

| Old Field | New Object.Field | Notes |
|-----------|-----------------|-------|
| `Rule_Code__c` | `Policy_Rule__c.Rule_Code__c` | Moved to child |
| `Rule_Label__c` | `Policy_Rule__c.Rule_Label__c` | Moved to child |
| `Rule_Category__c` | `Policy_Rule__c.Rule_Category__c` | Moved to child |
| `Operator__c` | `Policy_Rule__c.Operator__c` | Moved to child |
| `Threshold_Value__c` | `Policy_Rule__c.Threshold_Value__c` | Moved to child |
| `Threshold_High__c` | `Policy_Rule__c.Threshold_High__c` | Moved to child (BETWEEN operator) |
| `Fact_Field__c` | `Policy_Rule__c.Fact_Field__c` | Moved to child |
| `Severity__c` | `Policy_Rule__c.Severity__c` | Moved to child |
| `Rule_Explanation__c` | `Policy_Rule__c.Rule_Explanation__c` | Moved to child |
| `Allowed_Values__c` | `Policy_Rule__c.Allowed_Values__c` | Moved to child (IN operator) |
| `Effective_Date__c` | `Policy_Version__c.Effective_Date__c` | Moved to parent |
| `Expiration_Date__c` | `Policy_Version__c.Expiration_Date__c` | Moved to parent |
| `Version_Number__c` | `Policy_Version__c.Version_Number__c` | Moved to parent |
| `Is_Active__c` | `Policy_Version__c.Is_Active__c` | Moved to parent |
| `Supersedes__c` | `Policy_Version__c.Supersedes__c` | Moved to parent |
| `Regulatory_Citation__c` | `Policy_Rule__c.Regulatory_Citation__c` | Moved to child |
| `Override_Permitted__c` | `Policy_Rule__c.Override_Permitted__c` | Moved to child |
| `Override_Justification_Required__c` | `Policy_Rule__c.Override_Justification_Required__c` | Moved to child |
| `Change_Justification__c` | `Policy_Version__c.Change_Justification__c` | Moved to parent |

---

## 1. Entity Relationship Diagram

```
                                   ┌──────────────────────┐
                                   │  Policy_Version__c   │
                                   │  (versioned policy)  │
                                   └──────────┬───────────┘
                                              │ 1
                                              │
                                              │ *
                                   ┌──────────┴───────────┐
                                   │  Policy_Rule__c      │
                                   │  (rule-as-data)      │
                                   └──────────┬───────────┘
                                              │
                              ┌───────────────┤ (lookup from Replay_Check)
                              │               │
┌─────────────┐    1    ┌─────┴───────┐   *   │
│  Loan__c    │────────→│Audit_Case__c│───────┼──→ Replay_Check__c
│ (loan data) │         │ (case hub)  │       │    (rule evaluation result)
└─────────────┘         └──────┬──────┘       │
                               │              │
                    ┌──────────┼──────────┐   │
                    │          │          │   │
                    ▼ *        ▼ *        ▼ * │
             ┌──────────┐ ┌────────┐ ┌────────────────┐
             │Evidence_  │ │Finding_│ │Borrower_       │
             │Item__c    │ │_c      │ │Snapshot__c     │
             │(documents)│ │(judgmt)│ │(fact snapshot)  │
             └──────────┘ └────────┘ └────────────────┘
                    │
                    ▼ (lookup from Replay_Check)
                    │
         ┌──────────┴───────────────────────────┐
         │                                      │
    ┌────┴──────────┐                  ┌────────┴──────────┐
    │Audit_Event__c │                  │Audit_Receipt__c   │
    │[APPEND-ONLY]  │                  │[APPEND-ONLY]      │
    │(chain of      │                  │(sign-off record)  │
    │ custody)      │                  └───────────────────┘
    └───────────────┘
                                       ┌───────────────────┐
                                       │Agent_Action_Log__c│
                                       │[APPEND-ONLY]      │
                                       │(AI action audit)  │
                                       └───────────────────┘
```

---

## 2. Object Specifications

### 2.1 Audit_Case__c

**Label:** Audit Case
**Description:** A single loan under review -- the central hub that links evidence, findings, replay checks, events, and the final receipt.
**Old name:** `Audit_Case__c` (unchanged)
**FR coverage:** FR-1, FR-2, FR-3, FR-4, FR-5, FR-6, FR-8, FR-12

| Field API Name | Type | Required | Description | Default / Picklist Values |
|----------------|------|----------|-------------|--------------------------|
| `Name` | AutoNumber (`AC-{000000}`) | Auto | Case identifier | -- |
| `Loan__c` | Lookup(`Loan__c`) | Yes | The loan under audit | -- |
| `Status__c` | Picklist | Yes | Current case status | `In_Review`, `Evidence_Needed`, `Ready_for_Signoff`, `Closed` |
| `Risk_Tier__c` | Picklist | Yes | Risk classification | `High`, `Medium`, `Low` |
| `Auditor__c` | Lookup(User) | Yes | Assigned QC analyst | -- |
| `Original_Approver__c` | Text(255) | No | Loan officer who originally approved | -- |
| `Policy_Version__c` | Lookup(`Policy_Version__c`) | No | Governing policy version at approval time | -- |
| `Scope__c` | Picklist | No | Audit scope | `Full`, `Targeted`, `Re_Audit` |
| `Sampling_Reason__c` | Text(255) | No | Why this loan was selected for audit | -- |
| `Sampled_At__c` | DateTime | No | When the loan was sampled | -- |
| `Assigned_At__c` | DateTime | No | When the auditor was assigned | -- |
| `Due_At__c` | DateTime | Yes | SLA deadline | -- |
| `Signed_Off_At__c` | DateTime | No | When manager signed off | -- |
| `Signed_Off_By__c` | Lookup(User) | No | Manager who signed off | -- |
| `Borrower_Name_Snapshot__c` | Text(255) | No | Point-in-time borrower name (write-once) | -- |
| `Approval_Timestamp__c` | DateTime | No | Original loan approval date | -- |
| `Branch__c` | Text(100) | No | Originating branch (for FR-2 filtering) | -- |
| `Product_Type__c` | Picklist | No | Loan product type (for FR-2 filtering) | `Conventional`, `FHA`, `VA`, `USDA` |
| `Loan_Amount__c` | Currency(18,2) | No | Snapshot of loan amount (for queue display FR-1) | -- |

**Relationships:**
- Lookup to `Loan__c` (the loan being audited)
- Lookup to `Policy_Version__c` (governing policy)
- Parent of: `Evidence_Item__c`, `Replay_Check__c`, `Finding__c`, `Borrower_Snapshot__c`, `Audit_Event__c`, `Audit_Receipt__c`

**Validation Rules:**
- `Prevent_Self_Audit`: `Signed_Off_By__c` cannot equal `Auditor__c` (FR-12)
- `Snapshot_Write_Once`: `Borrower_Name_Snapshot__c` cannot be changed after initial set

**Notes:** Carried forward from old branch with added `Branch__c`, `Product_Type__c`, `Loan_Amount__c` fields for queue display and filtering (FR-1, FR-2).

---

### 2.2 Loan__c

**Label:** Loan
**Description:** The loan record being audited -- contains loan-level data snapshotted at audit creation time.
**Old name:** `Loan_Application__c` (renamed)
**FR coverage:** FR-1, FR-6, FR-26

| Field API Name | Type | Required | Description | Default / Picklist Values |
|----------------|------|----------|-------------|--------------------------|
| `Name` | AutoNumber (`LN-{000000}`) | Auto | Loan identifier | -- |
| `Borrower_Name__c` | Text(255) | Yes | Borrower full name | -- |
| `Loan_Amount__c` | Currency(18,2) | Yes | Approved loan amount | -- |
| `Property_Value__c` | Currency(18,2) | Yes | Appraised property value | -- |
| `Annual_Income__c` | Currency(18,2) | No | Borrower annual income | -- |
| `Loan_Type__c` | Picklist | Yes | Product type | `Conventional`, `FHA`, `VA`, `USDA` |
| `Purpose__c` | Picklist | Yes | Loan purpose | `Purchase`, `Refinance`, `Cash_Out_Refi` |
| `Approval_Date__c` | Date | Yes | Original approval date (drives policy version resolution) | -- |
| `Originating_Branch__c` | Text(100) | No | Branch that originated the loan | -- |
| `Approver_Name__c` | Text(255) | No | Loan officer who approved | -- |
| `LOS_Loan_Id__c` | Text(50) | No | External loan ID from LOS (future integration) | -- |
| `DTI_At_Approval__c` | Percent(5,4) | No | DTI ratio at time of approval | -- |
| `FICO_At_Approval__c` | Number(3,0) | No | FICO score at time of approval | -- |
| `LTV_At_Approval__c` | Percent(5,4) | No | LTV ratio at time of approval | -- |
| `Source_Application__c` | Lookup(`Loan_Application__c`) | No | Link back to origination record if available | -- |

**Relationships:**
- Optional lookup to `Loan_Application__c` (origination system)
- Parent of: `Audit_Case__c`

**Notes:** This is the audit-side loan record. It holds snapshotted loan data relevant to the audit. It is NOT the origination application -- `Loan_Application__c` is retained separately for the origination flow. The `Approval_Date__c` field is critical for FR-26 (policy version resolution).

---

### 2.3 Borrower_Snapshot__c

**Label:** Borrower Snapshot
**Description:** Point-in-time borrower financial data used for replay evaluation -- typed fields per fact category, not EAV.
**Old name:** `Reconstructed_Fact__c` (renamed) / absorbs concept from `Extracted_Facts__c`
**FR coverage:** FR-6, FR-7, FR-27

| Field API Name | Type | Required | Description | Default / Picklist Values |
|----------------|------|----------|-------------|--------------------------|
| `Name` | AutoNumber (`BS-{000000}`) | Auto | Snapshot identifier | -- |
| `Audit_Case__c` | Lookup(`Audit_Case__c`) | Yes | Parent audit case | -- |
| `Evidence_Item__c` | Lookup(`Evidence_Item__c`) | No | Source evidence document | -- |
| `Fact_Category__c` | Picklist | Yes | Category of fact | `Income`, `Employment`, `Asset`, `Credit`, `Identity`, `Residency`, `Debt` |
| `Annual_Income__c` | Currency(18,2) | No | Verified annual income | -- |
| `Monthly_Income__c` | Currency(18,2) | No | Verified monthly income | -- |
| `DTI_Ratio__c` | Percent(5,4) | No | Debt-to-income ratio | -- |
| `FICO_Score__c` | Number(3,0) | No | Credit score (300-850) | -- |
| `LTV_Ratio__c` | Percent(5,4) | No | Loan-to-value ratio | -- |
| `Employment_Months__c` | Number(4,0) | No | Months at current employer | -- |
| `Employer_Name__c` | Text(255) | No | Current employer name | -- |
| `Address_Tenure_Months__c` | Number(4,0) | No | Months at current address | -- |
| `Asset_Value__c` | Currency(18,2) | No | Total verified assets | -- |
| `Monthly_Debt__c` | Currency(18,2) | No | Total monthly debt obligations | -- |
| `Confidence__c` | Percent(5,2) | No | Extraction/reconstruction confidence | -- |
| `Extractor_Version__c` | Text(50) | No | Version of extraction tool used | -- |
| `Is_Unverifiable__c` | Checkbox | No | Whether the fact could not be verified | `false` |
| `Unverifiable_Reason__c` | Text(255) | No | Explanation if unverifiable | -- |
| `Verified__c` | Checkbox | No | Whether auditor has verified this snapshot | `false` |
| `Verified_At__c` | DateTime | No | When verification occurred | -- |
| `Verified_By__c` | Lookup(User) | No | Who verified | -- |

**Relationships:**
- Lookup to `Audit_Case__c` (parent)
- Lookup to `Evidence_Item__c` (source document)
- Referenced by `Replay_Check__c`

**Notes:** Follows Philosophy #4 (Structured Facts, Not EAV). Each fact category populates the relevant typed fields. The old `Reconstructed_Fact__c.Value__c` generic text field is eliminated in favor of proper typed fields.

---

### 2.4 Policy_Version__c

**Label:** Policy Version
**Description:** A versioned container for a set of lending policy rules with effective date range.
**Old name:** (none -- split from `Policy_Rule_Version__c`)
**FR coverage:** FR-6, FR-7, FR-26

| Field API Name | Type | Required | Description | Default / Picklist Values |
|----------------|------|----------|-------------|--------------------------|
| `Name` | AutoNumber (`PV-{000000}`) | Auto | Version identifier | -- |
| `Version_Label__c` | Text(100) | Yes | Human-readable version name | e.g., "Q1 2025 Conventional" |
| `Version_Number__c` | Number(4,0) | Yes | Sequential version number | -- |
| `Effective_Date__c` | Date | Yes | Date this version becomes active | -- |
| `Expiration_Date__c` | Date | No | Date this version expires (null = current) | -- |
| `Is_Active__c` | Checkbox | Yes | Whether this version is currently in force | `true` |
| `Policy_Type__c` | Picklist | Yes | What type of lending policy | `Conventional`, `FHA`, `VA`, `USDA`, `Universal` |
| `Supersedes__c` | Lookup(`Policy_Version__c`) | No | Previous version this replaces | -- |
| `Change_Justification__c` | LongTextArea(32000) | No | Why this version was created | -- |
| `Approved_By__c` | Text(255) | No | Compliance officer who approved | -- |
| `Approved_Date__c` | Date | No | When approved | -- |

**Relationships:**
- Self-lookup via `Supersedes__c` (version chain)
- Parent of: `Policy_Rule__c`
- Referenced by: `Audit_Case__c`, `Replay_Check__c`

**Notes:** The old `Policy_Rule_Version__c` combined version metadata and individual rule definitions in one flat object. The canonical schema splits this: `Policy_Version__c` holds the version envelope, `Policy_Rule__c` holds individual rules as children. This enables multiple rules per version without record duplication of version fields.

---

### 2.5 Policy_Rule__c

**Label:** Policy Rule
**Description:** A single lending policy rule within a policy version -- rules are data, not code.
**Old name:** (fields from `Policy_Rule_Version__c`, restructured as child)
**FR coverage:** FR-6, FR-7, FR-26, FR-27, FR-28

| Field API Name | Type | Required | Description | Default / Picklist Values |
|----------------|------|----------|-------------|--------------------------|
| `Name` | AutoNumber (`PR-{000000}`) | Auto | Rule identifier | -- |
| `Policy_Version__c` | Master-Detail(`Policy_Version__c`) | Yes | Parent policy version | -- |
| `Rule_Code__c` | Text(50) | Yes | Machine-readable rule code (unique within version) | e.g., `DTI_MAX`, `FICO_MIN`, `LTV_MAX` |
| `Rule_Label__c` | Text(100) | Yes | Human-readable rule name | e.g., "Maximum DTI Ratio" |
| `Rule_Category__c` | Picklist | Yes | Rule domain | `Income`, `Credit`, `Collateral`, `Employment`, `Residency`, `Debt`, `Documentation` |
| `Operator__c` | Picklist | Yes | Comparison operator | `GTE`, `LTE`, `GT`, `LT`, `EQ`, `NEQ`, `IN`, `BETWEEN` |
| `Threshold_Value__c` | Number(18,4) | Yes | Primary threshold value | -- |
| `Threshold_High__c` | Number(18,4) | No | Upper bound (for BETWEEN operator) | -- |
| `Fact_Field__c` | Text(100) | Yes | API name of the `Borrower_Snapshot__c` field to evaluate | e.g., `DTI_Ratio__c`, `FICO_Score__c` |
| `Severity__c` | Picklist | Yes | Consequence of failure | `Hard_Decline`, `Soft_Decline`, `Warning`, `Info` |
| `Rule_Explanation__c` | LongTextArea(32000) | Yes | Plain-language explanation for findings and adverse notices | -- |
| `Allowed_Values__c` | Text(255) | No | Comma-separated allowed values (for IN operator) | -- |
| `Regulatory_Citation__c` | Text(255) | No | Regulatory reference (e.g., "12 CFR 1026.43(e)") | -- |
| `Override_Permitted__c` | Checkbox | No | Whether exceptions are allowed | `false` |
| `Override_Justification_Required__c` | Checkbox | No | Whether exception requires written justification | `true` |
| `Sort_Order__c` | Number(4,0) | No | Display order for deterministic replay (FR-28) | -- |

**Relationships:**
- Master-Detail to `Policy_Version__c` (parent)
- Referenced by: `Replay_Check__c`

**Indexes:**
- `Rule_Code__c` should be unique within a given `Policy_Version__c` (enforced by validation rule or unique compound key)

**Notes:** Rules are data, not code (Philosophy #3). The `Fact_Field__c` maps to a specific typed field on `Borrower_Snapshot__c`, enabling pure evaluation (FR-27). `Sort_Order__c` ensures deterministic replay ordering (FR-28).

---

### 2.6 Evidence_Item__c

**Label:** Evidence Item
**Description:** A document or record linked to an audit case -- pay stub, appraisal, credit report, etc.
**Old name:** `Evidence_Item__c` (unchanged)
**FR coverage:** FR-5, FR-7, FR-8, FR-10

| Field API Name | Type | Required | Description | Default / Picklist Values |
|----------------|------|----------|-------------|--------------------------|
| `Name` | AutoNumber (`EI-{000000}`) | Auto | Evidence identifier | -- |
| `Audit_Case__c` | Lookup(`Audit_Case__c`) | Yes | Parent audit case | -- |
| `Document_Type__c` | Picklist | Yes | Type of document | `Pay_Stub`, `W2`, `Bank_Statement`, `Tax_Return`, `Appraisal`, `Credit_Report`, `Purchase_Agreement`, `Photo_ID`, `Employment_Verification`, `Other` |
| `Status__c` | Picklist | Yes | Evidence status | `Linked`, `Missing`, `Unverifiable` |
| `ContentDocument_Id__c` | Text(18) | No | Salesforce ContentDocument ID (null if Missing) | -- |
| `SHA256_Hash__c` | Text(64) | No | Document integrity hash | -- |
| `Required__c` | Checkbox | Yes | Whether this evidence type is required for the audit | `true` |
| `Received_Timestamp__c` | DateTime | No | When the document was received/linked | -- |
| `Notes__c` | LongTextArea(32000) | No | Auditor notes about this evidence item | -- |

**Relationships:**
- Lookup to `Audit_Case__c` (parent)
- Referenced by: `Borrower_Snapshot__c`, `Replay_Check__c`, `Finding__c`

**Notes:** Status changes create `Audit_Event__c` records per FR-8. The `Missing` and `Unverifiable` states are first-class outcomes, not error states.

---

### 2.7 Replay_Check__c

**Label:** Replay Check
**Description:** The result of applying one policy rule to one audit case's evidence during historical replay.
**Old name:** `Rule_Check__c` (renamed)
**FR coverage:** FR-6, FR-7, FR-9, FR-27, FR-28

| Field API Name | Type | Required | Description | Default / Picklist Values |
|----------------|------|----------|-------------|--------------------------|
| `Name` | AutoNumber (`RC-{000000}`) | Auto | Check identifier | -- |
| `Audit_Case__c` | Lookup(`Audit_Case__c`) | Yes | Parent audit case | -- |
| `Policy_Rule__c` | Lookup(`Policy_Rule__c`) | Yes | The rule being evaluated | -- |
| `Rule_Name__c` | Text(100) | Yes | Denormalized rule name for display | -- |
| `Result__c` | Picklist | Yes | Evaluation outcome | `Pass`, `Fail`, `Unverifiable` |
| `Expected_Value__c` | Text(100) | Yes | Threshold from the policy rule | -- |
| `Actual_Value__c` | Text(100) | No | Value from borrower snapshot (null if unverifiable) | -- |
| `Evidence_Item__c` | Lookup(`Evidence_Item__c`) | No | Supporting evidence document | -- |
| `Borrower_Snapshot__c` | Lookup(`Borrower_Snapshot__c`) | No | Fact snapshot used for evaluation | -- |
| `Rationale__c` | LongTextArea(32768) | No | Detailed explanation of the outcome | -- |
| `Replay_Timestamp__c` | DateTime | Yes | When the replay was executed | -- |
| `Sort_Order__c` | Number(4,0) | No | Deterministic display order (mirrors Policy_Rule sort) | -- |

**Relationships:**
- Lookup to `Audit_Case__c` (parent)
- Lookup to `Policy_Rule__c` (the rule evaluated)
- Lookup to `Evidence_Item__c` (supporting evidence)
- Lookup to `Borrower_Snapshot__c` (fact data used)
- Referenced by: `Finding__c`

**Notes:** `Expected_Value__c` and `Actual_Value__c` are stored as text to support heterogeneous value types (percentages, scores, currency amounts). The evaluator is a pure function (FR-27) -- zero SOQL, zero DML in the evaluator itself. Results are sorted by `Sort_Order__c` for deterministic ordering (FR-28).

---

### 2.8 Finding__c

**Label:** Finding
**Description:** An auditor's documented judgment on a replay check result -- pass, exception, or violation.
**Old name:** `Finding__c` (unchanged, fields expanded)
**FR coverage:** FR-9, FR-10, FR-11

| Field API Name | Type | Required | Description | Default / Picklist Values |
|----------------|------|----------|-------------|--------------------------|
| `Name` | AutoNumber (`FN-{000000}`) | Auto | Finding identifier | -- |
| `Audit_Case__c` | Lookup(`Audit_Case__c`) | Yes | Parent audit case | -- |
| `Replay_Check__c` | Lookup(`Replay_Check__c`) | No | Source replay check (null for manual findings) | -- |
| `Severity__c` | Picklist | Yes | Auditor judgment | `Pass`, `Exception`, `Violation` |
| `Category__c` | Picklist | No | Finding category | `Income`, `Credit`, `Collateral`, `Employment`, `Documentation`, `Other` |
| `Description__c` | LongTextArea(32000) | Yes | Finding description (free text or AI-drafted) | -- |
| `Remediation_Notes__c` | LongTextArea(32000) | No | Recommended remediation | -- |
| `Remediation_Owner__c` | Lookup(User) | No | Person responsible for remediation | -- |
| `Remediation_Due_At__c` | Date | No | Remediation deadline | -- |
| `Exception_Approver__c` | Text(255) | No | Who approved the exception at origination | -- |
| `Exception_Reason__c` | LongTextArea(32000) | No | Documented reason for exception | -- |
| `Disposition__c` | Picklist | No | Final disposition | `Open`, `Acknowledged`, `Remediated`, `Closed` |
| `Closed_Reason__c` | Text(255) | No | Why the finding was closed | -- |
| `AI_Drafted__c` | Checkbox | No | Whether Agentforce drafted the description | `false` |
| `AI_Draft_Accepted__c` | Checkbox | No | Whether auditor accepted AI draft without edits | `false` |

**Relationships:**
- Lookup to `Audit_Case__c` (parent)
- Lookup to `Replay_Check__c` (source check)

**Notes:** Exception data (`Exception_Approver__c`, `Exception_Reason__c`) moved here from old `Rule_Check__c` because exceptions are an auditor judgment, not a replay result. `AI_Drafted__c` and `AI_Draft_Accepted__c` support SM-C2 (counter-metric for AI over-reliance).

---

### 2.9 Audit_Receipt__c [APPEND-ONLY]

**Label:** Audit Receipt
**Description:** The immutable sign-off record created when a manager approves a completed audit case. Once created, it cannot be updated or deleted.
**Old name:** (none -- NEW)
**FR coverage:** FR-12, FR-13, FR-14, FR-25

| Field API Name | Type | Required | Description | Default / Picklist Values |
|----------------|------|----------|-------------|--------------------------|
| `Name` | AutoNumber (`AR-{000000}`) | Auto | Receipt identifier | -- |
| `Audit_Case__c` | Lookup(`Audit_Case__c`) | Yes | The audit case being signed off | -- |
| `Reviewer__c` | Lookup(User) | Yes | Manager who signed off | -- |
| `Signed_Off_At__c` | DateTime | Yes | Timestamp of sign-off | -- |
| `Findings_Snapshot__c` | LongTextArea(131072) | Yes | JSON snapshot of all findings at sign-off time | -- |
| `Evidence_Snapshot__c` | LongTextArea(131072) | Yes | JSON snapshot of all evidence items at sign-off time | -- |
| `Replay_Snapshot__c` | LongTextArea(131072) | Yes | JSON snapshot of all replay check results at sign-off time | -- |
| `Total_Findings__c` | Number(4,0) | Yes | Count of findings | -- |
| `Violation_Count__c` | Number(4,0) | Yes | Count of violation-severity findings | -- |
| `Exception_Count__c` | Number(4,0) | Yes | Count of exception-severity findings | -- |
| `Pass_Count__c` | Number(4,0) | Yes | Count of pass-severity findings | -- |
| `Receipt_Hash__c` | Text(64) | No | SHA-256 hash of snapshot data for tamper detection | -- |

**Relationships:**
- Lookup to `Audit_Case__c` (the case signed off)

**Immutability enforcement:**
- Validation rule `Prevent_Edit_After_Creation`: blocks UPDATE on all fields after initial insert
- Before-delete trigger `AuditReceiptPreventDelete`: blocks DELETE
- FR-25 requires both mechanisms

**Notes:** The three snapshot fields capture the complete state at sign-off time as JSON. This makes the receipt self-contained -- even if child records are later modified (which should not happen), the receipt preserves the original state. `Receipt_Hash__c` provides an additional tamper-detection layer.

---

### 2.10 Audit_Event__c [APPEND-ONLY]

**Label:** Audit Event
**Description:** An immutable log entry in the case's chain of custody. Every material action appends a record. Never updated, never deleted.
**Old name:** `Audit_Event__c` (unchanged)
**FR coverage:** FR-8, FR-9, FR-12, FR-13, FR-22, FR-23, FR-24, FR-25

| Field API Name | Type | Required | Description | Default / Picklist Values |
|----------------|------|----------|-------------|--------------------------|
| `Name` | AutoNumber (`AE-{000000}`) | Auto | Event identifier | -- |
| `Audit_Case__c` | Lookup(`Audit_Case__c`) | Yes | Parent audit case | -- |
| `Event_Type__c` | Picklist | Yes | What happened | See Event Types table below |
| `Actor__c` | Text(255) | Yes | Who or what performed the action | -- |
| `Timestamp__c` | DateTime | Yes | When the event occurred | -- |
| `Payload__c` | LongTextArea(131072) | No | JSON payload with event-specific details | -- |
| `Related_Record_Id__c` | Text(18) | No | ID of the related record (Finding, Evidence, etc.) | -- |

**Event Types (picklist values):**

| Value | Trigger | FR |
|-------|---------|-----|
| `Case_Created` | Audit case created | FR-24 |
| `Case_Assigned` | Auditor assigned to case | FR-24 |
| `Evidence_Status_Changed` | Evidence item status updated | FR-8 |
| `Replay_Executed` | Replay run completed | FR-6, FR-24 |
| `Finding_Created` | Finding record created | FR-9, FR-24 |
| `Finding_Updated` | Finding record modified | FR-24 |
| `Submitted_For_Signoff` | Case submitted for manager review | FR-12 |
| `Case_Signed_Off` | Manager approved and signed receipt | FR-13 |
| `Case_Returned` | Manager returned case for rework | FR-13 |
| `Violation_Alert_Sent` | Proactive violation notification sent | FR-22 |
| `Agent_Action` | Agentforce action executed | FR-23 |
| `Evidence_Requested` | Evidence request sent to loan officer | FR-20 |

**Immutability enforcement:**
- Validation rule `Prevent_Edit_After_Creation`: `ISCHANGED(Event_Type__c) || ISCHANGED(Actor__c) || ISCHANGED(Timestamp__c) || ISCHANGED(Payload__c) || ISCHANGED(Related_Record_Id__c)` --> error
- Before-delete trigger `AuditEventPreventDelete`: blocks all deletes
- FR-25 requires both mechanisms

**Notes:** Carried forward from old branch with unchanged structure. This is the core integrity guarantee of the product.

---

### 2.11 Agent_Action_Log__c [APPEND-ONLY]

**Label:** Agent Action Log
**Description:** A record of every Agentforce action taken, for auditing the AI assistant. Append-only.
**Old name:** (none -- NEW)
**FR coverage:** FR-11, FR-17, FR-18, FR-19, FR-20, FR-21, FR-22, FR-23

| Field API Name | Type | Required | Description | Default / Picklist Values |
|----------------|------|----------|-------------|--------------------------|
| `Name` | AutoNumber (`AL-{000000}`) | Auto | Log identifier | -- |
| `Audit_Case__c` | Lookup(`Audit_Case__c`) | No | Related audit case (null for system-level actions) | -- |
| `Action_Name__c` | Picklist | Yes | The action performed | See Action Names table below |
| `Subagent__c` | Picklist | Yes | Which Agentforce subagent executed | `Auditor_Assistant`, `Evidence_Request`, `Manager_Review`, `Compliance_Analytics` |
| `Actor__c` | Text(255) | Yes | The user who invoked the action | -- |
| `Timestamp__c` | DateTime | Yes | When the action was executed | -- |
| `Input_Summary__c` | LongTextArea(32000) | No | Summary of input provided to the agent | -- |
| `Output_Summary__c` | LongTextArea(32000) | No | Summary of output returned by the agent | -- |
| `Prompt_Template__c` | Text(255) | No | Which prompt template was used | -- |
| `Duration_Ms__c` | Number(8,0) | No | Execution duration in milliseconds | -- |
| `Status__c` | Picklist | Yes | Action outcome | `Success`, `Failed`, `Partial` |
| `Error_Message__c` | Text(255) | No | Error details if failed | -- |

**Action Names (picklist values):**

| Value | Subagent | FR |
|-------|----------|-----|
| `Summarize_Case` | Auditor_Assistant | FR-17 |
| `List_Missing_Evidence` | Auditor_Assistant | FR-18 |
| `Draft_Finding_Text` | Auditor_Assistant | FR-19 |
| `Draft_Evidence_Request` | Evidence_Request | FR-20 |
| `Prepare_Manager_Summary` | Manager_Review | FR-21 |
| `Send_Violation_Alert` | Compliance_Analytics | FR-22 |
| `Log_Agent_Action` | (system) | FR-23 |
| `Generate_Analytics` | Compliance_Analytics | FR-15 |

**Immutability enforcement:**
- Validation rule `Prevent_Edit_After_Creation`: blocks UPDATE on all fields after insert
- Before-delete trigger `AgentActionLogPreventDelete`: blocks DELETE

**Notes:** Every Agentforce action MUST call `logAgentAction` before executing (FR-23). A corresponding `Audit_Event__c` with `Event_Type = Agent_Action` is also created for each action, creating dual-write traceability.

---

## 3. Immutability Rules Summary

| Object | UPDATE Blocked | DELETE Blocked | Enforcement |
|--------|---------------|---------------|-------------|
| `Audit_Event__c` | Yes (all fields post-insert) | Yes | Validation rule + before-delete trigger |
| `Audit_Receipt__c` | Yes (all fields post-insert) | Yes | Validation rule + before-delete trigger |
| `Agent_Action_Log__c` | Yes (all fields post-insert) | Yes | Validation rule + before-delete trigger |
| `Decision_Event__c` (origination) | Yes (all fields post-insert) | Yes | Apex trigger (existing) |

All other objects allow standard CRUD operations subject to FLS and sharing rules.

---

## 4. Indexing Strategy

| Object | Field(s) | Index Type | Reason |
|--------|----------|-----------|--------|
| `Audit_Case__c` | `Loan__c` | Lookup (auto) | Parent join |
| `Audit_Case__c` | `Status__c` | Custom Index | Queue filtering (FR-2) |
| `Audit_Case__c` | `Due_At__c` | Custom Index | SLA sort (FR-1) |
| `Audit_Case__c` | `Risk_Tier__c` | Custom Index | Queue filtering (FR-2) |
| `Evidence_Item__c` | `Audit_Case__c` | Lookup (auto) | Parent join |
| `Replay_Check__c` | `Audit_Case__c` | Lookup (auto) | Parent join |
| `Replay_Check__c` | `Policy_Rule__c` | Lookup (auto) | Rule join |
| `Finding__c` | `Audit_Case__c` | Lookup (auto) | Parent join |
| `Borrower_Snapshot__c` | `Audit_Case__c` | Lookup (auto) | Parent join |
| `Audit_Event__c` | `Audit_Case__c` | Lookup (auto) | Parent join |
| `Audit_Event__c` | `Event_Type__c` | Custom Index | Event filtering |
| `Policy_Rule__c` | `Policy_Version__c` | Master-Detail (auto) | Parent join |
| `Policy_Rule__c` | `Rule_Code__c` | Custom Index | Rule resolution (FR-26) |
| `Policy_Version__c` | `Effective_Date__c` + `Is_Active__c` | Compound Custom Index | Version resolution (FR-26) |
| `Agent_Action_Log__c` | `Audit_Case__c` | Lookup (auto) | Parent join |
| `Agent_Action_Log__c` | `Timestamp__c` | Custom Index | Chronological queries |

---

## 5. Demo Data Sizing Estimate

Developer Edition org limit: 5 MB data storage.

Salesforce data storage formula: each record consumes approximately 2 KB. Custom object records vary but 2 KB is the standard allocation.

| Object | Records (Demo) | Estimated Size | Notes |
|--------|---------------|----------------|-------|
| `Loan__c` | 205 | 0.40 MB | 5 personas + 200 bulk |
| `Audit_Case__c` | 205 | 0.40 MB | 1:1 with loans |
| `Policy_Version__c` | 4 | < 0.01 MB | 4 versions (Q1-Q4 2025) |
| `Policy_Rule__c` | 40 | 0.08 MB | ~10 rules per version |
| `Evidence_Item__c` | 1,025 | 2.00 MB | ~5 evidence items per case |
| `Borrower_Snapshot__c` | 615 | 1.20 MB | ~3 fact categories per case |
| `Replay_Check__c` | 2,050 | (deferred) | ~10 checks per case -- run on demand, not pre-seeded |
| `Finding__c` | 410 | (deferred) | ~2 findings per case -- created during demo, not pre-seeded |
| `Audit_Receipt__c` | 10 | 0.02 MB | Only closed cases |
| `Audit_Event__c` | 1,000 | (deferred) | Created during demo workflow |
| `Agent_Action_Log__c` | 50 | (deferred) | Created during demo |
| **TOTAL (pre-seeded)** | **~2,094** | **~4.1 MB** | Within 5 MB limit |

**Strategy:** Pre-seed `Loan__c`, `Audit_Case__c`, `Policy_Version__c`, `Policy_Rule__c`, `Evidence_Item__c`, and `Borrower_Snapshot__c`. Let `Replay_Check__c`, `Finding__c`, `Audit_Receipt__c`, `Audit_Event__c`, and `Agent_Action_Log__c` be created during demo workflow execution. This keeps pre-seeded data under 4.1 MB with ~0.9 MB headroom for runtime records.

**Risk mitigation:** If approaching the limit, reduce bulk records from 200 to 100 (saves ~1.5 MB). The 5 persona cases are sufficient for all demo scenarios.

---

## 6. FR-to-Object Traceability Matrix

| FR | Objects Required |
|----|-----------------|
| FR-1 (Queue display) | `Audit_Case__c`, `Loan__c` |
| FR-2 (Queue filtering) | `Audit_Case__c` |
| FR-3 (Queue metrics) | `Audit_Case__c` |
| FR-4 (Case navigation) | `Audit_Case__c` |
| FR-5 (Evidence panel) | `Evidence_Item__c`, `Audit_Case__c` |
| FR-6 (Replay execution) | `Replay_Check__c`, `Policy_Version__c`, `Policy_Rule__c`, `Borrower_Snapshot__c`, `Evidence_Item__c` |
| FR-7 (Replay check detail) | `Replay_Check__c`, `Policy_Rule__c`, `Evidence_Item__c` |
| FR-8 (Evidence status update) | `Evidence_Item__c`, `Audit_Event__c` |
| FR-9 (Create finding) | `Finding__c`, `Replay_Check__c`, `Audit_Event__c` |
| FR-10 (Finding form) | `Finding__c`, `Evidence_Item__c` |
| FR-11 (AI-drafted finding) | `Finding__c`, `Agent_Action_Log__c` |
| FR-12 (Sign-off workflow) | `Audit_Case__c`, `Audit_Event__c` |
| FR-13 (Manager sign-off) | `Audit_Receipt__c`, `Audit_Case__c`, `Audit_Event__c` |
| FR-14 (Receipt PDF) | `Audit_Receipt__c` |
| FR-15 (Analytics) | `Audit_Case__c`, `Finding__c`, `Evidence_Item__c` |
| FR-16 (Approver drift) | `Audit_Case__c`, `Finding__c`, `Loan__c` |
| FR-17 (Case summarization) | `Audit_Case__c`, `Agent_Action_Log__c`, `Audit_Event__c` |
| FR-18 (Missing evidence) | `Evidence_Item__c`, `Agent_Action_Log__c` |
| FR-19 (Finding drafting) | `Finding__c`, `Replay_Check__c`, `Agent_Action_Log__c` |
| FR-20 (Evidence request) | `Evidence_Item__c`, `Agent_Action_Log__c` |
| FR-21 (Manager summary) | `Audit_Case__c`, `Finding__c`, `Agent_Action_Log__c` |
| FR-22 (Violation notification) | `Replay_Check__c`, `Audit_Event__c`, `Agent_Action_Log__c` |
| FR-23 (Agent governance) | `Agent_Action_Log__c`, `Audit_Event__c` |
| FR-24 (Append-only events) | `Audit_Event__c` |
| FR-25 (Immutability) | `Audit_Event__c`, `Audit_Receipt__c` |
| FR-26 (Policy resolution) | `Policy_Version__c`, `Policy_Rule__c`, `Loan__c` |
| FR-27 (Pure evaluation) | `Borrower_Snapshot__c`, `Policy_Rule__c`, `Replay_Check__c` |
| FR-28 (Deterministic ordering) | `Policy_Rule__c`, `Replay_Check__c` |

**Coverage check:** All 28 FRs map to at least one object. All 11 objects are referenced by at least one FR.

---

## 7. Origination Schema (Retained, Not Part of 11)

The following objects were deployed during the origination phase and remain in the org. They are NOT part of the Veridact audit schema but are referenced where noted.

### 7.1 Loan_Application__c (Origination)

Retained as-is. `Loan__c.Source_Application__c` provides an optional lookup back.

### 7.2 Evidence__c (Origination)

Retained as-is. Distinct from `Evidence_Item__c` (audit-side).

### 7.3 Extracted_Facts__c (Origination)

Retained as-is. Distinct from `Borrower_Snapshot__c` (audit-side).

### 7.4 Decision_Event__c (Origination, Append-Only)

Retained as-is. Distinct from `Audit_Event__c` (audit-side).

### 7.5 Custom Metadata Types

| Object | Purpose | Status |
|--------|---------|--------|
| `Adverse_Action_Config__mdt` | ECOA/Reg B adverse action notice configuration | Retained |
| `PreFlight_Assumption__mdt` | Pre-flight calculation assumptions | Retained |

---

## 8. Open Design Decisions

| # | Question | Recommendation | Status |
|---|----------|----------------|--------|
| 1 | Should `Audit_Case__c.Loan__c` be Master-Detail or Lookup? | Lookup -- a loan can exist without being audited | PROPOSED |
| 2 | Should `Replay_Check__c` records be immutable? | No -- they are regenerated on each replay. Findings capture the auditor's judgment | PROPOSED |
| 3 | Should `Evidence_Item__c.Audit_Case__c` be Master-Detail or Lookup? | Lookup -- evidence may be shared across re-audits | PROPOSED |
| 4 | Maximum `Payload__c` size on `Audit_Event__c`? | 131,072 chars (128 KB). Sufficient for JSON snapshots | PROPOSED |
| 5 | How to enforce `Rule_Code__c` uniqueness within a `Policy_Version__c`? | Validation rule with SOQL count. Cannot use unique index (unique is org-wide, not parent-scoped) | PROPOSED |
