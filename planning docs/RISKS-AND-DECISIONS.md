# RISKS AND DECISIONS

> [!NOTE]
> **AI-Assisted Documentation**
> Portions of this document were drafted with the assistance of an AI language model.

This is the decision log. Undocumented decisions are decisions waiting to be made again, badly, by someone else. Each entry records what we chose, what we rejected, and why — so the rationale survives the people.

---

## Architectural Decision Records (ADR)

### ADR-1 — Append-only audit, enforced in code (not field history)
**Decision:** `Decision_Event__c` is immutable. Every UPDATE and DELETE is blocked by the `DecisionEventImmutabilityTrigger` (before update / before delete → `addError`). A changed outcome is a NEW event (`Triggered_By__c = RE_EVALUATION`), never an edit.
**Rejected:** Salesforce Field History Tracking; a "last modified" model.
**Why:** "Every decision has a receipt." Field history is opt-in, capped, and silently truncates. A receipt that can be altered is not a receipt. Enforcement lives in code so it cannot be bypassed by API, Flow, or another trigger. **Proven by** `DecisionEventImmutabilityTest` (insert allowed; bulk update blocked & records unchanged; bulk delete blocked & records survive).

### ADR-2 — Worst-wins verdict precedence
**Decision:** Severity collapses to a single verdict by worst outcome: any HARD_DECLINE → HARD_DECLINED; else any SOFT_DECLINE → PENDING_REVIEW; else any WARNING → APPROVED_WITH_CONDITIONS; else APPROVED. ADVISORY failures never change the verdict.
**Rejected:** Weighted scoring / point systems.
**Why:** Lending decisions must be explainable to a regulator and a borrower in one sentence. A score of "0.62" explains nothing; "your DTI exceeds 43%" explains everything. Precedence is deterministic and citable.

### ADR-3 — A missing fact is INDETERMINATE, never a decline
**Decision:** When a rule's `Fact_Field__c` is absent from the context, the rule yields INDETERMINATE and does not contribute to a decline.
**Rejected:** Treating null as failure.
**Why:** During progressive onboarding, most facts are absent early. Declining for "not yet uploaded" would be both wrong and cruel. Absence is a state of the process, not a judgment on the borrower.

### ADR-4 — Rules are data, not code
**Decision:** Policy lives in `Policy_Rule_Version__c` records with a compound key `(Rule_Code__c, Version_Number__c)`. Analysts version rules through quick actions; no deployment, no sandbox refresh. The evaluator reads them generically by operator + threshold + fact field.
**Rejected:** Hardcoded thresholds in Apex.
**Why:** Underwriting thresholds change with the market and with regulation. Coupling them to a release train guarantees they go stale. Versioning + effective-date windows give a complete, queryable history of what governed any given decision.

### ADR-5 — Three-layer engine with a pure kernel
**Decision:** `FactAssemblerService` (the only reader) → `PolicyRuleEvaluator` (pure: zero SOQL, zero DML) → `DecisionCommitService` (the only writer). `LoanDecisionService` is a thin orchestrator/Flow adapter.
**Rejected:** A single service doing query + evaluate + write.
**Why:** Conceptual integrity. The kernel is exhaustively unit-testable without an org and bulk-safe by construction. The contract is **3 SOQL + 1 DML for N applications**, proven by `LoanDecisionServiceTest.bulk_200Applications_withinGovernorLimits` asserting `soqlUsed ≤ 3` and `dmlUsed ≤ 1` at 200 records.

### ADR-6 — Deterministic governing-rule order
**Decision:** `loadGoverningRules` sorts the resolved set by `Rule_Code__c` before returning (Apex `Map.values()` order is not guaranteed).
**Rejected:** Returning `Map.values()` directly.
**Why:** The verdict is order-independent (worst-wins), but the receipt and any future explanation sequencing must be byte-stable across runs for audit reproducibility. One comparator removes a latent source of nondeterminism. *(Raised by Brooks in architecture review.)*

### ADR-7 — Pre-check runs the same kernel, creates no record
**Decision:** `PreFlightEvaluator` (and `PreFlightController` for the LWC) produces the soft band from the live INCOME + COLLATERAL rules without creating a `Loan_Application__c`.
**Rejected:** A separate, simplified pre-check formula.
**Why:** If the pre-check used different math than the real decision, the borrower's first number would be a promise the system might not keep. Same kernel = honest promise. No record = no friction and no orphaned drafts before the borrower commits.

### ADR-8 — No pre-filled answer values in intake (the "horoscope" rule)
**Decision:** Property value and income start empty; "Continue" is disabled until the borrower actually touches the control; the display shows "Set your estimate," never a fake number.
**Rejected:** Convenient slider defaults ($450k / $120k).
**Why:** A pre-filled value produces a "personalized" range the borrower never entered — a horoscope. The product's credibility rests on the number being *theirs*. *(Raised by Jobs in product review.)*

### ADR-9 — Semantic colors are chips, not text
**Decision:** Approved/conditions/review/declined colors are chip/badge **backgrounds** with paired text colors, all WCAG ≥ 4.5:1. Amber is reserved for action (CTAs + the accent bar) and never decorates the approved screen — green owns approval.
**Rejected:** Colored status text on the indigo background.
**Why:** Verified contrast failures as text on indigo (approved 3.26:1, review 2.64:1, declined 1.66:1). Accessibility is non-negotiable in a regulated flow. *(Raised by Glaser in brand-enforcement review.)*

### ADR-10 — Adverse Action Notice composed in a pure class, grounded in cited regulation
**Decision:** The ECOA / Reg B notice is built by a pure `AdverseActionService` (zero SOQL/DML, unit-testable without an org) fed by a thin `with sharing` controller; reasons come from each failing rule's `Rule_Explanation__c` (specific), the §701(a) anti-discrimination text and oversight agency live in `Adverse_Action_Config__mdt` (config-as-data), and the PDF is rendered with standard `{!}` escaping. Requirements were grounded in the verbatim text of **12 CFR 1002.9** (Cornell Law mirror) and FCRA **15 U.S.C. 1681m**, not from memory.
**Rejected:** (a) A generic "your application did not meet our criteria" template — explicitly **non-compliant** under 1002.9(b)(2). (b) Hard-coding the creditor/agency/notice text in Apex — would force a release for a compliance edit. (c) Letting the FCRA block invent a consumer reporting agency identity we do not yet have.
**Why:** The (b)(2) specific-reason requirement is the trap; our reasons are the rules' own explanations, and a test pins that the forbidden "qualifying score" / "internal standards" phrasing is never emitted. Config-as-data mirrors `PreFlight_Assumption__mdt` so legal owns the wording. The FCRA block is honest about scope — the CRA identity arrives with P3. **This closes the *code* half of the P1 adverse-action item; counsel sign-off and proof-of-delivery remain ⚖️.** *(See DESIGN-adverse-action.md; FR-19 / CR-1..5.)*

### ADR-12 — Audit reconciliation: dad's 4 credit rules vs 6 starter rules

**Decision:** After reconciling the external audit requirements (4 credit rules) against the 6 starter policy rules, the following actions were taken:

1. **FICO_MIN** (620, HARD_DECLINE) — exact match with audit. No change.
2. **DTI_MAX** (0.43, HARD_DECLINE) — system threshold is 43%, audit guideline is 45%. The system is intentionally MORE conservative. **Keep DTI_MAX at 43%.** The 2% gap is a feature, not a bug: the system catches what the guideline would allow. This discrepancy was explicitly visible on the audit check sheet (guideline 45% vs system 43%).
3. **ADDRESS_TENURE_MIN** — **new rule added** (RESIDENCY, GTE 12, SOFT_DECLINE, `Address_Tenure_Months__c`). No prior rule existed. New field `Address_Tenure_Months__c` (Number 4,0) added to `Extracted_Facts__c`. New picklist value RESIDENCY added to `Fact_Type__c`.
4. **EMPLOYMENT_TENURE** (24 months, WARNING) — threshold matches audit (2 years). Severity kept as WARNING: dad's audit treats this as a verification item, not a decline trigger.

**Rejected:** (a) Changing DTI_MAX from 43% to 45% — would weaken a regulatory-grounded threshold without clear business mandate. (b) Escalating EMPLOYMENT_TENURE to SOFT_DECLINE — no evidence in audit that it should be a gate. (c) Adding a second DTI_GUIDELINE_WARNING rule at 45% — premature complexity; the discrepancy is documented and can be layered later if needed.
**Why:** Supersede-not-replace (ADR-4). No existing rule threshold was modified. One pure ADD (ADDRESS_TENURE_MIN). The DTI gap is architectural: the system's 43% is backed by CFPB 12 CFR 1026.43(c)(2) — the Qualified Mortgage ATR threshold. Dad's 45% is an internal guideline that is less restrictive. Keeping both visible (rule at 43%, documentation noting 45% guideline) preserves the audit trail.

### ADR-11 — Epic & story planning layer (EPICS-AND-STORIES.md)
**Decision:** Generate a structured epic-and-story decomposition covering all 26 requirements (FR-1..19, NFR-1..7, CR-1..5), grouped into 6 epics (EP-0..5) following the ENTERPRISE-READINESS-ROADMAP phase structure. Each story traces to specific FR#/CR#/NFR# identifiers. EP-0 stories map directly to existing Apex test classes for verification; EP-1 addresses Pike's ❌ UX gate findings (missing orchestrator, no progress indicator, 4 untested LWCs, mobile-first unverified).
**Rejected:** (a) Single flat backlog without phase grouping — would collapse 15% enterprise-ready code with 85% forward work into one undifferentiated list. (b) BMad-format epics requiring PRD/UX/Architecture documents in BMad conventions — project uses Carlos Guidelines; the mapping from Carlos docs onto epics was done explicitly in the readiness report.
**Why:** The BMAD implementation-readiness report flagged the 0% epic coverage as the single structural gap. With R-1 resolved, the codebase is verified but has no structured work-unit layer. This document provides that layer, bridges Carlos ↔ BMAD, and gives every FR a home in a story. **Generated 2026-06-07 by Brooks orchestrating Knuth + Scout + Pike in Party Mode.** *(See EPICS-AND-STORIES.md.)*

### ADR-13 — Brand evolution: Figma Brand Kit v1.0.1 replaces v1.0.0 palette
**Decision:** The Veridact visual identity migrates from the dark-authority palette (Indigo Depth #1b2b5e / Proof Amber #d4920a / Source Serif 4) to the Figma Brand Kit v1.0.1 warm palette (Cream #F5F0E8 / Charcoal #1F1E1C / Orange #E25D22 / Approval #308357 / Outfit Bold). This is a full dark-to-light paradigm shift affecting all 6 LWC components, veridactTokens.css, and all design documentation. The body font (Inter) is unchanged.
**Rejected:** (a) Keeping the old Indigo palette — owner confirmed Figma v1.0.1 is canonical. (b) Dual-brand strategy (audit vs portal) — a single brand serves both surfaces.
**Why:** Brand evolution. The warm palette better expresses Veridact's "mortgage audit intelligence" positioning under the Allura ecosystem. WCAG re-verification required: Charcoal on Cream passes AA (14.68:1); Orange on Cream passes only for large text ≥14pt bold (3.18:1); Figma's Approval green #308357 fails AA at 4.10:1 — retain old Approved #16734a (5.16:1 on Cream) for status chips. Amber #d4920a fails completely on Cream (2.34:1) — replaced by Orange. ADR-9 chip principle preserved: semantic colors remain chip/badge backgrounds, never text on Cream.

### ADR-14 — Fact correction deferred to EP-4; Evidence Queue is confirm-only
**Decision:** The Evidence Queue's "confirm/correct" UX is narrowed to "confirm only" for EP-1. Borrowers can confirm extracted facts via a checkbox but cannot edit them. Fact correction arrives in EP-4 alongside document-extraction integrations.
**Rejected:** (a) Building FactCorrectionService in EP-1 — adds ~2-3 days of Apex + LWC work to a journey-orchestration epic. (b) Hybrid flag-only approach — borrower flags but no downstream handling exists, creating false expectation.
**Why:** EP-1's goal is the journey spine (6-screen state machine, progress indicator, Flows). Adding correction Apex muddies the scope. The extraction method itself is undecided (OQ-2), so building correction before extraction is premature. DESIGN-onboarding-ux.md updated to say "view-only with confirm checkbox."

> _ADRs 15–17 (Agentforce confirmed, Production Path A, dual-kernel debt) were logged to Allura Brain during the audit pivot and are pending backfill into this doc. ADR-18/19 below formalize the items that were actioned in code this session._

### ADR-18 — `Policy_Rule__c` is a thin reference object (dual-kernel)
**Decision:** `Policy_Rule__c` carries exactly 8 fields — `Rule_Code__c`, `Rule_Label__c`, `Rule_Category__c`, `Operator__c`, `Threshold_Value__c`, `Fact_Field__c`, `Severity__c`, `Policy_Version__c`. All versioned detail (`Threshold_High__c`, `Sort_Order__c`, `Rule_Explanation__c`, `Allowed_Values__c`, `Override_Permitted__c`, `Override_Justification_Required__c`, `Regulatory_Citation__c`) lives only on `Policy_Rule_Version__c`. `ReplayService` keeps an ADAPT step that maps `Policy_Rule__c` → in-memory `Policy_Rule_Version__c`, so the pure evaluator's interface is unchanged.
**Rejected:** (a) Keeping the 7 detail fields on both objects — duplicated, drift-prone, and the source of the long-running "phantom field" confusion. (b) Migrating the kernel wholesale onto `Policy_Rule__c` and deleting `Policy_Rule_Version__c` (Path Y) — larger blast radius than warranted now.
**Why:** Conceptual integrity for the dual-kernel. One object is the analyst-facing reference; the other is the versioned record of what governed a decision. The adaptor already existed, so thinning the reference object cost nothing and removed seven fields' worth of ambiguity. **Note:** thinning was *architecturally* correct but was NOT the fix for the deploy/test failures — that was FLS (ADR-19).

### ADR-19 — The multi-session "phantom field" bug was Field-Level Security; CMDT records load via the Apex Metadata API
**Decision:** (a) Diagnose Salesforce "missing field" symptoms with the Tooling API (`CustomField` + `FieldPermissions`), never with SOQL/`describe` alone — those run in user context and enforce FLS. (b) The permission set `Veridact_Mortgage_Engine_Access` now grants FLS on every grantable custom field across all 16 custom objects (133 grants). (c) The 2 `CustomMetadata` records that fail `sf project deploy start` with a server-side `UNKNOWN_EXCEPTION` (Salesforce support ErrorId) are created instead via the **Apex Metadata API** (`Metadata.Operations.enqueueDeployment`), scripted at `scripts/load-cmdt.apex`; `customMetadata/` is excluded from the CLI deploy on this org family.
**Rejected:** (a) "Org is poisoned / use a fresh org" — disproven: the symptom reproduced on a brand-new scratch org because it was never the org. (b) Removing/retyping the CMDT `LongTextArea` field — disproven: the all-`Number` record failed identically; the type deploys fine, only the *record* deploy throws. (c) Manual Setup-UI record entry — not repeatable; the Apex loader is.
**Why:** Required fields are auto-readable, so they appeared "present" while optional fields with no FLS grant were invisible — the exact fingerprint that masqueraded as "deployed but doesn't exist" across `Borrower_Snapshot__c`, `Policy_Rule__c`, and `Policy_Version__c` for three sessions. A field-meta deploy does not grant FLS; the permission set must. Result: full `force-app` (minus `customMetadata/`) deploys 279/279 zero-rollback; Apex 75/75 (100%); LWC Jest 39/39; SabirSr demo green.

### ADR-20 — Auditor demo surface is a Salesforce LWC on a Lightning page (not the React cockpit)
**Decision (2026-06-16):** The auditor-facing Audit Queue is built as native Salesforce LWCs (`auditQueue` + `auditMetricCards` + `auditQueueFilters`, reusing the tested `auditQueueDatatable`/`riskBadge`) over a FLS-safe `AuditQueueController`, hosted on the `Veridact_Audit_Queue` FlexiPage inside the `Veridact_Audit` Lightning app. The React `veridact-frontend` stays a sales/marketing cockpit, not the system of record.
**Rejected:** Building the audit surface as a separate React/Vercel app calling Salesforce by API.
**Why:** Path A — one SOC 2 boundary inherited from Salesforce. Governance (FLS, append-only `Audit_Event__c`/`Agent_Action_Log__c`, immutable `Audit_Receipt__c`) and Agentforce all live where the data lives; the agent's SOQL runs as the user, so it cannot see what the auditor cannot. A second system would require its own security review. **Proven by** `AuditQueueControllerTest` (6) + Jest (9, incl. parent wire/search) + on-org screenshot of the rendered queue (Sabir Sr. high-risk, 5 metric cards, filters, `Review ›`).

### ADR-21 — Deterministic kernel decides; the agent only narrates (read-only diagnosis)
**Decision (2026-06-16):** "What's wrong with this loan?" is answered by `LoanDiagnosisService` (an `@InvocableMethod` + `@AuraEnabled` fallback) that **reads persisted `Replay_Check__c`** and phrases the result in English. It never re-runs `ReplayService.replay()` (which commits DML — a question must stay read-only), never decides compliance, applies a staleness guard (newest `Replay_Timestamp__c` vs `Loan.LastModifiedDate`), and always defers the final determination to the human auditor. Agentforce delivery = interactive single-loan agent (MVP) + Agentforce Grid as a licensed-org bulk-QC stretch; same invocable feeds both.
**Rejected:** Letting the LLM compute or override verdicts; having the agent call `replay()` on demand.
**Why:** No hallucinated verdicts in a regulated workflow — the tested Apex engine owns the truth, the LLM owns the wording. **Proven by** `LoanDiagnosisServiceTest` (3: surfaces DTI_MAX, no "denied", writes `Agent_Action_Log__c`, no-replay path) + live run on `veridact-af` (2 violations, guardrail text, `Agent_Action_Log__c` count = 1).

### ADR-22 — Agentforce enables on a Developer-edition scratch org; deploy piecewise
**Decision (2026-06-16):** Add `"features": ["Einstein1AIPlatform"]` plus `agentPlatformSettings.enableAgentPlatform` and `einsteinGptSettings.enableEinsteinGptPlatform` to `config/project-scratch-def.json`. Because a **full** `sf project deploy start` throws a generic `UNKNOWN_EXCEPTION` (0 component errors) on this org family, deploy **piecewise in dependency order**: objects → pages+classes+triggers → lwc+staticresources → flexipages+tabs+applications+permissionsets → customMetadata.
**Rejected:** Assuming Agentforce requires a licensed (non-scratch) org; relying on a single full-source deploy.
**Why:** Retires the prior assumption (plan risk #1) that Agentforce couldn't run on Dev-edition scratch — `veridact-af` provisioned the platform cleanly. Classes reference VF page `AdverseActionNotice`, so pages must deploy with/before classes; a `CustomApplication` cannot reference `standard-<CustomObject>__c` tabs.

### ADR-23 — Agentforce agents are not cleanly org-portable; migration requires manual re-binding
**Decision (2026-06-19):** The migration runbook MUST treat Agentforce agents as *partially* source-deployable and add a manual post-deploy re-binding step in the **target** org. After `force-app` deploys green, an operator must: (a) create/assign an Agentforce Service Agent User in the target org, (b) re-point the agent's `<botUser>` binding via Agent Builder, (c) re-pull the agent metadata, and (d) re-activate the agent. The org-bound `<botUser>` on the Bot metadata and the org-specific `genAiPlugin` `developerName` prefix (e.g. `p_16jAq…`) are explicitly excluded from the "deploy and done" path.
**Rejected:** Treating agent (Bot) and `genAiPlugin` metadata as fully source-deployable like Apex/LWC — i.e., assuming a green `force-app` deploy yields a live agent in the target org.
**Why:** During the `veridact-af` (scratch) → `mortagate-de` (permanent Dev) migration, all base + CMDT + Agentforce components deployed green, yet the agent `Veridact_Auditor_Copilot_v4` could **not** activate: its `<botUser>` pointed at the source scratch org's user hash, a user absent in `mortagate-de`. Licensing was *not* the cause — 200 free Agentforce Service Agent User seats (PSLs) were available. Salesforce reported "This Agent Type should have a user assigned." This proves the agent identity binding is provisioned **per-org in Setup**, not in source control, so it cannot survive cross-org migration as pure source. (Raised by Hightower during R-10 runtime verification; see Risk Register R-10.)

### ADR-24 — KYC/OFAC are gating preconditions OUTSIDE the pure kernel (R-8 design ratified)
**Decision (2026-06-19):** Ratify the R-8 design (`my-project/_bmad-output/planning/DESIGN-kyc-ofac.md`). Identity verification (KYC/CIP) and OFAC sanctions screening are **preconditions evaluated before** `PolicyRuleEvaluator` runs — never modeled as `Policy_Rule__c` records and never entering the pure kernel. A sanctions `Confirmed_Match` (or any uncleared `Potential_Match`/`Pending_Review`/absent screen) **blocks origination regardless of the policy verdict**, and conversely a clean screen never improves a policy decline; the two axes are orthogonal. Screening events are recorded in a new append-only `Sanctions_Screening__c` (Lookup→`Loan__c`, `deleteConstraint=Restrict`, PreventDelete-guarded). Raw SSN is **never** stored in Salesforce — external tokenization only (`SSN_Token__c` + `SSN_Last_Four__c` on `Loan__c`), and no raw/de-tokenized SSN may touch any immutable, snapshot, or Agentforce payload. Resolves Brooks-owned open questions OQ-R8-3 (identity *status* on `Loan__c` is sufficient for R-8; append-only `Identity_Check__c` history deferred to P3) and OQ-R8-5 (`Sanctions_Screening__c` parents on `Loan__c`, the audit-relevant snapshot side, surviving the dual-kernel split).
**Sign-off:** Owner (Sabir) ✅, Architect (Brooks) ✅. **Still required before R-8 clears:** Compliance reviewer (OQ-R8-2 "no screen = hard BLOCK", OQ-R8-4 match-score cutoff, OQ-R8-6 retention vs vault-deletion duty) and Security (OQ-R8-1 vault vendor, OQ-R8-7 token-at-rest encryption). This ratifies the **design** step only.
**Rejected:** Modeling sanctions/KYC as policy rules inside the kernel (would force ADR-2 "worst-wins" to collapse a sanctions hit into a creditworthiness `HARD_DECLINED` — an ECOA-wrong adverse-action characterization, and would make the kernel impure/un-unit-testable per ADR-5); storing raw SSN under Shield encryption alone as the single control.
**Why:** Keeps the kernel exhaustively unit-testable without an org (ADR-5) and preserves the ADR-3 asymmetry — a *missing borrower fact* is INDETERMINATE (never a decline) for progressive onboarding, but a *missing sanctions screen* must BLOCK, because absence of proof of clearance is not clearance. (Drafted by Knuth; kernel-boundary signed off by Brooks; see Risk Register R-8.)

---

## Risk Register

| ID | Risk | Severity | Likelihood | Mitigation / Status |
|----|------|----------|-----------|---------------------|
| R-1 | **No live-org gate verification this session** — Apex written & inspected but never deployed/executed; `sf org display --target-org mortagate-de` → NamedOrgNotFoundError. | High | Certain (was) | **RESOLVED (2026-06-07).** 53/53 Apex (94%), 10/10 Jest, clean deploy preview. Gate R-1 is GREEN. Three defects fixed (FLS gap, case-insensitive identifier shadowing, SOQL field omission). CMDT deploy limitation documented. |
| R-2 | Platform Events for real-time Decision Room may be limited in Developer Edition. | Medium | Medium | OPEN (OQ-3). Fallback: polling. Decision Room already degrades gracefully (pending heartbeat state needs no live feed). |
| R-3 | Document fact extraction method undecided (Apex OCR vs external AI vs manual). | Medium | High | OPEN (OQ-2). Engine is decoupled — it reads `Extracted_Facts__c` regardless of how facts arrive. |
| R-4 | Decision latency model (sync vs async) unspecified. | Medium | Medium | OPEN (OQ-1). Engine is sync and fast; async is an orchestration choice layered above `LoanDecisionService`, not a kernel change. |
| R-5 | Pre-flight band uses illustrative rate/term assumptions (7% / 360mo). | Low | Certain | ACCEPTED. Labeled an estimate; thresholds are rule-driven. Real rate sheet integration is post-MVP. |
| R-6 | FSC availability in Developer Edition unknown. | Low | Medium | OPEN (OQ-4). Current model uses custom objects only — no FSC dependency. |
| R-7 | **Adverse Action Notice not legally reviewed** — the generator is built and grounded in cited regulation, but no qualified counsel has signed off that the wording/reasons are sufficient per jurisdiction, and there is no delivery + proof-of-delivery mechanism (Reg B 30-day duty). | High | Certain (now) | **OPEN (⚖️).** Code half done (FR-19, ADR-10, DESIGN-adverse-action.md). Do **not** deliver to a real applicant before compliance sign-off + a HITL delivery/record step. CRA identity for the FCRA block arrives with P3. |
| R-8 | **No KYC/OFAC identity verification or SSN field on `Loan_Application__c`** — the data model carries no Social Security Number, no identity-verification status, and no OFAC/sanctions-screening result. `Extracted_Facts__c` does not model identity verification. These are non-negotiable for any production lending origination. | High | Certain (for production use) | **OPEN (deferred to P3 / EP-4 integrations).** SSN absent from `Loan_Application__c`; identity-verification and sanctions-screening fields do not exist. These are essential lending facts that return in Phase 3 alongside CRA identity and document-extraction integrations. Documented now so the gap is visible in every audit. |
| R-9 | **`CustomMetadata` records fail CLI deploy on the Agentforce-trial org family** — `sf project deploy start` of the 2 config records throws a server-side `UNKNOWN_EXCEPTION` + Salesforce support ErrorId (reproduces on a fresh scratch org; the `__mdt` types deploy fine, only records fail). | Low | Certain (this org family) | **MITIGATED (2026-06-15).** Records are created via the Apex Metadata API (`scripts/load-cmdt.apex`) as a post-deploy step; `customMetadata/` is excluded from the CLI deploy. Platform-side bug, not our metadata (ADR-19). |
| R-10 | **Conversational Agentforce agent not activated** — `sf agent create` builds the agent object but fails activation with "User doesn't have access to use agent" + "Topics are not set", even after assigning `AgentPlatformBuilder` + `CopilotSalesforceAdmin` + `EinsteinGPTPromptTemplateManager`. The topic→action wiring to `LoanDiagnosisService` and final activation need the Agent Builder UI, not headless CLI. | Low | Certain (CLI path) | **OPEN — MVP not blocked.** The read-only `LoanDiagnosisService` invocable is the governed brain and is green on `veridact-af` (ADR-21); per DoD the conversational agent is best-effort. Finish in Agentforce Studio, then `sf agent preview`. |

---

## Confidence Caps (what is gated on what)
- **Engineering (Brooks):** capped until **R-1** clears — the Apex test suite must run green against `mortagate-de`.
- **Product (Jobs):** capped until the full intake → pre-check flow is clicked on a real device in a deployed org (depends on R-1).
- **Production Lending:** capped until **R-8** clears — no production origination without KYC/OFAC identity verification and SSN on the application record. The current data model supports evaluation and demonstration but not legally compliant loan origination.
- Everything buildable without an org is built and, where executable (LWC), verified.
