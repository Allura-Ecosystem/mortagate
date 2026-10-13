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

## Context and execution

- Use the host's configured model. This skill defines evidence and authority requirements, not a provider or model pin.
- Reuse the current conversation's intake, document inventory, citations, and replay identifiers only for the same case, review scope, supplied source versions, and authorization. Keep source references attached to every reused finding. If case identity is uncertain, do not combine files or carry findings across cases.
- New or replaced documents, a changed policy/replay version, changed scope or authorization, conflicting evidence, or unavailable originals invalidate the affected findings. Re-read those sources and recheck dependent comparisons; do not treat an earlier model summary as authoritative evidence.
- When the employee's request and necessary inputs are clear, perform the requested review directly. Ask only for missing inputs that affect its correctness. Do not repeat onboarding, re-request supplied scope, or seek approval merely to continue an already requested draft.
- One owner may apply the relevant skills in the same conversation. A skill handoff is not a requirement to launch another agent or run all four skills. Existing human-review and prohibited-action boundaries always apply.

## Workflow

1. Identify the policy version, replay run identifier if supplied, and source materials.
2. For each reported rule, compare the expected result, actual result, and cited evidence.
3. Classify the comparison as `match`, `mismatch`, `insufficient evidence`, or `source unclear`.
4. Preserve exact source wording for rule IDs and thresholds; do not normalize or repair identifiers. Cite provenance per `references/evidence-metadata.md`.
5. Produce this table:

| Rule / check | Expected | Actual | Evidence cited by source | Comparison | Human review question |
|---|---|---|---|---|---|

6. State explicitly that the output summarizes a supplied replay and does not determine the loan outcome.

## Handoff

Use `audit-packet-draft` to create a human-review packet from the evidence and replay comparison.

## Additional resource

- `references/safety-boundaries.md` — fixed authority and data-handling boundaries.
- `references/evidence-metadata.md` — provenance fields and rendering rules.
