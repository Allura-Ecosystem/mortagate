---
name: loan-file-evidence-review
description: Reviews attached mortgage documents when a user asks "what is missing", "summarize this loan file", or "show evidence for this review".
---

# Loan-File Evidence Review

Use this skill to organize evidence in documents supplied in the current Cowork conversation.

## Safety boundary

- Extract and summarize; do not decide whether an applicant qualifies.
- State uncertainty when a document is unreadable, incomplete, inconsistent, or absent.
- Do not infer protected-class attributes, eligibility, creditworthiness, or a principal adverse-action reason.
- Do not send a condition request, notice, or update to any loan-origination system.

## Workflow

1. Inventory each supplied document by visible filename, stated type, and readable date.
2. Extract only facts supported by the supplied material. Cite the file and page or section whenever available.
3. Mark each fact as one of: `supported`, `ambiguous`, `missing`, `conflicting`, or `unidentified`. Use `unidentified` when a document's type or content cannot be determined from the supplied material — report it as unidentified rather than guessing.
4. Compare the available evidence with the employee-provided document checklist. If no checklist is supplied, provide an evidence inventory only; do not invent lender policy.
5. Produce the review in this format:

| Evidence area | Supported fact | Source | Status | Follow-up for human reviewer |
|---|---|---|---|---|

6. End with a short boundary statement: this is an evidence summary for an authorized human reviewer, not an underwriting decision.

## Handoff

- Use `policy-replay-review` only when the employee supplies an approved policy version or deterministic replay output.
- Use `audit-packet-draft` when the employee requests a review record.

## Additional resource

- `references/safety-boundaries.md` — fixed authority and data-handling boundaries.
