# Data Dictionary

> [!NOTE]
> **AI-Assisted Documentation**
> Portions of this document were drafted with the assistance of an AI language model.

---

## Entity Relationship Diagram

```
┌─────────────────────┐         ┌──────────────────┐
│ Loan_Application__c │ 1───0..* │ Evidence__c      │
│                     │         │                  │ 1───0..*  ┌────────────────────┐
│ • Name (AutoNumber) │         │ • Name (AutoNum) │ ────────→ │ Extracted_Facts__c │
│ • Status__c         │         │ • Document_Type  │           │                    │
│ • Borrower__c (User)│         │ • Content_Ver_Id │           │ • Fact_Type__c     │
│ • Purpose__c        │         │ • Upload_Date    │           │ • Annual_Income__c │
│ • Property_Value__c │         │ • Extraction_Stat│           │ • DTI_Ratio__c     │
│ • Requested_Amount  │         │ • Application__c │           │ • FICO_Score__c    │
│ • Submission_Date   │         └──────────────────┘           │ • LTV_Ratio__c     │
│ • Current_Stage__c  │                                        │ • Employment_Mon   │
└─────────┬───────────┘                                        │ • Evidence__c (Lkp)│
          │                                                    │ • Application__c   │
          │ 1───1..*                                           └────────────────────┘
          ▼
┌─────────────────────────┐         ┌──────────────────────────┐
│ Decision_Event__c       │ *───1   │ Policy_Rule_Version__c   │
│ [APPEND-ONLY]           │ ──────→ │                          │
│                         │         │ • Rule_Code__c (UNIQUE)  │
│ • Name (AutoNumber)     │         │ • Rule_Label__c          │
│ • Application__c (MD)   │         │ • Rule_Category__c       │
│ • Outcome__c            │         │ • Operator__c            │
│ • Rule_Version__c (Lkp) │         │ • Threshold_Value__c     │
│ • Rule_Results_JSON__c  │         │ • Fact_Field__c          │
│ • Evaluated_Rule_Count  │         │ • Severity__c            │
│ • Hard_Decline_Count    │         │ • Rule_Explanation__c    │
│ • Decision_Timestamp    │         │ • Effective_Date__c      │
│ • Evaluated_Facts__c    │         │ • Expiration_Date__c     │
│ • Triggered_By__c       │         │ • Version_Number__c      │
└─────────────────────────┘         │ • Is_Active__c           │
                                    │ • Supersedes__c (Self)   │
                                    └──────────────────────────┘
```

---

## Loan_Application__c

| Field API Name | Type | Required | Description |
|----------------|------|----------|-------------|
| Name | AutoNumber (LA-{000000}) | Auto | Application number |
| Status__c | Picklist | Yes | DRAFT, SUBMITTED, IN_REVIEW, DECIDED, WITHDRAWN |
| Purpose__c | Picklist | Yes | PURCHASE, REFINANCE |
| Borrower__c | Lookup(User) | Yes | Community user who submitted |
| Property_Value__c | Currency(18,2) | Yes | Estimated/appraised property value |
| Requested_Amount__c | Currency(18,2) | Yes | Loan amount requested |
| Annual_Income__c | Currency(18,2) | Yes | Self-reported annual income |
| Submission_Date__c | DateTime | No | Null until submitted |
| Current_Stage__c | Picklist | Yes | INTENT, DOCUMENTS, REVIEW, DECISION |
| Loan_Type__c | Picklist | Yes | CONVENTIONAL, FHA, VA, USDA |

---

## Evidence__c

| Field API Name | Type | Required | Description |
|----------------|------|----------|-------------|
| Name | AutoNumber (EV-{000000}) | Auto | Evidence ID |
| Application__c | Master-Detail(Loan_Application__c) | Yes | Parent application |
| Document_Type__c | Picklist | Yes | PAY_STUB, W2, BANK_STATEMENT, TAX_RETURN, PHOTO_ID, PURCHASE_AGREEMENT |
| Content_Version_Id__c | Text(18) | Yes | Salesforce ContentVersion ID |
| Upload_Date__c | DateTime | Yes | When borrower uploaded |
| Extraction_Status__c | Picklist | Yes | PENDING, PROCESSING, COMPLETED, FAILED |

---

## Extracted_Facts__c

Structured fields per fact type. NOT EAV.

| Field API Name | Type | Required | Description |
|----------------|------|----------|-------------|
| Name | AutoNumber (EF-{000000}) | Auto | Fact ID |
| Application__c | Lookup(Loan_Application__c) | Yes | Parent application |
| Evidence__c | Lookup(Evidence__c) | Yes | Source document |
| Fact_Type__c | Picklist | Yes | INCOME, EMPLOYMENT, ASSET, CREDIT, IDENTITY, RESIDENCY |
| Annual_Income__c | Currency(18,2) | No | Extracted annual income |
| Monthly_Income__c | Currency(18,2) | No | Extracted monthly income |
| DTI_Ratio__c | Percent(5,4) | No | Calculated debt-to-income |
| FICO_Score__c | Number(3,0) | No | Credit score (300-850) |
| LTV_Ratio__c | Percent(5,4) | No | Calculated loan-to-value |
| Employment_Months__c | Number(4,0) | No | Months at current employer |
| Employer_Name__c | Text(255) | No | Current employer |
| Address_Tenure_Months__c | Number(4,0) | No | Months at current address (used by ADDRESS_TENURE_MIN rule, minimum 12) |
| Asset_Value__c | Currency(18,2) | No | Total verified assets |
| Extraction_Confidence__c | Percent(5,2) | No | AI/OCR confidence score |
| Extracted_Date__c | DateTime | Yes | When extraction completed |
| Verified__c | Checkbox | No | Borrower confirmed accuracy |

---

## Decision_Event__c [APPEND-ONLY]

| Field API Name | Type | Required | Description |
|----------------|------|----------|-------------|
| Name | AutoNumber (DE-{000000}) | Auto | Event ID |
| Application__c | Master-Detail(Loan_Application__c) | Yes | Parent application |
| Outcome__c | Picklist | Yes | APPROVED, APPROVED_WITH_CONDITIONS, PENDING_REVIEW, HARD_DECLINED |
| Rule_Version__c | Lookup(Policy_Rule_Version__c) | Yes | Governing rule set at decision time |
| Evaluated_Facts__c | Lookup(Extracted_Facts__c) | No | Facts snapshot used |
| Rule_Results_JSON__c | LongTextArea(131072) | Yes | Full evaluation receipt |
| Evaluated_Rule_Count__c | Number(4,0) | Yes | Total rules evaluated |
| Hard_Decline_Count__c | Number(4,0) | Yes | Rules that hard-declined |
| Decision_Timestamp__c | DateTime | Yes | When decision was rendered |
| Triggered_By__c | Picklist | Yes | SYSTEM, UNDERWRITER, RE_EVALUATION |
| Decline_Reason__c | LongTextArea | No | Human-readable from Rule_Explanation__c |

**Immutability:** Enforced by `DecisionEventImmutability` Apex trigger. No UPDATE, no DELETE.

---

## Policy_Rule_Version__c

See `docs/BLUEPRINT.md` §B6 for complete 17-field schema.

---

## Indexing Strategy

| Object | Field | Index Type | Reason |
|--------|-------|-----------|--------|
| Evidence__c | Application__c | Master-Detail (auto) | Parent lookup |
| Decision_Event__c | Application__c | Master-Detail (auto) | Parent lookup |
| Extracted_Facts__c | Application__c | Custom Index | WHERE clause in FactAssemblerService |
| Extracted_Facts__c | Evidence__c | Custom Index | Join from evidence to facts |
| Policy_Rule_Version__c | Rule_Code__c | Unique External ID | Compound key resolution |
| Policy_Rule_Version__c | Is_Active__c + Effective_Date__c | Custom Index | Governing rule query |
