# DESIGN: KYC / OFAC / SSN Handling (Production Gate R-8)

> [!NOTE]
> **AI-Assisted Documentation**
> Portions of this document were drafted with the assistance of an AI language model.

> [!WARNING]
> **PROPOSAL — not deployed.** This is a planning artifact for human (HITL) review and
> sign-off. No SObject metadata, Apex, Flow, or permission set described here has been
> created or deployed. It closes the *design* half of Risk **R-8**; it does not clear the
> gate. Do not originate a real loan against this model until a human approves the schema
> and a compliance reviewer confirms the SSN-tokenization and sanctions-screening
> approach for the target jurisdiction.

Author: Knuth (data architect). Date: 2026-06-19. Branch: `feat/veridact-v1-demo`.
Reference risk: **R-8** (RISKS-AND-DECISIONS.md). Reference schema: DATA-DICTIONARY.md.

---

## 1. Why this exists

Risk **R-8** states the production-blocking gap plainly: the data model carries no Social
Security Number, no identity-verification status, and no OFAC / sanctions-screening
result. The Confidence Caps section of RISKS-AND-DECISIONS.md gates **Production Lending**
on R-8 clearing. These are non-negotiable preconditions for any compliant U.S. mortgage
origination:

- **KYC / CIP** — the Customer Identification Program rule (31 CFR 1020.220, BSA) requires
  a verified identity before extending credit.
- **OFAC sanctions screening** — 31 CFR Part 501 et seq. prohibits transacting with
  parties on the SDN / sanctions lists. A match is a hard stop, regardless of
  creditworthiness.
- **SSN** — required for the CIP identity record and for the consumer-report pull, but it
  is the single highest-blast-radius PII element in the system.

This design adds the schema to record these facts **without** weakening the two invariants
the product is built on: append-only audit (ADR-1) and a pure, deterministic decision
kernel (ADR-5).

---

## 2. Design principles (carried from existing ADRs)

1. **Append-only for screening events.** A sanctions screen is a receipt, not a mutable
   status. It follows the same pattern as `Audit_Event__c` / `Audit_Receipt__c` /
   `Agent_Action_Log__c`: validation rule blocks UPDATE, before-delete trigger blocks
   DELETE (Immutability Rules Summary, DATA-DICTIONARY.md §3).
2. **KYC/OFAC are gating preconditions, OUTSIDE the kernel** (see §5). The pure
   `PolicyRuleEvaluator` (ADR-5) decides *loan policy*. Identity and sanctions are checked
   *before* the kernel runs and can block independently of any policy outcome.
3. **Never store raw SSN.** External tokenization only; store a token reference plus
   `Last_Four__c` (see §4).
4. **Structured, typed facts — not EAV** (Philosophy #4 / Borrower_Snapshot pattern).

---

## 3. New object: `Sanctions_Screening__c` [APPEND-ONLY]

**Label:** Sanctions Screening
**Plural:** Sanctions Screenings
**Name field:** AutoNumber, display format `SS-{000000}` (matches `AE-`/`AR-`/`AL-` style).
**Description:** Immutable record of a single OFAC / sanctions screening event against a
party on a loan. Append-only — never updated, never deleted.

### 3.1 Parent decision: child of `Loan__c` (not `Audit_Case__c`)

**Decision: parent on `Loan__c`.**

A sanctions screen is a fact about the **borrower/party on the loan**, established at
origination — it exists whether or not the loan is ever sampled for audit. An
`Audit_Case__c` is created only when a loan is selected for QC review (it is a *Lookup*,
not Master-Detail, precisely because "a loan can exist without being audited" — Open
Design Decision #1, DATA-DICTIONARY.md §8). If screening hung off `Audit_Case__c`, loans
that were never audited would carry no screening record, which is exactly backwards: every
originated loan must be screened; only some are audited.

The audit side reaches the screening history through the existing `Loan__c` ←
`Audit_Case__c` lookup, so the auditor still sees it. This mirrors how `Loan__c` already
holds the origination-time snapshot fields (`DTI_At_Approval__c`, `FICO_At_Approval__c`)
that the audit reads but does not own.

Relationship: **Lookup** to `Loan__c` (not Master-Detail), with
`deleteConstraint = Restrict`, consistent with the append-only lookups on
`Audit_Event__c`. Restrict is required: you cannot cascade-delete an immutable screening
receipt.

### 3.2 Field-level table

| Field API Name | Type | Length / Scale | Required | Append-only? | Description | Picklist Values |
|----------------|------|----------------|----------|--------------|-------------|-----------------|
| `Name` | AutoNumber (`SS-{000000}`) | — | Auto | n/a | Screening identifier | — |
| `Loan__c` | Lookup(`Loan__c`) | — | Yes | Yes (write-once) | Parent loan. `deleteConstraint=Restrict`, `relationshipName=Sanctions_Screenings` | — |
| `Screened_Name__c` | Text | 255 | Yes | Yes | Exact name string submitted to the screening provider | — |
| `Screened_Party_Role__c` | Picklist | — | Yes | Yes | Which party was screened | `Borrower`, `Co_Borrower`, `Guarantor`, `Other` |
| `List_Source__c` | Picklist | — | Yes | Yes | Which sanctions list set | `OFAC_SDN`, `OFAC_Consolidated`, `EU_Consolidated`, `UN_Consolidated`, `Vendor_Aggregate` |
| `List_Version__c` | Text | 50 | Yes | Yes | Provider list version / publish date (e.g. `OFAC-SDN-2026-06-18`) — pins exactly which list governed this screen | — |
| `Match_Score__c` | Number | (5,2) | No | Yes | Provider fuzzy-match confidence 0.00–100.00; null if provider returned no candidate | — |
| `Disposition__c` | Picklist | — | Yes | Yes | Outcome of the screen | `No_Match`, `Potential_Match`, `Confirmed_Match`, `False_Positive_Cleared`, `Pending_Review` |
| `Disposition_Rationale__c` | LongTextArea | 32000 | No | Yes | Analyst note explaining a clear/confirm decision (required by validation rule when disposition is `False_Positive_Cleared` or `Confirmed_Match`) | — |
| `Provider__c` | Text | 100 | No | Yes | Screening vendor / service name | — |
| `Provider_Reference_Id__c` | Text | 100 | No | Yes | Vendor-side screening transaction ID for traceability | — |
| `Screened_By__c` | Lookup(User) | — | Yes | Yes | User or service account that ran/recorded the screen | — |
| `Screened_At__c` | DateTime | — | Yes | Yes | When the screen was executed | — |

**Immutability enforcement (matches DATA-DICTIONARY.md §3):**
- Validation rule `Prevent_Edit_After_Creation`: `errorConditionFormula = NOT(ISNEW())`,
  identical to the `Audit_Event__c` rule.
- Before-delete trigger `SanctionsScreeningPreventDelete` (one-for-one with
  `AuditEventPreventDelete.trigger`): `evt.addError('Sanctions Screenings are
  append-only. Records cannot be deleted.')`.

**A changed disposition is a NEW record**, never an edit — same discipline as
`Decision_Event__c` re-evaluation (ADR-1). The newest `Screened_At__c` for a given
`Loan__c` + `Screened_Party_Role__c` is the current disposition; the chain is the audit
trail.

**Indexing (extends DATA-DICTIONARY.md §4):** custom index on `Loan__c` (parent join) and
on `Screened_At__c` (chronological "latest screen" queries).

---

## 4. SSN handling — external tokenization, never raw

**Decision: Veridact never stores a raw SSN in Salesforce.** The SSN is tokenized by an
**external** tokenization/vault service at the point of capture; Salesforce receives back
only an opaque token plus the last four digits.

### 4.1 Where the SSN reference lives

Add to `Loan__c` (the origination-side party record), **not** to `Borrower_Snapshot__c`
(an audit reconstruction should never re-hold raw PII):

| Field API Name | Type | Length | Required | Append-only? | Description |
|----------------|------|--------|----------|--------------|-------------|
| `SSN_Token__c` | Text (Encrypted recommended) | 255 | No | No | Opaque token returned by the external SSN vault. Not the SSN. Meaningless without the vault. |
| `SSN_Last_Four__c` | Text | 4 | No | No | Last four digits only, for display/verification (e.g. `••• •• 1234`) |
| `SSN_Tokenized_At__c` | DateTime | — | No | No | When tokenization occurred |
| `SSN_Vault_Provider__c` | Text | 100 | No | No | Which external vault holds the SSN (for de-tokenization routing) |

### 4.2 Why tokenize externally (justification)

- **Blast-radius reduction.** If Salesforce data is ever exfiltrated (export, misconfigured
  report, compromised integration user), a token + last-four cannot be reversed to an SSN
  without separately compromising the external vault. The most sensitive PII element never
  rests in the CRM at all. This is the single largest reduction in breach impact available
  to us.
- **Compliance scope.** Keeping raw SSNs out of Salesforce shrinks the
  GLBA / state-data-breach-law scope of the org and avoids relying on Salesforce Shield
  Platform Encryption (which is a licensed add-on of unknown availability — cf. R-6 FSC
  uncertainty) as the *only* control. Tokenization is defense-in-depth, not a single point.
- **Right-to-delete / retention.** Purging an SSN becomes a single vault operation; the
  CRM token can remain in immutable audit records without holding recoverable PII —
  reconciling the append-only invariant (ADR-1) with PII deletion duties.

`SSN_Last_Four__c` is deliberately *not* append-only and *not* on any immutable object, so
a correction (mistyped capture) does not require a new immutable record. Last-four alone is
not a reportable SSN.

> [!WARNING]
> No raw SSN, and no de-tokenized SSN, may ever be written to `Audit_Event__c`,
> `Audit_Receipt__c`, `Agent_Action_Log__c`, `Sanctions_Screening__c`, or any
> `Payload__c` / snapshot field. Agentforce actions (which run SOQL as the user) must
> never receive or echo a de-tokenized SSN.

---

## 5. KYC gating sits OUTSIDE the policy kernel

### 5.1 New field: `Identity_Verification_Status__c` on `Loan__c`

| Field API Name | Type | Required | Append-only? | Description | Picklist Values |
|----------------|------|----------|--------------|-------------|-----------------|
| `Identity_Verification_Status__c` | Picklist | Yes | No | KYC / CIP identity verification state for the loan's primary party | `Not_Started`, `Pending`, `Verified`, `Failed`, `Manual_Review` |
| `Identity_Verified_At__c` | DateTime | No | No | When identity reached `Verified` | — |
| `KYC_Provider__c` | Text(100) | No | No | Identity-verification vendor | — |

(The append-only *history* of identity checks, if a provider returns multiple attempts,
can be modeled as a sibling append-only object in a follow-up; for R-8 the current status
on `Loan__c` plus the immutable `Sanctions_Screening__c` chain is sufficient. Flagged as
Open Question OQ-R8-3.)

### 5.2 The gating precondition pattern (architectural core of R-8)

The pure kernel (`PolicyRuleEvaluator`, ADR-5) decides **loan policy** — DTI, FICO, LTV,
tenure. It must stay pure (zero SOQL, zero DML) and order-independent (ADR-6). KYC and
OFAC are **not** policy rules and must **not** be modeled as `Policy_Rule__c` records.
They are **preconditions** evaluated *before* the kernel runs:

```
  Origination orchestrator (LoanDecisionService — thin adapter, ADR-5)
        │
        ▼
  GATING PRECONDITIONS  (outside the pure kernel)
    ├─ Identity_Verification_Status__c == Verified ?   ──no──▶ BLOCK: KYC_INCOMPLETE
    └─ latest Sanctions_Screening__c.Disposition__c
         ∈ {No_Match, False_Positive_Cleared} ?        ──no──▶ BLOCK: SANCTIONS_HOLD
        │ (both pass)
        ▼
  PURE KERNEL  (PolicyRuleEvaluator — DTI / FICO / LTV / tenure)  ──▶ verdict
```

**Key property:** a `Confirmed_Match` (or any uncleared `Potential_Match` /
`Pending_Review`) **blocks the loan regardless of the policy verdict.** A borrower could
have a perfect 760 FICO and 20% DTI and still be blocked by a sanctions hit — and
conversely, a clean screen never *improves* a policy decline. The two axes are orthogonal
by design:

- This keeps the kernel exhaustively unit-testable without an org (ADR-5) — it never needs
  to know about sanctions.
- It avoids the "worst-wins" verdict (ADR-2) ever collapsing a sanctions hit into a
  *policy* outcome like `HARD_DECLINED`. A sanctions block is categorically different from
  a creditworthiness decline and must be recorded and explained as such (it is **not** an
  adverse-action-by-creditworthiness event under ECOA, and must not be papered over with a
  DTI explanation).
- The block is recorded append-only: a `Decision_Event__c` / `Audit_Event__c` with a
  precondition reason, plus the governing `Sanctions_Screening__c` record it points to.

> [!NOTE]
> A missing screen is **not** a pass. Where ADR-3 makes a *missing borrower fact*
> INDETERMINATE (never a decline) for progressive onboarding, a missing **sanctions
> screen** must BLOCK origination — absence of proof of clearance is not clearance. This
> asymmetry is intentional and is called out as OQ-R8-2 for human confirmation.

---

## 6. Field summary (consolidated)

| Object | New Field | Type | Append-only? |
|--------|-----------|------|--------------|
| `Sanctions_Screening__c` (NEW) | all fields (§3.2) | — | Yes (object-level) |
| `Loan__c` | `SSN_Token__c` | Text(255), encrypted rec. | No |
| `Loan__c` | `SSN_Last_Four__c` | Text(4) | No |
| `Loan__c` | `SSN_Tokenized_At__c` | DateTime | No |
| `Loan__c` | `SSN_Vault_Provider__c` | Text(100) | No |
| `Loan__c` | `Identity_Verification_Status__c` | Picklist | No |
| `Loan__c` | `Identity_Verified_At__c` | DateTime | No |
| `Loan__c` | `KYC_Provider__c` | Text(100) | No |

New trigger: `SanctionsScreeningPreventDelete` (before delete).
New validation rule: `Sanctions_Screening__c.Prevent_Edit_After_Creation`.

---

## 7. Open questions / decisions needing human sign-off

| # | Question | Knuth's recommendation | Owner |
|---|----------|------------------------|-------|
| OQ-R8-1 | Which external SSN tokenization vault? (Skyflow / Very Good Security / Salesforce Shield-only / in-house) | External vault preferred over Shield-only for blast-radius reduction (§4.2). Needs vendor + security review. | Owner + Security |
| OQ-R8-2 | Is "no sanctions screen on file" a hard BLOCK to origination? | Yes — absence ≠ clearance (§5.2). Confirm. | Compliance |
| OQ-R8-3 | Model identity-check *attempts* as a separate append-only object, or keep status-on-`Loan__c` only? | Status-on-`Loan__c` for R-8; append-only `Identity_Check__c` deferrable to P3. | Architect (Brooks) |
| OQ-R8-4 | Match-score threshold for auto `No_Match` vs `Potential_Match` routing — schema stores the score; who owns the cutoff? | Threshold is config-as-data (mirror `Adverse_Action_Config__mdt`), not hardcoded. | Compliance |
| OQ-R8-5 | Should `Sanctions_Screening__c` parent on `Loan__c` survive the dual-kernel `Loan_Application__c` vs `Loan__c` split? | Parent on `Loan__c` (audit-relevant snapshot side) per §3.1; confirm origination writes there. | Architect (Brooks) |
| OQ-R8-6 | Retention/purge policy for `SSN_Token__c` in immutable records vs vault deletion duty | Token may persist in audit; raw SSN purged at vault. Needs legal retention schedule. | Compliance + Legal |
| OQ-R8-7 | Encrypt `SSN_Token__c` at rest in Salesforce even though it is already a token? | Yes, defense-in-depth (Encrypted Text or Shield if licensed — cf. R-6). | Security |

**Approval required from:** Owner (Sabir), Architect (Brooks — owns the kernel boundary in
§5), and a compliance reviewer (KYC/OFAC sufficiency, retention). This document does not
self-certify; it provides the schema and the cited rationale so reviewers can verify.

---

## 8. Effect on R-8 when approved + built

Clearing R-8 requires: (a) this schema deployed, (b) the gating-precondition code wired
into the origination orchestrator outside the kernel, (c) external tokenization integrated,
and (d) compliance sign-off (parallel to the R-7 counsel-sign-off pattern). This document
closes the **design** step only. Per the Confidence Caps, Production Lending stays capped
until all four land and a human approves.

---

## 9. Addendum — Slice 1 build (schema only) — 2026-07-03

> [!NOTE]
> **AI-Assisted Documentation.** This addendum records what was *actually built and
> deployed* in slice 1 (schema only), and reconciles the original §3–§6 design vocabulary
> (drafted 2026-06-19) with the **active audit-side three-zone schema**. Schema is the
> contract; where this addendum and §3–§6 differ, **this addendum governs** (schema > docs).

### 9.1 Active-schema mapping (design draft → active objects)

The design was drafted before the audit-side pivot settled. The active parent is `Loan__c`
(the audit-relevant snapshot object, `LN-{000000}`), **not** the legacy origination
`Loan_Application__c`. ADR-24 already ratified `Sanctions_Screening__c` parenting on
`Loan__c` (OQ-R8-5), so the §3.1 decision carries over unchanged.

| Design draft reference | Active object/field built | Note |
|------------------------|---------------------------|------|
| `Loan__c` (SSN + identity host, §4.1/§5.1) | `Loan__c` (audit-side, active) | Same object; confirmed as the active parent |
| `Borrower_Snapshot__c` "never re-hold raw PII" (§4.1) | unchanged | Still holds no SSN; slice added nothing there |
| `Loan_Application__c` (origination, dual-kernel) | not modified | Origination-side object retained; SSN lives on `Loan__c` per ADR-24 |

### 9.2 Field-vocabulary reconciliation (ratified slim set vs §3.2/§5.1 draft)

Slice 1 built the **ratified slim vocabulary** for `Sanctions_Screening__c` (per the loop
item #6 instruction), which differs from the fuller §3.2 draft. Deployed fields:

| §3.2 / §5.1 draft field | Built field (active) | Disposition |
|-------------------------|----------------------|-------------|
| `Disposition__c` (`No_Match`/`Potential_Match`/`Confirmed_Match`/`False_Positive_Cleared`/`Pending_Review`) | `Result__c` (`Clear`/`Potential_Match`/`Confirmed_Match`/`Pending_Review`) | RENAMED + narrowed. `Clear` replaces `No_Match`; `False_Positive_Cleared` folded into `Clear` (the current-state vocabulary the slice-2 gating service compares against) |
| `List_Source__c` (5 values incl. EU/UN/Vendor) | `List_Source__c` (`OFAC_SDN`, `Consolidated`) | Narrowed to the two in-scope list sets |
| `Disposition_Rationale__c` + `Match_Score__c` | `Match_Details__c` (LongTextArea) | Merged into one free-text detail field for slice 1 |
| `Screened_By__c` (Lookup User, required) | `Adjudicated_By__c` (Lookup User, optional) | Re-scoped to the adjudicator; optional (auto-cleared screens have none) |
| `Screened_Name__c`, `Screened_Party_Role__c`, `Provider__c`, `Provider_Reference_Id__c` | not built | Deferred; not in the slice-1 ratified set |
| `List_Version__c`, `Screened_At__c`, `Loan__c` | built as designed | `List_Version__c` Text(50), `Screened_At__c` DateTime, `Loan__c` Lookup required `Restrict` |
| `Identity_Verification_Status__c` (§5.1) | built (`Not_Started`/`Pending`/`Verified`/`Failed`/`Manual_Review`, default `Not_Started`, required) | Full design vocabulary retained; `SSN_Tokenized_At__c`/`SSN_Vault_Provider__c`/`Identity_Verified_At__c`/`KYC_Provider__c` deferred (not in slice-1 set) |

### 9.3 What slice 1 built and deployed (org `mortagate-de`)

- **New object** `Sanctions_Screening__c` [APPEND-ONLY], AutoNumber `SS-{000000}`, with fields
  `Loan__c` (Lookup→`Loan__c`, required, `Restrict`), `Result__c`, `List_Source__c`,
  `List_Version__c`, `Match_Details__c`, `Adjudicated_By__c` (Lookup→User, `SetNull`),
  `Screened_At__c`.
- **Append-only guards:** validation rule `Prevent_Edit_After_Creation` (`NOT(ISNEW())`) +
  trigger `SanctionsScreeningPreventDelete` (before update + before delete, `addError`,
  mirroring `AgentActionLogPreventDelete`).
- **`Loan__c` additive fields:** `SSN_Token__c` Text(255), `SSN_Last_Four__c` Text(4),
  `Identity_Verification_Status__c` restricted picklist.
- **Permission set** `Veridact_KYC_Officer_Access` (need-to-know isolation): screening object
  (create+read only) + `Loan__c` SSN fields FLS. **Not** added to
  `Veridact_Mortgage_Engine_Access`.
- **Test:** `SanctionsScreeningPreventDeleteTest` (insert allowed; update blocked bulk 200;
  delete blocked bulk 200; rows survive). Deployed green alongside `PreventDeleteTriggerTest`
  (9/9 passing).
- **DATA-DICTIONARY.md** updated: §2.2 `Loan__c` field additions, new §2.12
  `Sanctions_Screening__c`, §3 immutability row, §4 indexing rows.

### 9.4 What remains

- **Slice 2 — gating service (code, NOT in this slice):** wire the KYC/OFAC gating
  preconditions into the origination orchestrator (`LoanDecisionService`) OUTSIDE the pure
  kernel per §5.2 — `Identity_Verification_Status__c == Verified` AND latest
  `Sanctions_Screening__c.Result__c == Clear`, else BLOCK (`KYC_INCOMPLETE` /
  `SANCTIONS_HOLD`); a missing screen is a BLOCK, not a pass. Record the block append-only.

- **BLOCKED — HUMAN sign-off required (verbatim from §7, still open):**
  - **OQ-R8-1** — Which external SSN tokenization vault? (Skyflow / Very Good Security /
    Salesforce Shield-only / in-house). *Owner + Security.*
  - **OQ-R8-2** — Is "no sanctions screen on file" a hard BLOCK to origination? (Knuth: yes —
    absence ≠ clearance.) *Compliance.*
  - **OQ-R8-4** — Match-score threshold for auto `Clear` vs `Potential_Match` routing — who
    owns the cutoff? (Config-as-data, not hardcoded.) *Compliance.*
  - **OQ-R8-6** — Retention/purge policy for `SSN_Token__c` in immutable records vs vault
    deletion duty. *Compliance + Legal.*
  - **OQ-R8-7** — Encrypt `SSN_Token__c` at rest in Salesforce (Encrypted Text / Shield if
    licensed, cf. R-6)? Built as plain Text(255) in slice 1 — encryption deferred to this
    sign-off. *Security.*

  (OQ-R8-3 and OQ-R8-5 were resolved by ADR-24: identity *status* on `Loan__c` is sufficient
  for R-8; `Sanctions_Screening__c` parents on `Loan__c`.)

R-8 stays OPEN until slice 2 lands, external tokenization is integrated, and the BLOCKED
items above are signed off by Compliance/Security/Legal. Slice 1 clears none of the caps on
its own; it deploys the **schema half** of the ratified ADR-24 design.
