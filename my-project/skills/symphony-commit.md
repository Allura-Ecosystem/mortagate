# Symphony Commit

**Trigger:** When asked to commit, prepare a commit message, or finalize staged work during a
Symphony run.

**Adapts:** openai/symphony `commit` skill → Mortgate git conventions (Claude co-author trailer).

---

## Steps

1. Read the session/run history for scope, intent, and rationale.
2. Inspect the tree: `git status`, `git diff`, `git diff --staged`.
3. Stage intended changes **by name** (avoid blind `git add -A`); confirm scope.
4. Sanity-check new files — flag anything that looks like a build artifact, log, secret
   (`.env`, credentials), or `temp/` scratch **before** committing.
5. Choose a conventional type+scope: `feat(...)`, `fix(...)`, `refactor(...)`, `chore(...)`,
   `test(...)`, `docs(...)`.
6. Subject: imperative mood, ≤ 72 chars, no trailing period.
7. Body (wrap at 72): **Summary** (what changed) + **Rationale** (why) + **Tests** (commands run,
   or explicit "not run (reason)").
8. Pass the message via HEREDOC to `git commit -F` (never `-m` with `\n`).
9. Commit only when the message matches the staged diff. If unrelated files are staged or the
   message describes unstaged work, fix the index or revise the message first.

## Rules (Mortgate)

- Create a **NEW** commit; never blind `--amend` (a failed pre-commit hook means the commit did not
  happen — amending would rewrite the previous one).
- Never skip hooks or signing (`--no-verify`, `--no-gpg-sign`) unless the user explicitly asks.
- Do not commit `.env`, credentials, or large binaries.
- Commit only when the user has asked to commit.

## Template

```
<type>(<scope>): <short summary>

Summary:
- <what changed>

Rationale:
- <why>

Tests:
- <command or "not run (reason)">

Co-Authored-By: Claude Opus 4 <noreply@anthropic.com>
```

**Source:** openai/symphony `commit` skill; Mortgate CLAUDE.md git protocol.
