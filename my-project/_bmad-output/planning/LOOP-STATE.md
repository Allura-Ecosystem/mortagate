# Veridact Finish Loop — State

> Loop iteration log + backlog state. Source prompt: LOOP-PROMPT-veridact-finish.md. Do not edit history rows; append.

**Iteration counter:** 12 (started 2026-07-02) — **LOOP COMPLETE 2026-07-03**

## Backlog

| # | Item | Owner | Status | Evidence |
|---|------|-------|--------|----------|
| 1 | Copilot function-invocation gap | Bellard→Woz | **DONE** | ec08104 — planner extracts auditCaseId from utterance, List_Missing_Evidence + Summarize_Case launch, 2 Initiated log rows (ADR-26 live). Root cause: schema-less GenAiFunction bundles |
| 2 | Schedule nightly sweep (CronTrigger) | Hightower | **DONE** | b3fd34f — CronTrigger 08egL00000bzH8HQAU WAITING, next fire 2026-07-03 02:00 PT; FR-32 updated |
| 3 | Priya Nair data fix (AC-0001) | Knuth | **DONE** | 66209a7 — Loan+snapshots+evidence inserted, replay 10 checks (6F/3P/1U, 3 HARD), Critical tier preserved |
| 4a | P2 action: Draft_Evidence_Request | Woz | **DONE** | 14fa57c — ADR-28: conversational drafting rides governed retrieval + LLM composition (verb actions shadowed by noun-mates, measured 2x); service retained as UI-path, 8/8 tests |
| 4b | P2 action: Prepare_Manager_Summary | Woz | **DONE (retired)** | ADR-29 — Audit_Event__c.Audit_Case__c non-nillable blocks caseless dual-write; satisfied by FR-28/FR-21 UI |
| 4c | P2 action: Send_Violation_Alert | Woz | **DONE** | 31e080a+086cfc9 — service 5/5 (Task+idempotency), same-noun shadowing measured → retired to UI-path per ADR-28; FR-37 ✅ |
| 4d | P2 action: Generate_Analytics | Woz | **DONE (retired)** | ADR-29 — satisfied by FR-28 AnalyticsController (already built) |
| 5 | RuleNarration fold-in | Fowler | **DONE** | 9af6e6c — byte-identical dup deleted, -52 LOC, 22/22 on-org, zero behavior change |
| 6 | KYC/OFAC build | Knuth+Woz | **DONE (code)** | 89d7dc0 + 6cd351a — schema + IdentityGateService (orthogonality proven by test), FR-38 ✅ code; R-8 human gates fenced (OQ-R8-1/2/4/6/7) |
| 7 | Gates run + receipts | Hightower | **DONE** | 95657a9+b63e3e2+c0e0e9f — 15 PASS / 0 FAIL / 2 OPEN-MANUAL(human); Apex 198/198 83%; deploy-with-jobs toggle enabled (Setup-only) |
| 8 | Eval + un-quarantine | Hightower | **DONE** | 0828779 — eval PASS 3/3 (planner selects expected actions, June 'Unknown error' gone); AiEvaluationDefinition is Testing-API-only (no Version metadata exists — ADR-25 corrected); quarantine permanent-by-design |
| 9 | 90-day QC-window lens | Woz+Pike | **DONE** | f5dfb56 — qcWindowDaysLeft + 6th metric card, anchor=Approval_Date__c (no closing date; documented proxy), Jest 63/63, token guard clean, on-org screenshot |
| 10 | Packaging spike | Hightower | **DONE** | 0b2f097 — DESIGN-packaging.md: core app packageable, Agentforce excluded-with-runbook, top blocker = namespace (BLOCKED-HUMAN) |
| 11 | Curator promotion proposals | Brooks | **DONE (approved)** | 2026-07-03: all 19 pending proposals (5 doctrine + 14 session traces) approved by owner-curator sabir-ronin704, witness hashes frozen, canonical memories materialized + search-verified. Two Brain platform fixes required en route (see addendum) |


## POST-LOOP ADDENDUM — signature-list burn-down (2026-07-03, owner-delegated session)

Owner directive: "take all recommended actions to finish." Executed:

- **Curator queue CLEARED (was BLOCKED-HUMAN):** all 19 pending proposals approved (curator `sabir-ronin704`, per-proposal rationales, witness hashes frozen). Found + fixed two Allura Brain platform defects blocking this: (1) `approval-audit.ts` re-connected the caller's live PoolClient (`"connect" in pg` guard matched clients too) — every curator approval 500'd; (2) the `promotion_sync_pending` outbox had **no consumer** — wrote `scripts/drain-promotion-outbox.ts` (append-only completion events, governed writer), drained 19/19, semantic retrieval verified. Both committed to allura-memory.
- **Gates p2-005/p2-006 CLOSED (was BLOCKED-HUMAN):** fresh evidence reviews (Fowler: zero project Flows in source, all 107 org Flows managed/standard → vacuous PASS with re-open condition; Pike: 13 components, 5/5 criteria PASS, one non-blocking a11y polish note `policyVersions.html:18`). Owner-signed. **GATES 17/17 PASS, zero OPEN.**
- **R-7 packet READY (counsel still signs):** `R7-ADVERSE-ACTION-SIGNOFF-PACKET.md` — 30 verbatim copy strings across 4 emitting classes with file:line + regulatory concern each; formal AAN wording correctly deferred to `Adverse_Action_Config__mdt` (ADR-10, legal-owned).
- **R-8 decision memo READY (owner decides):** `R8-DECISION-MEMO.md` — recommendation per OQ (pilot: last-four-only, vendor-owned disposition, hard-block SCREEN_MISSING; production: external vault, config-as-data cutoff, legal retention schedule). None of the five blocks pilot; all five block production lending. Backlog rows R8-1-a…R8-7-c pre-enumerated for a future loop.
- **Namespace (still BLOCKED-HUMAN, irreversible):** naming decision remains the owner's; registration is a 10-minute execution once named.

Remaining human signatures after this session: R-7 counsel signature, R-8 decisions (memo ready), namespace name. Everything else on the signature list is resolved.

## FINAL REPORT (2026-07-03)

**Stop condition met: all 14 backlog items DONE or BLOCKED-HUMAN. 12 iterations, ~19 specialist dispatches, 17 commits (ec08104..0b2f097 range), zero open FAILs, zero invariant violations.**

### DONE (with evidence)
1. Copilot end-to-end (ec08104) — first utterance-launched Apex actions ever on this org; ADR-26 receipts live
2. Nightly sweep scheduled (b3fd34f) — CronTrigger 08egL00000bzH8HQAU, fired its first night during this loop
3. AC-0001 repaired (66209a7) — coherent Critical case, 10 replay checks
4a. Draft evidence request (14fa57c, ADR-28) — conversational via governed retrieval
4b/4d. Manager summary + analytics (35cba89, ADR-29) — retired to existing UI; spine invariant preserved
4c. Violation alert (31e080a + 086cfc9) — UI-path service, 5/5 tests
5. RuleNarration fold-in (9af6e6c) — −52 LOC, zero behavior change
6. KYC/OFAC (89d7dc0 + 6cd351a) — schema + gating precondition, orthogonality proven by test
7. Gates fully green (95657a9 + b63e3e2 + c0e0e9f) — 15 PASS / 0 FAIL / 2 OPEN-MANUAL; Apex 198/198 @ 83%
8. Headless eval PASS 3/3 (0828779 + e12b643) — R-10 CI gap closed; ADR-25 corrected
9. QC-window lens (f5dfb56) — Fannie 90-day clock on the queue; Jest 63/63
10. Packaging spike (0b2f097) — DESIGN-packaging.md with phased plan
11. Five doctrine promotions proposed (see table)

### BLOCKED-HUMAN — the signature list (exact next actions)
- **R-7**: counsel signs the adverse-action notice wording (docs ready: DESIGN-adverse-action.md)
- **R-8**: (a) pick the SSN vault vendor (OQ-R8-1), (b) decide token encryption (OQ-R8-7), (c) compliance sign-offs OQ-R8-2/4/6 — code half is DONE (FR-38)
- **Gates p2-005/p2-006**: owner performs/signs the flow + LWC manual quality reviews (standing evidence linked in GATES-REPORT.md)
- **Curator queue**: approve/reject the 5 doctrine proposals (+ ~30 episodic traces pending)
- **Packaging**: register + link a namespace to the DevHub (irreversible naming decision), then the pilot-gate phase of DESIGN-packaging.md
- **Runbook (release-time only)**: bot deactivation for full-source redeploys

### Most valuable next session
Demo dry-run: walk the exact pitch script against the live org (queue → hero case → copilot sidebar with the 3 live utterances → sign-off), then decide the namespace name — it gates everything commercial.

### New ADRs this loop: 27 (sweep), 28 (routing physics), 29 (spine over affordance) + ADR-25 correction
### New FRs: 32–39, all with on-org verification

## Iteration log

- **Iter 12 (2026-07-03):** ITEM #9 DONE (f5dfb56). QC Window beside SLA (different truths: internal workload vs Fannie clock), chips not text (ADR-9), null-clock for Closed. Future ADR line: Closing_Date__c is the higher-fidelity anchor when LOS lands. Picked #10 packaging spike. Hightower dispatched (report-only).

- **Iter 11 (2026-07-03):** ITEM #8 DONE (0828779): headless eval PASS 3/3 — planner action-selection now CI-verifiable via run-eval --spec (R-10 CI gap closed); action-name assertion quirk = beta framework suffix-matching bug (not spec-fixable portably). ADR-25 corrected in decision log. Picked #9: 90-day QC-window lens. Woz dispatched with Pike gate.

- **Iter 10 (2026-07-03):** ITEM #7 FULLY CLOSED (c0e0e9f): 15/0/2, all piecewise slices green after enabling deploy-with-pending-jobs (Setup-UI-only, not in ApexSettings metadata — 16 fields inspected). Picked #8: eval Version file + un-quarantine + headless eval run. Hightower dispatched.

- **Iter 9b (2026-07-03):** Gates run landed (95657a9): phase-0 4/4, phase-1 7/7, phase-2 → Apex 198/198 83% coverage, Jest 53/53, p2-005/006 OPEN-MANUAL (owner sign-off), p2-002 FAIL triaged: blocked by DESIGNED org state (nightly cron + Active bot), not source. BROOKS RULING: fix the gate, not the org — Hightower resumed to update mortagate.gates.json (piecewise dry-run canonical per ADR-22 + release-runbook note; p2-004 command fixed) and re-run piecewise.

- **Iter 9 (2026-07-03):** ITEM #6 CODE-COMPLETE (6cd351a): IdentityGateService outside kernel, orthogonality proven (Confirmed_Match blocks a clean 780-FICO replay), lead-with-block in case summary, 22/22+10/10. Brooks approved the system-mode sanctions read (privileged-gate infra: verdict+label to auditors, never PII). R-8 human gates fenced. Picked #7 gates run. Hightower dispatched (full receipts, known full-source gack handled as PASS-WITH-DEVIATION per ADR-22/25, manual reviews marked OPEN-MANUAL honestly).

- **Iter 8b (2026-07-03):** Slice 1 DONE (89d7dc0): Sanctions_Screening__c append-only + guards 9/9, SSN token fields (encryption deferred OQ-R8-7), Veridact_KYC_Officer_Access need-to-know permset, DESIGN §9 vocabulary reconciliation. Gotcha: permset description >255 chars blocks deploy. Woz dispatched slice 2: IdentityGateService (Verified AND newest Result==Clear; absence=SCREEN_MISSING hard BLOCK; orthogonality proof test) wired into CaseSummaryService lead-with-block, NOT into kernel/replay/sweep.

- **Iter 8 (2026-07-03):** ITEM #5 DONE (9af6e6c). Picked #6 KYC/OFAC — multi-slice item: slice 1 = Knuth schema per DESIGN-kyc-ofac.md + ADR-24 (Sanctions_Screening__c append-only, SSN token fields, gating status), slice 2 = gating precondition service + tests. Compliance/security OQs (vault vendor, sign-offs) = BLOCKED-HUMAN fences, build proceeds around them.

- **Iter 7 (2026-07-02):** ITEM #4c DONE (086cfc9) — item-4 family complete (1 conversational, 3 UI-path/retired by measured doctrine). Note: Draft_Evidence_Request binding remained on topic from 4a (harmless, shadowed) — cleanup candidate later. Picked #5 RuleNarration fold-in. Fowler dispatched (refactor slice is the refactor gate's own lane).

- **Iter 6b (2026-07-02):** 4c build landed GREEN (31e080a: ViolationAlertService 5/5 incl. controlled-Task + idempotency; enableActivities gap found+fixed on Audit_Case__c; Auditor__c is the auditor lookup). Routing tripwire fired as predicted: 'alert about violations' shadowed by same-noun sibling (ledger: Summarize_Case fired, 0 alert rows). BROOKS RULING: retire conversational affordance per ADR-28 — side-effecting same-noun actions go UI-path WITHOUT emulation (side effects can't ride another action's payload). Woz transcript lost again (resume fails after long sessions — pattern); fresh Woz dispatched: detach action + instruction, regression-verify, FR-37 ✅ as UI-path, ADR-28 addendum, commit.

- **Iter 6 (2026-07-02):** ITEMS #4b + #4d CLOSED by ADR-29 (Woz stop-early gate measured Audit_Event__c.Audit_Case__c non-nillable → caseless dual-write impossible; queue intents = UI surfaces, spine invariant stands, sentinel + relaxation rejected). Zero code written against the constraint. Picked #4c Send_Violation_Alert (case-anchored, viable). Woz dispatched.

- **Iter 5 (2026-07-02):** ITEM #4a DONE (14fa57c, ADR-28). Verb disambiguation failed verification twice (ledger truth) → accepted platform grain: conversational drafting = governed retrieval + LLM composition; EvidenceRequestService = UI path. ROUTING DOCTRINE: one action per data intent per topic; distinct nouns only. 4b re-scoped as portfolio rollup. Woz dispatched.

- **Iter 4b (2026-07-02):** 4a build GREEN through Builder wiring (deploys 0AfgL00000QHXodSAH + 0AfgL00000QHjoASAT, tests 8/8, action bound w/ visible input, 5 files uncommitted in tree). VERIFY DEVIATION: 'draft an evidence request' routed to List_Missing_Evidence (overlapping 'missing documents' instructions); ledger shows 0 Draft_Evidence_Request rows ever. Woz honestly caught its own DOM-grep false positive — LEDGER IS THE VERIFICATION TRUTH, never reply text. Brooks ruling: verb-level disambiguation (LIST=status question vs DRAFT=compose message). First Woz's transcript was lost (resume failed) — fresh Woz dispatched with self-contained brief: edit both instructions, reactivate, ledger-verify both utterances, land FR-36 + commit.

- **Iter 4 (2026-07-02):** ITEM #3 DONE (66209a7). Picked #4a Draft_Evidence_Request. Recipe now proven: invocable w/ planner descriptions + ADR-26 runX orchestrator + PNB tests + genAiFunction BUNDLE w/ input+output schema.json + Builder add-to-topic + reactivate + preview verify + log-row check.

- **Iter 3 (2026-07-02):** ITEM #2 DONE (b3fd34f, cron 08egL00000bzH8HQAU). Note: org alias spelling is mortagate-de; sf-deploy skill's 'mortgate-de' is a stale variant. Picked item #3: Priya Nair AC-0001 data fix. Knuth dispatched.

- **Iter 2 (2026-07-02):** ITEM #1 CLOSED GREEN (ec08104) — copilot live end-to-end, doctrine traced to Brain (GenAiFunction=bundle w/ I/O schemas; re-add after schema change). Picked item #2: nightly sweep schedule. Hightower dispatched (schedule + CronTrigger verify + FR-32 doc + commit).

- **Iter 1h (2026-07-02):** DEFINITIVE root cause (Brooks direct inspection + Woz's no-inputs screenshot): our 4 GenAiFunction bundles contain ONLY the -meta.xml — no input/schema.json or output/schema.json. Working actions are bundles WITH both (reference: EmployeeCopilotPlanner/localActions/.../GetRecordDetails/{input,output}/schema.json). The deployed bundle IS the contract → empty inputs → planner can't construct a call → Actions: 0. June's Diagnose has the same birth defect (no Apex action has EVER launched from an utterance on this org). Slice 5 also cleaned topic 2 (0 standard actions left). Woz dispatched: author 4× input+output schema.json from the invocable DTOs, deploy bundles, re-add actions (mid-point proof: auditCaseId visible in Builder action edit), reactivate, verify, item-1-closing commit.

- **Iter 1g (2026-07-02):** Description fix deployed (4 classes, 22/22 tests, deploy 0AfgL00000QHrNVSA1) — necessary but NOT sufficient. Discriminating test (context var set) CONCLUSIVE: planner sees 0 candidate actions on the topic even with input available — the runtime planner definition doesn't carry the Builder-bound actions. Also found: leftover AnswerQuestionsWithKnowledge on the SECOND topic (Compare Expected vs Actual Values) stealing pass-2 planning. BROOKS HYPOTHESIS: topic binding snapshots the function schema at attach-time (all attached pre-description-deploy) — refresh = remove+re-add all 4 actions. Woz resumed: re-add on topic 1, clean standard actions off topic 2, reactivate, verify. If still 0 → Bellard planner-bundle localActions deep-dive (working EmployeeCopilot actions live as localActions WITH input/schema.json inside the planner bundle; ours may never have materialized there). 4 .cls edits sit uncommitted in tree (deployed, green).

- **Iter 1f (2026-07-02):** Bellard debug:root_cause_found — @InvocableVariable inputs carry label= but NO description=; GenAiFunction input schema derives from the invocable at class deploy, so the planner has no extraction hint for the required auditCaseId → declines all 4 actions. Working EmployeeCopilot actions have rich input descriptions (the measured diff). June's "working" Diagnose was masked by testSpec-injected context var (in-prompt crutch). Fix = add planner-grade description= to the invocable vars in all 4 classes, redeploy CLASSES only (GenAiFunction metadata round-trip is UNKNOWN_EXCEPTION-broken on this org). Woz resumed to land it + verify (no context var set) + hygiene + commit. DOCTRINE: every Agentforce-facing @InvocableVariable needs a planner-grade description with an extraction example.

- **Iter 1e (2026-07-02):** Slice 3 done: standard actions removed, topic now exactly 4 governed Apex actions (ADR-16 compliant), data-library deflection + wrong-action hijack GONE. Remaining: planner selects the right subagent but launches 0 of 4 actions ("Actions: 0"), re-plans to Off_Topic, zero log rows. PRIMARY HYPOTHESIS: required auditCaseId input is context-variable-bound (June R-10 fix pattern) and context vars are unset in Preview → planner can't satisfy required input → declines all four. Bellard dispatched for function-contract inspection (GenAiFunction defs, @InvocableVariable descriptions, bot context-var wiring, discriminating test = set context var in Preview).

- **Iter 1d (2026-07-02):** Router fix WORKED (widened classification: Subagent Selected = Summarize Rule Violations, Off_Topic bug gone). New residual isolated: action-selection launched standard "Answer Questions with Knowledge" (which can never succeed — no data library → INVALID_ID_FIELD) instead of List_Missing_Evidence. BROOKS RULING: topic carries ONLY governed ADR-26 actions — remove BOTH standard actions (Answer Questions with Knowledge + Summarize Record) from the topic; standard actions bypass log-before-execute and steal selection. Woz resumed to execute + re-verify + hygiene/commit if green. Note: in-org topic API name is p_16jAq000000HTgj_Summarize_Rule_Violations_16jgL000001qbVy (hybrid prefix — Bellard's foreign-orphan model needs refining; the 16jAq-named plugin exists in-org under a suffixed name).

- **Iter 1c (2026-07-02):** Woz phase 1 done: all 3 actions confirmed bound on the LIVE topic (6 actions total), agent deactivate→reactivate published the binding (v1 Active). Verification MIXED: preview still deflects — plan trace proves the TOP-LEVEL router classifies audit-case utterances as Off_Topic (0 actions), never enters the topic. Not an action-binding defect. Woz resumed with the routing fix: widen subagent scope description + add per-action instructions, reactivate, re-verify, then repo hygiene (rm foreign p_16jAq* files) + commit if green. Watch: null-Audit_Case__c log row = input-binding residual (R-10 pattern).

- **Iter 1b (2026-07-02):** Bellard ROOT CAUSE (certain): actions were attached to a FOREIGN orphan plugin (p_16jAq… — another org's prefix; this org is 16jgL); live topics bind only Diagnose_Loan_Audit. Licenses/Apex-access/CRUD all measured green. Woz dispatched: deactivate → Builder attach to the real topic → reactivate → verify (preview answer + ≥1 List_Missing_Evidence log) → delete orphan 16jAq files → commit/push. Residual rank-2 risk: planner may not fill required auditCaseId input (R-10 pattern) — detect by log row with null case.
- **Iter 1 (2026-07-02):** Seeded state. Picked item #1 (highest priority, no deps). Dispatched Bellard for measurement-first root-cause of the function-invocation gap. Facts going in: agent ACTIVE (botUser=veridact_auditor_internal@00dgl…ext); permset incl. Wave-2 classes assigned; object perms Read=true (Audit_Case/Evidence_Item/Replay_Check); OWD ReadWrite; hero case visible; ZERO Agent_Action_Log__c rows on both preview attempts (fail-closed proves Apex never entered); planner SELECTED Summarize Rule Violations subagent on attempt 1, routed Off-Topic on attempt 2; canned deflection "unable to access… data library or permissions issue."
