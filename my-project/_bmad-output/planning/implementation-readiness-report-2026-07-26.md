---
stepsCompleted:
  - step-01-document-discovery
  - step-02-source-inventory
  - step-03-epic-coverage-validation
  - step-04-docs-vs-code-reconciliation
  - step-05-final-assessment
documentsUsed:
  carlos: BLUEPRINT.md, SOLUTION-ARCHITECTURE.md, REQUIREMENTS-MATRIX.md, RISKS-AND-DECISIONS.md, DATA-DICTIONARY.md
  epics: my-project/_bmad-output/planning-artifacts/EPICS-AND-STORIES.md (live)
  source: force-app/main/default (objects, classes, triggers, lwc, permissionsets)
method: "Source-first. Every claim below was read out of force-app or the live backlog. No live-org query was made — bash is unavailable in this environment."
supersedes: implementation-readiness-report-2026-06-11.md
---

# Implementation Readiness Assessment — 2026-07-26

**Date:** 2026-07-26
**Baseline:** 2026-06-11 report (95%, READY FOR EP-1)
**Project:** CaseFile — post-close mortgage audit replay and QC (Salesforce)
**Assessor:** Brooks (Chief Architect)

---

## Verdict first

**EP-0 is dev-ready. The project is not gate-proven, and the repository is carrying two engines.**

| Question | Answer |
|---|---|
| Can a developer start EP-1 work today? | **Yes** — schema, seed data, kernel, and tests all exist in source. |
| Is EP-0 provably deployed and green? | **No** — `mortagate.gates.json` p2-002 and p2-003 have not been run this cycle. |
| Do the Carlos docs describe the code that ships? | **No** — they describe the retired intake engine. This is the top finding. |
| Is the backlog's tick state trustworthy? | **EP-0 yes. EP-1 through EP-5 no** — they under-report what is already built. |

---

## Why the prior report is retired

The 2026-06-11 report is stale in three independent ways, which is why it is superseded rather than amended:

It names the product **"Veridact — Salesforce Community Mortgage Approval Engine."** ADR-30 renamed the product to **CaseFile** on 2026-07-03; *Veridact* survives only as an internal codename and inside frozen metadata API names such as `Veridact_Mortgage_Engine_Access`.

It assesses a **borrower-intake product**. ADR-15 pivoted the product to post-close audit replay. The 2026-06-11 EP-1 story list (brand migration, onboarding orchestrator, progress indicator, mobile 375px, chrome removal) belongs to the intake portal, not to the audit tool. Story numbers **US-1.0 … US-1.7 have since been reused for entirely different work** — today's `US-1.4` is the audit replay orchestrator, not "Mobile 375px." Any reader trusting the old report will map story IDs to the wrong scope.

It reports a **95% composite** that was computed against that retired scope, so the number is not comparable to anything below.

---

## Finding 1 (top finding) — two engines live in one repository

`force-app` contains two complete, non-overlapping policy engines. They share the pure kernel and nothing else.

| | Audit engine (current, post-ADR-15) | Intake engine (legacy, pre-ADR-15) |
|---|---|---|
| Assembler | `ReplayService` (Step 1: ASSEMBLE) | `FactAssemblerService` |
| Kernel | `PolicyRuleEvaluator` | `PolicyRuleEvaluator` *(shared)* |
| Writer | `ReplayCommitService` | `DecisionCommitService` |
| Orchestrator | `ReplayService` | `LoanDecisionService` |
| Reads | `Audit_Case__c`, `Borrower_Snapshot__c`, `Evidence_Item__c`, `Policy_Version__c` → `Policy_Rule__c` | `Loan_Application__c`, `Extracted_Facts__c`, `Evidence__c`, `Policy_Rule_Version__c` |
| Writes | `Replay_Check__c`, `Audit_Event__c` | `Decision_Event__c` |
| Ordering | `Sort_Order__c ASC NULLS LAST, Rule_Code__c ASC` (SOQL, schema-level) | `RuleCodeComparator` (in-memory sort) |

Neither engine calls the other. `ReplayService` does **not** reference `FactAssemblerService`; the only live caller of `FactAssemblerService` is `LoanDecisionService`.

**Full object inventory — 19 definitions, not 11:**

| Group | Count | Objects |
|---|---|---|
| Canonical audit schema (DATA-DICTIONARY §0.1) | 11 | `Audit_Case__c`, `Loan__c`, `Borrower_Snapshot__c`, `Policy_Version__c`, `Policy_Rule__c`, `Evidence_Item__c`, `Replay_Check__c`, `Finding__c`, `Audit_Receipt__c`, `Audit_Event__c`, `Agent_Action_Log__c` |
| Gating precondition (ADR-24, outside the 11) | 1 | `Sanctions_Screening__c` |
| **Legacy intake schema** | **5** | `Loan_Application__c`, `Extracted_Facts__c`, `Evidence__c`, `Decision_Event__c`, `Policy_Rule_Version__c` |
| Custom metadata types | 2 | `Adverse_Action_Config__mdt`, `PreFlight_Assumption__mdt` |

**Correction to the record.** The 2026-07-26 ruling appended to US-0.4 concluded "11 canonical + 1 gating = 12 audit-side SObjects." That ruling is still correct *about `Sanctions_Screening__c`*, but it understated the repository: 5 legacy intake objects and roughly a dozen legacy Apex classes are also in `force-app` and will deploy with everything else unless deliberately excluded. Recorded here rather than quietly amended.

**Why this matters, in order of severity.** Every Carlos doc describes the *legacy* stack as the architecture: `BLUEPRINT.md` §"Layer 1: Fact Assembly (`FactAssemblerService`)", `SOLUTION-ARCHITECTURE.md` line 86 and the line-193 sequence diagram, and `RISKS-AND-DECISIONS.md` ADR-5 all name `FactAssemblerService → PolicyRuleEvaluator → DecisionCommitService`. **The audit path that actually ships is undocumented in the source-of-truth docs.** Under the project's own Schema > Code > Docs precedence the code wins, so nothing is *broken* — but a new developer reading the blueprint will build against the wrong engine, and an examiner reading it will be shown an architecture the product does not run.

Secondary consequences: deploy surface and test-execution time are roughly doubled; `PolicyRuleEvaluator` now has two consumers, so any change to it must satisfy both; and the intake engine's `Policy_Rule_Version__c` has fields (`Threshold_High__c`, `Allowed_Values__c`, `Rule_Explanation__c`, `Override_Permitted__c`) that the audit engine's `Policy_Rule__c` lacks — see Finding 4.

**This is a decision, not a defect.** It needs a ruling from Sabir, not a fix from me. The three options are laid out under *Decisions required* below.

---

## Finding 2 — EP-0 is 36/36 in source, and org-unproven

Reconciled story by story against `force-app` on 2026-07-26. One genuine gap was found and closed the same day.

**The gap:** `Policy_Rule__c.Sort_Order__c` was specified in `DATA-DICTIONARY.md` §2.5 (FR-28) but had never been implemented. Fixed across six files:

| File | Change |
|---|---|
| `objects/Policy_Rule__c/fields/Sort_Order__c.field-meta.xml` | Created — `Number(4,0)`, optional |
| `permissionsets/Veridact_Mortgage_Engine_Access.permissionset-meta.xml` | Added FLS grant |
| `classes/ReplayService.cls` | `ORDER BY Sort_Order__c ASC NULLS LAST, Rule_Code__c ASC` |
| `classes/SeedDataLoader.cls` | `makeRule()` now assigns the parameter it was discarding |
| `classes/ReplayServiceTest.cls` | `buildRule()` fixed; 3 determinism tests added |
| `classes/SabirSrSmokeTest.cls` | `buildRule()` fixed |

The defect was three-headed: `SeedDataLoader.makeRule()`, `ReplayServiceTest.buildRule()`, and `SabirSrSmokeTest.buildRule()` all accepted a `sortOrder` argument and silently dropped it. Ten call sites passed 0–9 into a void.

**Severity correction.** I first reported this as "replay determinism is unpinned." That was wrong. The subquery already carried `ORDER BY Rule_Code__c ASC` and `ReplayService` back-maps outcomes to rules by business key, so replays *were* deterministic — deterministic by alphabetical accident rather than by authored intent, and silently breakable by anyone choosing a new rule code. Real defect, wrong severity.

**The FLS trap worth remembering.** `Veridact_Mortgage_Engine_Access` had zero `Policy_Rule__c` field entries before today, which looks like an omission and is not: every other field on the object is `<required>true</required>`, and universally required fields cannot carry a `fieldPermissions` entry. `Sort_Order__c` is optional, so without an explicit grant the `WITH USER_MODE` rule fetch would have silently dropped it for every non-admin — a bug that would never reproduce for whoever debugged it.

**What source cannot prove.** Two EP-0 criteria are org-only and no amount of reading closes them: that the metadata is actually deployed to `mortagate-de` (gate p2-002) and that the Apex tests actually pass (gate p2-003). Until those two commands run, EP-0 is dev-ready and not gate-proven.

---

## Finding 3 — the EP-1…EP-5 backlog under-reports the build

Every acceptance box from line 234 onward in the live backlog is unticked, yet the implementing source demonstrably exists:

| Story area | Backlog | In source |
|---|---|---|
| US-1.1 assembler / US-1.3 replay orchestrator | ☐ | `ReplayService.cls` + `ReplayServiceTest.cls` |
| US-1.2 pure evaluator | ☐ | `PolicyRuleEvaluator.cls` + test |
| US-1.3 commit service | ☐ | `ReplayCommitService.cls` + test |
| US-1.5 audit event service | ☐ | `AuditEventService.cls` |
| US-1.6 Case Review two-pane | ☐ | `CaseReviewController.cls` + `lwc/caseReview` |
| US-1.8 finding creation | ☐ | `FindingController.cls` + `lwc/findingDetail` |
| US-1.9 sign-off + receipt | ☐ | `SignoffController.cls` + `lwc/signoffReceipt` |
| EP-2 audit queue | ☐ | `AuditQueueController.cls` + 3 `auditQueue*` LWCs |
| EP-4 analytics | ☐ | `AnalyticsController.cls` + `auditAnalytics`, `auditMetricCards` |

Thirteen LWCs and sixty-five Apex classes are present. **The backlog is not a reliable picture of remaining work for EP-1 onward** — it will overstate what is left, and a sprint planned from it will be planned against fiction.

I did not tick these boxes. Ticking EP-0 was defensible because each criterion maps to a single named metadata file I could open. EP-1+ criteria assert *behaviour* ("replay completes in < 5 seconds", "bulk test: 200 cases in one transaction", "keyboard navigable"), and behaviour cannot be verified by reading. Ticking them from source inspection would launder an assumption into a record — which is the failure mode this whole reconciliation exists to prevent.

---

## Finding 4 — known divergences carried forward

| # | Divergence | Where | Disposition |
|---|---|---|---|
| D-1 | US-1.1 AC says "Orchestrates `FactAssemblerService` → …". The audit path uses `ReplayService`'s own ASSEMBLE step; `FactAssemblerService` serves the *legacy* engine. | backlog:281 | Rewrite AC once Finding 1 is ruled |
| D-2 | US-1.1 AC says "Results sorted by `Rule_Code__c` (deterministic ordering)". **Superseded today** by `Sort_Order__c` primary / `Rule_Code__c` tiebreaker. | backlog:254 | Rewrite AC |
| D-3 | Budget: ACs say 3 SOQL + 1 DML; `ReplayService` docblock and tests say **3 SOQL + 2 DML** (checks + event). Code is authoritative. | backlog:282 | Correct the AC to 2 DML |
| D-4 | `Policy_Rule__c.Operator__c` exposes `BETWEEN` and `IN`, but the object has no `Threshold_High__c` and no `Allowed_Values__c`. **Selecting either operator produces an unevaluable rule.** | schema | EP-5 hardening — see below |
| D-5 | Six `Policy_Rule__c` fields specified in DATA-DICTIONARY §2.5 are absent from source: `Threshold_High__c`, `Rule_Explanation__c`, `Allowed_Values__c`, `Regulatory_Citation__c`, `Override_Permitted__c`, `Override_Justification_Required__c`. | schema | EP-5 hardening |
| D-6 | API version drift: org 67.0 vs `sourceApiVersion` 66.0. | `sfdx-project.json` | Low risk; align at next deploy |

**D-4 deserves promotion.** It is the only divergence a *user* can trip over without writing code: a policy author picking `BETWEEN` in the rule editor creates a rule that cannot evaluate, and the failure will surface as an `INDETERMINATE` replay result with no explanation of why. Either ship the two missing threshold fields or restrict the picklist to the four operators that work. Restricting the picklist is the smaller change and should be done before any non-developer touches the rule editor.

---

## Scorecard

Scored against the **current** (post-pivot) scope. Not comparable to the 2026-06-11 composite, which measured a different product.

| Dimension | Score | Note |
|---|---|---|
| Schema completeness (EP-0) | 10/10 | 11 canonical + 1 gating, all present; last gap closed today |
| Kernel correctness and purity | 10/10 | ADR-5 held: 0 SOQL / 0 DML in `PolicyRuleEvaluator` |
| Replay determinism | 10/10 | Now schema-pinned and covered by 3 dedicated tests |
| Immutability enforcement | 9/10 | 6 triggers + 6 validation rules; org-unproven |
| Test coverage breadth | 8/10 | Every service has a paired test class; coverage % unknown until p2-003 runs |
| Backlog accuracy | 4/10 | EP-0 reconciled; EP-1–EP-5 tick state stale (Finding 3) |
| **Docs ↔ code alignment** | **3/10** | Carlos docs describe the retired engine (Finding 1) |
| Scope hygiene | 4/10 | Two engines, 5 legacy objects, no ruling on removal |
| Org verification | 0/10 | p2-002 and p2-003 not run this cycle |

Composite is deliberately omitted. Averaging a 10 for kernel purity against a 0 for org verification produces a number that hides the only two facts that decide whether this ships.

---

## Epic status

| Epic | Status | Blocker |
|---|---|---|
| EP-0 Schema Foundation | 🟡 **Dev-ready in source, org-unproven** | Run p2-002 + p2-003 |
| EP-1 Vertical Slice | 🟡 **Largely built, unreconciled** | Reconcile ACs against behaviour; rule on Finding 1 |
| EP-2 Audit Queue | 🟡 Controller + 3 LWCs exist, unreconciled | Same |
| EP-3 Agentforce Actions | 🔴 Blocked | Licence status on `mortagate-de` unknown; ADR-23 quarantine |
| EP-4 Analytics | 🟡 Controller + 2 LWCs exist, unreconciled | Depends on EP-2 |
| EP-5 Integration and Hardening | ⬜ Not started | Carries D-4 and D-5 |

---

## Decisions required

**1. What happens to the legacy intake engine?** Three options:

*Delete it.* Smallest deploy surface, fastest tests, docs become true once rewritten. Risk: `Decision_Event__c` and `Policy_Rule_Version__c` are append-only audit objects — if anything was ever written to them in a real org, deleting is destructive and possibly a records-retention problem. Verify emptiness first.

*Quarantine it via `.forceignore`*, as ADR-23 already does for Agentforce metadata. Reversible, non-destructive, shrinks the deploy surface immediately. Leaves dead code in git, which is a smaller sin than deleting evidence. **This is my recommendation** — it is the only option that is both fast and reversible, and it does not require answering the retention question today.

*Keep and document it* as a supported second product line. Only correct if intake is genuinely coming back. Costs a full rewrite of three Carlos docs to describe two engines instead of one.

**2. Rewrite the Carlos docs to describe the audit engine.** Not optional once option 1 is chosen. `BLUEPRINT.md`, `SOLUTION-ARCHITECTURE.md`, and ADR-5 in `RISKS-AND-DECISIONS.md` currently document an engine the product does not run.

**3. Restrict `Operator__c` or ship the missing threshold fields (D-4)** before any non-developer opens the rule editor.

---

## Still open from prior reports

Unchanged and still unanswered: Data 360 / Agentforce licence status on `mortagate-de`; whether the org is permitted to make callouts at all (this decides ADR-31 and the Allura runtime question); ADR-31 `Auditor_Memory__c` scope; the four §8 decisions in `DESIGN-LangChain-Compliance.md`; and multi-tenancy.

ADR-31 remains blocked on the licence and callout answers, so `Auditor_Memory__c` rows in `REQUIREMENTS-MATRIX.md` and `DATA-DICTIONARY.md` are deliberately not written yet.

---

## Method and its limits

Every factual claim above was read out of `force-app` or the live backlog file. **No live-org query was made** — the shell is unavailable in this environment, so nothing here can speak to deployment state, test results, coverage percentages, or data already sitting in `mortagate-de`.

Corollary worth stating plainly: this report can prove that code *exists* and can prove that code is *absent*. It cannot prove that code *works*. The two org gates are not a formality at the end of the checklist; they are the only steps in this assessment that test reality.

---

*Assessment completed: 2026-07-26*
*Assessor: Brooks (Chief Architect, CaseFile)*
*Supersedes: implementation-readiness-report-2026-06-11.md*
