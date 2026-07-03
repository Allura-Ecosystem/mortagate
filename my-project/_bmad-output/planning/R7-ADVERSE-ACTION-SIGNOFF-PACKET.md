# R-7 — Adverse-Action / Plain-Language Wording Counsel Sign-Off Packet

- **Risk:** R-7 (OPEN, ⚖️) — *RISKS-AND-DECISIONS.md* line 185
- **Related decisions:** ADR-10 (line 58), FR-19, DESIGN-adverse-action.md
- **Prepared by:** Woz (builder) · **For:** Compliance counsel · **Date prepared:** 2026-07-03
- **AI disclosure:** This packet was assembled by an AI agent (Claude/Woz). Every quoted string is copied verbatim from source with a `file:line` citation; no copy was invented or paraphrased.

---

## Purpose

Counsel is asked to review and sign off on the exact borrower-facing and finding-facing wording the system can emit, so that R-7 can move from OPEN to closed. The concern is ECOA / Reg B (12 CFR 1002) adverse-action-notice adjacency, UDAAP plain-language expectations, and FCRA adjacency where a reason is credit-report-derived — none of this copy may reach a real applicant or a legal finding record until it is approved here.

---

## Scope — copy strings requiring counsel review

**30 strings inventoried** across 4 emitting classes. All plain-language reason wording is centralized in `RuleNarration.cls` (see Appendix).

### A. Plain-language rule reasons — `RuleNarration.plainName` (feeds diagnosis, finding drafts, and alerts)

| # | Exact copy string (verbatim) | Where it appears | Regulatory concern |
|---|---|---|---|
| 1 | `Credit score too low` | RuleNarration.cls:21 (FICO_MIN) → LoanDiagnosis summary, FindingDraft | ECOA/Reg B §1002.9(b)(2) specific reason; **FCRA** — credit-report-derived |
| 2 | `Credit score is below the preferred level` | RuleNarration.cls:27 (FICO_PREF) | ECOA specific reason; **FCRA** — credit-report-derived |
| 3 | `Debt vs. income too high` | RuleNarration.cls:19 (DTI_MAX) | ECOA/Reg B §1002.9(b)(2) specific reason |
| 4 | `Debt vs. income is getting high` | RuleNarration.cls:20 (DTI_WARN) | ECOA specific reason (soft/warn band) |
| 5 | `Loan too big vs. home value` | RuleNarration.cls:22 (LTV_MAX) | ECOA specific reason |
| 6 | `Loan is bigger than the preferred level vs. home value` | RuleNarration.cls:28 (LTV_PREF) | ECOA specific reason |
| 7 | `Income is below the minimum needed` | RuleNarration.cls:23 (INCOME_MIN) | ECOA specific reason |
| 8 | `Has not worked at the job long enough` | RuleNarration.cls:24 (EMPLOY_MIN) | ECOA specific reason; UDAAP tone |
| 9 | `Not enough savings in the bank` | RuleNarration.cls:25 (ASSET_MIN) | ECOA specific reason; UDAAP tone |
| 10 | `Total debt is over the limit` | RuleNarration.cls:26 (DEBT_MAX) | ECOA specific reason |
| 11 | `the most allowed is` | RuleNarration.cls:48 (directionPhrase, ceilings) | UDAAP plain-language framing of the threshold |
| 12 | `the lowest allowed is` | RuleNarration.cls:51 (directionPhrase, floors) | UDAAP plain-language framing of the threshold |
| 13 | `the limit is` | RuleNarration.cls:53 (directionPhrase, fallback) | UDAAP plain-language framing of the threshold |

### B. Plain-language loan diagnosis — `LoanDiagnosisService` (auditor copilot summary; characterizes the credit decision)

| # | Exact copy string (verbatim) | Where it appears | Regulatory concern |
|---|---|---|---|
| 14 | `This loan did not pass ` + N + ` rule(s):` (per-rule lines: `<plainName> (<code>): <directionPhrase> <expected>, but this loan is <actual>.`) | LoanDiagnosisService.cls:204, 176-178 | ECOA §1002.9(b)(2) specific-reason characterization |
| 15 | `Good news: this loan passed all ` + N + ` of the checks we could run.` | LoanDiagnosisService.cls:208-209 | UDAAP — no false assurance implied |
| 16 | `We could not check ` + N + ` item(s) because some papers are missing.` | LoanDiagnosisService.cls:212-213 | UDAAP plain-language |
| 17 | `Note: this loan changed after the last check. Run the check again before sign-off.` | LoanDiagnosisService.cls:200-201 | UDAAP plain-language |
| 18 | `We have not run the check on this loan yet, so there is nothing to explain. Run the check first, then ask again.` | LoanDiagnosisService.cls:144-145 | UDAAP plain-language |
| 19 | `A human auditor must make the final call on this loan.` (FINAL_AUTHORITY) | LoanDiagnosisService.cls:25 | Governance disclaimer — HITL, not an automated adverse decision |

### C. Finding-facing draft text — `FindingDraftService` (text an auditor accepts into a Finding record)

| # | Exact copy string (verbatim) | Where it appears | Regulatory concern |
|---|---|---|---|
| 20 | `DRAFT FINDING — AI-drafted, auditor review required.` | FindingDraftService.cls:196 | AI-disclosure header on finding copy |
| 21 | `What the rule expects: <directionPhrase> <expected>. What this loan shows: <actual>.` | FindingDraftService.cls:199-201 | ECOA specific-reason characterization in the finding |
| 22 | `Why it matters: <rationale>` | FindingDraftService.cls:203 | Finding narrative — rationale sourced from Replay_Check__c |
| 23 | `The human auditor accepts or edits this text and makes the final determination.` (FINAL_AUTHORITY) | FindingDraftService.cls:33 | Governance disclaimer — HITL |

### D. Borrower-facing evidence request — `EvidenceRequestService` (only copy addressed to a borrower)

| # | Exact copy string (verbatim) | Where it appears | Regulatory concern |
|---|---|---|---|
| 24 | `Dear Borrower / Branch Team,` | EvidenceRequestService.cls:167 | Directly borrower-addressed; Reg B communication adjacency |
| 25 | `To complete our review of audit case <name>, we still need the following document(s).` | EvidenceRequestService.cls:169-170 | Reg B — document request, not an adverse decision |
| 26 | `Please provide these documents by [DATE]. If you have any questions about what is needed, your auditor can help.` | EvidenceRequestService.cls:189-191 | Reg B — deadline framing (note `[DATE]` is a placeholder) |
| 27 | `Thank you for your prompt attention.` | EvidenceRequestService.cls:193 | Tone / UDAAP |
| 28 | `This is a request for documentation only and is not a decision on the loan. The human auditor reviews this draft and decides whether to send it.` (FINAL_AUTHORITY) | EvidenceRequestService.cls:38-39 | Reg B — explicit not-a-decision disclaimer |
| 29 | `DRAFT EVIDENCE REQUEST — AI-drafted, auditor review required. Not sent.` | EvidenceRequestService.cls:163 | AI-disclosure header |
| 30 | `Required document(s):` / `Additional document(s) that would help us complete the file:` | EvidenceRequestService.cls:174, 181-182 | Reg B — document-category framing |

### E. Cross-reference — formal Adverse Action Notice (already legal-owned, config-as-data)

The statutory AAN itself is **not hardcoded**. Per ADR-10, the notice is composed by `AdverseActionService.cls`; its specific reasons come from each rule's `Rule_Explanation__c`, and the §701(a) anti-discrimination text and oversight-agency identity live in `Adverse_Action_Config__mdt` (config-as-data, editable by legal without a release). Counsel reviews that wording **in the metadata record**, not in this packet. This packet covers the *new* plain-language surfaces (A–D) that sit adjacent to, but are separate from, the formal notice.

---

## Explicit non-scope — internal auditor-only text counsel does NOT need to review

| Surface | Why out of scope |
|---|---|
| `ViolationAlertService.cls` — internal follow-up Task copy, e.g. `This is an internal follow-up task created by the Veridact auditor copilot. No borrower or external party was contacted.` (line 194-195); `A human auditor must review and act; the copilot only raised this follow-up.` (line 39) | Creates an internal Salesforce Task for the assigned auditor only. It never emails or contacts any external/borrower party (asserted in the copy itself and the invocable description, line 44). Not borrower-facing, not a finding record. |
| `lwc/findingDetail` form labels, e.g. `What did the auditor find? (Description)`, `How serious is it? (Severity)` (findingDetail.html:42-96) | Auditor-tool UI field labels inside the internal audit console — they prompt the human auditor, they are not emitted into any borrower or finding narrative. |
| `lwc/caseReview`, `lwc/signoffReceipt` chrome, e.g. `Re-run replay`, `Evidence pack`, `Illustrative hash, not a cryptographic seal.` (signoffReceipt.html:74), `Demo` badge (line 16) | Internal audit-console UI chrome and demo-data markers. No borrower-facing or finding-facing legal content. |
| `@InvocableVariable` / `@InvocableMethod` labels and descriptions across all four services | Agentforce action metadata visible only to the internal copilot builder, never rendered to a borrower. |

---

## Sign-Off Block

I have reviewed the wording inventoried in sections A–D above (and confirmed the section E config-as-data location).

- **Reviewer name (counsel):** ______________________________
- **Firm / role:** ______________________________
- **Date:** ______________________________
- **Jurisdiction(s) covered:** ______________________________

Decision (check one):

- [ ] **Approved as-is** — all 30 strings acceptable for borrower-facing / finding-facing use.
- [ ] **Approved with changes** — changes attached / listed below; re-review not required after edits are applied to `RuleNarration.cls` and the emitting classes.
- [ ] **Not approved** — do not deliver to any real applicant; changes required and re-review required.

Notes / required changes:

_________________________________________________________________

_________________________________________________________________

**Signature:** ______________________________

---

## Appendix — how wording is centralized (one-file changes)

All plain-language *reason* wording is defined once in `RuleNarration.cls`:

- `RuleNarration.plainName` (lines 19-28) — the rule-to-plain-English map (strings #1-#10). Every consumer (`LoanDiagnosisService`, `FindingDraftService`, `ViolationAlertService`) calls `RuleNarration.plainName(code)`; none of them hardcode a rule reason.
- `RuleNarration.directionPhrase` (lines 44-53) — threshold framing (strings #11-#13), shared by diagnosis and finding drafts.
- `RuleNarration.prettyNum` — number formatting only, no legal copy.

**Consequence for counsel:** an approved-with-changes edit to any rule reason is a single-line change in `RuleNarration.cls` that propagates to every surface automatically — no per-class hunt, no risk of a stale reason surviving in one path. The disclaimers (`FINAL_AUTHORITY`) and letter scaffolding are per-class constants at the top of each service, also single-point edits. The formal AAN reasons and agency text (section E) are edited in `Adverse_Action_Config__mdt` with no code release at all.
