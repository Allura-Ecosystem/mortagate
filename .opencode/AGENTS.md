# Agent Directory

This file defines the **live agent surface** for the Team RAM Mortgate Harness,
a unique deployment running under `group_id: allura-mortgage` with its own
`.opencode/agent/` ownership. It follows the Allura Overlay pattern but is
not derived live from OpenAgentsControl.

## Architecture Principle

> **OAC Core:** Context-first, plan-first, validation-first.
> **Allura Overlay:** Team RAM personas, Brain memory, governance, HITL, Brooks orchestration.
> **Memory supplements context; it does not replace it.**

## Canonical Rule

The nested files in `.opencode/agent/` are the only live agent definitions in this repo.
`.claude/agents/` is a Claude runtime adapter that mirrors those definitions.

> `.opencode/` is canonical. `.claude/` is generated.

If the two diverge, `.opencode/` wins. Brooks owns the canonical surface; Pike owns the adapter simplicity.

```text
.opencode/agent/
├── brooks.md              ← Architect + Orchestrator (PRIMARY)
├── woz.md                 ← Primary builder (Apex, LWC, Flow)
├── bellard.md             ← Diagnostics + perf
├── carmack.md             ← (reserved — not active in Mortgate)
├── scout.md               ← Recon + discovery (ContextScout)
├── pike.md                ← Interface simplicity (LWC)
├── fowler.md              ← Refactor safety (Apex)
├── knuth.md               ← Data architect (SObject)
└── hightower.md           ← DevOps (sf CLI, deploy, gates)
```

## ContextScout First Gate (MANDATORY)

Every implementation task must follow this execution sequence:

```
User task
  ↓
① Scout loads local .opencode/context files
  ↓
② Scout searches Allura Brain for prior decisions/blockers
  ↓
③ Skill resolver identifies required skills
  ↓
④ Builder executes with loaded context + skills
  ↓
⑤ Validation passes before done
```

**No agent may skip step ①.** Woz and all builders must have Scout context
loaded before writing implementation code.

## Ralph Skill Gate (MANDATORY)

Ralph may not execute unless this gate passes:

```json
{
  "context_loaded": true,
  "context_files": [],
  "brain_memories_checked": true,
  "required_skills": [],
  "skills_loaded": [],
  "validation_commands": []
}
```

**Failure conditions (Ralph MUST refuse):**

- No Scout context loaded
- Missing required skill
- Stale context without acknowledgment
- Missing validation command

## Team RAM

| Agent     | Persona                 | Role                               | Mode     |
| --------- | ----------------------- | ---------------------------------- | -------- |
| Brooks    | Frederick P. Brooks Jr. | Architecture and orchestration     | primary  |
| Woz       | Steve Wozniak           | Primary builder (Apex, LWC, Flow)  | subagent |
| Bellard   | Fabrice Bellard         | Deep diagnostics + perf            | subagent |
| Scout     | Utility role            | Discovery and recon (ContextScout) | subagent |
| Pike      | Rob Pike                | Interface simplicity (LWC)         | subagent |
| Fowler    | Martin Fowler           | Refactor safety (Apex)             | subagent |
| Knuth     | Donald Knuth            | Data and schema (SObject)          | subagent |
| Hightower | Kelsey Hightower        | Infra and deployment (sf CLI)      | subagent |

## Team RAM as Overlay

Team RAM personas consume OAC context — they do not replace it.

- **Brooks** = architecture/orchestration (consumes context/project/, context/navigation.md)
- **Scout** = ContextScout + Brain retrieval (consumes context/, Brain search)
- **Woz** = builder (consumes context/project/, skills/apex-quality, skills/lwc-craft)
- **Pike** = interface review (consumes skills/lwc-craft)
- **Fowler** = refactor gate (consumes skills/apex-quality)
- **Knuth** = data/schema (consumes skills/sf-data-model)
- **Hightower** = infra (consumes skills/sf-deploy)
- **Bellard** = diagnostics/performance (consumes skills/apex-quality)

## Skill Assignment Matrix

| Owner      | Required skills                                                                                           | Optional / routed skills                  | Notes                                                |
| ---------- | --------------------------------------------------------------------------------------------------------- | ----------------------------------------- | ---------------------------------------------------- |
| All agents | `allura-memory-skill`                                                                                     | `systematic-debugging`                    | Memory governance is mandatory.                      |
| Brooks     | `mortgate-orchestrator`, `carlos-guidelines`, `sf-deploy`, `sf-data-model`, `party-mode`, `skill-creator` | `lwc-craft`, `apex-quality` (for routing) | Brooks orchestrates; he routes, doesn't hoard.       |
| Scout      | `allura-memory-skill`                                                                                     | —                                         | Scout owns Brain/search recon and context discovery. |
| Woz        | `lwc-craft`, `apex-quality`, `sf-deploy`, `carlos-guidelines`                                             | —                                         | Woz builds with loaded context.                      |
| Knuth      | `sf-data-model`, `carlos-guidelines`                                                                      | —                                         | Knuth owns SObject schema integrity.                 |
| Hightower  | `sf-deploy`, `carlos-guidelines`                                                                          | —                                         | Hightower owns deployability and gates.              |
| Pike       | `lwc-craft`                                                                                               | —                                         | Pike owns LWC interface simplicity.                  |
| Fowler     | `apex-quality`                                                                                            | —                                         | Fowler owns Apex refactor safety.                    |
| Bellard    | `apex-quality`                                                                                            | —                                         | Bellard owns diagnostics + performance.              |

## Execution Rule

**Scout before build. Skills before Ralph. Validate before done.**

## Source of Truth

- `.opencode/AGENTS.md` — This file (live agent surface)
- `.opencode/config/agent-metadata.json` — Machine-readable agent registry
- `.opencode/config/agent-skills.json` — Skill ownership matrix
- `.opencode/agent/` — Active Team RAM agent definitions
- `.opencode/command/` — Reusable workflow commands
- `.opencode/skills/` — Skill definitions and supporting assets

## Memory Group

All memory operations for Mortgate use `group_id: "allura-mortgage"`. Each agent has its own `user_id` suffix (e.g., `brooks-architect-mortgage`, `woz-builder-mortgage`).

## Change History

| Date       | Change                                                   | Reason                                        |
| ---------- | -------------------------------------------------------- | --------------------------------------------- |
| 2026-06-06 | Initial harness install                                  | Mirror canonical Team RAM to Mortgate project |
| 2026-06-07 | Flatten agent dir, add Scout, align with OAC conventions | Sync with OpenAgentsControl reference         |
