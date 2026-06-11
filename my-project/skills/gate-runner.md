# Gate Runner

**Trigger:** Before claiming any phase complete. After deploy. Before PR merge.

Parse and execute `mortagate.gates.json` for the target phase. The JSON is the single source of truth for gate definitions — this skill executes it, does not restate it.

---

## Steps

1. Read `mortagate.gates.json` and identify checks for the target phase (0, 1, or 2).
2. Execute each check in order (`fail_fast: true`).
3. Report PASS/FAIL per check ID with evidence (command output or file existence).
4. Block completion claim if any required check fails.

## Manual Discipline Warning

Until CI/CD exists (US-5.1), this skill is the only gate. It must be run before every merge. There is no branch protection or automated enforcement — this is a manual discipline risk. Document every gate run.

**Source:** mortagate.gates.json.
