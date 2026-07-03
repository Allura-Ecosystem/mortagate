# Gate Run Receipt — mortagate.gates.json

> **AI-Assisted Documentation** — This gate receipt was generated with AI assistance (Hightower, DevOps agent).

- **Date (UTC):** 2026-07-03
- **Project:** Mortgage Approval Engine (Veridact)
- **Checkout:** `/media/ronin704/Games/Projects/Allura-ecosystem/allura module/mortgage-audit`
- **Branch:** `feat/veridact-v1-demo`
- **Org alias:** `mortagate-de` (Connected — Developer Edition, orgId `00DgL00000SseMyUAJ`, apiVersion 67.0)
- **Gate file:** `mortagate.gates.json` (schema gate-runner.v1)
- **Runner:** sf CLI 2.137.7, node v24.14.0
- **Note:** `seed-data.apex` was NOT run (per standing instruction).

## Executive Summary

| Phase | PASS | PASS-WITH-DEVIATION | OPEN-MANUAL | FAIL |
|---|---|---|---|---|
| phase-0 (workspace/org readiness) | 4 | 0 | 0 | 0 |
| phase-1 (Carlos doc readiness) | 7 | 0 | 0 | 0 |
| phase-2 (metadata + quality) | 2 | 2 | 2 | 0 |
| **Total** | **13** | **2** | **2** | **0** |

> **Update 2026-07-03 (Triage Resolution):** `p2-002` was reclassified FAIL → PASS-WITH-DEVIATION after Brooks' ruling — the gate was fixed to the ADR-22 piecewise set (org state is correct by design). See the Triage Resolution section at the end.

- **Apex tests:** 198/198 passing (100%), org-wide coverage **83%**, test-run coverage 93%.
- **LWC Jest:** 53/53 passing across 12 suites.
- **Blocking failure:** `p2-002` full-source `--dry-run` FAILED with **132 component errors** — pending scheduled/async Apex jobs and an active Agentforce bot in the org block a full-source deploy. This is **not** the ADR-22/25 UNKNOWN_EXCEPTION gack, so the piecewise fallback was **not** invoked. Reported for triage; not fixed in this slice.

---

## Phase 0 — Workspace And Org Readiness

| Check ID | Command / Test | Result | Evidence |
|---|---|---|---|
| p0-001-sf-cli-version | `sf --version` | PASS | `@salesforce/cli/2.137.7 linux-x64 node-v24.14.0` — `p0-001-sf-version.txt` |
| p0-002-org-display | `sf org display --target-org mortagate-de --json` | PASS | `connectedStatus: Connected`, alias `mortagate-de`, apiVersion 67.0 — `p0-002-org-display.json` (accessToken redacted by CLI) |
| p0-003-org-list | `sf org list --all --json` | PASS | `mortagate-de` present in nonScratchOrgs + devHubs, Connected — `p0-003-org-list.json` |
| p0-004-project-context | file_exists ×3 | PASS | `planning docs/copilot-instructions.md`, `CLAUDE.md`, `mortagate.gates.json` all present |

---

## Phase 1 — Carlos Documentation Readiness

| Check ID | Command / Test | Result | Evidence |
|---|---|---|---|
| p1-001-blueprint | `test -f planning docs/BLUEPRINT.md` | PASS | present |
| p1-002-solution-architecture | `test -f planning docs/SOLUTION-ARCHITECTURE.md` | PASS | present |
| p1-003-requirements-matrix | `test -f planning docs/REQUIREMENTS-MATRIX.md` | PASS | present |
| p1-004-risks-decisions | `test -f planning docs/RISKS-AND-DECISIONS.md` | PASS | present |
| p1-005-data-dictionary | `test -f planning docs/DATA-DICTIONARY.md` | PASS | present |
| p1-006-design-doc | glob `my-project/_bmad-output/planning/DESIGN-*.md` | PASS | 5 matches (adverse-action, kyc-ofac, onboarding-ux, policy-engine, second-pass-data) — `p1-006-design-glob.txt` |
| p1-007-ai-disclosure | content_match `AI-Assisted Documentation` ×5 docs | PASS | matched in all 5 Carlos docs |

---

## Phase 2 — Salesforce Metadata And Quality Readiness

| Check ID | Command / Test | Result | Evidence |
|---|---|---|---|
| p2-001-project-json | `test -f sfdx-project.json` | PASS | present |
| p2-002-source-status | full-source dry-run (original gate cmd) → replaced by ADR-22 piecewise set | **PASS-WITH-DEVIATION** (was FAIL) | Original full-source: 132 errors / 432 (by-design block). Gate updated to 4 piecewise slices: objects PASS, lwc+staticresources PASS, experience-set PASS; classes+triggers FAIL-BY-DESIGN (active scheduled Apex). See Triage Resolution section — `p2-002-fullsource-dryrun.json`, `p2-002a..d-*.json` |
| p2-003-apex-tests | `sf apex run test --target-org mortagate-de --result-format json --code-coverage` | PASS | 198/198 passing, orgWideCoverage **83%**, testRunCoverage 93% — `p2-003-apex-tests.json` |
| p2-004-lwc-tests | `npm test -- --runInBand` → ran `npm run test:unit` | PASS-WITH-DEVIATION | 53/53 passing, 12 suites. Literal gate cmd fails: no `test` script in package.json (script is `test:unit` = sfdx-lwc-jest). Ran actual suite — `p2-004-lwc-jest.txt` |
| p2-005-flow-quality-review | manual_review | OPEN-MANUAL | Not freshly reviewed. Standing evidence: Flow bulk-safety discipline (no DML/Get-Records in loops) per apex/flow ADRs; fault-connector convention. Pointer: `planning docs/RISKS-AND-DECISIONS.md`, `copilot-instructions.md`. Requires human sign-off. |
| p2-006-lwc-quality-review | manual_review | OPEN-MANUAL | Not freshly reviewed. Standing evidence: brand-token guard (`npm run test:tokens`) green, `@sa11y/jest` a11y matchers in suite, no innerHTML-with-user-data convention, Apex CRUD/FLS via USER_MODE. Pointer: `lwc-craft` skill PICKLES checklist. Requires human sign-off. |

### p2-002 Failure Detail (for triage)

Full-source `--dry-run` returned `result.status: Failed`, **132 component errors** across 432 components. Distinct problems:

| Count | Problem | Type |
|---|---|---|
| 54 + 65 (paired msgs) | `This schedulable class has jobs pending or in progress - CronTrigger IDs ()` + "bypass via Deployment Settings" | ApexClass |
| 10 | `This schedulable class has jobs pending or in progress - CronTrigger IDs (08egL00000bzH8H)` | ApexClass |
| 1 | `This Apex class has asynchronous Apex jobs ... pending or in progress; AsyncApexJob ID(s): 707gL000010vWCP` | ApexClass |
| 1 | `Cannot update record as Agent is Active` | GenAiPlannerBundle |
| 1 | `Can't edit an active bot version` | BotVersion |

Failing component types: 130 ApexClass, 1 GenAiPlannerBundle, 1 BotVersion.

**Root cause (org state, not source):** A scheduled job (CronTrigger `08egL00000bzH8H`, consistent with `SecondPassSweepBatch` scheduled per commit d3f1a9e) and pending async Apex block redeploy of the Apex classes they reference. The Agentforce bot/planner is Active, blocking its metadata update. None of these are source-compile errors.

**Why no piecewise fallback:** Gate-run policy invokes the documented piecewise dry-run only when the full-source attempt returns `UNKNOWN_EXCEPTION` with **0** component errors (ADR-22/25 gack). Here there is no UNKNOWN_EXCEPTION and 132 real component errors, so the fallback condition is not met. Marked FAIL, left for triage.

**Suggested triage (NOT applied in this slice):**
- Unschedule/abort the pending `SecondPassSweepBatch` CronTrigger + drain async jobs, or enable "Allow deployments of components when corresponding Apex jobs are pending or in progress" in Deployment Settings; and deactivate the bot version / planner before a full-source deploy.
- Delegate remediation to woz-builder-mortgate per routing policy if a fix is authorized.

---

## Evidence Files (same directory)

- `p0-001-sf-version.txt`
- `p0-002-org-display.json` (accessToken redacted by CLI)
- `p0-003-org-list.json` (accessToken redacted by CLI)
- `p1-006-design-glob.txt`
- `p2-002-fullsource-dryrun.json` (raw), `p2-002-fullsource-dryrun.clean.json` (warning-stripped), `p2-002-failure-summary.txt`
- `p2-003-apex-tests.json`
- `p2-004-lwc-jest.txt`
- Piecewise dry-run slices: `p2-002a-objects.json`, `p2-002b-classes-triggers.json`, `p2-002c-lwc-staticresources.json`, `p2-002d-flexipages-tabs-apps-permsets.json`

---

## Triage Resolution (2026-07-03, Brooks ruling)

**Ruling:** The org state is CORRECT — the nightly `SecondPassSweepBatch` schedule and the Active Agentforce bot are the product working as designed. The gate definition predates a live org. **Fix the gate, not the org.** Do NOT unschedule the batch or deactivate the bot.

**Actions taken (this commit):**

1. **`mortagate.gates.json` p2-002 updated** — the single full-source `--dry-run` command was replaced with the ADR-22 piecewise dry-run set (4 commands: objects; classes+triggers; lwc+staticresources; flexipages+tabs+applications+permissionsets) and a `notes` field documenting that full-source deploy is blocked by design (active bot + scheduled Apex), piecewise is canonical per ADR-22/25, and full redeploys require the Deployment-Settings "Allow deployments with Apex jobs" toggle + bot deactivation as a **release runbook item, not a gate**.
2. **`mortagate.gates.json` p2-004 updated** — command corrected from `npm test -- --runInBand` to `npm run test:unit -- --runInBand` (the real script; resolves the p2-004 deviation).

**Piecewise dry-run results (run 2026-07-03):**

| Slice | Command (dirs) | Result | Components |
|---|---|---|---|
| p2-002a | objects | PASS | 239/239, 0 errors |
| p2-002b | classes + triggers | **FAIL-BY-DESIGN** | 130 errors / 136 — `This schedulable class has jobs pending or in progress` (CronTrigger `08egL00000bzH8H` = active nightly `SecondPassSweepBatch`) + 1 async AsyncApexJob `707gL000010vWCP` |
| p2-002c | lwc + staticresources | PASS | 13/13, 0 errors |
| p2-002d | flexipages + tabs + applications + permissionsets | PASS | 16/16, 0 errors |

**Honest note:** 3 of 4 piecewise slices are green. The **classes+triggers slice still fails** for the same by-design reason as the full-source run — the active scheduled batch blocks redeploy of the Apex classes it references. This is exactly the org state Brooks ruled correct; remediation is the documented runbook toggle ("Allow deployments with Apex jobs"), not a code or gate fix. Recorded verbatim per instruction; not fixed. The GenAiPlannerBundle/BotVersion "active" errors from the full-source run do not appear in the piecewise set because those metadata types are excluded from the 4 canonical slices (and quarantined in `.forceignore` per ADR-23).

**Reclassification:** `p2-002` FAIL → **PASS-WITH-DEVIATION** at the gate level: the gate now reflects the live-org reality (piecewise canonical + documented runbook for full redeploys). The classes-slice block is a known by-design condition captured in the p2-002 `notes` field, not an open defect.

**Unchanged:** `p2-005` (flow quality) and `p2-006` (LWC quality) remain **OPEN-MANUAL** — awaiting owner sign-off; no fresh manual review claimed.
