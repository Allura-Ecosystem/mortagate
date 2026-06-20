# Symphony Task Runner

**Trigger:** When asked to "run the board", "pick up the next task", "start a Symphony run", or
otherwise dispatch autonomous implementation work from the Notion task board.

**Reads:** `my-project/policies/symphony-workflow.md` (the workflow contract — states, isolation,
validation, handoff). **Adapts:** Symphony orchestrator + `linear` skill → Notion tracker.

---

## Goal

Turn one eligible Notion task into an isolated, validated, landed (or human-handed-off)
implementation run — without supervising every step.

## Steps

1. **Select work.** Query the EDOS Tasks Database (data source
   `collection://49c1d9be-65b3-82a7-b827-8706d14c74dd`) for tasks where Project = Veridact/Mortgage
   Audit and Status ∈ {`Not started`, `In Progress`}. Sort by Priority (High → Low), then Deadline.
   - Use `notion-query-data-sources`; never guess task state — read it.
   - Skip compliance/security sign-off tasks (human-only; see policy Handoff).
2. **Claim it.** Set Status → `In Progress` (`notion-update-page`). One task per run.
3. **Isolate.** Create the worktree:
   `git worktree add .claude/worktrees/<task-key> -b claude/<task-key>` (sanitize `<task-key>`).
4. **Plan, then build.** Brooks plans against the source-of-truth docs; Woz implements. Keep the
   change minimal and reversible.
5. **Sync + commit.** If behind `origin/main`, run `symphony-pull`. Then `symphony-commit`.
6. **Validate.** Run the full gauntlet from the policy (deploy dry-run → Apex → Jest → gates).
   Do not advance on red.
7. **Publish.** `symphony-push` (push + PR). Then `symphony-land` (shepherd to green + squash-merge).
8. **Close the loop in Notion.**
   - Landed: Status → `Completed`, add a comment with the PR URL + tests run.
   - Needs a human (sign-off / Setup-UI / destructive): Status → `On Hold`, comment titled
     `Human Review:` with exactly what the human must do. **This is a successful end-state.**
9. **On stall/failure:** run `symphony-debug` to classify, then retry, fix, or hand off.

## Notion write rules

- Every write carries the Mortgate Project relation so the board stays filterable.
- Memory writes about the run use `group_id: allura-mortgage` (governance).
- Append progress as comments; do not overwrite the task body.

## Concurrency

- Bounded: one active worktree+run per task. Do not start a second task until the current one
  reaches a terminal or handoff state, unless explicitly told to parallelize.

## Output

- A merged PR (or a task parked at `On Hold (Human Review)` with a crisp instruction), and a Notion
  comment trail linking task → PR → tests.

**Source:** openai/symphony SPEC §3 (Orchestrator/Workspace/Agent Runner) + `linear` skill, adapted
to Notion + git worktrees. `my-project/policies/symphony-workflow.md`.
