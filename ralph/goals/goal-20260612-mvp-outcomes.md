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

### Phase 1 — Fix B: close the FLS gap (click-in must not error)
- [ ] P1.1 Make `CaseReviewController` (runReplay/getCaseReview), `PolicyVersionSelector` (loadPolicyVersion), `FindingService` (allExceptionsApproved) degrade gracefully on FLS-blocked optional fields via dynamic SOQL + try/catch (idiom from `FactAssembler.queryLoanValues` / `PolicyRuleEvaluator.setRationale`). Add named debug logging + a visible "some fields unavailable" inline notice (Risk #1 mitigation).
- **Gate:** Apex **37/37** pass on mortagate-de AND opening AC-0001 produces **no exception**.

### Phase 2 — Host on a Lightning App Page
- [ ] P2.1 Create `Audit_Queue_Page` (FlexiPage app page hosting `auditQueue`) + `Audit_Queue_App` (Lightning app) + tab; deploy; assign app to the exact demo user profile and verify AS that user (Risk #3 mitigation).
- **Gate:** demo user opens **Audit Queue from the App Launcher** (no Setup navigation) and sees the queue with live seed data.

### Phase 3 — Stat cards (5 aggregates)
- [ ] P3.1 Add 5 cards: Assigned to Me / High Risk / Evidence Needed / Ready for Signoff / SLA at Risk. Selective WHERE + LIMIT guards (Risk #2 mitigation).
- **Gate:** card counts match Developer Console SOQL.

### Phase 4 — Figma styling pass (no functional changes)
- [ ] P4.1 Style sidebar, stat cards, filter bar, table, sigils to brand-accurate fidelity. Run Jest + manual end-to-end after every commit (Risk #4 mitigation).
- **Gate:** sidebar + cards + filter bar + table + sigils all present and recognizable vs the Figma.

### Phase 5 — Error/empty states + no-op buttons
- [ ] P5.1 Empty-state row message; `+ New Audit` toast; Export CSV no-op.
- **Gate:** a zero-result filter shows the empty state; `+ New Audit` does not error.

### Phase 6 — Final integration verify + tag
- [ ] P6.1 Full integration verify; tag `audit-queue-v1.1-mvp`.
- **Gate:** git clean, 37/37, 12/12, AC-0001 full golden path loads end-to-end.

---

## Top risks (with mitigations — keep true every phase)
1. Fix B silently swallows real data errors → named debug logging + visible "some fields unavailable" notice.
2. DE governor limits on broad filter queries → selective WHERE + LIMIT; review debug logs before tagging.
3. App not visible to demo profile → assign app to exact demo profile in P2, verify as that user.
4. Figma styling causes table CSS regression → Jest + manual e2e after every P4 commit.
5. Demo-environment state drift → 3-step reset runbook (clear filters, default view, confirm AC-0001 visible) run immediately before demo.

---

## APPROVAL GATE (Brooks — stop condition; ALL true simultaneously on the final tagged commit, by direct observation in mortagate-de)
- [ ] Demo user navigates to Audit Queue from App Launcher (no Setup navigation)
- [ ] Queue table loads seed-data loans with correct risk sigils (Critical/High/Medium/Low)
- [ ] 5 stat cards visible and labeled (counts may be 0, cards must be present)
- [ ] Status + Risk Tier filters demonstrably narrow the row set
- [ ] AC-0001 detail loads completely: evidence, facts, rule checks, finding, audit events all rendered; zero Apex exceptions; zero browser console errors
- [ ] Brand-accurate styling: sidebar, cards, filter bar, table all visually structured as professional enterprise software
- [ ] 37/37 Apex + 12/12 Jest pass on the clean tagged tree
- [ ] Export CSV and `+ New Audit` buttons present and do not throw
- [ ] `git status` clean; `git tag -l` shows `audit-queue-v1.1-mvp`; no `git add -A` used

## Verification commands
```bash
# Apex (must stay 37/37)
sf apex run test -o mortagate-de --suite-names AuditQueue --code-coverage --result-format human
# Jest (must stay 12/12)
npm run test:unit
# Clean tree + tag
git status --porcelain && git tag -l 'audit-queue-v1.1-mvp'
```
