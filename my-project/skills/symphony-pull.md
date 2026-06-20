# Symphony Pull (update-branch)

**Trigger:** When a task worktree is behind `origin/main`, a push is rejected as non-fast-forward,
or you need to merge latest main and resolve conflicts. Merge-based, **not** rebase.

**Adapts:** openai/symphony `pull` skill (portable; conflict guidance kept verbatim in spirit).

---

## Workflow

1. Ensure a clean tree, or `symphony-commit` / stash first.
2. Enable rerere once: `git config rerere.enabled true && git config rerere.autoupdate true`.
3. Confirm `origin` exists and you are on the intended `claude/<task-key>` branch.
4. `git fetch origin`.
5. Sync the remote feature branch first (picks up CI auto-commits):
   `git pull --ff-only origin "$(git branch --show-current)"`.
6. Merge main with clearer markers:
   `git -c merge.conflictstyle=zdiff3 merge origin/main`.
7. Resolve conflicts (below), then `git add <files>` and `git commit` / `git merge --continue`.
8. Re-run the validation gauntlet (`symphony-workflow.md`): deploy dry-run → Apex → Jest → gates.
9. Summarize the merge: hardest conflicts, how resolved, assumptions, follow-ups.

## Conflict resolution

- Inspect before editing: `git status`, `git diff --merge`,
  `git diff :1:path :2:path` (base vs ours) and `git diff :1:path :3:path` (base vs theirs).
- State each side's intent → decide the correct final behavior → only then edit to match.
- Preserve invariants, API/contract surfaces, and user-visible behavior unless the conflict is a
  deliberate change.
- Salesforce specifics:
  - **Metadata XML** (objects, flows, planner bundles): resolve by intent, then re-retrieve or
    re-validate; never hand-merge a `.genAiPlannerBundle` without a follow-up Tooling-API check
    (green deploy ≠ persisted).
  - **Generated artifacts**: resolve source first, then regenerate.
- One file at a time; rerun tests after each logical batch. `git diff --check` (no markers left).

## When to ask (keep minimal)

Only when resolution depends on product intent not inferable from code/docs, crosses a user-visible
contract/migration, picks between equal-merit designs, or risks data loss / irreversible change, or
the target branch is wrong. Otherwise decide, document, proceed.

**Source:** openai/symphony `pull` skill; Mortgate trust-but-verify (re-verify metadata persistence).
