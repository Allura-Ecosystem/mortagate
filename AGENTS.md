# AGENTS.md — Mortgage Approval Engine (Mortgate)

> **AI-Assisted Documentation**
> Portions of this file were drafted with the assistance of an AI language model. Defer to source code, `copilot-instructions.md`, and team consensus.

## Source of Truth

- **Project:** Salesforce Community Mortgage Approval Engine (Mortgate, brand: Veridact)
- **Memory group:** `allura-mortgage`
- **Org alias:** `mortgate-de`
- **Documentation standard:** Carlos Guidelines (see `copilot-instructions.md` §1)
- **Claude context:** See `CLAUDE.md`
- **AI instructions:** See `copilot-instructions.md`

If documentation conflicts with Salesforce metadata, Apex, Flow XML, LWC source, or JSON schema, defer to source code or schema first.

## Harness: Team RAM (Mortgate)

**Goal:** Provide a Brooks-orchestrated team of specialist agents (Woz, Knuth, Hightower, Pike, Fowler, Bellard) to build, review, deploy, and govern the Salesforce Mortgage Approval Engine under Carlos Guidelines and the Allura memory group `allura-mortgage`.

**Trigger:** When the user requests work on the **Mortgate** project (Salesforce mortgage app, Apex/LWC/Flow code, sf CLI deploy, `mortgate-de` org, or any of the six Carlos Guidelines docs), load the `mortgate-orchestrator` skill and route through Brooks. Simple chat or non-project questions do not require the orchestrator.

**Skills to load in this project (when applicable):**

| Skill                   | When to load                                   |
| ----------------------- | ---------------------------------------------- |
| `mortgate-orchestrator` | Project entry, status, routing, story start    |
| `carlos-guidelines`     | Before writing any code; doc sync work         |
| `sf-deploy`             | sf CLI, org auth, deploy, gate execution       |
| `sf-data-model`         | SObject design, schema review, DATA-DICTIONARY |
| `lwc-craft`             | LWC component build / review                   |
| `apex-quality`          | Apex build, review, refactor                   |

**Required loop:**

```text
Brooks → Scout hydration → Allura Brain (group_id: allura-mortgage) → Skills → Route → Build/review → Validate (mortgate.gates.json) → Log
```

**Non-negotiables:**

- All memory operations use `group_id: "allura-mortgage"`.
- Carlos Guidelines six docs must exist before code lands.
- `mortgate.gates.json` must pass before claiming done.
- `Decision_Event__c` is append-only — never UPDATE/DELETE.
- No DML / SOQL / Get Records inside loops in Apex.
- Source of truth: Schema > Code > Docs.

**Agent registry (canonical):**

| Agent            | File                                                    | Role                          |
| ---------------- | ------------------------------------------------------- | ----------------------------- |
| Brooks (primary) | `.opencode/agent/core/brooks.md`                        | Architect, ADR, contract gate |
| Woz              | `.opencode/agent/subagents/code/woz.md`                 | Apex / LWC / Flow builder     |
| Knuth            | `.opencode/agent/subagents/infrastructure/knuth.md`     | SObject data architect        |
| Hightower        | `.opencode/agent/subagents/infrastructure/hightower.md` | sf CLI, deploy, gates         |
| Pike             | `.opencode/agent/subagents/review/pike.md`              | LWC interface review          |
| Fowler           | `.opencode/agent/subagents/review/fowler.md`            | Apex refactor gate            |
| Bellard          | `.opencode/agent/subagents/code/bellard.md`             | Deep diagnostics / perf       |

**Claude runtime adapter (`.claude/`):**

| Adapter                         | Source                     | Notes                              |
| ------------------------------- | -------------------------- | ---------------------------------- |
| `.claude/agents/{name}.md` (×7) | `.opencode/agent/**/*.md`  | Mirrored for Claude Code / Desktop |
| `.claude/skills/{name}/` (×6)   | `.opencode/skills/{name}/` | Mirrored project skills            |
| `.claude/skills/bmad-*/` (×54)  | pre-existing               | BMad installation (untouched)      |
| `.claude/settings.local.json`   | —                          | MCP + CLI permission grants        |
| `.claude/AGENTS.md`             | —                          | Adapter pointer / change history   |

> `.opencode/` is canonical. `.claude/` is generated. If they drift, `.opencode/` wins.

**Model (canonical):** `ollama-cloud/deepseek-v4-pro` (fallback: `ollama-cloud/deepseek-v4-pro`).
**Harness:** Mortgate runs its own independent Team RAM harness — a unique fork under `.opencode/agent/` and `group_id: allura-mortgage`. It is not derived live from OpenAgentsControl.
**Model (Claude adapter):** `opus` (per `.claude/agents/*.md` frontmatter).

## Change History

| Date       | Change                   | Target                                                                                                   | Reason                                                                                                      |
| ---------- | ------------------------ | -------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------- |
| 2026-06-06 | Initial Team RAM install | `.opencode/agent/`, `.opencode/skills/`, `AGENTS.md`                                                     | Add governed Brooks-orchestrated agent team to Mortgate project under Allura memory group `allura-mortgage` |
| 2026-06-06 | Claude runtime adapter   | `.claude/agents/`, `.claude/skills/mortgate-*/` etc., `.claude/settings.local.json`, `.claude/AGENTS.md` | Mirror canonical Team RAM to Claude Code / Desktop runtime                                                  |
