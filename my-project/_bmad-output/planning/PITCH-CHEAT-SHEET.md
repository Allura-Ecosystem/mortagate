# Veridact — Pitch Cheat Sheet

> One page. Say it out loud 5×. Memorize three terms cold: **post-close QC, stipulations, repurchase risk**.

---

## The 20-second opener

> "I built a post-close QC tool on Salesforce for companies that buy loans. It runs an automated second pass behind the human auditor — re-validates each file against investor guidelines and the cleared stipulations, flags exceptions, and ties every decision back to the exact document and rule it used. Evidence-first and fully auditable, so it cuts repurchase risk and gives them a defensible paper trail."

## The 60-second version (if they lean in)

> "You know how when a lender or investor buys a pool of loans on the secondary market, they have to run post-close QC — re-verify every file meets investor guidelines and that all the underwriting conditions and stipulations were actually cleared before the loan funded? Right now that's a manual audit. And if a loan slips through that doesn't meet guidelines, they're exposed to repurchase risk — the investor can force a buyback. I built a system on Salesforce Financial Services Cloud that acts as an automated second pass behind the human QC analyst. It re-validates each loan against the stipulations and the policy rules, flags exceptions like DTI, LTV, or missing trailing docs, and — this is the part they care about — every decision is evidence-first and fully auditable: it points to the exact document and the exact rule version it used, so the whole audit is replayable. It's not replacing the analyst; it's catching what the human misses and handing them a defensible trail."

**Lead with repurchase risk** — that's the dollar they're protecting.

---

## The terms doing the work

| Term | What it means | Why it matters |
|---|---|---|
| **Post-close / post-closing QC** | The audit done *after* a loan closes | Your category. Dad's "validating steps" = this |
| **Stipulations ("stips") / conditions** | What the borrower had to satisfy before funding (pay stubs, LOEs, etc.) | Your if-then rules check whether these were actually cleared |
| **Investor guidelines** | The rulebook the loan must match (often Fannie/Freddie agency guidelines) | What your policy rules encode |
| **Repurchase / buyback risk (reps & warranties)** | Buy a bad loan → the investor can force you to take it back | The money pain. *Why they'd pay you* |
| **Correspondent lender / aggregator** | The "smaller lending companies that bought a bunch of loans" | Your buyer persona |
| **Trailing documents** | Docs that arrive after closing (recorded mortgage, final title policy) | Common audit gap |
| **DTI / LTV** | Debt-to-income, loan-to-value | The core ratios the engine re-checks |

---

## Three pushbacks and how to answer them

**1. "How is this different from ACES or ICE? That already exists."**
> "ACES manages the QC *workflow* — the evaluation is still a human with a checklist. ICE's Analyzers automate the evaluation but they're a black box — they flag an exception, they can't show their work. Mine replays the **exact rule version that was in force at approval** against the frozen loan facts, and every check carries a receipt: this document, this rule, this threshold, this result. When the investor's repurchase demand letter arrives, ACES gives you a workflow history; I give you a replayable proof."

**2. "AI in a lending decision? That sounds like regulatory risk."**
> "The AI never decides anything. A deterministic rules engine produces every verdict — same inputs, same output, byte-for-byte. The AI layer only *narrates*: it summarizes the case, drafts the finding, explains the exception in plain English. And every AI action is logged to an append-only ledger *before* it executes. Fannie and Freddie now require AI governance from seller/servicers — approval trails, versioning, retrievable audit logs. Most vendors are retrofitting that. It's my architecture's starting point."

**3. "Why build it on Salesforce?"**
> "Because that's where the loans already live — correspondents and aggregators are on Financial Services Cloud and nCino. Building inside their org means one security boundary: the tool inherits their SOC 2, their field-level security, their user access. The AI agent literally cannot see a loan the auditor can't. A standalone SaaS tool would mean shipping loan files to a third party and a second vendor security review. Mine is a managed package away from their AppExchange cart."

---

## Grounding (what's actually true in the build — don't oversell past this)

- Deterministic replay kernel, live and tested on org (Apex 140+, worst-wins verdicts, INDETERMINATE for missing facts)
- Immutable receipts: append-only `Audit_Event__c` / `Audit_Receipt__c` / `Agent_Action_Log__c`, trigger-enforced (ADR-1, ADR-26)
- Historical fidelity: replays the policy version effective at approval date (ADR-4)
- Agentforce copilot: diagnosis action live; logs before execution with dual-write (ADR-16/26)
- Roadmap, not yet built: overnight exception sweep (ICE-style), draft-finding/evidence-request actions, doc extraction (v3)
