# Executive Demo Script — Mortgage Audit Queue (Allura Ecosystem)

**Audience:** Wells Fargo / Bank of America executive sponsors (Risk, Compliance, Model Governance)
**Duration:** ~5 minutes live + 3 minutes Q&A
**Org:** `mortagate-de` (Salesforce Developer org) · component: **Audit Queue** (`c-audit-queue`)
**Golden-path case:** **AC-0001 — Priya Nair** (Critical risk tier)

> One-line frame to open with: *"This is an independent, replayable second line of defense
> on mortgage credit decisions. It re-runs the policy that was in force at decision time,
> against reconstructed facts, and produces a tamper-evident finding with a regulatory
> citation — without ever touching the original decision record."*

---

## Pre-flight (do this BEFORE the execs are watching)

- [ ] Log into `mortagate-de` and pin the **Audit Queue** tab.
- [ ] Confirm **AC-0001 (Priya Nair)** opens and shows the full drill-down:
      5 evidence items, 5 reconstructed facts, 4 rule checks (1 Violation), 1 Finding, 5 events.
- [ ] Set browser zoom to ~110% for projector legibility.
- [ ] Close dev tooling, Setup tabs, and any console — nothing "engineering" on screen.
- [ ] Have the **one-pager** (`exec-one-pager.md`) open in a second tab for Q&A.

---

## Scene 1 — The queue (60s): *"Risk-ranked work, not a spreadsheet"*

1. Open the **Audit Queue**. The metric cards read across the top
   (Critical / High / Medium / Low counts).
2. Talking point: *"Every approved loan is eligible for sampling. The queue surfaces the
   riskiest cases first — auditors work top-down by tier, not by gut feel."*
3. Point to the **risk tier column**: each tier shows a **word** ("Critical") and a shape
   sigil — **never color alone**. Say: *"This is WCAG 1.4.1 compliant — it reads correctly
   for a color-blind auditor and for a screen reader. That matters for ADA/508 posture."*

## Scene 2 — Open the case (45s): *"A write-once snapshot"*

1. Click **AC-0001 (Priya Nair)**.
2. Talking point: *"The borrower name you see is a write-once snapshot captured at sampling
   time. The auditor can never silently edit it — it's locked by a platform validation rule.
   The audit record is a fixed photograph of what was true, not a live mirror."*

## Scene 3 — Reconstructed facts (45s): *"We rebuilt the file independently"*

1. Show the **Reconstructed Facts** section: DTI **47%**, Credit Score 712, Annual Income
   $82,000, Loan Amount $410,000, LTV 80%.
2. Talking point: *"These weren't copied from the loan-origination system. They were
   reconstructed from the underlying evidence — W-2, pay stubs, the tri-merge credit report,
   bank statements, the appraisal. Five evidence items, five derived facts. Independent
   recomputation is the whole point of a credible second line."*

## Scene 4 — The replay & the violation (60s): *"The decision contradicts the policy"*

1. Show the **Rule Checks**: 4 checks ran against the policy version in force at decision
   time (**Policy DTI_MAX v3**). Three pass (credit ≥ 620, LTV ≤ 80%, income documented).
2. Land on the **DTI check → Violation**.
3. Talking point: *"Reconstructed DTI is 47%. The Ability-to-Repay / Qualified Mortgage
   ceiling is 43% — 12 CFR 1026.43(c). This loan was approved anyway. The replay engine
   re-applied the **exact policy version that was active at the time** — not today's policy —
   so this is a fair, point-in-time judgment."*

## Scene 5 — The finding & adverse-action basis (45s): *"Defensible, cited, tracked"*

1. Show the **Finding**: Category **Eligibility**, Severity **High**, Disposition **Open**.
2. Talking point: *"The finding carries the regulatory citation and an adverse-action basis —
   excessive debt-to-income. This is the language ECOA/Reg B requires. A remediation clock
   starts, and the disposition is tracked to sign-off."*

## Scene 6 — The audit trail (30s): *"Tamper-evident by construction"*

1. Show the **5 audit events**: Case Created → Evidence Linked → Facts Reconstructed →
   Replay Executed → Finding Created.
2. Talking point: *"Every step is an append-only event. Events cannot be edited or deleted —
   enforced at the platform layer, not by policy. When a regulator or internal audit asks
   'who did what, when, and on what basis,' the answer is a complete, immutable chain.
   That's the SR 11-7 evidence story for model governance."*

---

## Close (15s)

*"To summarize: independent fact reconstruction, point-in-time policy replay, a cited and
defensible finding, and a tamper-evident trail — on a platform your teams already run.
This is the audit layer that turns 'we think the model is governed' into 'here is the
evidence, case by case.'"*

---

## If asked to go deeper (optional Scene 7)

- **"Can the auditor cheat?"** — Show that the auditor cannot be the original approver
  (validation rule `Prevent_Self_Audit`), the snapshot is write-once, and events are
  delete-protected. Separation of duties is enforced in metadata.
- **"How do you know the policy version is right?"** — The case pins `DTI_MAX@v3`; the
  Policy Rule Version object is a versioned, immutable snapshot — superseded, never edited.

## Do NOT do on screen
- Don't open Setup, Developer Console, VS Code, or run any `sf` command.
- Don't mention the `[KAGGLE-SEED]` test rows or scratch-org reproducibility work.
- Don't filter the queue down to the seed data — stay on the curated AC-0001 path.
