# Outcome Checklist — Audit Queue MVP (goal-20260612-mvp)

**Goal:** Ship a clickable, demo-ready **Audit Queue MVP** in `mortagate-de` for a bank-exec demo (Wells Fargo / Bank of America). "Done" = **Brooks (PM) approval gate**, all conditions simultaneously true on the final tagged commit.
**Org:** mortagate-de (Salesforce Developer Edition — coverage gate NOT enforced) · **Worktree:** audit-pivot · **PM / approval gate:** Brooks.
**Authority:** User authorized the MVP build; Brooks owns scope + sign-off. Stop ONLY when Brooks approves.
**Created:** 2026-06-12 · Ratified by Brooks (PM) — source: `~/.claude/agent-memory/brooks/project_audit_queue_mvp.md`.

Legend: `[x]` done & verified · `[~]` partial · `[!]` blocked · `[ ]` not started

---

## MVP in one sentence
A reviewer opens a Lightning App Page in `mortagate-de`, sees a live queue with real seed data, filters it, and clicks into AC-0001 without error — styled brand-accurately to the Figma, 37/37 Apex + 12/12 Jest green, tree clean, tagged `audit-queue-v1.1-mvp`.

## OUT of MVP scope (deliberately deferred — do NOT build)
- Experience Cloud / Community site (post-MVP sprint 2)
- Pixel-perfect Figma match (brand-accurate approximate is the bar)
- `+ New Audit` creation workflow (no-op toast acceptable)
- Export CSV backend (button renders, no-op acceptable)
- Multi-approver routing
- Extra seed data beyond existing ~614 loans + AC-0001
- Automated UI / E2E tests
- Remote push or PR merge (no authorization)

## PM Decisions (locked by Brooks)
- **Fix B** (dynamic SOQL + try/catch) over Fix A (permission set) — matches the codebase idiom; resilient to future field adds; no revertible org config.
- **Lightning App Page first**, Community post-MVP — removes DE-org misconfig risk on demo day; exec audience views a shared screen, not a public URL.
- **Brand-accurate approximate styling**, not pixel-match — bar is "would a bank exec believe this is shipping-quality enterprise software."

---

## Phases (mandatory order — each ends in a verifiable gate)

### Phase 0 — Documentation (per `guidelines/AI-GUIDELINES.md`; docs are first-class, precede code)
Produce the six required artifacts in `planning docs/` (per `.github/copilot-instructions.md` house layout), each with the **AI-disclosure notice**, conformant to `guidelines/templates/*`. Field names pulled from the authoritative schema (never invented). **"What AI must not decide alone"** (failure semantics, security boundaries, field naming, business requirements) is routed to Brooks/user — recorded, not self-decided.
- [x] D.1 `planning docs/RISKS-AND-DECISIONS.md` — AD-01..AD-07 = Brooks's locked PM decisions; RK-01..RK-05 = Brooks's 5 risks. ✅ disclosure + 4 xrefs.
- [x] D.2 `planning docs/BLUEPRINT.md` — 7 core concepts, B1-B7/F1-F14, component table, 5 Mermaid (component/flow/sequence/ER/event), data model from real fields. ✅
- [x] D.3 `planning docs/DATA-DICTIONARY.md` — per-entity field tables; ALL field names verified against authoritative `/tmp/mortagate-landing` metadata (0 invented). erDiagram of 7 entities. ✅
- [x] D.4 `planning docs/REQUIREMENTS-MATRIX.md` — B→F mapping, F# detail (Satisfied by + test), use-case index. ✅
- [x] D.5 `planning docs/SOLUTION-ARCHITECTURE.md` — LWC ↔ Apex ↔ Salesforce topology (flowchart), interface catalogue, RK-01..RK-05 → architecture traceability. ✅
- [x] D.6 `planning docs/DESIGN-AUDIT-QUEUE.md` — queue + replay deep-dive: F# trace, Apex API reference, Audit_Case__c state machine (stateDiagram-v2), business rules, use cases. ✅
- **Gate:** ✅ MET — all six files exist in `planning docs/`, render, carry the AI-disclosure notice, cross-link (4-5 links each), field names validate against authoritative schema. Honest TBDs recorded (Product/Branch filter has no backing field; some status transitions + test classes absent from this worktree) — not faked.
- **Guardrail (per guideline §8):** any schema/API change in Phases 1–6 updates `REQUIREMENTS-MATRIX.md` + `DATA-DICTIONARY.md` in the SAME commit.

### Phase 1 — Click-in must not error (Brooks amendment: Option 3 — standard record page + related lists)
> **Brooks (PM) ruling, 2026-06-12:** Row-click navigates to the **standard `Audit_Case__c` record page**, not `getCaseReview` — that wrapper is dead code (no LWC consumer). The standard Lightning record page hides FLS-blocked fields natively (no Apex exception) and renders child detail from the **page layout's related lists**. So Phase 1 = enrich the page layout (detail fields + 5 child related lists) AND harden the dead `CaseReviewController` defensively so the post-MVP `caseReview` LWC can wire to it without a rewrite.
- [x] P1.1 Enriched `Audit Case Layout`: Information section detail fields (Risk_Tier__c, Auditor__c, Original_Approver__c, Scope__c, Assigned_At__c, Due_At__c, Policy_Version__c, Signed_Off_At__c/By__c read-only) + 5 child related lists (Evidence_Item__c, Reconstructed_Fact__c, Rule_Check__c, Finding__c, Audit_Event__c — all on `Audit_Case__c` lookup). Deployed to mortagate-de.
- [x] P1.2 Applied Fix B defensively to `CaseReviewController.getCaseReview`: all 5 section queries now dynamic SOQL via `Database.query(soql, AccessLevel.USER_MODE)` with full→minimal fallback, named `System.debug` logging, and a `fieldWarnings` channel feeding a future "some fields unavailable" inline notice (Risk #1). Marked the class header `POST-MVP: caseReview LWC consumer` (idiom from `FactAssembler.queryLoanValues`).
- **Gate (Brooks amended):** Apex **37/37** pass on mortagate-de AND the **AC-0001 record page renders all five related lists with zero console errors and zero Apex exceptions on the demo profile**.
  - [x] 37/37 Apex pass on mortagate-de (run 707gL00000wdUJk, 85% org-wide). ✅
  - [x] AC-0001 (`a05gL00000JbEfOQAV`) has populated children in every list — Evidence 5 / Facts 5 / Rule Checks 4 / Findings 1 / Events 5. ✅
  - [x] `getCaseReview(AC-0001)` returns all 5 sections with **zero exceptions, zero field warnings** (verified in Phase 6 after fixing two latent bugs — see note). ✅
  - [ ] Browser render check on the demo profile (manual — final demo dry-run).

> **Phase 6 correction (schema reconciliation):** Final verification revealed the live `mortagate-de` schema is **leaner** than the `/tmp/mortagate-landing` reference metadata. Two bugs were fixed: (1) the hardened `safeQuery` ran `Database.query` in a scope where the `:caseId` bind didn't exist → switched to `Database.queryWithBinds` with an explicit bind map; (2) layout related lists + the Findings query referenced fields absent in this org (`Required__c`, `Received_Timestamp__c`, `Confidence__c`, `Verified__c`, `Remediation_Due_At__c`, `Rationale__c`) → trimmed to the real org fields. Authoritative org field sets per child object: Evidence_Item__c {Document_Type__c, Status__c}; Reconstructed_Fact__c {Fact_Type__c, Value__c}; Rule_Check__c {Rule_Name__c, Outcome__c, Policy_Rule_Version__c}; Finding__c {Category__c, Disposition__c, Severity__c}; Audit_Event__c {Event_Type__c, Actor__c, Timestamp__c}.

### Phase 2 — Host on a Lightning App Page
- [x] P2.1 Created `Audit_Queue_Page` (FlexiPage AppPage hosting `auditQueue`) + `Audit_Queue_App` (Lightning app) + 2 tabs (Audit Queue page tab + Audit_Case__c object tab); deployed to mortagate-de. Granted the demo profile (System Administrator / "Admin") app + tab visibility via a minimal additive profile deploy (Risk #3 mitigation).
- **Gate:** demo user opens **Audit Queue from the App Launcher** (no Setup navigation) and sees the queue with live seed data.
  - [x] App accessible to demo user (Tiberius Jones, System Administrator): `AppMenuItem.IsAccessible=true, IsVisible=true`. ✅
  - [x] Live seed data present: 624 `Audit_Case__c` rows across 6 statuses (In_Review 204, Assigned 106, Ready_For_Signoff 98, Evidence_Needed 89, Created 79, Closed 48). ✅
  - [ ] Browser App-Launcher render check (manual — final demo dry-run).

### Phase 3 — Stat cards (5 aggregates)
- [x] P3.1 5 cards present (Assigned to Me / High Risk / Evidence Needed / Ready for Signoff / SLA at Risk). `AuditQueueController.getMetrics` runs 5 independent FLS-enforced COUNT() queries with selective WHERE clauses (Risk #2 mitigation; COUNT aggregates return no rows so no LIMIT needed). LWC `metricsData` getter + template cards already wired.
- **Gate:** card counts match Developer Console SOQL. ✅ MET — getMetrics vs raw SOQL on mortagate-de: assignedToMe 37=37, highRisk 77=77, evidenceNeeded 89=89, readyForSignoff 98=98, slaAtRisk 4=4.

### Phase 4 — Figma styling pass (no functional changes)
- [x] P4.1 Brand-accurate styling in place. Stat cards (colored accent bars), filter pills, themed datatable, and WCAG risk sigils (●▲◆■ + color) were already styled via brand tokens (Outfit/Inter, cream/charcoal/orange/approval/violation/amber/SLA-blue). Added the missing element: a brand **sidebar** (navy rail, orange logo mark, "Audit Queue" wordmark, Queue/Cases/Reports nav — decorative chrome, no invented brand name) + a flex app-shell (sidebar + main) with a mobile breakpoint. Deployed to mortagate-de.
- **Gate:** sidebar + cards + filter bar + table + sigils all present and recognizable vs the Figma. ✅ all five present; Jest 12/12 auditQueue (42/42 repo-wide) green after the layout change (Risk #4 — no CSS regression; tests assert datatable/comboboxes/alert, all intact).

### Phase 5 — Error/empty states + no-op buttons
- [x] P5.1 Empty-state block (`isEmpty` getter → "No audit cases match your filters" + hint) renders when a successful query returns zero rows; datatable now gates on `hasRows` so a filtered-to-empty queue shows the message instead of a bare header. Added an **Export CSV** button (secondary style) wired to a no-op `handleExportCsv` that fires an info toast (backend deferred to v2). `+ New Audit` navigates to the standard new-record page (does not throw). Error state (`role="alert"`) unchanged. Deployed to mortagate-de.
- **Gate:** a zero-result filter shows the empty state; `+ New Audit` does not error. ✅ empty-state logic verified by getter (`hasData && queueData.length === 0`); New Audit + Export CSV both no-throw; Jest 12/12 green.

### Phase 6 — Final integration verify + tag
- [x] P6.1 Full integration verify; tag `audit-queue-v1.1-mvp` (annotated, on commit 7daf55c). End-to-end `getCaseReview(AC-0001)` returns evidence=5, facts=5, checks=4, findings=1, timeline=5, **warnings=0**, zero Apex exceptions. **Two latent bugs caught + fixed during this verify:** (a) `safeQuery` threw "Variable does not exist: caseId" — `Database.query` could not see the call-site `:caseId` bind, fixed by switching to `Database.queryWithBinds` with an explicit `{ 'caseId' => auditCaseId }` bind map; (b) "No such column 'Rationale__c' on Finding__c" — the live `mortagate-de` schema is leaner than the reference metadata, so the Findings query + all 5 related lists were trimmed to real org fields (verified via `sf sobject describe`).
- **Gate:** git clean (of MY files), 37/37, 12/12, AC-0001 full golden path loads end-to-end. ✅ 37/37 Apex (85% cov), 12/12 Jest auditQueue (42/42 repo-wide), AC-0001 golden path clean. ⚠️ **Caveat:** `git status` is not globally empty — the user has unrelated uncommitted work (`.opencode/`, `.agents/`, `.codex/`, `demo/`, `README.md`, onboarding LWC/Apex) that I correctly did NOT touch. All Audit-Queue files are committed and tagged.

---

## Top risks (with mitigations — keep true every phase)
1. Fix B silently swallows real data errors → named debug logging + visible "some fields unavailable" notice.
2. DE governor limits on broad filter queries → selective WHERE + LIMIT; review debug logs before tagging.
3. App not visible to demo profile → assign app to exact demo profile in P2, verify as that user.
4. Figma styling causes table CSS regression → Jest + manual e2e after every P4 commit.
5. Demo-environment state drift → 3-step reset runbook (clear filters, default view, confirm AC-0001 visible) run immediately before demo.

---

## APPROVAL GATE (Brooks — stop condition; ALL true simultaneously on the final tagged commit, by direct observation in mortagate-de)
- [x] Demo user navigates to Audit Queue from App Launcher (no Setup navigation) — verified via `AppMenuItem` (IsAccessible=true) for the demo user after additive Admin profile deploy. ⚠️ Final browser App-Launcher click left as demo dry-run.
- [x] Queue table loads seed-data loans with correct risk sigils (Critical/High/Medium/Low) — 624 seed audit cases present; sigil CSS classes (`risk-badge--critical/high/medium/low` + shape glyphs ●▲◆■) verified in `auditQueue.css`; Jest asserts datatable render.
- [x] 5 stat cards visible and labeled (counts may be 0, cards must be present) — all 5 cards present in `auditQueue.html` (Assigned to me, High risk, Evidence needed, Ready for sign-off, SLA at risk); all 5 counts match raw SOQL.
- [x] Status + Risk Tier filters demonstrably narrow the row set — filter combobox handlers + getter-driven row filtering present and unit-tested. ⚠️ Visual narrowing left as demo dry-run.
- [x] AC-0001 detail loads completely: evidence, facts, rule checks, finding, audit events all rendered; zero Apex exceptions — `getCaseReview(AC-0001)` returns evidence=5, facts=5, checks=4, findings=1, timeline=5, warnings=0, zero exceptions. ⚠️ Zero **browser console** errors left as demo dry-run.
- [x] Brand-accurate styling: sidebar, cards, filter bar, table all visually structured as professional enterprise software — sidebar/cards/filter rail/table + brand tokens (navy #1B2A4A, orange #E25D22) all present in CSS/HTML; SLDS-2 dark-mode-ready tokens with hex fallbacks. ⚠️ Final visual match-vs-Figma left as demo dry-run.
- [x] 37/37 Apex + 12/12 Jest pass on the clean tagged tree — 37/37 Apex (85% coverage), 12/12 Jest auditQueue (42/42 repo-wide).
- [x] Export CSV and `+ New Audit` buttons present and do not throw — both present; Export CSV fires info toast (no-op v2 deferral), New Audit navigates to standard new-record page; Jest green.
- [x] `git status` clean; `git tag -l` shows `audit-queue-v1.1-mvp`; no `git add -A` used — tag `audit-queue-v1.1-mvp` → commit 7daf55c exists; all Audit-Queue files committed via specific-file staging (no `git add -A`). ⚠️ **Caveat:** working tree is NOT globally empty — the user's unrelated uncommitted work (`.opencode/`, `.agents/`, `.codex/`, `demo/`, `README.md`, onboarding files) was intentionally left untouched.

## Brooks PM Approval Gate — Final Ruling (2026-06-13)

**Decision: APPROVE-WITH-CONDITIONS**

All 9 gate items are closed or accepted as documented dry-run residuals. Two conditions must be executed before the demo:

- **Condition A:** Browser dry-run on the demo profile — golden path (App Launcher → queue → filter → AC-0001 detail, zero console errors, brand visual check). Closes items 1, 4, 5-console, 6-Figma. ✅ **EXECUTED 2026-06-13** in `mortagate-de` Lightning (Chrome, authenticated as demo user `sasheed72.00f6e389a7e4@agentforce.com`):
  - Queue page rendered with brand chrome (navy sidebar + orange logo, 5 stat cards 37/77/89/98/4 with colored accent bars, pill filter rail, datatable) — matches Figma intent.
  - Risk Tier filter set to **Low** demonstrably narrowed the table (Risk column flipped from all-Critical to all-Low; pill showed "Low").
  - AC-0001 record page Details tab: all header fields populated (Loan LN-1002, Risk Tier Critical, Status In Review, Policy Version DTI_MAX@v3, Sampling Reason Risk Based).
  - AC-0001 Related tab: **all 5 child lists rendered with real data** — Evidence Items (5: W2/Pay Stub/Credit Report/Bank Statement/Appraisal), Reconstructed Facts (5: DTI 47, Credit Score 712, Annual Income 82000, Loan Amount 410000, LTV 80), Rule Checks (4: Max DTI→**Violation** DTI_MAX@v3, Min Credit Score→Pass, Max LTV→Pass, Income Doc→Pass), Findings (1: FN-0000 Eligibility / High / Open), Audit Events (5: Case Created → Evidence Linked → Facts Reconstructed → Replay Executed → Finding Created).
  - **Zero browser console errors/exceptions** across the full journey (checked after reload + filter + detail navigation).
  - ⚠️ Minor note: navigation used an authenticated deep link to the Audit Queue tab (which is present in the app nav bar) rather than a physical App-Launcher grid click; app accessibility was independently confirmed via `AppMenuItem.IsAccessible=true`.
- **Condition B:** Three-step reset runbook immediately before demo — clear filters, restore default view, confirm AC-0001 visible. ⏳ Demo-day operational step (run live, not pre-closable).

No code changes required. Tag `audit-queue-v1.1-mvp` → commit `7daf55c` stands. The builder's task is done. Condition A closed by live dry-run; Condition B is a demo-day runbook step.

---

## Verification commands
```bash
# Apex (must stay 37/37)
sf apex run test -o mortagate-de --suite-names AuditQueue --code-coverage --result-format human
# Jest (must stay 12/12)
npm run test:unit
# Clean tree + tag
git status --porcelain && git tag -l 'audit-queue-v1.1-mvp'
```
