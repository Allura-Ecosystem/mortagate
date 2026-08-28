# G-3 — Cowork module has planning traceability and a validated pilot path

**Status:** Defined, epic EP-6 filed, 4 of 8 stories actionable now
**Defined:** 2026-08-28
**Owner:** Sabir Asheed
**Workstream:** WS-1 (extends the Cowork work opened in the prior handoff)
**Authority:** Sprint Change Proposal 2026-08-28 (`bmad-correct-course`), triggered by
Sabir asking whether a brief/PRD/epic-stories existed for Cowork ahead of a new pilot
cohort — they did not.

## Goal

The Microsoft Copilot Cowork module ([PR #6](https://github.com/Allura-Ecosystem/mortagate/pull/6))
gets the same planning traceability every other shipped piece of this project has —
brief, PRD coverage, architecture entry, UX doc, epic/stories — and a pilot cohort of
mortgage employees can validate it against synthetic documents with a documented,
repeatable onboarding flow.

This is not a new goal for the module's functionality (that's already built and
scoped by the hard boundaries in the original handoff). It is a goal for the module's
*governance surface* — making sure the next person who touches this doesn't have to
reconstruct context from a single handoff note.

## Outcome

1. `product-brief.md`-equivalent Cowork brief exists (US-6.1).
2. PRD Section 10 points to it; a dedicated Cowork PRD section exists (US-6.2).
3. `SOLUTION-ARCHITECTURE.md` codifies the 7 hard boundaries as architecture, not
   advisory text (US-6.3 — **done**, see Section 5 of that doc).
4. A pilot-cohort onboarding doc exists, correctly scoped to the internal-employee
   persona rather than the borrower persona (US-6.4 — **done**, see
   `DESIGN-cowork-pilot-onboarding.md`).
5. PR #6 is merged (US-6.5), tenant-validated (US-6.6), piloted with synthetic docs
   (US-6.7), and the pilot feedback drives a go/no-go on the Entra-secured MCP
   connector (US-6.8).

## What is already true

Established 2026-08-28 by direct repo inspection (grep, `gh pr view`, file reads —
not recalled from memory).

| Fact | Value | How established |
|------|-------|-----------------|
| PR #6 state | OPEN, not merged | `gh pr view 6 --json state,mergedAt` |
| Cowork branch | `feat/microsoft-cowork-plugin`, HEAD `ac624e4` | `git log` |
| Cowork mentions in PRD/brief/architecture/live epics (pre-G-3) | 0 | grep across all 4 files |
| Live epics/stories location | `my-project/_bmad-output/planning-artifacts/EPICS-AND-STORIES.md` | The sibling file under `planning/` (same name) is marked SUPERSEDED — do not cite it |
| Onboarding UX doc available for reuse | No — existing doc is borrower-persona, frozen/superseded scope | Direct read of `DESIGN-onboarding-ux.md` |
| Cowork vs. ADR-33 pilot-scope freeze | ADR-34 **ACTIVE**, but **superseded in practice by ADR-36** | ADR-34 approved by Sabir 2026-08-28 (no Salesforce writes, no Allura calls, read-only). Same day, ADR-36 deprecated the entire prior implementation — the freeze ADR-34 exempted Cowork from no longer has a live product to freeze. Both ADRs in `planning docs/RISKS-AND-DECISIONS.md`. |

## Items still requiring Sabir (cannot be closed from this session)

- **US-6.5** — merging PR #6 is a human decision, not automated.
- **US-6.6** — tenant-side validation needs interactive Microsoft 365 sign-in against a
  Frontier-enabled tenant; unreachable from an agent session.
- **US-6.7 / US-6.8** — depend on the above.

## Related

- Sprint Change Proposal: `sprint-change-proposal-2026-08-28.md`
- Epic: EP-6 in `EPICS-AND-STORIES.md` (planning-artifacts)
- Prior handoff this extends: Microsoft Copilot Cowork Mortgate build, 2026-08 (session
  prior to this one)
