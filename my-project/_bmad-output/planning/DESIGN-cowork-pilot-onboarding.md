# DESIGN: Cowork Pilot Cohort Onboarding

> **Scope note:** This document covers the **internal mortgage employee** persona
> using the Microsoft Copilot Cowork module. It is deliberately separate from
> `DESIGN-onboarding-ux.md`, which covers the **borrower** persona from the frozen,
> superseded origination-portal design (ADR-15/ADR-30 pivot). Do not merge these —
> different products, different users, different systems.
>
> Origin: EP-6/US-6.4, Sprint Change Proposal 2026-08-28.

## Overview

The pilot cohort is a small set of mortgage employees (not engineers, not BMad/Allura
users) validating the Cowork module's four skills — mortgage case onboarding, loan
file evidence review, policy replay review, audit packet draft — against synthetic
documents in a private workspace, ahead of any production rollout.

## Flow

1. **Access.** Pilot user opens Microsoft Copilot Cowork inside a Frontier-enabled
   Microsoft 365 Copilot tenant, as a licensed user. (Cowork is a Frontier preview —
   this gate cannot be skipped or simulated.)
2. **Upload.** User uploads synthetic/nonproduction loan documents via private
   "Only you" Cowork upload. No shared workspace, no production borrower data, ever,
   during pilot.
3. **Request.** User issues plain-language requests — no Team RAM, BMad, Allura, or
   agent-name vocabulary required:
   - "Start an evidence review for this file."
   - "What documents are missing?"
   - "Compare the supplied policy replay results."
   - "Prepare an audit packet for my reviewer."
4. **Response boundary.** Cowork responds strictly within evidence-review /
   missing-document / policy-replay-comparison / audit-packet-drafting scope. It
   never approves, denies, rates, overrides policy, issues an adverse-action notice,
   messages a borrower, or writes to a loan system — see `SOLUTION-ARCHITECTURE.md`
   §5 "Cowork Hard Boundaries" for the governed version of this list.
5. **Feedback.** Pilot user's observations feed US-6.8 (feedback loop → go/no-go on
   the Entra-secured MCP connector).

## Open items (US-6.4 — not yet resolved)

- **Invite/licensing mechanics** — who provisions Frontier-tenant access for each
  pilot cohort member, and how?
- **Synthetic document fixture** — shared fixture set provided to all pilot users,
  or each user supplies their own synthetic documents?
- **Feedback capture channel** — where does pilot feedback land (form, Slack,
  direct session with Brooks) so US-6.8 has a real input rather than word-of-mouth?

These are decisions for Sabir, not defaults to assume — flag for `DG` (Define Goal)
or a direct answer before pilot kickoff.
