# planning-artifacts — the live planning root

`_bmad/bmm/config.yaml` sets `planning_artifacts` to this directory. BMad skills glob
here for PRD, epics, architecture, and UX documents.

## What is canonical here

| Document | File | Notes |
|---|---|---|
| PRD | `prds/prd-Mortagate-2026-06-14/prd.md` | Live PRD, 28 FRs |
| Epics and stories | `EPICS-AND-STORIES.md` | **Live backlog.** EP-0..EP-6 |
| Product brief | `product-brief.md` | Veridact/CaseFile scope |
| Cowork brief | `product-brief-cowork.md` | Cowork module scope (EP-6/US-6.1) |

## Symlinks (not copies)

Two documents are canonical elsewhere and surfaced here by symlink so skill globs can
discover them. They are **not** duplicates — editing either path edits the same file.

| Link here | Real file | Why it lives elsewhere |
|---|---|---|
| `SOLUTION-ARCHITECTURE.md` | `planning docs/SOLUTION-ARCHITECTURE.md` | One of the 6 Carlos docs. `mortagate.gates.json` p1-002 hardcodes the `planning docs/` path — moving it breaks the gate. |
| `DESIGN-cowork-pilot-onboarding-ux.md` | `../planning/DESIGN-cowork-pilot-onboarding.md` | Design docs live in `planning/`. The `-ux` suffix exists so the `*ux*.md` glob finds it. |
| `DESIGN-casefile-auditor-ux.md` | `../planning/DESIGN-casefile-auditor-ux.md` | Pointer to the Figma UX authority (see below), not a design spec itself. |

## CaseFile auditor UX — pointer, not a spec

`DESIGN-casefile-auditor-ux.md` points to the actual UX authority: **Figma**
([UX Wireframes — Allura Mortgage](https://www.figma.com/design/pObIwaZXpTy5cL57uzF7Ta/Mortgage-audit?node-id=58-2),
Locked, 5 screens, brand kit v1.0.1). Added 2026-08-28 — the pointer previously
existed only as a footnote in `product-brief.md`, undiscoverable by a UX-glob check.
It deliberately does not restate Figma's content in prose, to avoid a third copy that
can drift from both Figma and the shipped code.

`../planning/DESIGN-onboarding-ux.md` remains excluded from this root: it covers the
**borrower** persona from the origination portal frozen by ADR-15 and superseded by
ADR-30, bannered 2026-08-28 so no automated pass mistakes it for current UX.

## Archived, deliberately not here

`../archive/superseded-planning/EPICS-AND-STORIES-2026-06-07-borrower-portal.md` —
the dead borrower-portal backlog. It previously sat in `../planning/` under the *same
basename* as the live file above; on 2026-07-26 that collision misled an automated
survey into reporting the whole planning layer as stale. Archived and renamed
2026-08-28 (G-5) so the collision cannot recur.
