---
name: mortgate-orchestrator
description: "PRIMARY — Mortgate team orchestrator. Routes work to Team RAM specialists (Woz, Knuth, Hightower, Pike, Fowler, Bellard). Triggers on any Mortgate (Salesforce Mortgage Approval Engine) task. Use this skill to start a Mortgate session, route a story, or check project status."
---

# Mortgate Team RAM Orchestrator

This is the entry point for all work on the **Salesforce Community Mortgage Approval Engine** (project codename: **Mortgate**, brand: **Veridact**).

## When to Use This Skill

Use this skill when the user mentions:

- "Mortgate", "mortgage approval engine", "Veridact", "mortgate-de"
- Salesforce org auth, scratch orgs, deploy gates
- Apex, LWC, Flow work for the mortgage app
- Policy engine, decision engine, Decision_Event__c
- Carlos Guidelines compliance for the mortgage project

If a task touches the Mortgage project at `/media/ronin704/Games/Projects/Mortage/`, **start with this skill**.

## Required Startup

Before any work, the orchestrator MUST:

1. **Hydrate from local context** (read in parallel):
   - `CLAUDE.md` (memory group, org alias)
   - `copilot-instructions.md` (Carlos Guidelines, Flow standards, LWC standards)
   - `mortgate.gates.json` (gate contract)
   - `docs/BLUEPRINT.md` (B# / F#)
   - `docs/SOLUTION-ARCHITECTURE.md`
   - `docs/RISKS-AND-DECISIONS.md`
   - `docs/DATA-DICTIONARY.md`
   - `docs/REQUIREMENTS-MATRIX.md`
   - `sfdx-project.json`

2. **Search Allura Brain** with `group_id: "allura-mortgage"`:
   ```
   allura-brain_memory_search({ query: "active tasks blockers architecture decisions", group_id: "allura-mortgage", limit: 10 })
   allura-brain_memory_search({ query: "recent outcomes lessons patterns", group_id: "allura-mortgage", limit: 5 })
   allura-brain_memory_list({ group_id: "allura-mortgage", user_id: "brooks-architect-mortgage", limit: 10, sort: "created_at_desc" })
   ```

3. **Inspect Git HEAD**:
   ```
   git status --short --branch
   git log origin/main..HEAD --oneline
   ```

4. **Load the `carlos-guidelines` skill** (Carlos Guidelines is the documentation standard).

5. **Present status + menu** (see "Standard Status" below).

---

## Team RAM Roster

| Agent | Role | Subagent File | Use When |
|---|---|---|---|
| **Brooks** | Architect, contract, ADR | `core/brooks.md` | Architecture, ADRs, contract drift, routing |
| **Woz** | Apex/LWC/Flow builder | `subagents/code/woz.md` | Implementing a story |
| **Knuth** | Data architect (SObjects) | `subagents/infrastructure/knuth.md` | Schema design, DATA-DICTIONARY |
| **Hightower** | DevOps (sf CLI, deploy) | `subagents/infrastructure/hightower.md` | Org auth, deploy, gates |
| **Pike** | LWC interface review | `subagents/review/pike.md` | LWC review, simplicity, accessibility |
| **Fowler** | Refactor safety | `subagents/review/fowler.md` | Apex refactor, code smells |
| **Bellard** | Deep diagnostics | `subagents/code/bellard.md` | Hard SOQL/Apex runtime issues |

**Execution mode:** Sub-agent pattern. Brooks orchestrates; specialists do work and return receipts.

---

## Skills

| Skill | Purpose |
|---|---|
| `mortgate-orchestrator` (this skill) | Entry point, routing, status |
| `carlos-guidelines` | Carlos Guidelines documentation discipline |
| `sf-deploy` | sf CLI, gate execution, org auth |
| `sf-data-model` | SObject metadata, schema review |
| `lwc-craft` | LWC component standards, one-thing-per-screen |
| `apex-quality` | Apex bulk-safety, testing, refactor |

---

## Standard Status Shape

After hydration, the orchestrator should present:

```text
Mortgate — Status
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Project:       Salesforce Community Mortgage Approval Engine
Memory group:  allura-mortgage
Org alias:     mortgate-de
Gate contract: mortgate.gates.json
Doc standard:  Carlos Guidelines (six required docs)

Scout hydration:
- Local context: <files checked>
- Allura Brain: <query, group_id, status>
- Git HEAD: <branch, ahead count, latest commit>

Where we are:
- ...

Route:
- ...
```

---

## Routing Rules

1. **Architecture / ADRs / contract drift** → Brooks (primary)
2. **Apex / LWC / Flow implementation** → Woz
3. **SObject / schema / DATA-DICTIONARY** → Knuth
4. **Deploy / sf CLI / gates** → Hightower
5. **LWC review / simplicity** → Pike
6. **Apex refactor / code smells** → Fowler
7. **Hard runtime / SOQL / governor limits** → Bellard

**Iron law:** No fix ships without `debug:root_cause_found` logged to Brain. Brooks enforces this.

---

## Required Loop

For any implementation task:

```text
Brooks → Scout hydration → Allura Brain → Skills → Route → Build/review → Validate → Log
```

Plain English:

1. Brooks owns the chair.
2. Scout/context comes before code.
3. Allura memory supplements context (group_id: allura-mortgage).
4. Skills provide playbooks.
5. Woz or another specialist builds only after context is loaded.
6. Hightower runs `mortgate.gates.json` for validation.
7. Important results go back into Allura Brain.

---

## Non-Negotiables

- Always use `group_id: allura-mortgage` for Mortgate memory operations.
- Carlos Guidelines six docs must exist before any code lands.
- `mortgate.gates.json` must pass before claiming done.
- `Decision_Event__c` is append-only — no UPDATE/DELETE.
- No DML inside loops, no SOQL inside loops, no Get Records inside loops.
- AI-drafted docs must include the disclosure notice.
- Source of truth: Schema > Code > Docs.
- Brooks is primary; do not pretend OpenCode, Scout, or Woz ran unless a real subagent was invoked.
