---
name: audit-packet-draft
description: Drafts a human-review audit packet when a user asks "prepare an audit packet", "summarize the review", or "create a reviewer handoff".
---

# Audit-Packet Draft

Use this skill to prepare a review record from materials already present in the Cowork conversation.

## Safety boundary

- Draft only. An authorized employee must verify and approve the packet before it is stored, sent, or relied on.
- Do not claim the packet is complete when source evidence, a policy version, or a reviewer is missing.
- Do not create an adverse-action notice, disclosure, final condition letter, or credit decision.
- Do not send email, post to Teams, or update any loan system. These actions are outside this skill's authority and require the approved system of record.

## Context and execution

- Use the host's configured model. This skill defines evidence and authority requirements, not a provider or model pin.
- Reuse the current conversation's intake, document inventory, citations, and replay identifiers only for the same case, review scope, supplied source versions, and authorization. Keep source references attached to every reused finding. If case identity is uncertain, do not combine files or carry findings across cases.
- New or replaced documents, a changed policy/replay version, changed scope or authorization, conflicting evidence, or unavailable originals invalidate the affected findings. Re-read those sources and recheck dependent comparisons; do not treat an earlier model summary as authoritative evidence.
- When the employee's request and necessary inputs are clear, perform the requested review directly. Ask only for missing inputs that affect its correctness. Do not repeat onboarding, re-request supplied scope, or seek approval merely to continue an already requested draft.
- One owner may apply the relevant skills in the same conversation. A skill handoff is not a requirement to launch another agent or run all four skills. Existing human-review and prohibited-action boundaries always apply.

## Workflow

1. Gather only conversation-provided facts, document citations, and supplied replay results. Cite provenance per `references/evidence-metadata.md`.
2. Identify gaps rather than silently filling them.
3. Draft the packet:

# Evidence Review Packet — Draft

## Scope
- Review purpose:
- Materials reviewed:
- Policy/replay source and version:

## Evidence findings
| Finding | Source | Status | Human reviewer action |
|---|---|---|---|

## Replay findings
| Rule / check | Comparison | Evidence | Human reviewer action |
|---|---|---|---|

## Open items
- Missing information:
- Ambiguities or conflicts:
- Required authorization:

## Reviewer attestation placeholder
- Authorized reviewer:
- Review date:
- Decision (recorded by the reviewer in the approved system):

4. Mark the packet `DRAFT — HUMAN REVIEW REQUIRED`.

## Additional resource

- `references/safety-boundaries.md` — fixed authority and data-handling boundaries.
- `references/evidence-metadata.md` — provenance fields and rendering rules.
