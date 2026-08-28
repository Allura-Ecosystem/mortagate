# Sprint Change Proposal — 2026-08-28

**Trigger:** Cowork planning-artifact gap
**Workflow:** bmad-correct-course
**Facilitator:** Brooks
**Owner:** Sabir Asheed
**Mode:** Incremental (all 4 change proposals reviewed and approved individually)

---

## 1. Issue Summary

The Microsoft Copilot Cowork module — [PR #6](https://github.com/Allura-Ecosystem/mortagate/pull/6),
branch `feat/microsoft-cowork-plugin`, commit `ac624e4` — was designed and implemented
without following the project's own mandated pre-implementation sequence (CLAUDE.md:
"Before implementation, create or update the required Carlos artifacts"). It shipped
with no product brief, no PRD coverage, no architecture-doc entry, no UX doc, and no
epic/story entries.

**Discovered:** 2026-08-28, when Sabir asked directly whether a brief, PRD, and
epic/story breakdown existed for Cowork ahead of onboarding a new pilot cohort.

**Evidence:**
- Zero mentions of "cowork/copilot/microsoft" in `product-brief.md`,
  `prds/prd-Mortagate-2026-06-14/prd.md`, `planning docs/SOLUTION-ARCHITECTURE.md`,
  or the live `EPICS-AND-STORIES.md` (grep-verified).
- The superseded `EPICS-AND-STORIES.md` (then at `my-project/_bmad-output/planning/`,
  archived 2026-08-28 to
  `archive/superseded-planning/EPICS-AND-STORIES-2026-06-07-borrower-portal.md` under
  G-5 to eliminate the duplicate basename) was initially
  mistaken for the live backlog during document discovery; corrected mid-workflow —
  the actual live backlog is `my-project/_bmad-output/planning-artifacts/EPICS-AND-STORIES.md`,
  which also has zero Cowork coverage.
- The prior session's handoff note recommended "approve PR #6 → pilot → build MCP
  connector" with no step to backfill planning docs — confirming the gap was not an
  oversight in this conversation alone, but absent from the prior plan too.
- `DESIGN-onboarding-ux.md` (the only onboarding UX doc in the repo) covers the
  **borrower** persona from the frozen, superseded origination-portal design
  (ADR-15/ADR-30 pivot) — not usable for the Cowork pilot cohort (internal mortgage
  employees) without misfiling it under the wrong persona.

## 2. Impact Analysis

**Epic Impact:** No existing epic covers Cowork. G-1 (Brooks plugin binding) and G-2
(Beta Readiness / CaseFile) are unaffected, independent workstreams — no cross-epic
dependency found. A new epic is required, not a modification of an existing one.

**Story Impact:** None of the 32 stories in the live `EPICS-AND-STORIES.md` reference
Cowork. No rework of existing stories needed.

**Artifact Conflicts:**
- **PRD** — no conflict with MVP goals; Cowork is additive scope. Needs a pointer row
  in Section 10 (Integration and Dependencies).
- **Architecture** — no conflict; needs a new Integration Map row plus a codified
  "Cowork Hard Boundaries" subsection so the no-approve/no-deny/no-write invariant
  lives in governed architecture, not only in a handoff note.
- **UX** — the only existing onboarding doc is persona-mismatched (borrower, not
  pilot-cohort employee); needs a new, correctly-scoped doc rather than an edit to
  the existing one.

**Technical Impact:** None. This is a documentation/traceability backfill — no code,
infrastructure, or deployment changes.

## 3. Recommended Approach

**Selected: Option 1 — Direct Adjustment**, sequenced **alongside** G-2 (not ahead of
or behind). Add one new epic (EP-6 / G-3) and the four artifact edits below. Effort:
Low-Medium. Risk: Low.

- **Rollback (Option 2):** not viable — there is nothing to revert; the shipped code
  is sound, only the planning trail is missing.
- **MVP Review (Option 3):** not viable as primary — deferring would waste completed
  work already sitting in an open PR and further delay the pilot cohort.

## 4. Detailed Change Proposals

### 4.1 New Epic — EP-6 / GOAL-G3 (Cowork Pilot Readiness)

Add to `my-project/_bmad-output/planning-artifacts/EPICS-AND-STORIES.md` and create
`my-project/_bmad-output/planning/GOAL-G3-cowork-pilot-readiness.md` (same convention
as G-1/G-2).

| ID | Story | Layer | Depends on |
|---|---|---|---|
| US-6.1 | Author a Cowork-scoped product brief | Planning | none |
| US-6.2 | Add a "Microsoft Copilot Cowork Module" PRD section (4 skills, acceptance criteria) | Planning | US-6.1 |
| US-6.3 | Add integration/boundary subsection to `SOLUTION-ARCHITECTURE.md` | Planning | US-6.1 |
| US-6.4 | Document pilot-cohort onboarding UX | Planning | US-6.1 |
| US-6.5 | Review and merge PR #6 | Salesforce/Engineering | none |
| US-6.6 | Tenant-side package validation (Frontier tenant) | External | US-6.5 — hand-off to Sabir, interactive M365 sign-in required |
| US-6.7 | Private pilot upload, synthetic docs only | External | US-6.6 |
| US-6.8 | Pilot cohort feedback loop → retro → go/no-go on Entra-secured MCP connector | Planning | US-6.7 |

### 4.2 PRD — `my-project/_bmad-output/planning-artifacts/prds/prd-Mortagate-2026-06-14/prd.md`, Section 10

```diff
 | GitHub | `Allura-Ecosystem/mortagate` monorepo | Active — PRs #1-4, 3 branches |
+| Microsoft Copilot Cowork | Skills-only evidence-review module (`microsoft-cowork/`), no write access to Veridact/Salesforce, no decisioning authority | Built — PR #6 open, pilot pending. Full spec: US-6.2 deliverable |
```
(GitHub row's status text also updates to reflect PR #6 / 4+ branches.)

### 4.3 Architecture — `planning docs/SOLUTION-ARCHITECTURE.md`, Section 5

```diff
 | GitHub | `Allura-Ecosystem/mortagate` monorepo | Code + CI | Active |
 | Vercel | Hosting (free tier) | React deployment | Active |
+| Microsoft Copilot Cowork | Skills package (`microsoft-cowork/appPackage/skills/`), read-only evidence review | Standalone — no Salesforce/Veridact write path | Built (PR #6 open), pilot pending |
+
+### Cowork Hard Boundaries (codified, not advisory)
+
+The Cowork module cannot, by design: approve or deny a loan; set a rate or credit
+term; override policy; issue an adverse-action notice; send a borrower message; or
+write to any loan system (Salesforce or otherwise). It has no integration path into
+Section 2's layers beyond reading uploaded evidence documents supplied directly by
+the user in the Cowork chat. Any future connector (US-6.8, the Entra-secured MCP
+connector) is a new integration and requires its own ADR before it touches this map.
```

### 4.4 UX — new file `my-project/_bmad-output/planning/DESIGN-cowork-pilot-onboarding.md`

Scoped to the pilot-cohort (internal mortgage employee) persona, explicitly
distinguished from the borrower persona in `DESIGN-onboarding-ux.md`. Covers the
Frontier-tenant private-upload flow, plain-language request pattern, and in-scope
skill boundaries. Leaves open items (pilot invite/licensing mechanics, synthetic
doc fixture source, feedback capture channel) for US-6.4 to resolve.

## 5. Implementation Handoff

**Scope classification: Minor.** All four changes are documentation edits/additions
with no code, schema, or deployment impact — implementable directly in this session
(Claude Code, working shell — the "Desktop bash is non-functional" caveat in CLAUDE.md
does not apply here).

| Item | Owner | Note |
|---|---|---|
| EP-6/G-3 epic + stories | This session | Write now |
| PRD Section 10 edit | This session | Write now |
| Architecture Section 5 edit | This session | Write now |
| New UX doc | This session | Write now |
| US-6.5 (merge PR #6) | Sabir | Requires human approval — Brooks does not merge PRs unilaterally |
| US-6.6 (tenant validation) | Sabir | Requires interactive M365 sign-in, out of session scope |
| US-6.7 (pilot upload) | Sabir + pilot cohort | Depends on US-6.6 |
| US-6.8 (retro / connector go-no-go) | Sabir + Brooks | Depends on US-6.7 |

**Success criteria:** All four artifacts exist and are internally consistent;
`GOAL-G3` reads the same as `G-1`/`G-2` in format; PR #6 has a clear, documented
path to merge and pilot without relying on tribal knowledge from a handoff note.
