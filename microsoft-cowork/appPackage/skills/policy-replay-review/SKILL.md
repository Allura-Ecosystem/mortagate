---
name: policy-replay-review
description: Compares supplied policy-replay results when a user asks "compare expected and actual", "show rule differences", or "summarize replay findings".
---

# Policy-Replay Review

Use this skill only when the employee supplies an approved policy version, deterministic replay output, or a system-produced expected-versus-actual report.

## Safety boundary

- The supplied policy/replay system remains authoritative; do not replace it with model reasoning.
- Do not make a credit decision, recommend a loan action, or determine a legal notice reason.
- Do not invent policy rules, thresholds, or interpretation when the source is absent.
- Escalate unclear results to the authorized underwriter, auditor, or compliance owner.

## Workflow

1. Identify the policy version, replay run identifier if supplied, and source materials.
2. For each reported rule, compare the expected result, actual result, and cited evidence.
3. Classify the comparison as `match`, `mismatch`, `insufficient evidence`, or `source unclear`.
4. Preserve exact source wording for rule IDs and thresholds; do not normalize or repair identifiers.
5. Produce this table:

| Rule / check | Expected | Actual | Evidence cited by source | Comparison | Human review question |
|---|---|---|---|---|---|

6. State explicitly that the output summarizes a supplied replay and does not determine the loan outcome.

## Handoff

Use `audit-packet-draft` to create a human-review packet from the evidence and replay comparison.

## Additional resource

- `references/safety-boundaries.md` — fixed authority and data-handling boundaries.
