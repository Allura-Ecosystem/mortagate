# R-8 Reviewer Hand-off — KYC / OFAC / SSN

> [!NOTE]
> **AI-Assisted Documentation** — drafted with AI assistance; reviewed by Brooks (Architect).

**Purpose:** R-8 (production gate) needs two human sign-offs before it can clear —
**Compliance** and **Security**. Owner (Sabir) and Architect (Brooks) have already
signed off on the design and the kernel boundary (ADR-24, 2026-06-19).

You do **not** need to read the full design to do your part. Each section below is the
short list of decisions *you* own, with the exact citation. The full rationale lives in
[`DESIGN-kyc-ofac.md`](./DESIGN-kyc-ofac.md); the ratification is ADR-24 in
`planning docs/RISKS-AND-DECISIONS.md`.

**Nothing is built or deployed.** This is a design awaiting your decision. R-8 stays
capped until both sign-offs land **and** the schema + gating code + tokenization are built.

---

## For the Compliance reviewer

You are confirming the design is sufficient for U.S. mortgage origination under
BSA/CIP (31 CFR 1020.220), OFAC (31 CFR Part 501), GLBA, and ECOA. Three decisions:

| # | Decision you own | Design's proposed answer | Cite |
|---|------------------|--------------------------|------|
| **OQ-R8-2** | Is **"no sanctions screen on file" a hard BLOCK** to origination? (The design deliberately treats absence of a screen as a block — the inverse of how a missing *borrower fact* is treated as INDETERMINATE.) | **Yes — absence ≠ clearance.** Confirm this is correct and required. | DESIGN §5.2; ADR-24; ADR-3 |
| **OQ-R8-4** | Who owns the **match-score cutoff** that routes a screen to `No_Match` vs `Potential_Match`? The schema *stores* the score but does not hardcode the threshold. | Threshold is **config-as-data** (mirrors `Adverse_Action_Config__mdt`), owned by Compliance, not engineering. Confirm + provide the cutoff. | DESIGN §3.2, §7 |
| **OQ-R8-6** | **Retention / purge policy**: the SSN *token* may persist inside immutable audit records, while the *raw SSN* is purged at the external vault. Does this satisfy retention duty + right-to-delete? | Token persists in append-only audit; raw SSN deleted at vault. Needs a legal retention schedule. | DESIGN §4.2, §7 |

**Also confirm (architectural, for your awareness):** a sanctions block is recorded as a
*precondition* reason on an append-only `Decision_Event__c`/`Audit_Event__c`, **not** as a
creditworthiness adverse-action under ECOA. A sanctions hit must never be papered over with
a DTI/FICO explanation. (DESIGN §5.2.)

---

## For the Security reviewer

You are confirming the SSN/PII handling minimizes blast radius. Two decisions:

| # | Decision you own | Design's proposed answer | Cite |
|---|------------------|--------------------------|------|
| **OQ-R8-1** | Which **external SSN tokenization vault**? (Skyflow / Very Good Security / in-house / Salesforce Shield-only.) | **External vault preferred over Shield-only** — so a Salesforce exfiltration yields only token + last-four, unreversible without separately breaching the vault. Pick a vendor + run security review. | DESIGN §4.2, §7 |
| **OQ-R8-7** | **Encrypt `SSN_Token__c` at rest** in Salesforce even though it is already a token? | **Yes — defense-in-depth** (Encrypted Text, or Shield if licensed — note R-6 FSC licensing uncertainty). Confirm. | DESIGN §4.1, §7 |

**Hard invariant to enforce in review (non-negotiable, already decided):** no raw SSN and
no de-tokenized SSN may ever be written to `Audit_Event__c`, `Audit_Receipt__c`,
`Agent_Action_Log__c`, `Sanctions_Screening__c`, or any `Payload__c`/snapshot field.
Agentforce actions (which run SOQL as the user) must never receive or echo a de-tokenized
SSN. Verify the eventual build honors this. (DESIGN §4 WARNING.)

---

## Sign-off ledger

| Role | Status |
|------|--------|
| Owner (Sabir) | ✅ approved 2026-06-19 |
| Architect (Brooks) — kernel boundary | ✅ ADR-24 |
| Compliance | 🔓 pending — OQ-R8-2, OQ-R8-4, OQ-R8-6 |
| Security | 🔓 pending — OQ-R8-1, OQ-R8-7 |

Return your decisions against the OQ numbers above; engineering will not build the schema
or gating code until both sign-offs are recorded.
