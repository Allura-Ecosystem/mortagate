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

## Workflow

1. Identify the requested task: evidence review, missing-document check, policy-replay comparison, or audit-packet draft.
2. List the materials currently available in this Cowork conversation. Ask for only the missing material needed for the requested review.
3. Ask the employee to state the intended review scope and the policy/replay source, if one is required.
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
