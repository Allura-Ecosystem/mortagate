# Agent Routing — Team RAM (Mortgate)

## Team
| Agent | Role | Use When |
|-------|------|----------|
| Brooks | Architect + Orchestrator | Task planning, architecture, delegation |
| Woz | Builder | Apex, LWC, Flow implementation |
| Knuth | Data Architect | SObject design, schema review |
| Hightower | DevOps | sf CLI, deploy, gates |
| Pike | Interface Gate | LWC review, simplification |
| Fowler | Refactor Gate | Apex review, incremental change |
| Bellard | Diagnostics | Performance, measurement |

## Tool Restrictions
| Agent | Denied Tools | Why |
|-------|-------------|-----|
| Pike | write, edit, task | Read-only consultation |

## Invariants
- group_id = 'allura-mortgage' on every DB operation
- Carlos Guidelines enforced before code lands
- mortagate.gates.json must pass before claiming done
