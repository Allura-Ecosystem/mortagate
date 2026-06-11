# Audit Demo — Veridact Mortgage Approval Engine

> **AI-Assisted Documentation**
> Portions of this document were drafted with the assistance of an AI language model.

## Purpose

This demo proves the Veridact policy engine catches drift between practitioner
guidelines and system thresholds. It walks through 5 scenarios using real
Kaggle-sourced borrower data transformed into Salesforce records.

The key moment: a borrower at 43.1% DTI that a practitioner's 45% guideline
would approve, but the system's 43% CFPB-backed threshold catches. That is
the integration boundary made visible.

---

## Prerequisites

1. Org authenticated: `sf org display --target-org mortagate-de`
2. Metadata deployed: `sf project deploy start --source-dir force-app --target-org mortagate-de`
3. Seed rules loaded: `sf data import tree --files data/Policy_Rule_Version__c.json --target-org mortagate-de`
4. Demo data loaded: `sf data import tree --files data/demo/Loan_Application__c.json --target-org mortagate-de`
5. Facts loaded: `sf data import tree --files data/demo/Extracted_Facts__c.json --target-org mortagate-de`

---

## Scenario 1: Clean Approval — Karim Hassan

**Profile:** FICO 727, DTI 33.1%, 10.5 years employed, $97,803 income
**Expected verdict:** APPROVED
**Rules that fire:** None (all pass)

### Run
```apex
// Execute in Developer Console or via sf apex run
Id appId = [SELECT Id FROM Loan_Application__c
            WHERE Annual_Income__c >= 80000
            ORDER BY CreatedDate DESC LIMIT 1].Id;
LoanDecisionService.decideOne(appId);
```

### Verify
```sql
SELECT Outcome__c, Evaluated_Rule_Count__c, Hard_Decline_Count__c,
       Rule_Results_JSON__c
FROM Decision_Event__c
WHERE Application__c = :appId
ORDER BY Decision_Timestamp__c DESC LIMIT 1
```

**Expected:** `Outcome__c = 'APPROVED'`, `Hard_Decline_Count__c = 0`

---

## Scenario 2: Conditional — Maria Santos

**Profile:** FICO 704, DTI 8.6%, 1.2 years employed, $55,961 income
**Expected verdict:** APPROVED_WITH_CONDITIONS
**Rules that fire:** EMPLOYMENT_TENURE (WARNING — under 24 months)

### Verify
**Expected:** `Outcome__c = 'APPROVED_WITH_CONDITIONS'`, Rule_Results_JSON__c
shows EMPLOYMENT_TENURE with outcome FAIL and severity WARNING.

---

## Scenario 3: Hard Decline (DTI) — James O'Brien

**Profile:** FICO 688, DTI at 51.7% (exceeds 43% threshold), $80,393 income
**Expected verdict:** HARD_DECLINED
**Rules that fire:** DTI_MAX (HARD_DECLINE)

### Verify
**Expected:** `Outcome__c = 'HARD_DECLINED'`, `Hard_Decline_Count__c >= 1`.
Decline_Reason__c contains: "Your debt-to-income ratio exceeds our current
threshold of 43%."

### Adverse Action Notice
```
/apex/AdverseActionNotice?id=<DecisionEventId>
```
Verify: specific reason from Rule_Explanation__c, ECOA section 701(a) notice,
creditor name/address from Adverse_Action_Config__mdt.

---

## Scenario 4: Integration Boundary — Sabir Asheed Sr.

**Profile:** FICO 698, DTI at 43.1% — between dad's 45% guideline and system's 43%
**Expected verdict:** HARD_DECLINED
**Why this matters:** This borrower would pass a manual underwriter using
the practitioner's 45% threshold. The system catches it at 43% (CFPB QM rule).
The audit query below surfaces this exact drift.

### The Audit Query
```sql
SELECT a.Name, ef.DTI_Ratio__c, de.Outcome__c,
       de.Rule_Results_JSON__c, de.Decision_Timestamp__c
FROM Decision_Event__c de
JOIN Loan_Application__c a ON de.Application__c = a.Id
JOIN Extracted_Facts__c ef ON ef.Application__c = a.Id
WHERE de.Outcome__c = 'HARD_DECLINED'
  AND ef.DTI_Ratio__c > 43.0
  AND ef.DTI_Ratio__c <= 45.0
ORDER BY de.Decision_Timestamp__c DESC
```

**This is the sentence the Wells Fargo architect remembers:**
> "Here is a decision our kernel would never have missed.
> Here is the gap between your guideline and regulation, made queryable."

---

## Scenario 5: FICO Decline — Test Borrower

**Profile:** FICO 570, DTI 3.5%, 13.4 years employed, $32,015 income
**Expected verdict:** HARD_DECLINED
**Rules that fire:** FICO_MIN (HARD_DECLINE — below 620 minimum)

---

## Bulk Safety Verification

200 applications processed in a single transaction.

```apex
Set<Id> appIds = new Map<Id, Loan_Application__c>(
    [SELECT Id FROM Loan_Application__c LIMIT 200]
).keySet();
List<Decision_Event__c> events = LoanDecisionService.decide(appIds);
System.assertEquals(200, events.size());
```

Governor limits: 3 SOQL + 1 DML for 200 applications. Proven by
`LoanDecisionServiceTest.bulk_200Applications_withinGovernorLimits`.

---

## Rule Set Summary (7 rules, post-reconciliation)

| Rule | Category | Threshold | Severity | Source |
|------|----------|-----------|----------|--------|
| DTI_MAX | INCOME | <= 43% | HARD_DECLINE | CFPB 12 CFR 1026.43(c)(2) |
| FICO_MIN | CREDIT | >= 620 | HARD_DECLINE | FNMA Selling Guide B3-5.1 |
| LTV_CONVENTIONAL | COLLATERAL | <= 97% | SOFT_DECLINE | FNMA Selling Guide B5-1 |
| INCOME_MIN | INCOME | >= $25,000 | SOFT_DECLINE | Internal |
| EMPLOYMENT_TENURE | INCOME | >= 24 months | WARNING | Internal |
| ADDRESS_TENURE_MIN | RESIDENCY | >= 12 months | SOFT_DECLINE | ADR-12 (practitioner) |
| LTV_PMI_ADVISORY | COLLATERAL | <= 80% | ADVISORY | Internal |

---

## What This Proves

1. **Fact assembly** — Extracted_Facts__c queried in bulk (1 SOQL)
2. **Rule evaluation** — 7 versioned rules evaluated per application (0 SOQL)
3. **Verdict determination** — Worst-wins precedence (ADR-2)
4. **Immutable audit** — Decision_Event__c is append-only (ADR-1)
5. **Full receipt** — Rule_Results_JSON__c stores per-rule outcomes
6. **Adverse action** — Specific reasons, ECOA notice, FCRA block
7. **Integration boundary** — System catches what guidelines miss
8. **Bulk safety** — 3 SOQL + 1 DML for N applications (ADR-5)
