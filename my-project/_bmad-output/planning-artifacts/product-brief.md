# Product Brief: Veridact — Mortgage Audit Replay & QC

> **AI-Assisted Documentation**
> This brief was drafted with AI assistance, synthesizing the canonical Notion product page, Allura Brain memories, existing Carlos documentation, and Figma wireframes. Content has been reviewed against the codebase but requires stakeholder sign-off.

## Executive Summary

Veridact is an internal mortgage audit tool that helps bank auditors verify whether already-approved loans should have been approved. The auditor takes a closed loan, replays the exact rules that were in force at the time of approval, maps each rule to its supporting evidence, and records pass, exception, or violation findings — producing an immutable audit receipt ready for regulators.

The product runs on four layers: a React auditor cockpit for the daily workflow, Salesforce for enterprise records and workflow, Agentforce for in-platform AI assistance (summarizing cases, drafting findings, requesting evidence), and Allura for governed audit reasoning (historical policy replay, evidence mapping, exception detection). The human auditor remains the final decision-maker — AI assists, humans approve.

The core value proposition is speed with traceability: a mortgage auditor finishes a review faster with better evidence linkage and lower compliance risk. Target: from 45 minutes per loan review to 8 minutes, with a permanent, append-only audit receipt at the end.

## The Problem

Post-approval mortgage QC is slow, manual, and fragile. Today a bank auditor:

1. **Pulls the loan file** — scattered across the LOS, document vault, and spreadsheets
2. **Finds the rules** — digs through policy manuals to identify which rules governed at the time of approval, not today's rules
3. **Checks each rule** — manually compares thresholds (DTI, FICO, LTV) against the borrower's numbers, one at a time
4. **Hunts for evidence** — matches each rule to a specific document (pay stub, appraisal, credit report)
5. **Documents findings** — writes up violations and exceptions in a Word document or spreadsheet
6. **Gets sign-off** — emails the review to a manager, who re-reads everything

The cost: 45+ minutes per loan, inconsistent documentation, no standardized audit trail, and regulatory exposure when examiners ask "show me why this loan was approved and how you verified it."

The specific risk this product addresses: **unjustified special exemptions.** A loan officer approves a loan that violates a guideline, claims it was an approved exception, but there's no documented approval for the exemption. Without systematic replay, that gap is invisible until an examiner finds it.

## The Solution

Veridact gives auditors a 5-screen workflow:

1. **Audit Queue** — Triage assigned loans by risk tier, SLA, branch, and product. Queue-first, not dashboard-first.
2. **Case Review** — Two-pane view: evidence pack on the left, replay checklist on the right. Each rule shows pass/exception/violation with its supporting evidence linked.
3. **Finding Detail** — Document a violation, exception, or missing evidence with severity, remediation, and rule citation.
4. **Sign-off Receipt** — Reviewer approval creates an immutable, append-only audit receipt. Once signed, it cannot be edited or deleted.
5. **Analytics** — Exception rate, approver drift, missing evidence patterns, branch risk.

Agentforce sits in the Salesforce sidebar as the auditor's assistant:
- "Summarize this case" → reads the loan data and evidence, returns a natural-language overview
- "Draft a finding for the DTI violation" → pulls the rule explanation and evidence, drafts text the auditor can accept, edit, or override
- "What evidence is missing?" → lists unlinked or unverifiable items

Agentforce may summarize, draft, recommend, and create tasks. It must **never** approve audits, close cases, override policy, delete findings, or modify signed receipts.

## What Makes This Different

1. **Historical policy replay** — Veridact replays the exact rules that were in force at the time of approval, not today's rules. Most audit tools check current policy, which misses threshold changes.
2. **Evidence-to-rule mapping** — Every rule check is linked to its supporting evidence. Missing evidence is a first-class outcome, not a footnote.
3. **Append-only audit receipt** — The sign-off receipt is immutable. Enforced in code (Apex trigger + validation rule), not by convention.
4. **AI assists, humans decide** — Agentforce and Allura handle the tedious work (summarization, drafting, replay). The auditor makes every judgment call.
5. **Regulator-ready** — The audit trail is structured for examiner review: rule, threshold, actual value, evidence, finding, severity, reviewer, timestamp.

## Who This Serves

**Primary: Bank mortgage auditor (QC analyst)**
Reviews 10-30 loans per day. Needs to verify that each loan was approved correctly against the policy in force at the time. Success = faster reviews with better documentation and fewer missed exceptions.

**Secondary: Audit manager / Chief Risk Officer**
Reviews sign-off receipts, monitors exception rates across branches and approvers, reports to regulators. Success = confidence that the QC process is systematic and the audit trail is defensible.

**Buyer: Internal Audit / Mortgage Operations / Compliance / Technology**
The people who sign the check. They care about: fits existing controls, creates an audit trail, reduces review time, keeps human approval, explains findings with evidence and policy citation, produces an append-only receipt.

## Success Criteria

| Metric | Target |
|--------|--------|
| Review time per loan | < 10 minutes (from 45 min baseline) |
| Evidence linkage rate | > 95% of rule checks have evidence linked |
| Exception documentation rate | 100% of exceptions have documented approval or flagged as unjustified |
| Audit receipt completeness | 100% of closed cases have an immutable receipt |
| Agentforce action accuracy | > 90% of summaries/drafts accepted without major edits |
| False positive rate | < 5% of replay violations overturned on human review |

## Scope

### In (v1 — Demo Target)

- 5-screen auditor workflow (Queue → Review → Finding → Receipt → Analytics)
- Historical policy replay against versioned rules
- Evidence-to-rule mapping with missing/unverifiable as explicit states
- 4 Agentforce agents (Auditor Assistant, Evidence Request, Manager Review, Compliance Analytics)
- 8 safe Agentforce actions with governed logging
- 3 prompt templates (Draft Finding, Evidence Request, Manager Summary)
- Append-only audit receipt with immutability enforcement
- React cockpit + Salesforce workflow + Agentforce sidebar
- Veridact brand (Cream/Charcoal/Orange/Outfit)

### Out (v1)

- Borrower-facing portal (frozen — see ADR-15)
- Real LOS integration (Encompass / ICE / Blend)
- OCR / document extraction
- Vector search / embeddings
- Production borrower data in AI prompts
- Multi-org / multi-tenant deployment

## Compliance & Regulatory

Veridact operates in a regulated space. Key constraints:

- **No real customer data in demos** — all demo data is fictional (Kaggle-sourced, transformed)
- **Policy versioning** — rules are data, not code (ADR-4). Analysts version rules without deployment.
- **Append-only audit trail** — `Audit_Event__c` records are immutable. Enforced by code (ADR-1).
- **Human-final-authority** — Agentforce cannot approve, close, override, delete, or modify signed receipts.
- **ECOA / Reg B** — Adverse action notices cite specific reasons from rule explanations, not generic language (ADR-10).

## Vision

If Veridact succeeds as a demo and pilot:

**Year 1:** Single-region pilot with one bank partner. 90-day proof on sanitized historical data. Read-only Agentforce, human-reviewed findings only.

**Year 2:** Production deployment with LOS integration (Encompass or equivalent). Agentforce moves from draft-only to controlled write actions. Analytics dashboard drives operational decisions.

**Year 3:** Multi-bank SaaS. Allura's governed memory enables cross-audit pattern detection — "this approver grants DTI exceptions at 3x the branch average." The audit receipt becomes the product's moat: a permanent, structured, explainable record that regulators trust.

The tagline is the architecture: **"Every decision has a receipt."**

---

## Technical Approach (High-Level)

| Layer | Technology | Responsibility |
|-------|-----------|----------------|
| Auditor cockpit | React (Next.js) | 5-screen workflow, mobile nav, design system |
| Workflow & records | Salesforce (Apex, LWC, SObjects) | Case management, evidence, findings, receipts, policy versions |
| Workflow assistant | Agentforce (subagents, actions, prompt templates) | Summarize, draft, recommend, create tasks |
| Audit reasoning | Allura (Postgres, Neo4j, governed memory) | Historical policy replay, evidence mapping, exception detection |
| Human authority | The auditor | Every judgment call |

**Brand:** Veridact — Canvas #F5F0E8, Ink #1F1E1C, Primary #E25D22, Green #308357, Red #BE3232, Amber #D39826, Blue #2B5C83

**Design source of truth:** Figma — [UX Wireframes — Allura Mortgage](https://www.figma.com/design/pObIwaZXpTy5cL57uzF7Ta/Mortgage-audit?node-id=58-2)

**Canonical product page:** [Notion — Veridact Mortgage Audit Replay & QC](https://app.notion.com/p/82bb4ebe4c4d46f1a6f3caab96e14960)
