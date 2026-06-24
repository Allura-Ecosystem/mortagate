# Symphony Push

**Trigger:** When asked to push the task branch, publish updates, or open/refresh the PR for a
`claude/<task-key>` worktree branch.

**Adapts:** openai/symphony `push` skill → Mortgate gates + `gh` (no Elixir `mix`, no required PR
template).

---

## Prerequisites

- `gh` installed and `gh auth status` succeeds for this repo.
- You are inside the task worktree on the intended `claude/<task-key>` branch, tree clean
  (run `symphony-commit` first if not).

## Workflow

1. Confirm branch + remote state: `git branch --show-current`, `git status -sb`.
2. **Validate before push** — run the gauntlet from `symphony-workflow.md` (do NOT use
   `make`/`mix`):
   - `sf project deploy start --dry-run --target-org mortagate-de`
   - `sf apex run test --target-org mortagate-de --test-level RunLocalTests --result-format human --wait 30`
   - `npm run test:unit`
   - relevant phases of `mortagate.gates.json` (`gate-runner`).
   Do not push on red.
3. Push with upstream tracking: `git push -u origin HEAD` (keep the configured remote URL).
4. If the push is rejected (non-fast-forward / stale branch): run `symphony-pull`, re-validate,
   then push again. Use `--force-with-lease` **only** when history was deliberately rewritten;
   never `--force`. Never force-push to `main`.
5. If rejected for **auth / permissions / workflow restriction**: stop and surface the exact error —
   do not rewrite remotes or switch protocols as a workaround.
6. Ensure a PR exists:
   - No PR → `gh pr create --base main --title "<clear outcome-focused title>"`.
   - Open PR → `gh pr edit` and refresh title if scope shifted.
   - Branch tied to a CLOSED/MERGED PR → cut a new branch + PR.
7. **PR body** (no `.github/pull_request_template.md` exists here — write a clean body directly via
   `--body`/`--body-file`; do NOT block on a template, do NOT run `mix pr_body.check`):
   - **Summary** (what shipped, full branch scope — not just the latest commit),
   - **Tests** (the gauntlet commands run + pass/fail),
   - **Notion task** link + task-key, and any **Human Review** caveat.
8. Reply with the PR URL: `gh pr view --json url -q .url`.

## Notes

- The PR title/body describe the **whole branch**, refreshed on every update — not stale text from
  an earlier iteration.
- Salesforce trust-but-verify: a green dry-run is necessary but not sufficient for metadata that
  persists server-side (planner bundles, flows) — note any re-verify follow-up in the PR body.
- Distinguish sync problems (use `symphony-pull`) from auth/permission problems (surface, don't
  work around).

**Source:** openai/symphony `push` skill; Mortgate validation gauntlet (`symphony-workflow.md`).
