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

## Context and execution

- Use the host's configured model. This skill defines evidence and authority requirements, not a provider or model pin.
- Reuse the current conversation's intake, document inventory, citations, and replay identifiers only for the same case, review scope, supplied source versions, and authorization. Keep source references attached to every reused finding. If case identity is uncertain, do not combine files or carry findings across cases.
- New or replaced documents, a changed policy/replay version, changed scope or authorization, conflicting evidence, or unavailable originals invalidate the affected findings. Re-read those sources and recheck dependent comparisons; do not treat an earlier model summary as authoritative evidence.
- When the employee's request and necessary inputs are clear, perform the requested review directly. Ask only for missing inputs that affect its correctness. Do not repeat onboarding, re-request supplied scope, or seek approval merely to continue an already requested draft.
- One owner may apply the relevant skills in the same conversation. A skill handoff is not a requirement to launch another agent or run all four skills. Existing human-review and prohibited-action boundaries always apply.

## Workflow

1. Inventory each supplied document by visible filename, stated type, and readable date.
2. Extract only facts supported by the supplied material. Cite provenance per `references/evidence-metadata.md` — never render a field that is unavailable.
3. Mark each fact as one of: `supported`, `ambiguous`, `missing`, `conflicting`, or `unidentified`.

   | Status | Use when |
   |---|---|
   | `supported` | The supplied material states the fact directly. |
   | `ambiguous` | The **document type is recognisable** but a needed attribute is absent, illegible, or undated. The document belongs in the file; something about it cannot be relied on. |
   | `missing` | An expected document or fact is **not present** in the supplied material. |
   | `conflicting` | Two or more supplied sources disagree. Cite every source; do not decide which is correct. |
   | `unidentified` | The **document type itself cannot be determined**. Report as unidentified rather than guessing. |

   `ambiguous` and `unidentified` are distinct and must not be used
   interchangeably. An undated but recognisable form is `ambiguous`. Content that
   cannot be placed as any document type is `unidentified`. When both could
   apply, ask which is unknown: the *attribute* (`ambiguous`) or the *document*
   (`unidentified`).
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
- `references/evidence-metadata.md` — provenance fields and rendering rules.
