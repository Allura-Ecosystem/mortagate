# Session / Workspace Setup

Practical setup for working on the audit-queue, plus the durable fix for the
recurring **cwd-reset** annoyance (V4.4).

## 1. Pin the default org (kills `-o mortagate-de` on every command)

The verified Dev org alias is **`mortagate-de`**. The machine's *global* default
is `mortagate-dev`, which is ambiguous across machines, so pin the project to the
exact alias locally:

```bash
sf config set target-org mortagate-de
```

This writes `.sf/config.json` (git-ignored by design — it's machine-local), after
which `sf project deploy start`, `sf apex run test`, etc. need no `-o` flag.

## 2. The cwd-reset (and the real fix)

**Symptom:** in the agent harness, the shell working directory resets after every
command to a *different* worktree
(`Allura-ecosystem/mortgage - audit/.claude/worktrees/frosty-fermi-…`), so every
command must be prefixed with `cd "$PIVOT" &&`.

**Why a devcontainer alone does not fix it:** the reset is imposed by the **session
runtime**, not by repo configuration. `.devcontainer/devcontainer.json` pins the
*toolchain* and (for human IDE/Codespaces users) the workspace folder, but it does
not change where the agent harness drops each command.

**Durable fix (human/harness action):** re-point the agent's workspace root at the
audit-queue worktree itself —

```
/media/ronin704/Games/Projects/Client-Projects/mortgage-audit/.claude/worktrees/audit-pivot
```

— so the harness cwd and the source tree coincide and the `cd "$PIVOT" &&` prefix
is no longer needed. This is the proper resolution of V4.4; it cannot be set from
inside the repo.

## 3. Everyday verification commands

```bash
# LWC unit tests
npm run test:unit

# Audit Apex suite (single named handle — V4.2)
sf apex run test --suite-names AuditQueue --result-format human

# FLS markers must stay at 0
# (search force-app/main/default/classes for USER_MODE-TODO → expect none)

# Deploy guard (refuses a dirty tree — V0.3)
npm run deploy            # = guard:clean-tree && sf project deploy start
```
