# Mortgage Approval Engine — Blueprint

> [!NOTE]
> **AI-Assisted Documentation**
> Portions of this document were drafted with the assistance of an AI language model.
> Content has not yet been fully reviewed — this is a working design reference, not a final specification.

---

## B1. Project Identity

| Field | Value |
|-------|-------|
| **Project** | Mortagate — Salesforce Community Mortgage Approval Engine |
| **Brand** | Veridact (Brand Kit v1.0.1 — Cream/Charcoal/Orange/Outfit, ADR-13) |
| **Platform** | Salesforce Experience Cloud + LWC + Apex + Flows |
| **Org** | orgfarm-156cb47730-dev-ed (Developer Edition) |
| **Alias** | mortagate-dev |
| **Owner** | Sabir Asheed (sasheed72@gmail.com) |
| **Memory** | allura-mortgage |

---

## B2. Design Principles

1. **Mobile-first** — 375px is the primary design surface. Desktop is the scale-up.
2. **One thing per screen** — Every portal view renders exactly one question, one status, or one action.
3. **Three states, not screens** — Empty (capture intent) → Active (feed + status) → Decision (outcome).
4. **No Salesforce chrome** — Experience Cloud skinned completely. Zero platform branding in borrower view.
5. **Append-only audit** — Decision_Event__c records are immutable. Enforced by Apex trigger, not convention.
6. **Rules are data, not code** — Policy rules stored as records, maintained by analysts, versioned automatically.
7. **Structured facts, not EAV** — Extracted_Facts__c uses typed fields per fact category. No lateral join pain.

---

## B3. User Journey — Borrower Onboarding (6 Screens)

### Screen 1: Welcome Gate
- One sentence: "Let's find out what you qualify for. Takes 8 minutes."
- One button: **Get Started**
- No login wall. No account creation. Progressive identity (email captured after Screen 2).
- LWC: `c-welcome-gate`

### Screen 2: Intent Capture (The Three Questions)
- Full-screen, one question at a time, slide-in/slide-out animation
- Q1: "Are you buying or refinancing?" (two buttons)
- Q2: "What's the approximate property value?" (slider + number input)
- Q3: "What's your annual income — ballpark is fine." (slider + number input)
- Each answer slides out, next slides in. Not a form. A conversation.
- LWC: `c-intent-capture`

### Screen 3: Soft Pre-Check
- Runs lightweight policy evaluation against income + property value only
- Shows preliminary band: "Based on what you've told us, you're likely in range for $X–$Y"
- No documents required. No Loan_Application__c record yet.
- Calls `PreFlightEvaluator.evaluate()` — a stateless Apex invocable
- CTA: "Ready to apply? Enter your email to continue."
- Email captured here → magic link sent → account created
- LWC: `c-pre-check-result`

### Screen 4: Evidence Queue (Document Upload)
- Shows ONE document at a time, not a checklist of 14
- "Upload your most recent pay stub." → "Got it. That's the hardest one."
- Drag-and-drop upload with progress indicator
- Extracted_Facts__c populates as each document clears
- Borrower never sees raw field names — human-readable labels only
- LWC: `c-evidence-queue`

### Screen 5: Decision Room (Timeline Feed)
- Pike's "Active state" — single panel with application snapshot + event feed
- Timeline renders Decision_Event__c records chronologically
- Events: "Application received", "Income verified", "Underwriting review started"
- Real-time updates via Platform Events (if feasible) or polling
- LWC: `c-decision-room`

### Screen 6: Outcome
- **Approved:** Amount, rate, CTA to schedule a call. Clean. Celebratory but not excessive.
- **Declined:** Never the word "denied." "We weren't able to approve this application at this time."
  - Specific reason from `Rule_Explanation__c`: "Your debt-to-income ratio of 48% exceeds our current threshold of 43%."
  - Next steps always provided
- LWC: `c-outcome-view`

---

## B4. Data Model — Entity Relationships

```
Loan_Application__c (1) ──→ (0..*) Evidence__c
Loan_Application__c (1) ──→ (1..*) Decision_Event__c  [append-only]
Evidence__c (1)          ──→ (0..*) Extracted_Facts__c
Decision_Event__c (*)    ──→ (1)   Policy_Rule_Version__c  [rule at decision time]
```

### Cardinality Rules
| Relationship | Min | Max | Constraint |
|---|---|---|---|
| Application → Evidence | 0 | unlimited | Can exist with zero (pre-check only) |
| Application → Decision Event | 1 | unlimited | At least one (initial evaluation) |
| Evidence → Extracted Facts | 0 | unlimited | Zero if extraction pending/failed |
| Decision Event → Rule Version | 1 | 1 | Must reference the governing version |

### Invariants
- Decision_Event__c: No UPDATE, no DELETE. Enforced by `DecisionEventImmutability` trigger.
- Policy_Rule_Version__c: Immutable after referenced by any Decision_Event__c. Enforced by trigger.
- Only ONE Policy_Rule_Version__c per Rule_Code__c can have Is_Active__c = true and no Expiration_Date__c.

---

## B5. Policy Rule Engine — Three-Layer Architecture

### Layer 1: Fact Assembly (`FactAssemblerService`)
- Queries Extracted_Facts__c for a given Loan_Application__c
- Builds an immutable `PolicyEvaluationContext` value object
- Only class allowed to query the database on behalf of the engine

### Layer 2: Rule Evaluation (`PolicyRuleEvaluator`)
- Pure function: `evaluate(ctx: PolicyEvaluationContext) → EvaluationResult`
- Loads governing rules by effective date + version number
- Walks each rule: compares fact value against operator + threshold
- Operators: GT, GTE, LT, LTE, EQ, BETWEEN, IN_LIST, NOT_IN_LIST
- Determines verdict: APPROVED | APPROVED_WITH_CONDITIONS | PENDING_REVIEW | HARD_DECLINED
- Zero database writes. Zero side effects. Fully unit-testable.

### Layer 3: Decision Commitment (`DecisionCommitService`)
- Receives EvaluationResult, creates Decision_Event__c record
- Populates Rule_Version__c lookup, Rule_Results_JSON__c (full receipt)
- Only class that writes. Called from Flow or invocable Apex — never from evaluator.

### Pre-Flight Evaluator (`PreFlightEvaluator`)
- Stateless invocable for Screen 3 soft check
- Signature: `evaluate(income: Decimal, propertyValue: Decimal, loanType: String) → PreFlightResult`
- Does NOT require Loan_Application__c record
- Runs subset of rules (INCOME + COLLATERAL categories only)
- Returns: eligibility band, preliminary DTI, preliminary LTV

---

## B6. Policy_Rule_Version__c Schema (17 Fields)

| Field | Type | Required | Purpose |
|-------|------|----------|---------|
| Rule_Code__c | Text(50) UNIQUE | Yes | Machine identifier (DTI_MAX, LTV_CONVENTIONAL) |
| Rule_Label__c | Text(255) | Yes | Human-readable name |
| Rule_Category__c | Picklist | Yes | INCOME, CREDIT, COLLATERAL, COMPLIANCE, FRAUD |
| Operator__c | Picklist | Yes | LT, LTE, GT, GTE, EQ, BETWEEN, IN_LIST, NOT_IN_LIST |
| Threshold_Value__c | Number(18,4) | No | Primary threshold |
| Threshold_High__c | Number(18,4) | No | For BETWEEN operator |
| Allowed_Values__c | LongTextArea | No | JSON array for IN_LIST |
| Fact_Field__c | Text(255) | Yes | API name on Extracted_Facts__c |
| Severity__c | Picklist | Yes | HARD_DECLINE, SOFT_DECLINE, WARNING, ADVISORY |
| Rule_Explanation__c | LongTextArea | Yes | Human-readable decline reason for borrower |
| Effective_Date__c | Date | Yes | When this version activates |
| Expiration_Date__c | Date | No | Null = still active. Auto-set on supersede. |
| Version_Number__c | Number(8,0) | Yes | Monotonic per Rule_Code__c |
| Is_Active__c | Checkbox | Yes | False = archived |
| Override_Permitted__c | Checkbox | No | Can underwriter override? |
| Override_Justification_Required__c | Checkbox | No | Justification mandatory on override? |
| Regulatory_Citation__c | Text(255) | No | e.g. "CFPB 12 CFR 1026.43(c)(2)" |
| Change_Justification__c | LongTextArea | No | Why this version was created |
| Supersedes__c | Lookup(Policy_Rule_Version__c) | No | Points to prior version |

---

## B7. Bulk Safety Contract

- Rules loaded ONCE outside loop (1 SOQL)
- Facts loaded in single bulk query (1 SOQL)
- Evaluation is pure in-memory — zero SOQL per application
- Decision_Event__c records bulk-inserted (1 DML)
- Total for N applications: 3 SOQL + 1 DML. Scales linearly.

---

## B8. UX Principles — Non-Negotiable

> **Visual identity:** Veridact Brand Kit v1.0.1 (ADR-13). Core palette: Cream `#F5F0E8` background, Charcoal `#1F1E1C` text, Orange `#E25D22` accent, Outfit Bold display font, Inter body font. See `veridactTokens.css` v2.0.0 and DESIGN-onboarding-ux.md § Visual Direction for full token spec.

1. **One thing per screen.** No tabs, sidebars, or related lists in borrower portal.
2. **Mobile-first.** 375px primary. Desktop scales up.
3. **No Salesforce chrome.** Experience Cloud fully skinned with Veridact brand.
4. **Progress always visible.** Four steps: Intent → Documents → Review → Decision.
5. **Every error is human.** "We need your Social Security Number to continue" — not "required field missing."
6. **Zero dead ends.** Every state has a forward path.
7. **Status always visible.** Never buried, never a separate tab.

---

## B9. Open Questions

| ID | Question | Owner | Status |
|----|----------|-------|--------|
| OQ-1 | Decision latency model: synchronous or async with status updates? | Brooks | Open |
| OQ-2 | Document extraction: Apex-native OCR, external AI callout, or manual entry? | Woz | Open |
| OQ-3 | Platform Events for real-time Decision Room updates — feasible in Dev Edition? | Hightower | Open |
| OQ-4 | FSC (Financial Services Cloud) availability in Developer Edition? | Sabir | Open |
