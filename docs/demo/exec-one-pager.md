# Mortgage Audit Queue — Executive One-Pager

**The independent, replayable second line of defense for mortgage credit decisions.**

A bank approves a loan. Months later, a regulator, an internal-audit team, or a model-risk
committee asks: *was that decision defensible under the policy in force at the time, and can
you prove it?* The Mortgage Audit Queue answers that question — case by case, with cited,
tamper-evident evidence — on the Salesforce platform your teams already operate.

---

## What it does (the loop)

1. **Sample** every approved loan, risk-ranked (Critical → Low).
2. **Reconstruct** the underlying facts independently from the source evidence
   (W-2, pay stubs, credit report, bank statements, appraisal) — not copied from the LOS.
3. **Replay** the *exact policy version that was active at decision time* against those facts.
4. **Find** the violations, cite the regulation, and assign an adverse-action basis.
5. **Record** every step as an append-only, delete-protected event.

The original decision record is never touched. The audit is a fixed photograph, not a live mirror.

---

## Why a Wells Fargo / Bank of America risk leader cares

| Regulatory pressure | What examiners / auditors demand | How the Audit Queue answers it |
|---|---|---|
| **SR 11-7** (Model Risk Management) | Independent, ongoing validation of decision models; effective challenge; documented evidence | Independent fact reconstruction + point-in-time policy replay, with an immutable per-case evidence chain |
| **ATR / QM** — 12 CFR 1026.43(c) | Demonstrate ability-to-repay was assessed; DTI within the 43% QM safe harbor | The replay engine flags DTI > 43% against the policy version in force, with the citation attached |
| **ECOA / Reg B** | A specific, defensible adverse-action reason | Findings carry a categorized adverse-action basis (e.g. excessive debt-to-income) |
| **HMDA / Fair Lending** | Evidence of consistent, non-discriminatory application of policy | Same policy version replayed uniformly across sampled cases; findings are categorizable as Fair-Lending |
| **OCC / Fed exam readiness** | "Who did what, when, on what basis?" — a complete trail | Append-only audit events that cannot be edited or deleted; separation-of-duties enforced in metadata |
| **ADA / Section 508 / WCAG 2.1** | Accessible internal tooling | Risk conveyed by text + shape (not color alone, WCAG 1.4.1); error states announced to assistive tech |

---

## What makes it credible (not just a dashboard)

- **Independence.** Facts are recomputed from evidence, so the audit can disagree with the LOS.
- **Point-in-time fairness.** Policy is versioned and immutable; the replay uses the version
  that was active *then*, not today's rules.
- **Tamper-evidence by construction.** Write-once borrower snapshot, append-only events,
  delete-protection, and an auditor-≠-approver rule — all enforced at the platform layer.
- **Defensible output.** Every finding has a regulatory citation and an adverse-action basis.

---

## Worked example (the live demo case)

**AC-0001 — an approved mortgage.** Audit replay reconstructs a **DTI of 47%**. The policy in
force (**DTI_MAX v3**) sets the ATR/QM ceiling at **43%** as a HARD_DECLINE. The loan was
approved anyway. The engine produces a **High-severity Eligibility finding**, cites
**12 CFR 1026.43(c)**, sets an adverse-action basis of excessive debt-to-income, and writes a
five-step immutable event trail — all without altering the original decision.

That is the difference between *"we believe our models are governed"* and *"here is the
evidence, case by case."*

---

## Status & platform

- Runs on Salesforce (Lightning Web Components + Apex). No new infrastructure.
- Automated test coverage green: Apex AuditQueue suite + 12/12 LWC unit/accessibility tests.
- Deployed and demonstrable today on `mortagate-de`.
