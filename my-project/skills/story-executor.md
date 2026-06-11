# Story Executor

**Trigger:** When picking up a US-X.X story for implementation.

---

## Steps

1. Load story from EPICS-AND-STORIES.md by ID.
2. Check if blocked (legal, vendor, dependency on prior story). If blocked, stop and report.
3. Hand to `mortgate-orchestrator` skill for specialist routing and execution.
4. Definition of Done (verify before marking complete):
   - [ ] Acceptance criteria met
   - [ ] Tests written and passing
   - [ ] Relevant Carlos doc updated in same PR
   - [ ] Gate runner passes for affected phase
   - [ ] Brain trace written (`memory_add` with `group_id: allura-mortgage`)
5. Update story status in EPICS-AND-STORIES.md.

## Lightweight Path

For stories estimated under 2 hours, Brain search (pre-work) and Brain trace (post-work) are optional.

**Source:** EPICS-AND-STORIES.md, mortgate-orchestrator skill.
