# EP-1 Developer Context Bundle

> Quick-reference for any developer working on EP-1: Journey Orchestration + UX Hardening.
> Generated 2026-06-11 by Brooks.

---

## Data Model (Quick Reference)

```
Loan_Application__c (1) ──→ (0..*) Evidence__c
Loan_Application__c (1) ──→ (1..*) Decision_Event__c  [APPEND-ONLY]
Evidence__c (1)          ──→ (0..*) Extracted_Facts__c
Decision_Event__c (*)    ──→ (1)   Policy_Rule_Version__c
```

### Key Fields for EP-1

**Loan_Application__c** — Created at PreCheck→Evidence boundary:
- `Purpose__c` (PURCHASE | REFINANCE) — from intentCapture
- `Property_Value__c` (Currency) — from intentCapture
- `Annual_Income__c` (Currency) — from intentCapture
- `Current_Stage__c` (INTENT | DOCUMENTS | REVIEW | DECISION) — orchestrator updates this
- `Status__c` (DRAFT | SUBMITTED | IN_REVIEW | DECIDED | WITHDRAWN)
- `Borrower__c` (Lookup User) — community user after email capture

**Decision_Event__c** — Created by DecisionCommitService:
- `Outcome__c` (APPROVED | APPROVED_WITH_CONDITIONS | PENDING_REVIEW | HARD_DECLINED)
- `Triggered_By__c` (SYSTEM | UNDERWRITER | RE_EVALUATION)
- Immutable: DecisionEventImmutabilityTrigger blocks UPDATE/DELETE

---

## Apex Controller API

### PreFlightController (Screen 3 — soft pre-check)
```apex
@AuraEnabled(cacheable=true)
public static PreFlightResult getBand(Decimal income, Decimal propertyValue, String loanType)
// Returns: { eligibility, estimatedDTI, estimatedLTV, lowEstimate, highEstimate, guidance }
// Does NOT create a Loan_Application__c record (ADR-7)
```

### LoanDecisionService (Full evaluation)
```apex
public static void decide(Set<Id> applicationIds)
// 3 SOQL + 1 DML for N applications (ADR-5)
// Creates Decision_Event__c with full receipt
```

### DecisionCommitService
```apex
public static void commit(Id applicationId, EvaluationResult result)
// Only class that writes Decision_Event__c
```

---

## LWC Event Contract

| Source Component | Event Name | Detail | Consumer |
|-----------------|------------|--------|----------|
| welcomeGate | `start` | (none) | orchestrator |
| intentCapture | `intentcaptured` | `{ loanPurpose, propertyValue, annualIncome }` | orchestrator |
| preCheckResult | `emailcaptured` | `{ email }` | orchestrator |
| evidenceQueue | `evidencecomplete` | `{ applicationId }` | orchestrator |
| outcomeView | `schedulecall` | (none) | orchestrator |
| outcomeView | `nextsteps` | (none) | orchestrator |
| outcomeView | `viewreceipt` | `{ decisionEventId }` | orchestrator (opens VF page) |
| outcomeView | `viewnotice` | `{ decisionEventId }` | orchestrator (opens VF page) |

All events use `bubbles: true, composed: true`.

---

## Brand Tokens (v2.0.0 — Figma Kit v1.0.1, ADR-13)

| Token | Value | Usage |
|-------|-------|-------|
| `--veridact-bg` / `--veridact-indigo-depth` | `#F5F0E8` (Cream) | All screen backgrounds |
| `--veridact-fg` / `--veridact-white` | `#1F1E1C` (Charcoal) | Primary text |
| `--veridact-fg-muted` / `--veridact-white-60` | `rgba(31,30,28,0.5)` | Secondary text |
| `--veridact-accent` / `--veridact-proof-amber` | `#E25D22` (Orange) | CTAs, accent bar |
| `--veridact-font-display` | `'Outfit', 'Inter', sans-serif` | Headlines, tagline, verdict |
| `--veridact-font-body` | `'Inter', sans-serif` | Everything else |
| `--veridact-approved` | `#16734a` | Approved chip bg |
| `--veridact-conditions` | `#E25D22` | Conditions chip bg |
| `--veridact-review` | `#345182` | Review chip bg |
| `--veridact-declined` | `#8a3324` | Declined chip bg |

**Key WCAG constraint:** Orange on Cream is 3.18:1 — valid for large text only (≥18pt or ≥14pt bold). Use Charcoal for all body text.

---

## Testing Patterns

### Jest (LWC)

Follow existing patterns in `intentCapture.test.js` and `outcomeView.test.js`:

```javascript
import { createElement } from 'lwc';
import MyComponent from 'c/myComponent';

describe('c-my-component', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
    });

    it('renders with correct title', () => {
        const element = createElement('c-my-component', { is: MyComponent });
        document.body.appendChild(element);
        const heading = element.shadowRoot.querySelector('h1');
        expect(heading.textContent).toBe('Expected Title');
    });

    it('dispatches event on button click', () => {
        const element = createElement('c-my-component', { is: MyComponent });
        const handler = jest.fn();
        element.addEventListener('myevent', handler);
        document.body.appendChild(element);

        const button = element.shadowRoot.querySelector('button');
        button.click();

        expect(handler).toHaveBeenCalled();
    });
});
```

### Apex
- Bulk-safe at 200 records: `LoanDecisionServiceTest.bulk_200Applications_withinGovernorLimits`
- Governor limit assertion: `soqlUsed <= 3, dmlUsed <= 1`
- Use `PolicyEngineTestFactory` for test data construction

---

## Governor Limit Budget

| Operation | SOQL | DML | Scales With |
|-----------|------|-----|-------------|
| FactAssemblerService.assemble() | 1 | 0 | N applications (batched) |
| PolicyRuleEvaluator.evaluate() | 1 (rules) | 0 | Pure in-memory |
| DecisionCommitService.commit() | 1 (lookup) | 1 | N applications (bulk insert) |
| **Total per invocation** | **3** | **1** | **Linear in N** |

---

## Architectural Invariants (Never Violate)

1. Decision_Event__c is append-only — never UPDATE or DELETE (ADR-1)
2. PolicyRuleEvaluator has zero SOQL and zero DML — pure function (ADR-5)
3. Pre-check uses the same kernel as full decision (ADR-7)
4. No pre-filled default values in intake forms (ADR-8)
5. Semantic colors are chip backgrounds, not text (ADR-9)
6. Rules are data in Policy_Rule_Version__c, not hardcoded thresholds (ADR-4)
7. 3 SOQL + 1 DML for N applications — proven at 200 records (B7)

---

## Story Dependency Graph

```
US-1.0 (Brand Migration) ─────────────────────────┐
                                                    │
US-1.3 (Jest Tests) ── [parallel, no deps] ────────┤
                                                    │
US-1.1 (Orchestrator) ── depends on US-1.0 ────────┤
    │                                               │
    ├── US-1.2 (Progress Indicator) ── deps: 1.1    │
    ├── US-1.4 (Mobile 375px) ── deps: 1.0, 1.1    │
    ├── US-1.5 (Chrome Removal) ── deps: 1.0        │
    └── US-1.6 (Screen Flow) ── deps: 1.1           │
                                                    │
US-1.7 (HITL Flow) ── [independent] ───────────────┘
```

**Critical path:** US-1.0 → US-1.1 → US-1.6
**Parallel track:** US-1.3 + US-1.7 (can start immediately)
