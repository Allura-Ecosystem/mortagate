# Symphony Workflow Contract — Mortgate

**Always-on.** This is the repository-owned workflow contract (Symphony's `WORKFLOW.md`
equivalent, in Mortgate house style). It defines how an autonomous implementation run picks up
work, isolates it, validates it, and hands it off. Symphony is a scheduler/runner: ticket writes
and PR work are done by the agent using the `symphony-*` skills, governed by the rules below.

**Source:** [openai/symphony SPEC.md](https://github.com/openai/symphony) §1–§5, adapted to the
Mortgate BMad + Salesforce harness. Adaptations: tracker `linear → notion`, validation
`make -C elixir all → mortagate.gates.json + sf + sfdx-lwc-jest`, workspace `temp dir → git worktree`.

---

## Tracker (board of record)

- `kind`: **notion** (via MCP_DOCKER `notion-*` tools). Linear is NOT configured here.
- Task source: **EDOS: Tasks Database** (`collection://49c1d9be-65b3-82a7-b827-8706d14c74dd`),
  filtered to the Mortgate `Project` relation.
- Repo gates of record: `mortagate.gates.json` (phase-0 → phase-2). Notion tracks *intent*;
  the gate runner + org are the *truth*. If they conflict, defer to gates/org.
- `required_labels` / equivalent: a task is eligible only when its **Project** = Veridact/Mortgage
  Audit and **Status** ∈ active states below. Compliance/security sign-off tasks are HUMAN-ONLY
  (never auto-dispatched — see Handoff).

## States

- **active** (dispatch / continue): `Not started`, `In Progress`
- **handoff** (run ends here, NOT terminal): `On Hold` → used for **Human Review** / sign-off gates
- **terminal** (clean up, never dispatch): `Completed`, `Cancelled`, `Scheduled`

A successful run MAY end at `On Hold (Human Review)` — that is success, not failure, for any task
that crosses a compliance, security, or org-destructive boundary.

## Isolation (per-task workspace)

- One **git worktree per task**, never work on the shared checkout:
  `git worktree add .claude/worktrees/<task-key> -b claude/<task-key>`
- `<task-key>` = task title sanitized: replace any char not in `[A-Za-z0-9._-]` with `_`.
- Worktrees live under `.claude/worktrees/` (gitignored). `temp/` is scratch only (gitignored).
- Agent commands run **only inside the task worktree**.

## Validation gauntlet (must be green before push/land)

Run in this order; fail-fast:

1. **Deploy validate:** `sf project deploy start --dry-run --target-org mortagate-de`
2. **Apex tests:** `sf apex run test --target-org mortagate-de --test-level RunLocalTests --result-format human --wait 30`
3. **LWC Jest:** `npm run test:unit`
4. **Gate runner:** the phases in `mortagate.gates.json` relevant to the change (see `gate-runner` skill).

Do not claim Salesforce gate completion until these pass against `mortagate-de` (CLAUDE.md rule).

## Handoff rules (when a run STOPS for a human)

Stop and move the task to `On Hold (Human Review)` — do not merge, do not proceed — when the work:

- requires a **compliance** (OQ-R8-2/4/6) or **security** (OQ-R8-1/7) sign-off;
- is a Setup-UI-only Salesforce action (e.g. activating the default Agentforce agent);
- crosses a borrower-facing contract, schema migration, or irreversible org/data change;
- deletes metadata or runs a destructive `sf`/`git` operation.

## Governance invariants (inherited, non-negotiable)

- `group_id: allura-mortgage` on every memory/DB op; namespace must match `^allura-[a-z0-9-]+$`.
- PostgreSQL events append-only; Neo4j versioning via SUPERSEDES; HITL for promotion.
- DB ops via MCP tools only — never `docker exec`.
- Never skip git hooks/signing; create NEW commits (no blind `--amend`); no force-push to main.
- Enforced by the `governance-preflight.py` hook (see `allura-tenant` policy).

## Run lifecycle (summary)

```
pick eligible task (Notion)                       → symphony-task-runner
  └─ create worktree, mark In Progress
     └─ implement (Brooks plan → Woz build)
        └─ pull origin/main if behind             → symphony-pull
        └─ commit                                 → symphony-commit
        └─ run validation gauntlet (above)
        └─ push + open PR                         → symphony-push
        └─ shepherd PR to green + merge           → symphony-land
        └─ on stall/failure: trace + classify     → symphony-debug
  └─ end at Completed  OR  On Hold (Human Review)
```
