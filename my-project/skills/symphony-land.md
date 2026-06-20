# Symphony Land

**Trigger:** When asked to land, merge, or shepherd a Mortgate PR to completion — watch checks,
resolve conflicts, address review, and squash-merge when green.

**Adapts:** openai/symphony `land` skill → `gh` for a repo with **no required CI checks**; review
replies prefixed `[claude]`; no `land_watch.py` daemon.

---

## Preconditions

- `gh` authenticated; you are on the PR branch with a clean tree.
- The full validation gauntlet (`symphony-workflow.md`) is green **locally** before any push.

## Workflow

1. Locate the PR: `pr=$(gh pr view --json number,title,body,mergeable -q .)`.
2. If the tree has uncommitted work → `symphony-commit` then `symphony-push` first.
3. Check mergeability vs `main`. If `CONFLICTING`: run `symphony-pull` (fetch/merge `origin/main`,
   resolve), then `symphony-push`. If `UNKNOWN`: wait and re-check.
4. **Review handling (reply before changing code):** read PR review comments
   (`gh api repos/{owner}/{repo}/pulls/<n>/comments`) and top-level discussion
   (`.../issues/<n>/comments`). For each, classify *correctness / design / style / clarification /
   scope* and choose *accept / clarify / push back* — reply inline first, prefixed `[claude]`, then
   implement. Use `in_reply_to=<numeric review-comment id>` on
   `POST /repos/{owner}/{repo}/pulls/<n>/comments`.
   - **Context guard:** if feedback conflicts with the task's stated intent, reply with
     acknowledge + rationale + alternative and ask before changing code.
   - Correctness feedback you intend to decline → validate first, then explain why it doesn't apply.
5. Watch checks: `gh pr checks --watch`. On failure: `gh run list --branch "$branch"`,
   `gh run view <id> --log`; fix → `symphony-commit` → `symphony-push` → re-watch. Use judgment on
   obvious flakes.
6. **Handoff gate (Mortgate):** do NOT merge if the change crosses a compliance (OQ-R8-2/4/6) or
   security (OQ-R8-1/7) sign-off, a borrower-facing contract, a schema migration, a destructive org
   op, or a Setup-UI-only step. Move the Notion task to `On Hold (Human Review)` with a crisp
   instruction instead — that is a successful end-state, not a failure.
7. When green, review addressed, and no handoff gate applies: squash-merge with the PR title/body
   as subject/body:
   `gh pr merge --squash --subject "$pr_title" --body "$pr_body"`.
   The repo auto-deletes the head branch on merge.
8. Close the loop in Notion via `symphony-task-runner` step 8 (Status → `Completed`, comment with
   PR URL + tests run).

## Rules

- **No auto-merge** — this repo has no required checks, so auto-merge could skip tests. Watch and
  merge manually.
- Do not merge while human review comments are outstanding.
- Every PR comment this agent posts is prefixed `[claude]`.
- Salesforce caveat: a green merge does not prove metadata persisted (planner bundles, flows) —
  if the change touched those, leave a re-verify follow-up (Tooling-API check) in the merge note.

**Source:** openai/symphony `land` skill; Mortgate handoff rules + CLAUDE.md git protocol.
