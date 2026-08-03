# G-2 — Mortagate is beta-ready for mortgage analysis

**Status:** Defined, awaiting SC execution
**Defined:** 2026-08-03
**Owner:** Sabir Asheed
**Workstream:** WS-3
**Authority:** Sabir directive 2026-08-02 ("defing goal beta test ready" / "this make mortagate beta for mortgage analysis")

## Goal

A bank analyst who has never seen the codebase can take a loan application from
intake to a signed decision, and every fact in that decision can be traced back to a
specific document and a specific policy version.

Beta is not "the code deploys." Beta is "a non-engineer completes a real analysis and
the audit trail survives inspection."

## Outcome

One loan runs end to end — document upload → `Evidence__c` → `Intake_Received__e` →
extraction → rule evaluation → `Decision_Event__c` carrying a `Policy_Rule_Version__c`
reference — and the Audit Replay reconstructs it from stored evidence alone, with no
access to the original session.

## What is already true

Established 2026-08-03 by read-only SOQL against `mortagate-de`, Developer Console.
These are measurements, not claims.

| Fact | Value | How established |
|------|-------|-----------------|
| Org reachable, CLI authorized | `00DgL00000SseMyUAJ`, Connected, DevHub | `sf org display --target-org mortagate-de` |
| Org API version | 67.0 | same |
| `Audit_Case__c` records | **6** | `SELECT COUNT(Id) FROM Audit_Case__c` |
| `Replay_Check__c` records | **60** | `SELECT COUNT(Id) FROM Replay_Check__c` |
| `Rule_Check__c` records | **4** | `SELECT COUNT(Id) FROM Rule_Check__c` |
| Custom objects in org | **39** | `EntityDefinition` enumeration |
| `Audit_Check__c` | **does not exist** | `ERROR at Row:1:Column:29` |

The circulating claim of **629 `Audit_Case__c` records is false.** The Audit Console's
"Showing 6 of 6" was accurate. The "60 current checks" figure on the Analytics screen
is real but belongs to `Replay_Check__c`, not to any audit-case object.

## Success criteria

Each is observable by Sabir at a terminal or in a browser. None is satisfied by an
agent's self-report. Each requires a pasteable artifact.

| # | Test | Pass condition | Artifact |
|---|------|----------------|----------|
| SC-1 | `sf apex run test --target-org mortagate-de --code-coverage` | Suite green; org-wide coverage ≥ 75% | **PASS 2026-08-03** — 204 tests, 100% pass, 83% coverage, Run Id 707gL0000189QJ8 |
| SC-2 | `memory_search` against group `allura-mortgage` for a known-present record | Returns the record | **Revised** — see SC-2a/SC-2b below |
| SC-3 | `memory_add` with an explicit score of 0.9, then `memory_get` | Persisted score reads 0.9, not 0.5 | **IN PROGRESS** — known bug, subagent dispatched to fix |
| SC-4 | Inspect stored embeddings in the RuVector backend | Vectors are non-zero | **FAIL 2026-08-03** — zero embeddings. pgvector installed, Ollama models available, but no vector columns or data. Subagent dispatched to fix. |
| SC-5 | Four `p2-002` piecewise deploy slices | All four deploy without error | **PASS 2026-08-03** — all 4 dry-runs clean (20+125+55+17 = 217 files), zero errors, zero warnings |
| SC-6 | Upload a document through the portal | `Evidence__c` created with hash + scan status; `Intake_Received__e` fires; `Decision_Event__c` written | Record IDs for all three |
| SC-7 | Audit Replay on the SC-6 decision | Reconstructs evidence, rule version, approver, timestamps | Replay output |
| SC-8 | Analyst UAT script | A non-engineer completes SC-6 following the written script alone, unaided | Script + observed completion |

### Sequencing risk — run SC-4 before SC-2

A federation failure and a zero-embeddings condition produce an **identical** symptom:
`memory_search` returns empty. If SC-2 is tested first against zero embeddings, the
result will be misdiagnosed as a federation bug and the wrong fix will be attempted.
Confirm vectors are non-zero, then test search.

### SC-2 fix direction — recorded, do not rediscover

`memory_search` does not federate Postgres. `memory_get` and `memory_list` already do,
correctly, in the same codebase. The fix is to make `search` follow those two working
reference implementations. This is a known-good path; it does not need re-investigation.

### SC-3 background

The Allura promotion threshold is **0.85**. `memory_add` persists `score: 0.5`
regardless of the score passed in. Nothing can ever promote while that holds, which
makes the curated-insight tier permanently empty. SC-3 is the reproduction, not the
fix.

## Definition of done

SC-1 through SC-8 all pass, **and** all three open decisions below are ruled on, **and**
the ruling is reflected in the repository rather than only in conversation.

A criterion that passed once but has no artifact in the repo is not done. The artifact
is the mechanism; the passing run is the evidence.

## Open decisions that block done

| # | Decision | Why it blocks |
|---|----------|---------------|
| D-A | ~~Product name: CaseFile vs Veridact~~ — **RESOLVED 2026-08-03, see below** | No longer blocks SC-8. Residual work is string migration, not a decision. |
| D-B | Three policy objects exist — `Policy_Rule__c`, `Policy_Rule_Version__c`, `Policy_Version__c` — where the documented model names only `Policy_Rule_Version__c` | The governance invariant "every approval references `Policy_Rule_Version__c`" is unenforceable when a decision could reference any of three. SC-7 cannot pass on an ambiguous reference target. **Evidence gathered 2026-08-03 — see D-B evidence below. The ruling is still Sabir's.** |
| D-6 | `sourceApiVersion` 66.0 vs org API 67.0 | Confirmed 2026-08-03, no longer suspected. One-version gap; may surface on newer metadata types during SC-5. |

### D-A resolution — the name was never in dispute in the repository

**ADR-30 (2026-07-03) is explicit:** "Product name is **CaseFile**; Veridact retires to
internal codename; namespace target `casefile`." It was decided, not left open.

`sfdx-project.json` has already implemented it:

| Field | Value |
|-------|-------|
| `package` | `CaseFile` |
| `versionDescription` | "CaseFile — mortgage post-close audit (Veridact engine)" |
| Package Id | `0HogL00000034rtSAA` |
| `CaseFile@0.1.0-1` | `04tgL000000IMEzQAO` |

A real package with a real version Id. The name is committed in the one place that is
hardest to reverse.

**ADR-30's own recorded blocker was:** "Namespace registration BLOCKED on a fresh DE org
… Once an org exists and is CLI-authenticated, availability check + registration + DevHub
link are automatable." That blocker cleared **today** — `mortagate-de` is Connected and
DevHub-enabled, org `00DgL00000SseMyUAJ`.

What remains is a **string migration**, not a decision: `README.md` title,
`package.json` description, org nav labels ("Audit Console", "Veridact Analytics"),
permission-set API names (`Veridact_Mortgage_Engine_Access`,
`Veridact_KYC_Officer_Access`), the Agentforce agent `Veridact_Auditor_Copilot_v4`,
`specs/veridact*.yaml`, and the record prefix `VERIDACT-AC-0001`.

**Do not migrate the permission-set or agent API names before SC-1 and SC-5.** Renaming
deployed metadata mid-verification invalidates the coverage baseline the whole goal
rests on. SC-8's analyst script writes **CaseFile** and notes that in-org labels still
read Veridact. Cosmetic mismatch is honest; a broken deploy is not.

ADR-30 also carries a standing caution worth keeping visible: "Casefile" collides with a
well-known true-crime podcast and possible legal-tech marks. A trademark screen in
software/fintech classes should ride with the R-7 counsel review before public launch.
The Salesforce namespace is first-come and independent of trademark.

### D-B evidence — three objects are two competing designs, not three peers

Established 2026-08-03 by field-level metadata enumeration under `force-app/`.

| Object | Fields | Shape |
|--------|--------|-------|
| `Policy_Rule_Version__c` | 22 | **Denormalized** — rule and version in one record |
| `Policy_Rule__c` | 9 | **Normalized** — carries a `Policy_Version__c` lookup |
| `Policy_Version__c` | 10 | The version half of the normalized pair |

`Policy_Rule__c` and `Policy_Version__c` are not independent of each other. The former
holds a lookup field to the latter. They are one design expressed across two objects.
`Policy_Rule_Version__c` is a second, competing design expressing the same concept in one.

The denormalized object is the richer of the two. Fields present on
`Policy_Rule_Version__c` and absent from the normalized pair:

`Regulatory_Citation__c`, `Rule_Explanation__c`, `Override_Permitted__c`,
`Override_Justification_Required__c`, `Allowed_Values__c`, `DTI_Threshold__c`,
`Min_Credit_Score__c`, `Threshold_High__c`

Those are the governance fields. `Regulatory_Citation__c` is what makes a decision
defensible to a regulator; the override pair is what makes HITL enforceable. The
normalized pair cannot carry an approval that satisfies this project's own invariants.

### D-B — RECOMMENDATION RETRACTED 2026-08-03. It was backwards.

The recommendation printed here earlier read: "`Policy_Rule_Version__c` is canonical;
`Policy_Rule__c` and `Policy_Version__c` are a superseded normalization attempt."

**That is wrong.** It was inferred from field counts alone. Two documents and one code
path contradict it.

**ADR-18** states the normalized pair is deliberate: `Policy_Rule__c` is "a thin
reference object (dual-kernel)," and `ReplayService` keeps an ADAPT step that maps
`Policy_Rule__c` → in-memory `Policy_Rule_Version__c`. This is a documented pattern,
not accidental drift.

**Verified in source 2026-08-03** (`ReplayService.cls`, `SeedDataLoader.cls`,
`.forceignore`, `triggers/`):

| Path | Object touched | Status |
|------|----------------|--------|
| `SeedDataLoader` — production seed | inserts `Policy_Version__c` + `Policy_Rule__c` (master-detail) | **Live.** Never inserts `Policy_Rule_Version__c`. |
| `ReplayService` lines 82–126 | queries `Policy_Version__c` → `Policy_Rules__r`, adapts to **in-memory** `Policy_Rule_Version__c` | **Live.** No DML on the adapted objects. |
| `PolicyRuleVersionTrigger` + `PolicyRuleVersionHandler` | lifecycle enforcement on `Policy_Rule_Version__c` | **Live.** ADR-4 "rules are data." |
| `FactAssemblerService`, `DecisionCommitService`, `LoanDecisionService` | the only production writers of `Policy_Rule_Version__c` | **Quarantined** by `.forceignore` per ADR-32 |

### Corrected reading — neither object is superseded

Within the frozen pilot scope (ADR-33, CaseFile post-close audit loop), the two designs
serve different halves and both are live:

- The **normalized pair** is the *populated* path. It is what seed data writes and what
  `ReplayService` actually reads at run time.
- **`Policy_Rule_Version__c`** is the *governance* surface. It carries
  `Regulatory_Citation__c`, the override pair, and the thresholds; it is the lookup
  target of `Decision_Event__c.Rule_Version__c`; it has a trigger enforcing immutability.
  In the live pilot path it exists as an in-memory DTO, not a persisted record.

**Consequence for the invariant.** "Every approval references `Policy_Rule_Version__c`"
is not currently satisfiable by the deployed audit loop, because nothing deployed
*persists* a `Policy_Rule_Version__c`. Its production writers are quarantined. This is
a **governance gap**, not a naming ambiguity — and it is a different, larger problem
than D-B was originally framed as.

### Correction to the earlier `.forceignore` claim

An agent report cited `FactAssemblerService` and `DecisionCommitService` as the
production write path while also reporting them quarantined. Both halves were checked.
They **are** in `.forceignore` (lines 32–35). The file's own comment adds the nuance
that matters: "`.forceignore` only stops future deploys — these classes remain in-org
until explicitly destructively removed." So they may still execute in `mortagate-de`
today while being absent from source deploys. **Verify in-org before assuming either
way.**

### What D-B now asks Sabir to rule on

Not "which of three objects is canonical." The revised question:

1. Does the CaseFile audit loop need to **persist** `Policy_Rule_Version__c` records to
   satisfy the approval invariant, or does the ADR-18 in-memory adaptation satisfy it?
2. If persistence is required, which live class writes them — the quarantined
   originators are not coming back under ADR-33.

**Do not delete any of the three objects.** `Audit_Case__c` holds a lookup to
`Policy_Version__c`; `Policy_Rule__c` is master-detail on it; `Decision_Event__c` looks
up `Policy_Rule_Version__c`. All three are load-bearing.

## Naming trap — carry into every artifact

Canonical spelling is **`mortagate`**: the directory, `mortagate.gates.json`, the org
alias `mortagate-de`, and `SF_TARGET_ORG`. The single deliberate exception is the
Allura memory group, which is **`allura-mortgage`**.

The git remote reads `github.com/Allura-Ecosystem/mortgate.git` — missing the second
`a`. That is the likely infection source for every misspelling downstream. Renaming
the upstream repository once is cheaper than correcting this indefinitely.

## Assumption — VERIFIED 2026-08-03, and it failed

The assumption was that Mortagate writes to Brain group `allura-mortgage` **in code
today**, rather than that being design intent recorded in documentation.

**It is intent.** A repository-wide grep for `allura-mortgage` returns **44 files** —
all of them documentation, policies, skills, `.opencode/` agent definitions,
`mortagate.gates.json`, `README.md`, `AGENTS.md`, `copilot-instructions.md`.

**Zero hits under `force-app/`.** No Apex, no LWC, no Flow writes to this group.

### Consequence — SC-2 as written cannot pass

SC-2 says "`memory_search` against group `allura-mortgage` for a known-present record."
There is no known-present record, because nothing in the deployed application has ever
written one. Run as written, SC-2 returns empty — and empty is the **same symptom** as
the federation bug and the zero-embeddings condition. Three distinct causes, one
indistinguishable result. That is now a three-way ambiguity, not the two-way one the
sequencing note anticipated.

### Revised SC-2, replacing the original

Split into two criteria. Do not merge them back.

| # | Test | Pass condition |
|---|------|----------------|
| SC-2a | `memory_add` a record to group `allura-mortgage`, then `memory_search` for it | Returns the record. Isolates federation from population. |
| SC-2b | Trace one Mortagate decision path to an actual Brain write | A named Apex class or Flow writes `group_id = allura-mortgage`. If none exists, this is unbuilt work, not a bug. |

SC-2b is the honest one. The Allura-governed memory described throughout this project's
documentation is, in the deployed Salesforce application, **not yet wired**. That is a
scope finding, not a defect — but it must not be discovered during SC-8 with an analyst
in the room.

Revised sequencing: **SC-4 → SC-2a → SC-2b.** Confirm vectors are non-zero, then confirm
search federates against data known to exist, then confirm the application produces that
data on its own.

## SC-6 is at risk — the async spine does not exist in source

Established 2026-08-03 by exhaustive enumeration under `force-app/`.

| Expected | Found |
|----------|-------|
| `platformEvents/` directory | **absent** |
| `Intake_Received__e` definition or subscriber | **zero** |
| `.flow` files, any name | **zero** |
| Apex callouts (`HttpRequest`, `Http`, `@future(callout=true)`) | **zero** |
| Named Credentials, External Credentials, Remote Site Settings | **zero each** |
| `externalServices/`, `restResources/` | **absent** |

72 Apex classes, all pure SOQL/DML.

SC-6 reads: "`Intake_Received__e` fires." Nothing in source can fire it. As written,
SC-6 is not a test that can fail — it is a test of unbuilt work.

**This corroborates ADR-33's own parked open question OQ-3 ("Platform Events in DE").**
The two findings are the same fact reached from opposite directions: ADR-33 parked
Platform Events as unresolved; the source tree confirms nothing was built. That is
consistent, not contradictory — but it means SC-6 belongs behind an ADR-33 unpark
decision, not in the current beta gate.

**Knock-on:** gate `p2-005-flow-quality-review` reviews Flows. There are zero Flows.
The gate is vacuous — it passes by having nothing to inspect. Treat a green result
there as meaningless until a Flow exists.

### SC-6 — revised

| # | Test | Pass condition |
|---|------|----------------|
| SC-6a | Upload a document through the portal | `Evidence__c` created with hash + scan status |
| SC-6b | Decision written for that evidence | `Decision_Event__c` exists and references a policy record |
| SC-6c | *Deferred behind ADR-33 OQ-3* — `Intake_Received__e` fires and a subscriber consumes it | Not gated for beta. Unbuilt, not broken. |

Beta ships on the synchronous path. The event-driven path is scope, and scope decisions
are Sabir's.

## Out of scope

WS-1 (Brooks plugin binding, goal G-1) and WS-2 (the ADR-33 "Phase D" label). Neither
blocks this goal nor is blocked by it.

**Source:** Sabir directive 2026-08-02; live SOQL against `mortagate-de` 2026-08-03; ADR-30, ADR-33, AD-49; `mortagate.gates.json`.
