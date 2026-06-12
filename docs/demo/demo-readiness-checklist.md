# Demo-Readiness Checklist — Mortgage Audit Queue

**Demo target:** Wells Fargo / Bank of America executives
**Org:** `mortagate-de` · **Golden-path case:** AC-0001 (Priya Nair, Critical)
**Last verified:** 2026-06-12

Run this top-to-bottom the morning of the demo. Anything not green → fix or cut that scene.

---

## 1. Data is staged (the demo has something to show)

- [x] AC-0001 drill-down is fully populated, verified by query on 2026-06-12:
      - Evidence_Item__c: **5**
      - Reconstructed_Fact__c: **5** (DTI 47, Credit 712, Income 82k, Loan 410k, LTV 80)
      - Rule_Check__c: **4** (1 Violation: DTI; 3 Pass)
      - Finding__c: **1** (Eligibility / High / Open)
      - Audit_Event__c: **5** (Created → Evidence → Facts → Replay → Finding)
      - Case: `Status=In_Review`, `Policy_Version=DTI_MAX@v3`, `Risk_Tier=Critical`
- [ ] Re-confirm the counts the morning of (data could be altered between now and then).
      Seed is re-runnable from `/tmp/seed_demo.apex` if the chain is missing — **but the
      Policy_Rule_Version insert is NOT idempotent**, so only re-run against a clean case.

## 2. Tests are green (the "it works" claim is backed)

- [x] LWC Jest unit + accessibility: **12/12 pass** (`npm run test:unit`, 2026-06-12),
      including "conveys risk by text not color (WCAG 1.4.1)" and "role=alert load error".
- [x] Apex AuditQueue suite: **37/37** on `mortagate-de` (verified earlier this session).
- [ ] (Optional) Re-run `npm run test:unit` morning-of for a fresh green.

## 3. Accessibility posture (a talking point, be honest about scope)

- [x] **Automated** a11y contract is green (the two Jest tests above).
- [ ] **Manual** assistive-tech pass (NVDA/VoiceOver + dark mode) is **NOT yet executed** —
      script lives at `docs/accessibility/screen-reader-test-plan.md`. If asked, say:
      *"Automated accessibility checks pass; a full manual screen-reader certification is
      scheduled, not yet signed off."* Do not claim a completed manual pass.

## 4. ⚠️ Seed-data warning (do not let this surface on screen)

- The org contains **614 `[KAGGLE-SEED]` test rows** (Kaggle "Home Loan Approval" data),
  tagged in `Audit_Case__c.Scope__c`. These are **test data and must never reach prod**.
- [ ] Stay on the **curated AC-0001 path**. Do **not** sort/filter into the seed rows or
      open a random case — many seed cases have **empty drill-downs** and will look broken.
- [ ] The promotion guard `scripts/guard-no-seed-in-prod.sh` blocks any prod deploy while
      seed rows are resident. (Reassurance point if a technical reviewer asks about prod.)

## 5. Keep the engineering off-screen

- [ ] Close: VS Code, Developer Console, Setup, terminals, any `sf` CLI window.
- [ ] Browser: only the Lightning app tab (Audit Queue) + the one-pager tab for Q&A.
- [ ] Do **not** mention: scratch-org reproducibility, the PolicyRuleEvaluator git/org fork,
      the Brooks engine session, or "git is the org" plumbing. Irrelevant to the exec story.
- [ ] Zoom ~110%, notifications silenced, screen-saver/sleep disabled.

## 6. Fallback if the live org misbehaves

- [ ] Have screenshots of each of the 6 scenes captured in advance (queue → case → facts →
      violation → finding → events) so the narrative survives a connectivity/login failure.
- [ ] Know the re-login path: `sf org open -o mortagate-de` (run privately, before the room).

---

## Known limitations (say these plainly if pressed — don't oversell)

1. **One fully-curated case.** AC-0001 is the polished path. Other cases are test seed or
   thin. This is a capability demo, not a populated production tenant.
2. **Manual a11y certification pending** (see §3).
3. **Policy replay shown for DTI/ATR-QM.** The engine generalizes to other rules, but the
   demo narrative is built around the DTI violation for clarity.

## Sign-off

- [ ] Data verified morning-of
- [ ] Tests green morning-of
- [ ] Screens cleaned, fallback screenshots ready
- [ ] Presenter has read `exec-demo-script.md` and `exec-one-pager.md`
