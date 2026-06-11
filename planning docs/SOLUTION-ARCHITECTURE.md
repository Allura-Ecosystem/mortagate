# SOLUTION ARCHITECTURE

> [!NOTE]
> **AI-Assisted Documentation**
> Portions of this document were drafted with the assistance of an AI language model.

---

## 1. System Context

Mortagate is a Salesforce Experience Cloud application that lets a borrower self-serve a mortgage pre-qualification and application, and renders an immutable, auditable decision. The brand is **Veridact** — "Every decision has a receipt." That tagline is not marketing; it is the architecture (ADR-1).

```
        Borrower (mobile-first, 375px)
                │
        ┌───────▼─────────┐     Experience Cloud (Veridact-skinned, zero SF chrome)
        │  6 LWC screens   │
        └───────┬─────────┘
                │ @AuraEnabled / CustomEvent
        ┌───────▼──────────────────────────────────────────┐
        │              APEX KERNEL (this repo)              │
        │  FactAssembler → PolicyRuleEvaluator → Commit     │
        │  PreFlightEvaluator (stateless soft check)        │
        └───────┬──────────────────────────────────────────┘
                │ SOQL / DML
        ┌───────▼──────────────────────────────────────────┐
        │  Loan_Application__c · Evidence__c ·               │
        │  Extracted_Facts__c · Decision_Event__c [append]   │
        │  Policy_Rule_Version__c (rules-as-data)            │
        └───────────────────────────────────────────────────┘
```

## 2. Layered View

| Layer | Components | Responsibility | Constraint |
|-------|-----------|----------------|-----------|
| **Presentation** | `welcomeGate`, `intentCapture`, `preCheckResult`, `evidenceQueue`, `decisionRoom`, `outcomeView` | One thing per screen; brand-enforced; accessible; reduced-motion aware | No business logic; talks to Apex via controllers/events |
| **Application** | `LoanDecisionService`, `PreFlightController` | Orchestration, Flow/LWC adapters | Thin; no rule logic |
| **Domain (kernel)** | `PolicyRuleEvaluator`, value objects | Pure evaluation | Zero SOQL, zero DML |
| **Data access** | `FactAssemblerService` (read), `DecisionCommitService` (write) | All persistence | The only classes touching the DB |
| **Persistence** | 5 custom objects + immutability trigger | State + audit | Decision events append-only |

## 3. Key Flows

**Pre-check (no account):** `intentCapture` → `PreFlightController.getBand` → `PreFlightEvaluator` → band on `preCheckResult` → email capture. No `Loan_Application__c` created (ADR-7).

**Full decision:** Flow/Apex → `LoanDecisionService.decide(Set<Id>)` → assemble facts + load governing rules (3 SOQL) → pure evaluate per app (0 SOQL/DML) → commit one `Decision_Event__c` each (1 DML) → `outcomeView` renders verdict + reason.

## 4. Cross-Cutting Concerns

- **Bulk safety:** 3 SOQL + 1 DML for N applications, independent of N. Proven at 200 records (`LoanDecisionServiceTest`).
- **Auditability:** `Rule_Results_JSON__c` stores the full per-rule receipt; the governing `Policy_Rule_Version__c` is referenced by FK; the record is immutable.
- **Accessibility:** WCAG 2.1 AA; semantic colors as contrast-verified chips (ADR-9); focus management and `prefers-reduced-motion` honored.
- **Security:** `with sharing` on all service classes; community guest/borrower context respected.

## 5. Environments & Gates

| Gate | Command | Status |
|------|---------|--------|
| Org auth | `sf org login web --alias mortagate-de` | **Pending (R-1)** |
| Deploy | `sf project deploy start -o mortagate-de` | Pending |
| Apex tests | `sf apex run test -o mortagate-de -l RunLocalTests` | Pending |
| LWC tests | `npm run test:unit` | **Green (6/6)** |

## 6. Traceability

Requirements → components are tracked in `docs/REQUIREMENTS-MATRIX.md`. Decisions and risks in `docs/RISKS-AND-DECISIONS.md`. Data contracts in `docs/DATA-DICTIONARY.md`. Component specs in `docs/DESIGN-onboarding-ux.md` and `docs/DESIGN-policy-engine.md`.
