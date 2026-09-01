# AGENTS.md — Mortgage Approval Engine (Mortgate)

> **AI-Assisted Documentation**
> Portions of this file were drafted with the assistance of an AI language model. Defer to source code, `copilot-instructions.md`, and team consensus.

## Source of Truth

- **Product (current):** **Mortgate Evidence Review for Microsoft Copilot Cowork** — a native Microsoft 365 Copilot Cowork skills package under `microsoft-cowork/`. This is the whole product. Decision record: **ADR-36** (platform pivot to Cowork-only) in `planning docs/RISKS-AND-DECISIONS.md`.
- **Deprecated:** The prior **Salesforce Community Mortgage Approval Engine** (brand: Veridact) is no longer active product. Its legacy metadata (`force-app/`, `sfdx-project.json`, Apex/LWC/Flow) and old Carlos docs remain in-repo for reference only; do not develop or deploy to it.
- **Memory group:** `allura-mortgage`
- **Documentation standard:** Carlos Guidelines; current Cowork product docs are indexed from `README.md` and governed by ADR-36 in `planning docs/RISKS-AND-DECISIONS.md`.
- **Claude context:** See `CLAUDE.md`
- **AI instructions:** See `.github/copilot-instructions.md`

If documentation conflicts with the Cowork module's manifest, skill definitions, or JSON schema, defer to source code or schema first.

## Harness: Team RAM (Mortgate)

**Goal:** Provide a Brooks-orchestrated team of specialist agents (Woz, Knuth, Hightower, Pike, Fowler, Bellard) to build, review, and govern the **Mortgate Evidence Review for Microsoft Copilot Cowork** plugin under Carlos Guidelines and the Allura memory group `allura-mortgage`.

**Trigger:** When the user requests work on the **Mortgate** project (the Cowork plugin, `microsoft-cowork/`, its four Agent Skills, the Cowork package manifest, gate execution, or Cowork-scoped planning docs), load the `mortgate-orchestrator` skill and route through Brooks. Simple chat or non-project questions do not require the orchestrator.

**Skills to load in this project (when applicable):**

| Skill                   | When to load                                   |
| ----------------------- | ---------------------------------------------- |
| `mortgate-orchestrator` | Project entry, status, routing, story start    |
| `carlos-guidelines`     | Before writing any code; doc sync work         |

> The legacy Salesforce skills (`sf-deploy`, `sf-data-model`, `lwc-craft`, `apex-quality`) apply only to the deprecated Salesforce implementation and are **not** part of current Cowork product work.

**Required loop:**

```text
Brooks → Scout hydration → Allura Brain (group_id: allura-mortgage) → Skills → Route → Build/review → Validate (mortagate-cowork.gates.json) → Log
```

**Non-negotiables:**

- All memory operations use `group_id: "allura-mortgage"`.
- Carlos Guidelines six docs must exist before code lands — but for the Cowork product, work from Cowork-scoped planning artifacts (`my-project/_bmad-output/planning-artifacts/`) and keep `planning docs/RISKS-AND-DECISIONS.md` live (ADR-34/35/36). Do not edit the other five legacy Carlos docs in place for current work.
- `mortagate-cowork.gates.json` is the **active** gate file and must pass before claiming done. (`mortgate.gates.json` verifies the deprecated Salesforce implementation and does not apply.)
- Source of truth: Source / schema > Code > Docs.

**Agent registry (canonical):**

| Agent            | File                                                    | Role                          |
| ---------------- | ------------------------------------------------------- | ----------------------------- |
| Brooks (primary) | `.opencode/agent/core/brooks.md`                        | Architect, ADR, contract gate |
| Woz              | `.opencode/agent/subagents/code/woz.md`                 | Builder (legacy Apex/LWC/Flow; Cowork packaging) |
| Knuth            | `.opencode/agent/subagents/infrastructure/knuth.md`     | Data architect (legacy SObject) |
| Hightower        | `.opencode/agent/subagents/infrastructure/hightower.md` | Deploy / gates (legacy sf CLI; Cowork package validation) |
| Pike             | `.opencode/agent/subagents/review/pike.md`              | Interface review (legacy LWC; Cowork skill UX) |
| Fowler           | `.opencode/agent/subagents/review/fowler.md`            | Refactor gate (legacy Apex) |
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
| 2026-08-29 | Doc sync to Cowork-only | `AGENTS.md`                                                                                              | Align with ADR-36 / CLAUDE.md: `microsoft-cowork/` is the product, `mortagate-cowork.gates.json` is the active gate, Salesforce implementation marked deprecated |
