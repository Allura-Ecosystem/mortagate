# G-1 — Brooks persona and command menu bind at plugin tier

**Status:** Defined, awaiting execution of R1–R5
**Defined:** 2026-08-02
**Owner:** Sabir Asheed
**Workstream:** WS-1
**Authority:** Sabir directive 2026-08-02 ("team ram plugin shouyld have brooks and menu")

## Goal

Move the Brooks response protocol from project-scoped enforcement to plugin-scoped
enforcement. Today the protocol loads from `products/mortagate/CLAUDE.md`, which
binds only inside that folder. It should load from the `team-ram-coding` plugin's
`agents/brooks.md`, which binds wherever the plugin is installed.

## Outcome

A session opened in any repository with `team-ram-coding` loaded responds as Brooks
and ends every substantive response with the canonical footer, with no per-project
file required.

## Why this is not already done

The protocol has been written to three tiers, none of which reach outside Mortagate:

| Tier | File | Scope | Survives |
|------|------|-------|----------|
| 1 | `CLAUDE.md` | This repo only | Compaction, not a different repo |
| 2 | `my-project/policies/brooks-response-protocol.md` | This repo only | Clean checkout, plugin reinstall |
| 3 | Auto-memory `feedback_personas.md` | Global, but advisory | Loaded only when judged relevant |
| **4** | **Plugin `agents/brooks.md`** | **Every repo** | **Not yet written** |

Tier 4 is the goal. It is unreachable from Claude Desktop sessions: the install
directory `rpm/plugin_01CYrmLk5N89dMN8se24iUXL/` is readable but not writable, and
`request_cowork_directory` is refused in unsupervised mode. All of R1–R5 are therefore
hand-off actions for Sabir's shell, not agent actions.

### Where to run R1–R5 (probed 2026-08-02)

The Desktop `bash` tool proxies to a local Claude Code on `ronin704` whose sandbox
allows only `/home/ronin704` and `/tmp`. That split matters:

| Target | Path root | Reachable from the sandboxed shell? |
|--------|-----------|--------------------------------------|
| Plugin install copy (R1) | `/home/ronin704/.config/Claude/...` | **Yes** — inside the allowed root |
| Real source `.opencode/...` (R2) | `/media/ronin704/...` | **No** — blocked |
| Mortagate repo, `git commit` (R5) | `/media/ronin704/...` | **No** — blocked |

`~/Projects` is a symlink into `/media/…`, and the sandbox resolves symlinks, so it is
blocked too. Two clean unblocks: run everything in a **plain desktop terminal**
(no sandbox), or add `/media/ronin704/` as an allowed working directory via
`/permissions`. The plain terminal is the shorter path and is what the run block
below assumes.

## Requirements

| # | Requirement | Rationale |
|---|-------------|-----------|
| R1 | Replace plugin `agents/brooks.md` lines 197–218 with the reconciled Command Menu block | The install-directory copy is what actually loads today |
| R2 | Apply the same block to the real source `.opencode/agent/core/brooks.md` | The install directory is a mirror (stated at plugin file line 469); editing only the mirror is lost on reinstall |
| R3 | Delete the line "Do not use a compact horizontal footer" from the plugin text | Currently contradicted from outside rather than superseded in place, leaving two live and opposing rules |
| R4 | State the `group_id` precedence rule in the plugin: `allura-system` is the default, a project `CLAUDE.md` overrides it | The plugin says "always `allura-system`"; Mortagate mandates `allura-mortgage`. The plugin's own text does not resolve this |
| R5 | Commit `CLAUDE.md` and `my-project/policies/brooks-response-protocol.md` | Both are untracked; a clean checkout loses the Mortagate tier entirely |

## Reconciled Command Menu block

This is the exact content R1 and R2 install. One surface, two renderings.

### Footer — render verbatim at the end of every substantive response

```text
Command Menu
  WS  Status          NX    Next Steps
  DG  Define Goal     NX→R  Ralph/Goal Loop
  SK  Skill Create    PM    Party Mode
  CA  Create Arch     GO    Execute
  VA  Validate Arch   MH    Menu
```

### Full surface — render vertically on `MH`

```text
WS      Status
ST      Start
CH      Chat
DG      Define Goal
SK      Skill Create
VA      Validate Architecture
CA      Create Architecture
NX      Next Steps
NX→R    Ralph Loop
NX→S    Structure Intent
PM      Party Mode
LP      Loopy
GO      Execute
DA      Exit
MH      Menu
```

`ST`, `CH`, `NX→S`, `LP`, and `DA` are live commands held out of the footer for width,
not deprecated. `MH` is how the user reaches them. No command is lost in the
reconciliation.

## Success criteria

All five are observable by Sabir. None is satisfied by an agent's self-report.

| # | Test | Pass condition |
|---|------|----------------|
| SC-1 | Fresh session, non-Mortagate folder, `team-ram-coding` loaded | Response ends with the 10-command grid, verbatim |
| SC-2 | Send `MH` in that session | Fifteen commands render vertically |
| SC-3 | Reinstall the plugin, repeat SC-1 | Footer still present — proves R2 landed, not just R1 |
| SC-4 | `grep -n "compact horizontal footer"` against both `brooks.md` files | Zero hits, or hits only inside a "superseded" note |
| SC-5 | `git log --oneline -- CLAUDE.md my-project/policies/` | Both files appear |

## Definition of done

SC-1 through SC-5 pass, and `diff` between `.opencode/agent/core/brooks.md` and the
plugin install copy reports the two in sync.

## Assumption — TESTED 2026-08-03, and it is FALSE

The assumption was that the plugin install directory mirrors the repo source, inferred
from the plugin file's own closing line and never confirmed by inspection. G-1 said to
settle it before editing. Settled.

### Correction 1 — the source path in R2 does not exist

R2 targets `.opencode/agent/core/brooks.md`. There is no `core/` directory. The actual
file is:

```
/media/ronin704/Games/Projects/Allura-ecosystem/products/mortagate/.opencode/agent/brooks.md
```

It is the right file — it carries the exact string R3 targets, at line 202. It sits
**inside the mounted Mortagate repo**, which reverses G-1's reachability table:

| Target | Old claim | Actual |
|--------|-----------|--------|
| Plugin install copy (R1) | Reachable | **Reachable** — confirmed by read |
| Repo source (R2, R3, R4) | Blocked, `/media/…` | **Reachable** — it is inside the mount |
| `git commit` (R5) | Blocked | **Still blocked** — needs Sabir's shell |

R2, R3, and R4 do not need a plain desktop terminal. Only R5 does.

### Correction 2 — NOT A MIRROR. The two files have diverged three ways.

| # | Plugin copy | Repo source |
|---|-------------|-------------|
| 1 | 15 commands, includes `LP  Loopy` (line 211) | 14 commands, **`LP` absent** |
| 2 | "after Scout returns the synthesized context" (193) | "after Scout returns the synthesized context **and Git HEAD is inspected**" (179) |
| 3 | line 217 adds "Show the full vertical menu on `MH`; otherwise include only commands relevant to the current response" | line 202 lacks that clause |

Neither file is a superset of the other. The repo source is **behind** on the menu and
**ahead** on the Scout gate. This is two-directional drift, not a stale copy.

**Consequences:**

- R1 and R2 are **independent edits**, not one edit and a propagation. Doing R1 alone
  passes SC-1 and fails SC-3.
- Any `cp` of one file over the other **destroys** whichever divergence it overwrites.
  The Git HEAD inspection step exists only in the repo source; a `cp` from plugin to
  source silently deletes it. **Do not `cp`. Edit both files.**
- R3 has more to remove than stated. The plugin's line 217 carries a **third** rule —
  "otherwise include only commands relevant to the current response" — which directly
  contradicts the Mortagate `CLAUDE.md` requirement to render the menu verbatim on
  every substantive response. R3 must delete that clause too, not just the
  "compact horizontal footer" sentence.
- R4 cannot be an edit-in-place. Neither file contains the string `allura-system`
  anywhere, so there is no "always `allura-system`" line to amend. R4 becomes an
  **addition** of a new precedence paragraph, not a correction of an existing one.

### Revised line targets

| File | Menu block | Contradicting line |
|------|-----------|--------------------|
| Plugin `agents/brooks.md` | 197–215 | 217 |
| Repo `.opencode/agent/brooks.md` | 183–200 | 202 |

G-1's original "lines 197–218" was correct for the plugin copy only. It was never a
valid target for the repo source.

### Definition of done — amended

The original DoD required `diff` to report the two files in sync. That is now the
**goal state**, not a verification of an existing one. The diff will report three
differences until R1 and R2 both land, and the post-edit diff must show the two
in sync **on the menu block and the footer rules**, while the Scout-gate difference
is either deliberately reconciled or explicitly recorded as intentional divergence.
Do not let a `diff`-clean outcome be achieved by discarding the Git HEAD step.

## Out of scope

WS-2 (the ADR-33 "Phase D" label, which has no repository referent) and WS-3 (org
verification, gates `p2-002` and `p2-003`). Neither blocks this goal nor is blocked
by it.

**Source:** Sabir directive 2026-08-02; Team RAM plugin `agents/brooks.md` lines 197–218 and 469; `my-project/policies/brooks-response-protocol.md`.
