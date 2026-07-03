# R-8 Decision Memo — SSN / KYC / OFAC Sign-Off

> [!NOTE]
> **AI-Assisted Documentation.** Portions of this memo were drafted with the assistance of an
> AI language model (Knuth, data architect). It is a planning artifact for human (HITL)
> review and sign-off. It does **not** self-certify and it does **not** clear the R-8 gate.

Author: Knuth (data architect). Date: 2026-07-03. Branch: `feat/veridact-v1-demo`.
Reference risk: **R-8** (`planning docs/RISKS-AND-DECISIONS.md`).
Reference design: `my-project/_bmad-output/planning/DESIGN-kyc-ofac.md` §7 / §9.4 / §9.5.
Reference decision: **ADR-24** (RISKS-AND-DECISIONS.md).

---

## 0. Purpose and current state

The **code half** of R-8 shipped this sprint (slices 1 + 2, deployed to `mortagate-de`).
Verified against source metadata for this memo:

- **`Loan__c`** carries `SSN_Token__c` (Text 255, **plain text — not yet encrypted**),
  `SSN_Last_Four__c` (Text 4), and `Identity_Verification_Status__c` (restricted picklist,
  required, default `Not_Started`; values `Not_Started` / `Pending` / `Verified` / `Failed` /
  `Manual_Review`).
- **`Sanctions_Screening__c`** is append-only: `Result__c` (restricted picklist
  `Clear` / `Potential_Match` / `Confirmed_Match` / `Pending_Review`) plus `List_Source__c`,
  `List_Version__c`, `Match_Details__c`, `Adjudicated_By__c`, `Screened_At__c`, `Loan__c`
  (Lookup, required, `Restrict`). Immutability enforced by the `Prevent_Edit_After_Creation`
  validation rule (`NOT(ISNEW())`) and the `SanctionsScreeningPreventDelete` trigger.
- **`IdentityGateService`** evaluates the gate OUTSIDE the pure kernel, emitting
  `KYC_INCOMPLETE` / `SCREEN_MISSING` / `SANCTIONS_HOLD` / not-blocked (first-match precedence,
  newest `Screened_At__c` wins, `Result__c == 'Clear'` is the only pass).
- **`Veridact_KYC_Officer_Access`** is a separate need-to-know permission set (screening
  create+read, `Loan__c` SSN-field FLS), kept OFF the general engine/auditor permset.

What the code half **cannot** do is make the human policy calls. This memo exists to resolve
the five open questions that block R-8 from clearing: **OQ-R8-1** (vault vendor),
**OQ-R8-2** (missing-screen = hard block), **OQ-R8-4** (match-score threshold ownership),
**OQ-R8-6** (retention/purge policy), **OQ-R8-7** (token-at-rest encryption). OQ-R8-3 and
OQ-R8-5 were already resolved by ADR-24 and are out of scope here.

Each section states the question verbatim from the design doc, lays out options with
trade-offs, gives a recommendation grounded in the project's posture (demo/pilot stage,
append-only ledger doctrine, need-to-know permset already split, no live SSN capture path
yet), lists the backlog rows the decision creates, and ends with a decision block for the
named human owner to sign.

---

## OQ-R8-1 — External SSN tokenization vault vendor

**Question (verbatim, DESIGN-kyc-ofac.md §7 / §9.4):**
> Which external SSN tokenization vault? (Skyflow / Very Good Security / Salesforce
> Shield-only / in-house) — *Owner + Security.*

**Context.** The design (§4) fixes the invariant: Veridact **never stores a raw SSN** in
Salesforce; an external service tokenizes at capture and returns an opaque token +
last-four. `SSN_Token__c` and `SSN_Last_Four__c` already exist to hold the reference. No SSN
capture / de-tokenization path is built yet, so this decision has zero migration cost today
and unbounded cost once real SSNs land.

**Options.**

| Option | What it is | Trade-offs |
|---|---|---|
| **A. Salesforce Shield Platform Encryption (Shield-only)** | Keep the raw SSN in a Salesforce field, encrypted at rest by Shield; no external vault. | + Simplest integration (no third party, no outbound capture flow). − **Does not reduce blast radius** — the SSN still rests in the CRM; a misconfigured report, over-broad integration user, or export still exposes recoverable PII. − Shield is a licensed add-on of **unknown availability** in this org (cf. R-6 FSC uncertainty); single point of control. − Contradicts the design §4.2 "never rests in the CRM at all" posture. Poor compliance posture for the highest-blast-radius PII element. |
| **B. External tokenization vault (VGS / Basis Theory / Skyflow-class)** | A dedicated PCI/PII vault tokenizes the SSN at capture; Salesforce only ever sees token + last-four. | + **Largest available blast-radius reduction** — token+last-four cannot be reversed without separately breaching the vault. + Shrinks GLBA / state-breach scope of the org. + Right-to-delete becomes a single vault op while the immutable CRM token persists (reconciles ADR-1 append-only with PII deletion). − New vendor: contract, security review, DPA, integration build (capture proxy + de-tokenization routing via `SSN_Vault_Provider__c`). − Recurring vendor cost. − Adds an external dependency to the origination path. |
| **C. Defer — last-four-only, no token capture (current state)** | Ship pilot with `SSN_Last_Four__c` populated for display/verification and `SSN_Token__c` left null; no full SSN captured anywhere. | + Zero integration, zero vendor, zero new PII scope. + Fully adequate for a **demo/pilot that does not originate real loans** — last-four alone is not a reportable SSN. − Cannot support a real CIP identity record or a consumer-report pull, so it **cannot clear R-8 for production lending**. − Defers, does not resolve, the vendor question. |

**RECOMMENDED: C now (pilot), pre-committed to B for production.**
The project is explicitly demo/pilot stage and originates no real loans, so capturing full
SSNs today would *create* the very GLBA/breach scope the design works to avoid — for no pilot
benefit. Ship the pilot on last-four-only (Option C) and record the production path as
Option B (external vault), never Option A. Shield-only is rejected on posture grounds: it
leaves recoverable PII in the CRM, which defeats the §4.2 blast-radius rationale and leans on
a single licensed control of uncertain availability. Deferring the *capture* is safe; the
schema (`SSN_Token__c`, `SSN_Vault_Provider__c` routing) is already vault-shaped, so adopting
B later is additive, not a migration. The one hard rule this memo asks Security to ratify
now: **when SSN capture is built, it is an external vault, not Shield-only.**

**Backlog rows created.**
- `R8-1-a` — Security + Owner select and contract an external tokenization vendor
  (VGS / Basis Theory / Skyflow-class) before any production SSN capture. *(Blocking for
  production, not pilot.)*
- `R8-1-b` — Build the SSN capture proxy + de-tokenization routing keyed on
  `SSN_Vault_Provider__c` (add the field — deferred in slice 1). *(Production.)*
- `R8-1-c` — Pilot guardrail: leave `SSN_Token__c` null; add a data-entry/validation
  guard so no full SSN is ever written to the plain field before the vault exists.

**Decision block.**
- Chosen option: ________________________
- Decided by (Owner + Security): ________________________
- Date: ____________

---

## OQ-R8-2 — Is a missing sanctions screen a hard BLOCK?

**Question (verbatim, DESIGN-kyc-ofac.md §7 / §9.4):**
> Is "no sanctions screen on file" a hard BLOCK to origination? — *Compliance.*
> (Knuth: yes — absence ≠ clearance.)

**Context.** Slice-2 code **already implements** this as `SCREEN_MISSING` (a hard block):
`IdentityGateService.gateOne` blocks when no `Sanctions_Screening__c` exists for the loan.
This is the deliberate inversion of the ADR-3 asymmetry — a missing *borrower fact* is
INDETERMINATE (never a decline) for progressive onboarding, but a missing *sanctions screen*
BLOCKS. **The code choice does not substitute for the compliance ruling**; Compliance must
ratify (or overrule) the policy.

**Options.**

| Option | Behavior | Trade-offs |
|---|---|---|
| **A. Missing screen = hard BLOCK (`SCREEN_MISSING`)** — matches shipped code | No screen on file blocks origination until one is recorded. | + Correct OFAC posture: absence of proof of clearance is not clearance; a party never screened could be on the SDN list. + Already implemented and unit-pinned (`no screening row → SCREEN_MISSING`). + Fail-closed. − Requires a screen to exist before any loan can proceed (an operational sequencing requirement, not a defect). |
| **B. Missing screen = INDETERMINATE / soft-warn** | Loan may proceed with a flagged warning; screen backfilled later. | − Permits originating against an unscreened party — a direct OFAC exposure. − Contradicts §5.2 and would require reworking the shipped gate. Not defensible for a sanctions control. |
| **C. Missing screen = BLOCK, with a time-boxed grace window** | Block unless a screen is pending within N hours of a documented request. | ± Operational flexibility for batch screening. − Adds state/timer complexity to a present-state gate; still an exposure window. − Premature for pilot. |

**RECOMMENDED: A — confirm the hard block.**
The shipped gate is correct and matches the design's stated asymmetry. A sanctions screen is
categorically unlike a creditworthiness fact: a false negative here is a regulatory hard-stop
(transacting with an SDN party), not a confidence discount. Fail-closed is the only defensible
default for a sanctions control, and the code already enforces it. Compliance's job here is to
ratify the policy so the code choice is backed by a named human ruling rather than an
engineering default. No code change results from accepting A.

**Backlog rows created.**
- `R8-2-a` — Compliance issues a written ruling ratifying `SCREEN_MISSING` as a hard block
  (cite in ADR-24 and the R-8 row). *(Blocking for R-8 clearance.)*
- `R8-2-b` — Operational runbook: every loan must have a recorded screen before origination;
  define who runs it and when (ties to OQ-R8-4 ownership).

**Decision block.**
- Chosen option: ________________________
- Decided by (Compliance): ________________________
- Date: ____________

---

## OQ-R8-4 — Match-score threshold ownership (auto-Clear vs Potential_Match)

**Question (verbatim, DESIGN-kyc-ofac.md §7 / §9.4):**
> Match-score threshold for auto `Clear` vs `Potential_Match` routing — schema stores the
> score; who owns the cutoff? — *Compliance.* (Knuth: config-as-data, not hardcoded.)

**Context.** The §3.2 draft had a `Match_Score__c` (Number 5,2) field; the slice-1 ratified
slim set **folded score + rationale into `Match_Details__c`** (free-text) and did **not**
build a numeric score field. So today there is no structured cutoff to own — dispositions are
set by whoever records the screen. The Philosophy #3 doctrine ("rules are data, not code")
says any threshold that does emerge must live as config-as-data (mirror
`Adverse_Action_Config__mdt`), never hardcoded in Apex.

**Options.**

| Option | Where the cutoff lives | Trade-offs |
|---|---|---|
| **A. Vendor-owned, no local cutoff (pilot-appropriate)** | The screening provider returns a categorical disposition (`Clear` / `Potential_Match` / …); Veridact stores the label, owns no numeric threshold. | + Matches the shipped slim schema (no `Match_Score__c`). + No cutoff to govern; the vendor's tuned model owns it. + Zero build. − Opaque: Veridact cannot audit *why* a screen was Clear vs Potential beyond `Match_Details__c` free text. − Defers structured scoring. |
| **B. Config-as-data cutoff (`Custom Metadata`)** | Re-introduce `Match_Score__c` (Number) + a `Sanctions_Match_Config__mdt` holding the auto-Clear / route thresholds; Compliance edits records, not code. | + Auditable, tunable without deploy; consistent with `Adverse_Action_Config__mdt` and Philosophy #3. + Compliance owns the number as data. − Build cost (field + mdt + wiring). − Premature if the vendor already owns tuning. |
| **C. Hardcoded threshold in Apex** | A constant in the gate/service. | − Violates Philosophy #3 (rules-as-data). − Requires a deploy to retune a compliance-owned number. Rejected. |

**RECOMMENDED: A for pilot, B when a scoring provider is integrated.**
The shipped schema deliberately has no numeric score, so there is no cutoff to own at pilot
stage — Option A is the honest current state and needs only a named owner for the categorical
disposition. When a real screening provider that returns numeric confidence is integrated
(alongside the OQ-R8-1 vault work), promote to Option B: reintroduce `Match_Score__c` and a
`Sanctions_Match_Config__mdt` so **Compliance owns the cutoff as data**, never as Apex.
Option C is rejected outright under Philosophy #3. Either way the owner of the number is
**Compliance**, not engineering; this memo asks Compliance to accept that ownership.

**Backlog rows created.**
- `R8-4-a` — Compliance formally owns sanctions disposition/threshold policy (name the
  role). *(Blocking for R-8 clearance — ownership, even if the number is vendor-side today.)*
- `R8-4-b` — When a numeric-scoring provider is integrated: add `Match_Score__c` (Number 5,2)
  + `Sanctions_Match_Config__mdt` config-as-data; wire routing. *(Production.)*
- `R8-4-c` — Document the vendor's categorical disposition contract in DATA-DICTIONARY once a
  provider is chosen.

**Decision block.**
- Chosen option: ________________________
- Decided by (Compliance): ________________________
- Date: ____________

---

## OQ-R8-6 — Retention / purge policy for `SSN_Token__c` vs vault deletion duty

**Question (verbatim, DESIGN-kyc-ofac.md §7 / §9.4):**
> Retention/purge policy for `SSN_Token__c` in immutable records vs vault deletion duty —
> *Compliance + Legal.*

**Context.** The design's key reconciliation (§4.2): the raw SSN is purged at the **vault**,
while the opaque **token** can persist in Salesforce — including in immutable/audit records —
because a token without the vault is meaningless. This is what lets the append-only invariant
(ADR-1) coexist with PII deletion duties (GLBA, state breach law, right-to-delete). But the
retention *schedule* and the token↔vault deletion *contract* are legal/compliance calls, not
schema calls.

**Options.**

| Option | Policy | Trade-offs |
|---|---|---|
| **A. Token persists in CRM; raw SSN purged at vault on schedule** (design intent) | On a retention trigger, delete the SSN from the vault; leave the token in Salesforce (incl. immutable records). | + Preserves append-only audit — no CRM record is edited/deleted. + Single-point purge at the vault satisfies deletion duty. + Token is inert once the vault entry is gone. − Requires a documented retention schedule + a vault-deletion runbook + proof the token is truly non-reversible post-purge. − Needs legal confirmation that a retained inert token is not "retained PII." |
| **B. Purge token from CRM too (tokenize-then-null)** | Also null `SSN_Token__c` in the CRM at purge time. | − `SSN_Token__c` is not append-only (by design, §4.1) so nulling it is *possible* on `Loan__c` — but any token copied into an immutable record could **not** be nulled without breaking ADR-1. + Marginally reduces retained data. − Adds a CRM-side purge job for little gain (token already inert after vault delete). − Risks colliding with the append-only doctrine if tokens ever propagate to immutable objects. |
| **C. No defined retention (status quo)** | Keep everything indefinitely. | − Non-compliant: GLBA/state law require a retention schedule and honoring deletion requests. Rejected for production. |

**RECOMMENDED: A — vault-side purge, token persists, on a Legal-defined schedule.**
This is the only option that honors the append-only ledger doctrine (ADR-1) and the PII
deletion duty at the same time, which is precisely why the design chose external tokenization.
The token is inert once the vault entry is deleted, so the immutable audit trail stays intact
while the recoverable PII is gone at the source. What this memo needs from Legal + Compliance
is the missing non-schema pieces: (1) the **retention schedule** (how long before vault
purge), and (2) a **written finding** that a retained inert token is not "retained PII" under
the applicable regime. The design guarantees no raw/de-tokenized SSN is ever written to any
immutable, snapshot, or Agentforce payload (§4 WARNING) — Legal should rely on that invariant
being enforced (see backlog).

**Backlog rows created.**
- `R8-6-a` — Legal + Compliance publish the SSN retention schedule and the vault-purge trigger
  conditions. *(Blocking for R-8 clearance.)*
- `R8-6-b` — Legal written finding: a retained inert token (post vault-purge) is not retained
  PII under the target jurisdiction. *(Blocking for production lending.)*
- `R8-6-c` — Build the vault-deletion runbook/automation keyed on the schedule; log each purge
  append-only (as a receipt, not by editing the loan).
- `R8-6-d` — Add an enforcement test/guard proving no raw or de-tokenized SSN reaches
  `Audit_Event__c` / `Audit_Receipt__c` / `Agent_Action_Log__c` / any `Payload__c` (backs the
  §4 WARNING that Legal's finding depends on).

**Decision block.**
- Chosen option: ________________________
- Decided by (Compliance + Legal): ________________________
- Date: ____________

---

## OQ-R8-7 — Encrypt `SSN_Token__c` at rest in Salesforce

**Question (verbatim, DESIGN-kyc-ofac.md §7 / §9.4):**
> Encrypt `SSN_Token__c` at rest in Salesforce even though it is already a token? — *Security.*
> (Knuth: yes, defense-in-depth — Encrypted Text or Shield if licensed, cf. R-6.)

**Context.** Verified in metadata: `SSN_Token__c` shipped as **plain `Text(255)`** in slice 1;
its own field description records that at-rest encryption is deferred to this sign-off. The
token is already opaque (meaningless without the vault), so encryption here is
defense-in-depth, not the primary control.

**Options.**

| Option | Mechanism | Trade-offs |
|---|---|---|
| **A. Classic Encrypted Text field** | Convert `SSN_Token__c` to the Classic Encrypted Text type (masked, 175-char cap). | + No Shield license needed — available regardless of R-6 FSC uncertainty. + Masks the token in UI/reports; simple. − 175-char limit (must confirm token length fits; current field is 255). − Weaker key management than Shield; converting an existing field type requires care. |
| **B. Shield Platform Encryption** | Encrypt `SSN_Token__c` at rest via Shield, deterministic or probabilistic. | + Strongest at-rest posture, real key management. − **Licensed add-on of unknown availability** in this org (R-6). − Cannot be assumed present for pilot. Adopt only if licensing confirmed. |
| **C. Leave plain (current state), rely on FLS + vault opacity** | No field encryption; `Veridact_KYC_Officer_Access` FLS + token opacity are the controls. | + Zero change; the token is already inert without the vault. + Adequate while `SSN_Token__c` stays null at pilot (Option C of OQ-R8-1). − No defense-in-depth if a token is ever stored and FLS is misconfigured. Not acceptable once real tokens land. |

**RECOMMENDED: C for pilot (tokens null), A when tokens are first stored; B only if Shield is licensed.**
While the pilot stores no token (OQ-R8-1 Option C), plain text is acceptable because the field
is empty and gated by the need-to-know permset — encryption of nothing buys nothing. The
moment real tokens are captured, encrypt: prefer **Classic Encrypted Text (Option A)** because
it does not depend on the uncertain Shield license (R-6), first confirming a vault token fits
the 175-char cap (VGS/Basis Theory aliases typically do; if not, keep 255 + Shield). Use
**Shield (Option B)** only if licensing is confirmed available. This keeps defense-in-depth
layered on top of the primary control (the token is already useless without the vault) without
blocking the pilot on a license Veridact may not hold. Security owns the final mechanism call.

**Backlog rows created.**
- `R8-7-a` — Security decides the at-rest mechanism (Classic Encrypted Text vs Shield) and the
  trigger point (before first real token is stored). *(Blocking for production; not for a
  token-null pilot.)*
- `R8-7-b` — When tokens are stored: convert `SSN_Token__c` to encrypted; verify token length
  fits the chosen mechanism's cap; migrate FLS. *(Production.)*
- `R8-7-c` — Confirm Shield licensing status in `mortagate-de` (also unblocks R-6 uncertainty).

**Decision block.**
- Chosen option: ________________________
- Decided by (Security): ________________________
- Date: ____________

---

## Summary

| OQ | Recommendation | Effort if accepted | Blocking for pilot? |
|---|---|---|---|
| **OQ-R8-1** (vault vendor) | Pilot: last-four-only, `SSN_Token__c` null (Option C). Production: external vault, never Shield-only (Option B). | Pilot: low (a null-guard). Production: high (vendor contract + capture proxy + de-tokenization). | **No** — pilot originates no real loans. |
| **OQ-R8-2** (missing screen = block) | Confirm hard BLOCK (`SCREEN_MISSING`) — matches shipped code (Option A). | Low — Compliance ruling only, zero code change. | **No** — code already enforces it; needs written ratification. |
| **OQ-R8-4** (match-score cutoff owner) | Pilot: vendor-owned categorical disposition, no local cutoff (Option A). Production: config-as-data `Match_Score__c` + `Sanctions_Match_Config__mdt`, Compliance owns (Option B). | Pilot: low (name the owner). Production: medium (field + mdt + wiring). | **No** — but Compliance ownership must be named. |
| **OQ-R8-6** (retention/purge) | Vault-side purge; inert token persists in CRM; Legal-defined schedule (Option A). | Medium — retention schedule + legal finding + vault-purge runbook + no-SSN-in-immutable guard test. | **No** for demo; **Yes** for production lending. |
| **OQ-R8-7** (token encryption) | Pilot: plain text OK while token null (Option C). On first real token: Classic Encrypted Text (A); Shield (B) only if licensed. | Pilot: none. Production: low–medium (field type conversion + FLS migration). | **No** — token is null at pilot. |

**Net:** none of the five OQs blocks the demo/pilot (which originates no real loans and stores
no full SSN), but **all five block production lending** and therefore R-8 clearance. R-8 stays
**OPEN**. Per the Confidence Caps, Production Lending stays capped until: (a) schema deployed
[done, slice 1], (b) gating code wired [done, slice 2], (c) external tokenization integrated
[OQ-R8-1], and (d) Compliance / Security / Legal sign-offs land [OQ-R8-2, -4, -6, -7]. This
memo provides the options and recommendations; the decision blocks above require named human
signatures before any item is considered resolved.
