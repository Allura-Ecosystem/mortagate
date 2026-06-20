# Symphony Debug

**Trigger:** When a Symphony run stalls, retries, or fails unexpectedly — classify the failure and
isolate root cause before retrying. Honors the Iron Law: **no fix without a confirmed root cause.**

**Adapts:** openai/symphony `debug` skill → there is no `log/symphony.log` daemon here; the run
*is* the agent session + the task worktree + Salesforce org. Trace those instead.

---

## Correlation keys

- **task-key** — sanitized Notion task title; the worktree dir + branch (`claude/<task-key>`).
- **Notion page id** — the task row (stable id in EDOS Tasks Database).
- **org alias** — `mortagate-de`; deploy/test failures surface there, not in a local log.

## Quick triage

1. **Locate the run:** which worktree + branch + Notion task. `git -C .claude/worktrees/<task-key>
   status -sb`, `git log --oneline -5`.
2. **Classify the failure** into one bucket:
   - **Validation red** — deploy dry-run, Apex, Jest, or a gate failed. Most common; usually a real
     code/metadata defect.
   - **Sync/merge stall** — push rejected, conflicts unresolved, branch behind `origin/main`.
   - **Tooling/auth wall** — `sf` not authenticated to `mortagate-de`, `gh` not authed, MCP/Notion
     unreachable. Environmental, not a project defect.
   - **Persistence illusion** — green deploy but metadata didn't persist (planner bundle, flow):
     trust-but-verify miss, re-check via Tooling API.
   - **Stuck/looping run** — same step retried with no state change.
3. **Get the real error** (don't guess):
   - Deploy: `sf project deploy start --dry-run --target-org mortagate-de` and read the component
     failures (file + line).
   - Apex: `sf apex run test --target-org mortagate-de --test-level RunLocalTests --result-format human --wait 30`; for a specific failure pull the run id and `sf apex get test --test-run-id <id>`.
   - Jest: `npm run test:unit` (add `-- <path>` to isolate one spec).
   - Gates: re-run the failing phase via `gate-runner`; read its evidence output.
   - Org-side state: `sf data query` / Tooling-API check to confirm what actually persisted.
4. **Decide root cause**, then act: fix-forward (back to the gauntlet), `symphony-pull` for sync
   stalls, or hand off if it's a tooling/auth wall or a human-only boundary.

## Classify → action

| Class | Signal | Action |
|---|---|---|
| Validation red | component/test/gate failure | Fix the source, re-run gauntlet. Don't advance on red. |
| Sync/merge stall | non-fast-forward, conflicts | `symphony-pull`, re-validate, `symphony-push`. |
| Tooling/auth wall | not authenticated / unreachable | Surface exact error; re-auth or hand off. Not a code fix. |
| Persistence illusion | green deploy, missing at runtime | Re-retrieve / Tooling-API verify; fix the bundle, redeploy. |
| Stuck/looping | retried, no state change | Stop the loop; capture evidence; escalate to a human. |

## Rules

- **Iron Law:** capture the exact failing component/test/line + the run that produced it before
  proposing a fix. No speculative retries.
- Isolate one failure at a time; re-run the relevant check after each fix.
- A confirmed tooling/auth wall or a compliance/security/Setup-UI boundary is a **handoff**
  (`On Hold (Human Review)`), not a defect to grind on.
- Record root cause + failing stage to memory (`group_id: allura-mortgage`) so a retry doesn't
  repeat it.

**Source:** openai/symphony `debug` skill, re-keyed from `symphony.log`/`session_id` to
worktree + `mortagate-de`; Mortgate Iron Law + trust-but-verify.
