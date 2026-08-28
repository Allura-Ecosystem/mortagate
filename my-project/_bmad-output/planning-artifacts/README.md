# planning-artifacts — the live planning root

`_bmad/bmm/config.yaml` sets `planning_artifacts` to this directory. BMad skills glob
here for PRD, epics, architecture, and UX documents.

> [!CAUTION]
> **Platform pivot, 2026-08-28 (ADR-36).** Mortagate is a Microsoft Copilot Cowork
> plugin only. CaseFile/Salesforce is deprecated. Some files below predate the
> pivot and are bannered `Not current` rather than removed — check each row.

## What is canonical here

| Document | File | Status |
|---|---|---|
| PRD | `prds/prd-cowork-2026-08-28.md` | **Live.** CW-1..CW-22 |
| Epics and stories | `EPICS-AND-STORIES.md` | **Live.** EP-6 active; EP-0..EP-5 marked not-active in the overview table (deprecated product, kept for history) |
| Product brief | `product-brief-cowork.md` | **Live.** |
| PRD (deprecated) | `prds/prd-Mortagate-2026-06-14/prd.md` | Not current — bannered 2026-08-28 |
| Product brief (deprecated) | `product-brief.md` | Not current — bannered 2026-08-28 |

## Symlinks (not copies)

One document is canonical elsewhere and surfaced here by symlink so skill globs can
discover it. Not a duplicate — editing either path edits the same file.

| Link here | Real file | Status |
|---|---|---|
| `SOLUTION-ARCHITECTURE.md` | `planning docs/SOLUTION-ARCHITECTURE.md` | Not current — bannered. `mortagate.gates.json` p1-002 hardcodes the `planning docs/` path so the file can't move; the symlink exists only so the glob finds it, not because it's live. |
| `DESIGN-cowork-pilot-onboarding-ux.md` | `../planning/DESIGN-cowork-pilot-onboarding.md` | **Live.** The `-ux` suffix exists so the `*ux*.md` glob finds it. |

## No live architecture document exists on this branch

The Cowork module's own architecture doc,
`microsoft-cowork/docs/REFERENCE-ARCHITECTURE.md`, lives on branch
`feat/microsoft-cowork-plugin` (PR #6) — `microsoft-cowork/` doesn't exist on this
branch at all until that PR merges. Do not treat `SOLUTION-ARCHITECTURE.md`'s
presence here as filling that gap; it's deprecated Salesforce architecture, kept
discoverable only so nothing silently vanishes.

## Deliberately not here

- `../planning/DESIGN-onboarding-ux.md` — borrower persona, frozen ADR-15,
  superseded ADR-30. Bannered, kept outside this root so `*ux*.md` doesn't surface it.
- `../planning/DESIGN-casefile-auditor-ux.md` — CaseFile auditor persona pointer (to
  Figma). Symlinked in here 2026-08-28, then **removed** the same day once ADR-36
  deprecated CaseFile — same reasoning as the borrower doc above: a deprecated
  product's UX pointer shouldn't sit next to the live one under a glob that can't
  tell them apart. Still readable directly; just not glob-discoverable.
- `../archive/superseded-planning/EPICS-AND-STORIES-2026-06-07-borrower-portal.md` —
  the dead borrower-portal backlog. Previously sat in `../planning/` under the
  *same basename* as the live epics file; that collision misled an automated survey
  on 2026-07-26. Archived and renamed 2026-08-28 so it can't recur.
