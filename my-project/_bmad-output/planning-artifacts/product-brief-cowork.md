# Product Brief: Mortgate Evidence Review for Microsoft Copilot Cowork

> [!NOTE]
> **AI-Assisted Documentation**
> Drafted with AI assistance from the shipped module source (`microsoft-cowork/`),
> PR #6, ADR-33/ADR-34, and the originating build handoff. Reviewed against the
> codebase. Closes EP-6/US-6.1.

> **Scope:** This brief covers the **Cowork module only**. The CaseFile/Veridact audit
> product has its own brief in `product-brief.md`. They are separate products with
> separate users; ADR-34 rules Cowork outside the ADR-33 pilot-scope freeze.

## Executive Summary

Mortgate Evidence Review is a Microsoft Copilot Cowork skills package that helps an
authorized mortgage employee review a loan file's *evidence* — what documents are
present, what's missing, what conflicts, and whether a supplied policy replay lines up
— and draft an audit packet for a human reviewer.

It is an **evidence-review workspace, not an underwriting engine.** It reaches no
decision and writes to no system of record. Every output is a draft that a human
reviews.

The employee works in Microsoft 365, where they already are. They type plain requests
("start an evidence review for this file", "what documents are missing?"). They never
encounter Team RAM, BMad, Allura, or any agent name — the internal framework is not
part of the product surface.

## The Problem

An employee assembling or checking a loan file works document by document: opening
each PDF, remembering which documents the file type requires, noticing that the pay
stub and the application disagree on income, and writing up what's missing for a
reviewer. It is attention-intensive, easy to do inconsistently, and the "what's
missing" step is exactly where a tired reviewer skips something.

Existing AI tooling in this space tends to overreach — it wants to *decide*. In a
regulated lending context, a tool that drafts a credit decision creates compliance
exposure (ECOA/Reg B adverse-action requirements, fair-lending scrutiny) far faster
than it creates value.

## The Solution

Four Cowork skills, each scoped to evidence rather than decisions:

1. **Mortgage case onboarding** — set up an evidence-review task from an employee's request.
2. **Loan file evidence review** — inventory uploaded documents; identify missing, ambiguous, and conflicting evidence.
3. **Policy replay review** — compare a *supplied* deterministic policy replay against the evidence. The module does not evaluate policy itself; it reads results produced elsewhere.
4. **Audit packet draft** — assemble a packet for a human reviewer.

## Users

**Primary:** internal mortgage employees (processors, QC staff, reviewers) on a
Frontier-enabled Microsoft 365 Copilot tenant. Non-engineers. Not expected to know
anything about the implementation.

**Pilot cohort (first users):** a small group validating the module against synthetic,
nonproduction documents in a private "Only you" workspace. Flow documented in
`../planning/DESIGN-cowork-pilot-onboarding.md`.

**Not users:** borrowers. The module is internal-only and never communicates with an
applicant.

## Hard Boundaries

The module cannot approve or deny a loan, set a rate or credit term, override policy,
issue an adverse-action notice, send a borrower message, or write to any loan system.
These are product definition, not configuration — governed in
`planning docs/SOLUTION-ARCHITECTURE.md` §5 "Cowork Hard Boundaries", ruled in ADR-34.

The module has no connection to Salesforce (`mortagate-de`), no Allura Brain
integration, and no `group_id` usage. It reads only documents the user attaches in the
Cowork chat.

## Why Microsoft Copilot Cowork

The employee already works in Microsoft 365. Cowork supplies the workspace, the file
handling, and the tenant's existing identity and compliance posture; this package
supplies the mortgage-domain skills. Nothing new to log into.

## Constraints and Risks

| Item | Detail |
|---|---|
| **Frontier preview** | Cowork is a Microsoft Frontier preview. Requires a Frontier-enabled tenant and a licensed user. Not generally available. |
| **Tenant validation unproven** | Full tenant-side package validation needs interactive M365 sign-in and has not been run (EP-6/US-6.6). |
| **Synthetic data only** | No production borrower data during pilot — private "Only you" upload, synthetic documents only. |
| **Supplied replay, not computed** | Policy replay *results* come from elsewhere. Garbage in, garbage compared. |
| **No live case retrieval** | Reading real case/evidence data would need the Entra-secured read-only MCP connector — not built, gated on pilot outcome (US-6.8) and its own ADR per ADR-34. |

## What Reference Implementations Contributed

- **Confluent workshop** — event/infrastructure and reproducible-demo patterns only. Its automated final decisioning was deliberately excluded.
- **Red Hat quickstart** — RBAC, PII masking, audit/evaluation, role-scoped workflow, compliance source tiering. Its simulated policies and underwriting workflow were not copied.

## Success Criteria (pilot)

1. A pilot-cohort member completes an evidence review on synthetic documents unaided — no framework vocabulary needed.
2. Missing-document findings are accurate against a known-incomplete synthetic file.
3. The module refuses, cleanly and understandably, when asked to decide, price, or notify.
4. A drafted audit packet is usable by a human reviewer without rework.

## Status

Built and CI-green. [PR #6](https://github.com/Allura-Ecosystem/mortagate/pull/6) open
against `main`, unmerged. Tracked as EP-6 / GOAL-G3.
