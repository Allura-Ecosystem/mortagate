# Audit Demo Runner

**Trigger:** After deploy, after rule changes, or on request.

---

## Prerequisites

- Org authenticated: `sf org display --target-org mortagate-de`
- Metadata deployed
- Seed rules loaded: `sf data import tree --files data/Policy_Rule_Version__c.json --target-org mortagate-de`

## Steps

1. Load demo data: `sf data import tree --files data/demo/Loan_Application__c.json --target-org mortagate-de`
2. Load facts: `sf data import tree --files data/demo/Extracted_Facts__c.json --target-org mortagate-de`
3. Run each scenario via `LoanDecisionService.decideOne(appId)`:

| Scenario | Persona | Expected Verdict | Key Rule |
|----------|---------|-----------------|----------|
| 1 | Karim Hassan | APPROVED | None (all pass) |
| 2 | Maria Santos | APPROVED_WITH_CONDITIONS | EMPLOYMENT_TENURE WARNING |
| 3 | James O'Brien | HARD_DECLINED | DTI_MAX (51.7% > 43%) |
| 4 | Sabir Asheed Sr. | HARD_DECLINED | DTI_MAX (43.1% > 43%, integration boundary) |
| 5 | Test Borrower | HARD_DECLINED | FICO_MIN (570 < 620) |

4. Verify adverse action notice generates for declined scenarios (3, 4, 5).
5. Run bulk safety: 200 applications, assert 3 SOQL + 1 DML.
6. Report: scenario | expected | actual | PASS/FAIL.

**Source:** Audit Demo README, demo-scenarios.json, ADR-12.
