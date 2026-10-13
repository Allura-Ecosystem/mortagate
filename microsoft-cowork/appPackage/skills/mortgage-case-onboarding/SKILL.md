---
name: mortgage-case-onboarding
description: Onboards a mortgage evidence-review task when a user says "review this loan file", "start a case review", or "what do you need to review this file".
---

# Mortgage Case Onboarding

Use this skill to start an internal evidence-review task. This is an employee workflow, not borrower advice.

## Safety boundary

- Do not approve, deny, counteroffer, price, set a rate, or issue a regulatory notice.
- Do not claim legal, credit, underwriting, or compliance authority.
- Do not treat an uploaded file as a verified system of record.
- Do not send messages or update any loan system.

## Context and execution

- Use the host's configured model. This skill defines evidence and authority requirements, not a provider or model pin.
- Reuse the current conversation's intake, document inventory, citations, and replay identifiers only for the same case, review scope, supplied source versions, and authorization. Keep source references attached to every reused finding. If case identity is uncertain, do not combine files or carry findings across cases.
- New or replaced documents, a changed policy/replay version, changed scope or authorization, conflicting evidence, or unavailable originals invalidate the affected findings. Re-read those sources and recheck dependent comparisons; do not treat an earlier model summary as authoritative evidence.
- When the employee's request and necessary inputs are clear, perform the requested review directly. Ask only for missing inputs that affect its correctness. Do not repeat onboarding, re-request supplied scope, or seek approval merely to continue an already requested draft.
- One owner may apply the relevant skills in the same conversation. A skill handoff is not a requirement to launch another agent or run all four skills. Existing human-review and prohibited-action boundaries always apply.

## Workflow

1. Identify the requested task: evidence review, missing-document check, policy-replay comparison, or audit-packet draft.
2. List the materials currently available in this Cowork conversation. Ask for only the missing material needed for the requested review.
3. Use the stated review scope and supplied policy/replay source. Ask for scope only when unclear, and for a policy/replay source only when required by the requested task.
4. State the review boundary in one line: findings are for authorized human review and are not a credit decision.
5. Produce a case intake card:

| Field | Value |
|---|---|
| Review purpose | |
| Files available | |
| Missing inputs | |
| Requested policy/replay source | |
| Required human reviewer | |
| Next safe action | |

## Handoff

- For document facts and missing evidence, use `loan-file-evidence-review`.
- For a comparison against a supplied deterministic policy result, use `policy-replay-review`.
- For a review record, use `audit-packet-draft`.

## Additional resource

- `references/safety-boundaries.md` — fixed authority and data-handling boundaries.
