# Risks & Decisions Matrix: Audit Queue

> [!NOTE]
> **AI-Assisted Documentation**
> Portions of this document were drafted with the assistance of an AI language model (GitHub Copilot).
> Content has not yet been fully reviewed — this is a working design reference, not a final specification.
> AI-generated content may contain inaccuracies or omissions.
> When in doubt, defer to the source code, JSON schemas, and team consensus.

This document captures key architectural and design decisions made in the **Audit Queue** (mortgage loan-QC audit workflow on Salesforce, org `mortagate-de`), the rationale behind each, the alternatives considered, and the risks they introduce. Use it to understand *why* the design is the way it is, and to evaluate the impact of changing it.

The MVP architectural decisions (AD-01 … AD-03) were **ratified by Brooks (PM)** on 2026-06-12; the operational risks (RK-01 … RK-05) are his named demo risks. AD-04 … AD-07 record the pre-MVP controls carried forward from v1/v2.

---

## Table of Contents

- [1. Architectural Decisions](#1-architectural-decisions)
  - [AD-01: FLS gap closed by graceful degradation, not a permission set](#ad-01-fls-gap-closed-by-graceful-degradation-not-a-permission-set)
  - [AD-02: Lightning App Page first; Community deferred](#ad-02-lightning-app-page-first-community-deferred)
  - [AD-03: Brand-accurate styling, not pixel-match](#ad-03-brand-accurate-styling-not-pixel-match)
  - [AD-04: borrowerName bound to the write-once snapshot](#ad-04-borrowername-bound-to-the-write-once-snapshot)
  - [AD-05: Audit events are append-only](#ad-05-audit-events-are-append-only)
  - [AD-06: All read paths enforce WITH USER_MODE](#ad-06-all-read-paths-enforce-with-user_mode)
  - [AD-07: Audit Queue ships as its own deployable unit](#ad-07-audit-queue-ships-as-its-own-deployable-unit)
- [2. Risks](#2-risks)

---

## 1. Architectural Decisions

---

### AD-01: FLS gap closed by graceful degradation, not a permission set

| Field | Detail |
|-------|--------|
| **Status** | Decided |
| **Decision** | Make `CaseReviewController` (`runReplay`/`getCaseReview`), `PolicyVersionSelector` (`loadPolicyVersion`), and `FindingService` (`allExceptionsApproved`) degrade gracefully when an *optional* field is not FLS-readable — via dynamic SOQL + try/catch, returning partial data plus a visible "some fields unavailable" notice. (Fix B.) |
| **Rationale** | ~8 fields exist in `mortagate-de` but are not FLS-readable to the running user, so `WITH USER_MODE` SOQL selecting them throws `No such column` and the case-detail view fails closed. Graceful degradation matches the idiom the codebase already uses (`FactAssembler.queryLoanValues`, `PolicyRuleEvaluator.setRationale`), keeps the fix inside audit-queue code, and is portable to any org without per-org config. |
| **Alternatives considered** | **Fix A — ship an `Audit_Queue_Access` permission set granting FLS on the 8 fields.** Rejected for MVP: it is an access-control mutation that can be accidentally reverted, must be re-applied per org, and does not make the code resilient to future field additions. May still be desirable later for full-fidelity reads. |
| **Consequences** | Case-detail reads never throw on a missing/blocked optional field; instead the UI shows a partial record with an inline unavailability notice. Introduces RK-01 (silent error swallowing). |
| **Owner** | Brooks (PM) |
| **References** | [BLUEPRINT.md](BLUEPRINT.md) F-series (case review); Phase 1 of `ralph/goals/goal-20260612-mvp-outcomes.md`; RK-01 |

---

### AD-02: Lightning App Page first; Community deferred

| Field | Detail |
|-------|--------|
| **Status** | Decided |
| **Decision** | Host the `auditQueue` component on an internal **Lightning App Page** (`Audit_Queue_Page`) reachable from the App Launcher for the MVP. Experience Cloud / Community hosting is explicitly post-MVP. |
| **Rationale** | The exec demo is a shared-screen walkthrough, not a public URL. An App Page removes the Developer-Edition Community provisioning/publishing risk on demo day and reuses the platform sidebar for free. |
| **Alternatives considered** | **Go straight to a Community/Experience Cloud page.** Deferred: requires adding the `lightningCommunity__Page` target, provisioning + publishing an Experience site, and managing guest/member access — more surface to misconfigure before the demo. |
| **Consequences** | The component's `js-meta.xml` keeps `lightning__AppPage`/`lightning__RecordPage` targets for MVP; the community target is added in sprint 2. Demo audience views an authenticated internal page. |
| **Owner** | Brooks (PM) |
| **References** | Phase 2 of the MVP goal; [SOLUTION-ARCHITECTURE.md](SOLUTION-ARCHITECTURE.md) |

---

### AD-03: Brand-accurate styling, not pixel-match

| Field | Detail |
|-------|--------|
| **Status** | Decided |
| **Decision** | Style the queue to be **brand-accurate and recognizably the Figma** (sidebar, 5 stat cards, filter bar, table, risk sigils) — not a pixel-perfect reproduction. |
| **Rationale** | The bar is "would a bank exec believe this is shipping-quality enterprise software." Pixel-matching SLDS without a dedicated design engineer spends effort on accidental complexity with no demo payoff. |
| **Alternatives considered** | **Pixel-perfect Figma match.** Rejected for MVP scope/time; revisit if a design engineer is assigned. |
| **Consequences** | Phase 4 is visual-only (no functional change); the Jest contract that locks `riskTier` to plain text + `type:'text'` columns must stay green (sigils are CSS `::before`). Introduces RK-04. |
| **Owner** | Brooks (PM) |
| **References** | Figma "allura — Audit Queue"; Phase 4 of the MVP goal; RK-04 |

---

### AD-04: borrowerName bound to the write-once snapshot

| Field | Detail |
|-------|--------|
| **Status** | Decided |
| **Decision** | The borrower name displayed in the queue is sourced from `Audit_Case__c.Borrower_Name_Snapshot__c` (a write-once field), never fabricated or re-derived. |
| **Rationale** | An audit record must show the borrower identity *as captured at audit time*; re-deriving it risks drift from the evidenced value. The write-once validation rule (`Snapshot_Write_Once`) preserves first-capture integrity. |
| **Alternatives considered** | Looking up the live borrower name from the loan/contact at render time — rejected: defeats point-in-time audit fidelity. |
| **Consequences** | Empty snapshot renders as empty string (not `undefined`); locked by a Jest test. |
| **Owner** | Audit team |
| **References** | ADR-001 (v1); `AuditQueueController`; [DATA-DICTIONARY.md](DATA-DICTIONARY.md#audit_case__c) |

---

### AD-05: Audit events are append-only

| Field | Detail |
|-------|--------|
| **Status** | Decided |
| **Decision** | `Audit_Event__c` records cannot be edited (VR `Prevent_Edit_After_Creation`) or deleted (trigger `AuditEventPreventDelete`). |
| **Rationale** | Chain-of-custody for a regulator-grade audit trail requires an immutable event log. |
| **Alternatives considered** | Soft-delete / status flag — rejected: an editable trail is not defensible in audit. |
| **Consequences** | Corrections are made by appending new events, never mutating history. Guarded by `AuditDataIntegrityTest`. |
| **Owner** | Audit team |
| **References** | [DESIGN-AUDIT-QUEUE.md](DESIGN-AUDIT-QUEUE.md); `AuditEventService` |

---

### AD-06: All read paths enforce WITH USER_MODE

| Field | Detail |
|-------|--------|
| **Status** | Decided |
| **Decision** | SOQL on the evidence/audit surface runs `WITH USER_MODE` (or `Database.query(..., AccessLevel.USER_MODE)`) so FLS/CRUD is enforced for the running user; proven for `AuditEventService.getEventsForCase` via a `runAs` restricted-user test. |
| **Rationale** | Compliance requirement G-1: a least-privilege user must not read fields they lack FLS for. |
| **Alternatives considered** | System-mode reads (faster, no FLS) — rejected: leaks fields past FLS. |
| **Consequences** | Exposes AD-01's tension: enforcing USER_MODE on fields the running user lacks FLS for throws — hence the graceful-degradation handling for *optional* fields. |
| **Owner** | Audit team |
| **References** | AD-01; compliance G-1; `AuditEventService`, `AuditEvidenceReportController` |

---

### AD-07: Audit Queue ships as its own deployable unit

| Field | Detail |
|-------|--------|
| **Status** | Decided |
| **Decision** | The audit-queue is promoted as an independent unit gated on its **own** test suite (`AuditQueue` suite, `RunSpecifiedTests`), not the org-wide `RunLocalTests`. |
| **Rationale** | The org-wide gate is red due to policy-engine test drift in a *separate* bounded context the audit team does not own; the audit-queue is independently green (Apex 37/37, Jest 12/12). |
| **Alternatives considered** | Wait for the policy engine to go green org-wide — rejected: couples a clean component to an unrelated team's red tests. |
| **Consequences** | A package manifest excludes the co-owned `PolicyRuleEvaluator`; production promotion (if ever to a real prod org) still needs per-class coverage, which DE does not enforce. |
| **Owner** | Audit team |
| **References** | `manifest/package.audit-queue.xml`; goal `goal-20260612-1345-outcomes.md` Decision #2 |

---

## 2. Risks

| ID | Title | Severity | Status |
|----|-------|----------|--------|
| [RK-01](#rk-01-fix-b-silently-swallows-a-genuine-data-error) | Fix B silently swallows a genuine data error | Medium | 🔴 Open |
| [RK-02](#rk-02-de-governor-limits-during-a-broad-filter-query) | DE governor limits during a broad filter query | Medium | 🔴 Open |
| [RK-03](#rk-03-app-not-visible-to-the-demo-user-profile) | App not visible to the demo user profile | Medium | 🔴 Open |
| [RK-04](#rk-04-styling-pass-regresses-the-table) | Styling pass regresses the table | Low–Medium | 🔴 Open |
| [RK-05](#rk-05-demo-environment-state-drift) | Demo environment state drift | Medium | 🔴 Open |

---

### RK-01: Fix B silently swallows a genuine data error

| Field | Detail |
|-------|--------|
| **Severity** | Medium |
| **Likelihood** | Medium |
| **Status** | 🔴 Open |
| **Description** | The dynamic-SOQL + try/catch degradation (AD-01) could mask a *real* query error (typo, broken relationship) as if it were merely an FLS-blocked optional field, hiding a defect. |
| **Mitigation** | Named `System.debug` logging on every caught degradation path + a visible inline "some fields unavailable" notice so the gap is observable, not silent. Review debug logs before tagging. |
| **Owner** | Audit team |
| **Related decision** | [AD-01](#ad-01-fls-gap-closed-by-graceful-degradation-not-a-permission-set) |

---

### RK-02: DE governor limits during a broad filter query

| Field | Detail |
|-------|--------|
| **Severity** | Medium |
| **Likelihood** | Low–Medium |
| **Status** | 🔴 Open |
| **Description** | A broad/unfiltered queue query over ~614 seed loans could approach Developer-Edition governor limits live in front of the audience. |
| **Mitigation** | Selective `WHERE` + `LIMIT` guards (Critical-first ordering above the 200-row cap is already enforced); manual debug-log review before tagging. |
| **Owner** | Audit team |
| **Related decision** | [AD-07](#ad-07-audit-queue-ships-as-its-own-deployable-unit) |

---

### RK-03: App not visible to the demo user profile

| Field | Detail |
|-------|--------|
| **Severity** | Medium |
| **Likelihood** | Medium |
| **Status** | 🔴 Open |
| **Description** | The Lightning app/tab may not be assigned to the exact profile the demo user logs in with, so "open from App Launcher" fails on demo day. |
| **Mitigation** | Assign `Audit_Queue_App` to the exact demo profile during Phase 2 and verify by logging in *as that user* — not as admin. |
| **Owner** | Audit team |
| **Related decision** | [AD-02](#ad-02-lightning-app-page-first-community-deferred) |

---

### RK-04: Styling pass regresses the table

| Field | Detail |
|-------|--------|
| **Severity** | Low–Medium |
| **Likelihood** | Medium |
| **Status** | 🔴 Open |
| **Description** | The Phase 4 CSS/Figma pass could break the datatable layout or the risk-sigil rendering. |
| **Mitigation** | Phase 4 is visual-only; run Jest (12/12) + a manual end-to-end after every Phase-4 commit; sigils stay CSS `::before` so the JS data model is untouched. |
| **Owner** | Audit team |
| **Related decision** | [AD-03](#ad-03-brand-accurate-styling-not-pixel-match) |

---

### RK-05: Demo environment state drift

| Field | Detail |
|-------|--------|
| **Severity** | Medium |
| **Likelihood** | Medium |
| **Status** | 🔴 Open |
| **Description** | Filters left applied, a non-default view, or AC-0001 not visible could derail the live walkthrough. |
| **Mitigation** | A three-step reset runbook (clear filters → default view → confirm AC-0001 visible) run immediately before the demo. |
| **Owner** | Audit team |
| **Related decision** | [AD-02](#ad-02-lightning-app-page-first-community-deferred) |

---

**See also:**
- [BLUEPRINT.md](BLUEPRINT.md) — system design this document is based on
- [REQUIREMENTS-MATRIX.md](REQUIREMENTS-MATRIX.md) — requirement traceability
- [DESIGN-AUDIT-QUEUE.md](DESIGN-AUDIT-QUEUE.md) — queue + replay deep-dive
- [SOLUTION-ARCHITECTURE.md](SOLUTION-ARCHITECTURE.md) — system topology
