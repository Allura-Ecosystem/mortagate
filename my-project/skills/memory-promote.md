# Memory Promote Pipeline

**Trigger:** After substantive architectural work, or on request.

---

## Steps

1. List recent episodic memories:
   ```
   memory_list({ group_id: "allura-mortgage", user_id: "{agent_id}", sort: "created_at_desc" })
   ```
2. For each, assess promotion eligibility:
   - Confidence >= 0.85?
   - Stable canonical knowledge (not time-bound)?
   - Not a session trace or snapshot with mutable status flags?
3. For eligible memories, call:
   ```
   memory_promote({ id, group_id: "allura-mortgage", rationale })
   ```
4. Route to HITL approval (`curator:approve`) — never auto-approve.
5. After approval, verify retrieval via `memory_search`.

## Promotion Criteria

**PROMOTE:** ADRs, schema definitions, engine architecture, design specs, brand rules, invariants.

**KEEP EPISODIC:** Status snapshots, readiness reports, session traces, anything with mutable flags (status icons, completion percentages, "not yet run" claims).

**Source:** Allura governance invariants, allura-approve-promotion skill.
