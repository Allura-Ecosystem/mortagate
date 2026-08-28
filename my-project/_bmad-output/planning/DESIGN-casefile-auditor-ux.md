# DESIGN: CaseFile Auditor UX — Authority Pointer

> **This is a pointer document, not a design spec.** CaseFile's UX source of truth is
> a Figma file, not repo-committed prose. This file exists so a readiness check or a
> new contributor can *find* that authority without reading it out of a product brief
> footnote — created 2026-08-28, `implementation-readiness-report-2026-08-28.md`
> finding "no UX design document exists for the CaseFile auditor persona."

## Authority

**Figma — [UX Wireframes — Allura Mortgage](https://www.figma.com/design/pObIwaZXpTy5cL57uzF7Ta/Mortgage-audit?node-id=58-2)**

Status per `SOLUTION-ARCHITECTURE.md` §5 Integration Map: **Locked** — 5 screens,
brand kit v1.0.1. Referenced from `product-brief.md` and the PRD's own Integration
and Dependencies table, but not previously named in a discoverable design document.

## Persona

CaseFile auditor/analyst — internal, desktop-first (1280px+ monitors), the primary
product user. **Not** the persona in `DESIGN-onboarding-ux.md` (borrower, frozen
ADR-15/superseded ADR-30) and **not** the persona in
`DESIGN-cowork-pilot-onboarding.md` (Cowork pilot cohort, different product).

## Screens (per PRD §4 / Architecture Layer 1)

1. Audit Queue
2. Case Review
3. Finding Detail
4. Sign-off Receipt
5. Analytics

## What this document does not do

It does not restate Figma's content. Restating a locked design file in prose creates
a third copy that can drift from both Figma and the code — exactly the stale-document
pattern this repo has hit three times already (superseded epics file, superseded
borrower UX doc, dual-numbered requirements matrix). If Figma access is unavailable
when this doc is read, that is itself a finding to report, not a reason to
reconstruct the screens from memory or from the PRD's prose descriptions.
