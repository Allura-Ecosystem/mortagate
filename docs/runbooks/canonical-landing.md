# Runbook — Landing the audit-queue into the canonical repo (V0.4)

> **This runbook stops at the remote push.** The push / PR creation is a
> human-authorised step (it modifies a shared remote and touches another
> session's working tree). Nothing here should be executed autonomously.

## Background

- **Pivot source (this work):** the audit-queue v2 lives in the ignored-scratch
  worktree
  `…/Client-Projects/mortgage-audit/.claude/worktrees/audit-pivot`, on a local
  `master` with the v2 hardening commits and the `audit-queue-v1` rollback tag.
- **Canonical home:** `github.com/Allura-Ecosystem/mortagate.git`, checked out at
  `…/Allura-ecosystem/Client-Projects/mortgage-audit` (per MEMORY.md, the
  Allura-Ecosystem org is canonical).
- **Why this isn't a simple commit:** the canonical tree currently holds the
  **parallel Brooks consolidation session's uncommitted changes**, and the policy
  layer differs (`FactAssembler` in the pivot vs `FactAssemblerService` in
  canonical). Landing must be a coordinated branch/PR, not a push onto another
  session's dirty tree.

## Pre-flight (must all be true before landing)

- [ ] The Brooks session's uncommitted work in the canonical tree is committed or
      stashed (confirm with that session's owner — do not touch it).
- [ ] `FactAssembler` (pivot) vs `FactAssemblerService` (canonical) reconciliation
      decision is made (rename/merge/keep-both) and written down.
- [ ] Open Decision #1 (is prod the real target?) recorded — sets whether the
      org-wide `RunLocalTests` gate (V2) blocks this landing.
- [ ] The pivot tree is clean and tagged (`git status` clean; `audit-queue-v1`
      tag present). The `guard-clean-tree.sh` already enforces this on deploy/push.

## Landing steps (HUMAN-AUTHORISED — do not run autonomously)

1. **Create a feature branch in the canonical repo** (never commit straight to its
   default branch):
   ```bash
   cd <canonical>/Allura-ecosystem/Client-Projects/mortgage-audit
   git switch -c feat/audit-queue-v2
   ```
2. **Bring the audit-queue source across.** Preferred: format-patch from the pivot
   so authorship/history is preserved —
   ```bash
   # in the pivot worktree:
   git format-patch <base>..master --stdout > /tmp/audit-queue-v2.patch
   # in the canonical branch:
   git am --3way < /tmp/audit-queue-v2.patch
   ```
   Resolve the `FactAssembler` / `FactAssemblerService` collision per the decision
   above. Re-run the AuditQueue suite + Jest after reconciliation.
3. **Seed-data guard** before any prod-bound deploy:
   ```bash
   bash scripts/guard-no-seed-in-prod.sh <prod-or-staging-org>
   ```
4. **Push + open a PR** (⛔ explicit human go required — modifies the shared remote):
   ```bash
   git push -u origin feat/audit-queue-v2
   # then open a PR for review; CI (.github/workflows/ci.yml) gates it once the
   # DEVHUB_SFDX_AUTH_URL secret is configured.
   ```
5. **Merge** only after CI is green and review approves. Re-tag the canonical
   rollback point post-merge if desired.

## Rollback / safety

- The pivot's `audit-queue-v1` tag remains the durable rollback point until the
  canonical merge lands; nothing here deletes or rewrites it.
- If the patch import goes wrong, abort with `git am --abort` and the canonical
  branch is untouched; the pivot worktree remains the source of truth.

---

**Status:** documented and ready. Awaiting the human-coordinated go (Brooks-tree
handling + FactAssembler reconciliation + Decision #1). No remote push has been or
will be performed without explicit authorisation.
