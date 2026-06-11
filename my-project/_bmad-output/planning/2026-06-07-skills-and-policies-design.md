# Mortgate Skills & Policies Design

> **AI-Assisted Documentation**
> This document was drafted with the assistance of an AI language model.

**Date:** 2026-06-07
**Scope:** Platform-agnostic skills and policies for the Mortgate project harness
**Platforms:** Claude Code, Claude co-work, Codex Desktop, GitHub Copilot
**Location:** `my-project/` (policies/, skills/, .github/prompts/)

---

## Architecture

Three layers, layered by mutability:

| Layer | Path | Purpose | Mutability |
|-------|------|---------|------------|
| **Policies** | `my-project/policies/` | Mortgate-specific invariants not already enforced by installed skills | Rarely — requires ADR |
| **Skills** | `my-project/skills/` | Actionable workflows agents invoke | Evolves with project |
| **Wrappers** | `my-project/.github/prompts/` | Copilot-specific thin pointers to skills (manual-invoke unless workspace rules configured) | Follows skills |

All files are platform-agnostic markdown. Policies are **thin** — one paragraph + pointer to enforcement mechanism. They do not restate what installed skills (`apex-quality`, `lwc-craft`, `sf-deploy`, `sf-data-model`) already enforce.

---

## Policies (4 files)

Each policy is a short invariant statement with a pointer to its enforcement mechanism. Policies state what is true and what is forbidden — never how to do work.

**Not included as separate policies** (already enforced by installed skills):
- Bulk safety (DML/SOQL in loops) — enforced by `apex-quality` skill. Mortgate-specific contract (3 SOQL + 1 DML for N apps, FactAssembler-only reads, pure evaluator, CommitService-only writes) is referenced in `append-only-audit.md`.
- Mobile-first / one-thing-per-screen / no SF chrome — enforced by `lwc-craft` skill. Mortgate-specific constraints (375px primary, 100dvh, touch >= 44px, 32px/24px padding) are referenced in `veridact-brand.md` skill.

### 1. `append-only-audit.md`

Decision_Event__c is immutable. No UPDATE, no DELETE. Enforced by `DecisionEventImmutabilityTrigger` (before update / before delete -> addError). A changed outcome is a NEW event with `Triggered_By__c = RE_EVALUATION`, never an edit. Field History Tracking is not a substitute. The engine's bulk contract is 3 SOQL + 1 DML for N applications (enforced by `apex-quality` skill; proven at 200 by `LoanDecisionServiceTest`). Source: ADR-1, ADR-5, B4, B7.

### 2. `rules-as-data.md`

Policy rules live in records, not code. Policy_Rule_Version__c is immutable after referenced by any Decision_Event__c. Versioning via `Supersedes__c` — new version auto-expires prior. Only ONE active version per `Rule_Code__c`. No hardcoded thresholds in Apex. Analysts maintain rules through UI quick actions — no deployment required. Source: ADR-4, ADR-12, B5.

### 3. `compliance-quarantine.md`

No real applicant delivery without legal sign-off. The Adverse Action Notice generator is built (FR-19, ADR-10) but NOT approved for delivery. No notice sent without counsel sign-off (CR-5, R-7). No delivery without proof-of-delivery mechanism (30-day duty, 12 CFR 1002.9(a)(1)). FCRA block honest about CRA scope — CRA identity pending P3. Forbidden boilerplate never emitted — pinned by `doesNotEmitForbiddenScoreOnlyPhrasing` test. HITL required for any promotion of PENDING_REVIEW to APPROVED or HARD_DECLINED. Source: ADR-10, CR-1..5, R-7.

### 4. `allura-tenant.md`

Mortgate uses `group_id: allura-mortgage` on every DB operation. Agent IDs: `brooks-architect-mortgage`, `woz-builder-mortgage`, `knuth-data-architect-mortgage`, `hightower-devops-mortgage`, `pike-interface-review-mortgage`, `fowler-refactor-gate-mortgage`, `bellard-diagnostics-perf-mortgage`. General Allura invariants (append-only Postgres, Neo4j SUPERSEDES, HITL promotion, MCP_DOCKER-only DB ops, `allura-*` namespace) are enforced by the governance-preflight hook — this policy only documents the Mortgate-specific identifiers. Source: CLAUDE.md, Brooks agent definition.

---

## Skills (7 files)

Skills are **actionable workflows** that agents invoke when doing specific work.

### 1. `veridact-brand.md`

**Trigger:** Any LWC, CSS, or HTML change in `force-app/**/lwc/`.

**Invariants:**
- Amber (`#d4920a`) = action only. CTAs and accent bar. Never decorates approval screen.
- Green (`#16734a`) owns the approved outcome.
- Semantic colors are chip/badge backgrounds, not text. All WCAG >= 4.5:1:
  - Approved: `#16734a` bg, white text (5.86:1)
  - Approved w/ Conditions: `#d4920a` bg, indigo text (5.09:1)
  - Pending Review: `#345182` bg, white text (7.94:1)
  - Declined: `#8a3324` bg, white text (8.14:1)
- Amber accent bar: 4px, bottom of every screen, every state. Hard line — no glow, shadow, gradient.
- Source Serif 4: display only (>= 28px). Tagline, headline, verdict. Never in form labels.
- Inter: everything else.
- 8px border-radius. No 24px. No gradients.
- Motion: right-enter, left-exit. Honor `prefers-reduced-motion`.
- Mobile: 375px primary, 100dvh per screen, touch >= 44px, 32px/24px padding (refs `lwc-craft`).

**Enforcement checklist:**
- [ ] No hardcoded hex colors — all use CSS custom properties / SLDS tokens
- [ ] Verify: `grep -rn '#[0-9a-fA-F]\{6\}' force-app/**/lwc/**/*.css` — hits only in `veridactTokens.css`
- [ ] Amber not used on APPROVED outcome screen
- [ ] Semantic status uses chip component, not colored text
- [ ] All chip color pairs pass WCAG 4.5:1 contrast
- [ ] Source Serif 4 only on display text >= 28px
- [ ] Inter used for all non-display text
- [ ] Border-radius uses 8px token, not 24px
- [ ] No gradient fills on primary surfaces
- [ ] Accent bar present at bottom of screen
- [ ] `prefers-reduced-motion` honored (animations disabled)
- [ ] No Salesforce chrome visible in borrower view

**Source:** ADR-9, DESIGN-onboarding-ux.md (Glaser visual direction).

### 2. `gate-runner.md`

**Trigger:** Before claiming any phase complete. After deploy. Before PR merge.

Parse and execute `mortagate.gates.json` for the target phase. The JSON is the single source of truth for gate definitions — this skill executes it, does not restate it.

**Steps:**
1. Read `mortagate.gates.json` and identify checks for the target phase (0, 1, or 2).
2. Execute each check in order (`fail_fast: true`).
3. Report PASS/FAIL per check ID with evidence (command output or file existence).
4. Block completion claim if any required check fails.

**Note:** Until CI/CD exists (US-5.1), this skill is the only gate. It must be run before every merge. This is a manual discipline risk — document it, don't pretend it's automated.

**Source:** mortagate.gates.json.

### 3. `story-executor.md`

**Trigger:** When picking up a US-X.X story for implementation.

**Steps:**
1. Load story from EPICS-AND-STORIES.md by ID.
2. Check if blocked (legal, vendor, dependency on prior story). If blocked, stop and report.
3. Hand to `mortgate-orchestrator` skill for specialist routing and execution.
4. Definition of Done (verify before marking complete):
   - [ ] Acceptance criteria met
   - [ ] Tests written and passing
   - [ ] Relevant Carlos doc updated in same PR
   - [ ] Gate runner passes for affected phase
   - [ ] Brain trace written (`memory_add` with `group_id: allura-mortgage`)
5. Update story status in EPICS-AND-STORIES.md.

**Lightweight path:** For stories estimated under 2 hours, steps 2 (Brain search) and the Brain trace in step 4 are optional.

**Source:** EPICS-AND-STORIES.md, mortgate-orchestrator skill.

### 4. `audit-demo-runner.md`

**Trigger:** After deploy, after rule changes, or on request.

**Prerequisites:**
- Org authenticated (`sf org display --target-org mortagate-de`)
- Metadata deployed
- Seed rules loaded (`sf data import tree --files data/Policy_Rule_Version__c.json`)

**Steps:**
1. Load demo data: `sf data import tree --files data/demo/Loan_Application__c.json`
2. Load facts: `sf data import tree --files data/demo/Extracted_Facts__c.json`
3. Run each scenario via `LoanDecisionService.decideOne(appId)`:
   - Karim Hassan: expect APPROVED, 0 hard declines
   - Maria Santos: expect APPROVED_WITH_CONDITIONS, EMPLOYMENT_TENURE WARNING
   - James O'Brien: expect HARD_DECLINED, DTI_MAX fires
   - Sabir Asheed Sr.: expect HARD_DECLINED, DTI 43.1% caught at 43% threshold
   - Test Borrower: expect HARD_DECLINED, FICO_MIN fires
4. Verify adverse action notice generates for declined scenarios.
5. Run bulk safety: 200 applications, assert 3 SOQL + 1 DML.
6. Report: scenario | expected | actual | PASS/FAIL.

**Source:** Audit Demo README, demo-scenarios.json, ADR-12.

### 5. `adverse-action-validator.md`

**Trigger:** After any change to `AdverseActionService`, `AdverseActionNotice.page`, `AdverseActionNoticeController`, or `Adverse_Action_Config__mdt`.

**Checks:**
- [ ] Reasons come from `Rule_Explanation__c` (specific, not boilerplate)
- [ ] HARD_DECLINE reasons ranked first
- [ ] Capped at 4 reasons (Reason_Limit__c), deduped, blanks skipped
- [ ] ECOA anti-discrimination text present (from config)
- [ ] `[AGENCY]` token resolved to oversight agency name + address
- [ ] Creditor name + address present (from config)
- [ ] Statement of action taken present
- [ ] FCRA score block: present when FICO_Score__c exists, absent when not
- [ ] CRA identity marked as pending (honest about P3 scope)
- [ ] Forbidden phrasing not emitted ("qualifying score", "internal standards")
- [ ] `AdverseActionServiceTest` (13 tests) passes
- [ ] `AdverseActionNoticeControllerTest` (5 tests) passes
- [ ] `outcomeView` Jest tests for viewnotice pass
- [ ] No `escape="false"` on the VF page
- [ ] No `apex:form` on the VF page (read-only artifact)

**Source:** ADR-10, DESIGN-adverse-action.md, 12 CFR 1002.9, 15 U.S.C. 1681m.

### 6. `precheck-smoke.md`

**Trigger:** After changes to `PreFlightEvaluator`, `PreFlightController`, or `intentCapture` LWC.

**Steps:**
1. Run `PreFlightEvaluator.evaluate()` with Karim Hassan inputs (income $97,803, property ~$350k, CONVENTIONAL): expect LIKELY_ELIGIBLE.
2. Run with James O'Brien inputs (income $80,393, high DTI property): expect UNLIKELY.
3. Verify NO `Loan_Application__c` record created (ADR-7).
4. Verify evaluator uses live INCOME + COLLATERAL rules only (same kernel, ADR-7).
5. Run `PreFlightEvaluatorTest` and `PreFlightControllerTest`: all pass.
6. Verify `intentCapture` LWC: no pre-filled defaults (ADR-8), Continue disabled until touched.

**Source:** ADR-7, ADR-8, FR-4, FR-5.

### 7. `memory-promote.md`

**Trigger:** After substantive architectural work, or on request.

**Steps:**
1. List recent episodic memories: `memory_list({ group_id: "allura-mortgage", user_id: "{agent_id}", sort: "created_at_desc" })`.
2. For each, assess promotion eligibility:
   - Confidence >= 0.85?
   - Stable canonical knowledge (not time-bound)?
   - Not a session trace or snapshot with mutable status flags?
3. For eligible memories, call `memory_promote({ id, group_id: "allura-mortgage", rationale })`.
4. Route to HITL approval (`curator:approve`) — never auto-approve.
5. After approval, verify retrieval via `memory_search`.

**Promotion criteria:**
- PROMOTE: ADRs, schema definitions, engine architecture, design specs, brand rules, invariants
- KEEP EPISODIC: status snapshots, readiness reports, session traces, anything with mutable flags

**Source:** Allura governance invariants, allura-approve-promotion skill.

---

## Copilot Wrappers (6 files)

Thin pointers in `my-project/.github/prompts/`. These are **manual-invoke** unless Copilot workspace rules are configured for auto-trigger.

### Pattern

```markdown
---
description: "{one-line description}"
---
Follow the policy and checklist in ../skills/{skill-name}.md
Apply it to the changed files in this PR.
Report findings as: PASS / WARN / FAIL per item.
```

### Files

| File | Points to | Invoke |
|------|-----------|--------|
| `veridact-brand.prompt.md` | `skills/veridact-brand.md` | Manual, or configure auto on `*.css`/`*.html` in `force-app/**/lwc/` |
| `gate-runner.prompt.md` | `skills/gate-runner.md` | Manual, or configure auto on `force-app/` changes |
| `story-executor.prompt.md` | `skills/story-executor.md` | Manual: `@workspace /story US-1.1` |
| `audit-demo.prompt.md` | `skills/audit-demo-runner.md` | Manual: `@workspace /audit-demo` |
| `adverse-action.prompt.md` | `skills/adverse-action-validator.md` | Manual, or configure auto on `AdverseAction*` changes |
| `precheck-smoke.prompt.md` | `skills/precheck-smoke.md` | Manual, or configure auto on `PreFlight*` changes |

---

## Summary

| Layer | Count | Purpose |
|-------|-------|---------|
| Policies | 4 | Mortgate-specific invariants (thin, one paragraph each) |
| Skills | 7 | Actionable workflows with enforcement checks |
| Wrappers | 6 | Copilot invocation pointers |
| **Total** | **17** | |

### Design Decisions (from elicitation)

1. **Policies are thin** — one paragraph + pointer to enforcement. They don't restate what installed skills already enforce.
2. **Bulk safety and mobile-first merged** — referenced from `apex-quality` and `lwc-craft` respectively, not duplicated as policies.
3. **Allura tenant policy slimmed** — only documents Mortgate-specific agent IDs. General Allura invariants enforced by governance hook.
4. **Gate runner doesn't restate gates.json** — it parses and executes the JSON, which is the single source of truth.
5. **Story executor is thin** — loads story, checks blocked, hands to `mortgate-orchestrator`. Does not duplicate orchestrator routing.
6. **Veridact brand has grep checks** — automated hex-color verification, not review-discipline only.
7. **Copilot wrappers are manual-invoke** — honest about Copilot behavior. Auto-trigger requires workspace configuration.
8. **Lightweight path for small stories** — Brain search and trace optional for stories under 2 hours.

## Cross-References

- BLUEPRINT.md — B2, B4, B5, B7, B8
- RISKS-AND-DECISIONS.md — ADR-1..12
- EPICS-AND-STORIES.md — EP-0..5, US-*.* stories
- DESIGN-adverse-action.md — ECOA/Reg B compliance
- DESIGN-onboarding-ux.md — Veridact visual direction
- mortagate.gates.json — gate definitions
- Installed skills: `apex-quality`, `lwc-craft`, `sf-deploy`, `sf-data-model`, `mortgate-orchestrator`, `carlos-guidelines`
