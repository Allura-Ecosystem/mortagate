# Requirements Traceability Matrix: Audit Queue

> [!NOTE]
> **AI-Assisted Documentation**
> Portions of this document were drafted with the assistance of an AI language model.
> Content has not yet been fully reviewed — this is a working design reference, not a final specification.

This is the **coverage map** for the **Audit Queue**. It traces every Business Requirement (`B1`–`B7`) through the Functional Requirements (`F1`–`F14`) defined in the [Blueprint](BLUEPRINT.md#2-requirements) to the Apex classes, LWCs, custom objects, and tests that satisfy and verify them.

**See also:** [BLUEPRINT.md](BLUEPRINT.md) · [DESIGN-AUDIT-QUEUE.md](DESIGN-AUDIT-QUEUE.md) · [DATA-DICTIONARY.md](DATA-DICTIONARY.md) · [SOLUTION-ARCHITECTURE.md](SOLUTION-ARCHITECTURE.md) · [RISKS-AND-DECISIONS.md](RISKS-AND-DECISIONS.md)

---

## Table of Contents

- [1. Business → Functional Mapping](#1-business--functional-mapping)
- [2. Functional Requirements Detail](#2-functional-requirements-detail)
- [3. Use Case Index](#3-use-case-index)
- [4. Status Legend](#4-status-legend)

---

## 1. Business → Functional Mapping

| Business Req | Description | Functional Reqs | Use Cases |
|--------------|-------------|-----------------|-----------|
| **B1** | A QC auditor can view a prioritized queue of sampled loan audits. | F1, F2 | UC-QUEUE-1 |
| **B2** | An auditor can filter and sort the queue to find the cases they must work. | F3, F4, F5 | UC-FILTER-1 |
| **B3** | An auditor can open a case and inspect evidence, facts, rule-checks, findings, and event trail. | F6, F9, F10 | UC-CASE-1 |
| **B4** | An auditor can replay the original lending decision against the policy version in force at approval time. | F7, F8 | UC-REPLAY-1, UC-EVIDENCE-1 |
| **B5** | The system produces a regulator-presentable, immutable evidence report. | F14 | UC-REPORT-1 |
| **B6** | All audit activity is recorded in an immutable, append-only trail. | F9, F11 | UC-SIGNOFF-1 |
| **B7** | A reviewer cannot audit a loan they themselves approved (independence). | F13 | UC-SIGNOFF-1 |

> Coverage check: every `B#` maps to at least one `F#`; every `F1`–`F14` appears below.

---

## 2. Functional Requirements Detail

Status legend in [§4](#4-status-legend). Test classes that exist in the worktree are linked; the absence of a per-method controller test is flagged explicitly.

### Queue (list view)

| F# | Requirement | Satisfied by (Apex / LWC / object) | Verification | Status |
|----|-------------|-----------------------------------|--------------|--------|
| F1 | `getQueue` returns cases with loan #, borrower (write-once snapshot), risk tier, status, approver, SLA. | `AuditQueueController.getQueue` · `AuditCaseService.getQueue` · `auditQueue` (LWC) · `Audit_Case__c` · [AD-04](RISKS-AND-DECISIONS.md#ad-04-borrowername-bound-to-the-write-once-snapshot) | `AuditQueueControllerTest` | built & verified |
| F2 | Critical-tier cases surface above the 200-row cap (`ORDER BY Risk_Tier__c DESC`). | `AuditCaseService.getQueue` (picklist-definition-order sort + `LIMIT 200`) | `AuditQueueControllerTest` | built & verified |
| F3 | Queue filterable by status, risk tier, approver, sampling reason, approval date, due-before, My/All toggle. | `AuditQueueController.getQueue` · `AuditCaseService.getQueue` (bind-var WHERE builder) · `auditQueue` (LWC) | `AuditQueueControllerTest` | built & verified |
| F4 | Rows sort client-side with stable tie ordering; sort fields allow-list guarded. | `auditQueue` (LWC, client-side sort) | Jest (`auditQueue` suite) · manual | built not-yet-run |
| F5 | All queries injection-safe (bind variables + hardcoded allow-lists only). | `AuditCaseService.getQueue` (hardcoded field literals + `:bind` vars, `WITH USER_MODE`) · [F5 §7](BLUEPRINT.md#7-global-constraints) | `AuditQueueControllerTest` | built & verified |

> Note: the LWC exposes **Product** and **Branch** filter controls, but `Audit_Case__c` has no `Loan_Product__c` / `Branch__c` field — `AuditCaseService.getQueue` deliberately does not accept them (TBD — confirm in org; blocked on a data-model decision). They are out of scope for F3 as currently built.

### Case review & replay

| F# | Requirement | Satisfied by (Apex / LWC / object) | Verification | Status |
|----|-------------|-----------------------------------|--------------|--------|
| F6 | `getCaseReview` returns evidence, facts, rule-checks, findings (+ case header + timeline). | `CaseReviewController.getCaseReview` (returns `CaseReviewData`) · `Evidence_Item__c` · `Reconstructed_Fact__c` · `Rule_Check__c` · `Finding__c` | No `CaseReviewControllerTest` in worktree — manual | built not-yet-run |
| F7 | `runReplay` reconstructs facts, selects historical policy, replays rules, commits, creates findings. | `CaseReviewController.runReplay` · `FactAssembler.reconstructFacts` · `PolicyVersionSelector.selectByApprovalDate`/`loadPolicyVersion` · `PolicyRuleEvaluator.replayRules` (co-owned; not in this worktree) · `AuditCommitService.commitReplayResults` (not in this worktree) · `FindingService.createFromRuleChecks` | Manual (replay-pipeline classes not present here) | built not-yet-run |
| F8 | `updateEvidenceStatus` records an evidence-status change + appends `Evidence_Linked` event. | `CaseReviewController.updateEvidenceStatus` · `AuditEventService.logEvent` · `Evidence_Item__c` | Manual | built not-yet-run |
| F9 | `getTimeline` returns the append-only `Audit_Event__c` trail ordered by `Timestamp__c`. | `CaseReviewController.getTimeline` · `AuditEventService.getEventsForCase` (`WITH USER_MODE`) · `Audit_Event__c` | `AuditDataIntegrityTest` · (runAs restricted-user read) | built & verified |
| F10 | Case-review reads degrade gracefully on FLS-blocked optional fields (partial data + notice). | `CaseReviewController` · `PolicyVersionSelector.loadPolicyVersion` · `FindingService.allExceptionsApproved` · [AD-01](RISKS-AND-DECISIONS.md#ad-01-fls-gap-closed-by-graceful-degradation-not-a-permission-set) · [RK-01](RISKS-AND-DECISIONS.md#rk-01-fix-b-silently-swallows-a-genuine-data-error) | Manual (FLS-restricted profile) | built not-yet-run |

### Integrity controls

| F# | Requirement | Satisfied by (Apex / LWC / object) | Verification | Status |
|----|-------------|-----------------------------------|--------------|--------|
| F11 | `Audit_Event__c` append-only — no update (VR `Prevent_Edit_After_Creation`), no delete (trigger `AuditEventPreventDelete`). | `AuditEventPreventDelete` (trigger) · VR `Prevent_Edit_After_Creation` · `Audit_Event__c` · [AD-05](RISKS-AND-DECISIONS.md#ad-05-audit-events-are-append-only) | `AuditDataIntegrityTest` | built & verified |
| F12 | `Borrower_Name_Snapshot__c` write-once (VR `Snapshot_Write_Once`); blank→value first capture allowed. | VR `Snapshot_Write_Once` · `Audit_Case__c.Borrower_Name_Snapshot__c` · [AD-04](RISKS-AND-DECISIONS.md#ad-04-borrowername-bound-to-the-write-once-snapshot) | `AuditDataIntegrityTest` | built & verified |
| F13 | A reviewer cannot be assigned to audit their own approval (VR `Prevent_Self_Audit`). | `AuditCaseService.assignCase` (`SelfAuditException`) · VR `Prevent_Self_Audit` · `Audit_Case__c` | `AuditCaseServiceTest` | built & verified |

### Reporting

| F# | Requirement | Satisfied by (Apex / LWC / object) | Verification | Status |
|----|-------------|-----------------------------------|--------------|--------|
| F14 | A Visualforce PDF evidence report renders case identity + chain-of-custody, FLS-safe, default-escaped. | `AuditEvidenceReportController` · `AuditEvidenceReport.page` (`renderAs="pdf"`, `readOnly="true"`) · `AuditEventService.getEventsForCase` · [AD-06](RISKS-AND-DECISIONS.md#ad-06-all-read-paths-enforce-with-user_mode) | `AuditEvidenceReportControllerTest` | built & verified |

---

## 3. Use Case Index

Full step-by-step narratives live in [DESIGN-AUDIT-QUEUE.md §6](DESIGN-AUDIT-QUEUE.md#6-use-cases).

| Use Case | Domain area | Summary |
|----------|-------------|---------|
| **UC-QUEUE-1** | Queue review | Auditor opens the Audit Queue; sees Critical-first, capped, FLS-enforced list + stat cards. |
| **UC-FILTER-1** | Filter | Auditor filters by Status + Risk Tier (and other controls), toggles My/All cases. |
| **UC-CASE-1** | Click-into-case | Auditor opens AC-0001; reviews evidence, facts, rule-checks, findings, and timeline. |
| **UC-EVIDENCE-1** | Evidence status update | Auditor marks an evidence item `Available`; an `Evidence_Linked` event is appended. |
| **UC-REPLAY-1** | Replay | Auditor runs replay; facts reconstructed, historical policy selected, rules replayed, findings created. |
| **UC-SIGNOFF-1** | Sign-off | Auditor submits for sign-off (blocked if unapproved exceptions); `Signoff_Completed` event appended. |
| **UC-REPORT-1** | Reporting | Auditor generates the PDF evidence report for a closed case. |

---

## 4. Status Legend

| Status | Meaning |
|--------|---------|
| **built & verified** | Implemented and covered by an Apex test class present in the worktree. |
| **built not-yet-run** | Implemented, but its dedicated automated test is absent from this worktree (or is Jest/manual not yet run here). |
| **not built** | Not yet implemented. *(No F# currently carries this status — all F1–F14 have implementing code in the audit-queue codebase.)* |

> [!NOTE]
> Test classes confirmed present in the worktree `classes/` folder: `AuditQueueControllerTest`, `AuditCaseServiceTest`, `AuditDataIntegrityTest`, `AuditEvidenceReportControllerTest`. **Not present** in this worktree: `CaseReviewControllerTest`, and the replay-kernel classes `PolicyRuleEvaluator` / `AuditCommitService` (per [AD-07](RISKS-AND-DECISIONS.md#ad-07-audit-queue-ships-as-its-own-deployable-unit) the kernel is co-owned and excluded from the audit package manifest). Coverage figures cited in RISKS-AND-DECISIONS (Apex 37/37, Jest 12/12) refer to the full org build, not this worktree slice.
