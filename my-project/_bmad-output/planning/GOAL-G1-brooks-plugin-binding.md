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

## Assumption to verify before editing

That the install directory is a mirror of `.opencode/agent/core/brooks.md`. This is
inferred from the plugin file's own closing line ("This agent is mirrored from
`.opencode/agent/core/brooks.md`"), not confirmed by inspection. If the two are not
in a mirror relationship, R1 and R2 are independent edits and SC-3 will fail. Run the
diff in the Definition of Done **before** editing, not after — it is the cheapest way
to settle this and it costs one command.

## Out of scope

WS-2 (the ADR-33 "Phase D" label, which has no repository referent) and WS-3 (org
verification, gates `p2-002` and `p2-003`). Neither blocks this goal nor is blocked
by it.

**Source:** Sabir directive 2026-08-02; Team RAM plugin `agents/brooks.md` lines 197–218 and 469; `my-project/policies/brooks-response-protocol.md`.
