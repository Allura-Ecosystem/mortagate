# Steve Jobs Beta Sign-Off: CaseFile

**Reviewer:** Steve Jobs (product taste-maker)
**Date:** 2026-08-03
**Product:** CaseFile — post-close mortgage audit replay and QC
**Context:** Beta readiness gate, per Captain's directive ("still clear and Brooks and jobs approve it")

---

## Verdict

# CHANGES REQUESTED

Not because the engineering is bad. The engineering is *excellent* — 204 tests at 100%, 550ms benchmark, 86% governor headroom, a pure kernel with zero SOQL/DML, an append-only audit trail that blocks both UPDATE and DELETE. Brooks should be proud. The architecture is clean. The data model is sound. The Sabir Sr. demo tells a real story.

But this product is not ready for a bank QC analyst to touch. And I'm not talking about the 59 edge cases in the backlog. I'm talking about the *feel*. The confidence. The moment when Margaret sits down and thinks "I trust this."

Here's what I found.

---

## 1. Would a bank QC analyst feel confident using this?

**No. Not yet. And the gap is not technical — it's emotional.**

Margaret's first 30 seconds with CaseFile are a masterclass in how to destroy trust before you've done anything wrong:

- She searches for "CaseFile" in the App Launcher. Gets nothing. The org calls it "Veridact Audit." She doesn't know what Veridact is. She thinks the system is broken. **This is the first thing that happens.** Before she's reviewed a single case, she's already annoyed and confused.

- She clicks "Run Decision." The screen freezes for 3-10 seconds. No spinner. No progress bar. No "working on it." Just dead air. Every second of that silence, she's thinking "did it crash? Did I break it? Should I click again?" **This is the second thing that happens.** Now she's anxious.

- The decision completes. A toast says "Decision complete." That's it. No summary. No "8 rules passed, 2 failed, here's why." She has to navigate to a *different screen* to see what happened. **This is the third thing.** Now she's annoyed *and* anxious *and* doing extra work.

Three strikes in under two minutes. A real analyst would have called IT by now. A real analyst would be complaining to her manager. A real analyst would be printing the receipt and filing it in her manila folder, because the manila folder never made her wait.

**The product works. But it doesn't *feel* like it works.** That's the difference between a demo and a product people trust.

### What would fix this

- **Name consistency is not cosmetic.** It's the first trust signal a user gets. If the org label says "CaseFile," the user finds it. If it says "Veridact Audit," the user is lost. This is a one-line metadata change. Do it before beta.

- **Progress feedback is not a nice-to-have.** It's the difference between "this is working" and "this is broken." A spinner with "Evaluating rule 3 of 10: DTI Ratio Check..." tells the user the system is thinking. A frozen screen tells the user the system is broken. This is a few lines of LWC state. Do it.

- **The decision result should be the first thing the user sees, not the second.** After "Run Decision" completes, show the summary inline. "8 passed, 2 failed. DTI_MAX exceeded threshold (44.8% > 43%)." Don't make her navigate to find out what happened. The receipt is for filing. The summary is for *knowing*.

---

## 2. Does the audit replay tell a clear story?

**Almost. The data is there. The narrative is not.**

The Replay_Check__c records are beautiful. Each one carries:
- Rule name (DTI_MAX, FICO_MIN, etc.)
- Expected value (43)
- Actual value (44.8)
- Result (Fail)
- Sort order
- Rationale

That's the *what*. But the user needs the *why* — and the *so what*.

Here's what the replay shows today:

```
DTI_MAX | Fail | Expected: 43 | Actual: 44.8
```

Here's what it should show:

```
DTI_MAX | Fail | Expected: 43 | Actual: 44.8
→ Sabir's DTI of 44.8% exceeds the QM threshold of 43%.
→ This is a Hard Decline under QM rules.
→ Regulation: QM Ability-to-Repay (12 CFR 1026.43)
→ Evidence: Pay Stub (linked), W2 (linked)
```

**The story is: here's what happened, here's why, here's the rule, here's the evidence.**

Today the replay gives you "here's what happened" and "here's the rule." It's missing "here's why" (the rationale is a field on Replay_Check__c but it's not consistently populated with human-readable text) and "here's the evidence" (the evidence mapping exists in the left pane but there's no cross-link from a failing rule to the specific document that proves or disproves it).

### The comparison gap is the biggest missed opportunity

Margaret has to manually compare the original decision receipt with the replay results. Ten rules. Two screens. No diff view. No "results match" indicator.

**This is the core value proposition of the product.** The whole point of audit replay is to prove that the decision was reproducible. If the user has to do the comparison herself, you've turned your killer feature into homework.

Add a "Verify Replay" button. One click. Green checkmark: "All 10 rules match the original decision." Red alert: "Rule #3, #7 differ — review." That's the moment the analyst feels confident. That's the moment she trusts the system.

---

## 3. Is the sign-off moment satisfying?

**The mechanics are right. The ceremony is wrong.**

The sign-off flow works:
- Click "Sign off"
- Type a comment
- Status changes to "Signed Off"
- Receipt is immutable

That's technically correct. But it doesn't *feel* like justice was done. It feels like checking a box.

### What's missing

- **No "what happens next."** Margaret signs off and the screen just... changes status. She's left wondering "does my manager see this? Does it go to compliance? Did I just file this in a black hole?" A confirmation modal that says "Signed off. This case has been sent to Janet Chen for final approval. A copy has been filed to Compliance." That's closure. That's the feeling of "I did my job and it mattered."

- **No ceremony for the failing case.** The Sabir Sr. case is HARD_DECLINED. DTI 44.8% > 43%. That's a real finding. A real violation. A real person was denied a loan. The sign-off should reflect the gravity of that. The receipt should show the violation count prominently. The "Signed off" message should acknowledge the finding: "2 violations recorded. This case has been flagged for compliance review."

- **The receipt hash says "illustrative hash, not a cryptographic seal."** I understand why this is honest. But it undermines the entire point of showing a hash. Either make it a real cryptographic seal or remove it. A fake seal is worse than no seal — it tells the user "we wanted you to trust this, but we couldn't be bothered to finish it."

### The sign-off should feel like closing a case file

Right now it feels like updating a status field. It should feel like:
1. You review the evidence
2. You see the replay results
3. You compare them to the original decision (automatically)
4. You see the violations highlighted
5. You sign
6. The receipt seals with a satisfying visual — green border, checkmark, timestamp, reviewer name, hash
7. A confirmation tells you where it goes next

That's a ceremony. That's justice. That's a product an analyst would show her manager and say "look, I caught this one."

---

## 4. What's missing from a product feel standpoint?

### The big ones

| Missing | Why it matters | Priority |
|---------|---------------|----------|
| **Name consistency** | First trust signal. Org says Veridact, product says CaseFile, header says "Mortgage Audit." Three names = user thinks it's broken. | **BLOCKER** |
| **Progress indicator** | 3-10 seconds of frozen screen = user thinks it crashed. | **BLOCKER** |
| **Auto-compare decision vs replay** | Core value prop. Manual comparison defeats the purpose. | **BLOCKER** |
| **Post-sign-off workflow visibility** | No closure = user re-checks, re-submits, calls support. | **BLOCKER** |
| **Database field names exposed** | `Policy_Rule__c`, `__c` suffixes = unpolished, untrustworthy. | **BLOCKER** |

### The smaller ones that add up

- **Inconsistent button labels.** "Run Decision" / "Evaluate" / "Replay" for the same operation. Pick one. Standardize. Consistency is a form of trust.

- **The analytics dashboard competes for attention.** Margaret doesn't care about trends. She cares about the case in front of her. The dashboard should be a tab, not a split-pane default.

- **Empty states are empty.** The Evidence section says "No evidence items linked to this case." That's a database message, not a user message. It should say "Upload a document to begin your review" with a button.

- **The font is small.** Margaret is 58. She's not alone. Every bank has a Margaret. Make the default text size readable without squinting.

- **The "Demo" badge.** I understand why it's there. But it tells the user "this isn't real." For beta, that's honest. For GA, it needs to go. And the hash disclosure ("illustrative, not cryptographic") needs to be resolved before GA.

### The brand is good but not yet felt

The brand tokens are solid: Dark Green #0B2B1D, Gold #C8963E, Off-White #FAF9F6. Inter + Montserrat. The amber accent bar. The semantic color chips. The 8px border-radius. The restrained tone.

But the brand isn't *felt* because:
- The org chrome (Salesforce blue bar, 9-dot app launcher) dominates the visual experience
- The product name inconsistency undermines brand identity
- The "Veridact" ghost is everywhere — in the README, in the permission set names, in the record prefixes
- The brand is in the CSS tokens but not in the user's emotional experience

**A brand is what the user feels, not what the CSS says.** Right now the user feels "Salesforce with some green buttons." They should feel "CaseFile — a serious audit tool."

---

## 5. What I love (because I'm not a monster)

Let me be clear about what's excellent:

- **The audit replay data model is beautiful.** `Replay_Check__c` with `Expected_Value__c`, `Actual_Value__c`, `Sort_Order__c`, `Rationale__c` — this is the right schema. Every rule check is traceable, comparable, and auditable.

- **The staleness banner is a brilliant touch.** "This replay is stale — the loan changed after the last replay." That's the kind of honest, proactive communication that builds trust. More of this.

- **The immutable receipt is the right idea.** Append-only, no UPDATE, no DELETE. The validation rule and trigger are correct. The hash (even illustrative) is the right direction.

- **The Sabir Sr. demo tells a real story.** DTI 44.8% > 43% QM threshold. HARD_DECLINED. 8 pass, 2 fail. This is a real audit finding with a real regulatory consequence. The demo data is honest and meaningful.

- **The two-pane layout (evidence left, checks right) is the right information architecture.** It mirrors the physical workflow: file on the left, checklist on the right.

- **The engineering discipline is exceptional.** Pure kernel with zero SOQL/DML. 204 tests at 100%. 550ms for 6 cases. 86% governor headroom. 63 LWC Jest tests. This is a team that cares about quality.

- **The Margaret adversarial test was the right thing to do.** Finding 5 RED issues before a real analyst sees the product is exactly the kind of honesty that makes a product better. The fact that you fixed all 5 is commendable.

---

## The bottom line

**CaseFile is a well-engineered product with a trust problem.**

The engineering is beta-ready. The architecture is beta-ready. The data model is beta-ready. The tests are beta-ready.

But the *product feel* is not beta-ready. A bank QC analyst sitting down with CaseFile today would:
1. Not find the app (name mismatch)
2. Think it crashed (no progress indicator)
3. Not know what happened (no inline result summary)
4. Have to do manual comparison (no auto-compare)
5. Not know if her work mattered (no post-sign-off workflow)

That's five failures in the first five minutes. A real analyst would be back to her manila folder by step 3.

### What I need to see before I approve

1. **Org label changed to "CaseFile"** — one metadata change, zero code risk
2. **Progress indicator on decision execution** — spinner with rule-by-rule status
3. **Inline decision summary** — "8 passed, 2 failed" shown immediately after completion
4. **"Verify Replay" auto-compare** — one-click diff between original decision and replay
5. **Post-sign-off confirmation modal** — "Sent to [manager] for final approval. Filed to Compliance."
6. **Database field names cleaned up** — no `__c` suffixes visible to users
7. **Standardized button labels** — pick one term for the primary action

These are not architectural changes. They are *feel* changes. They are the difference between a product that works and a product that people trust.

### The good news

Every one of these is fixable in days, not weeks. The hard work is done. The engine is solid. The data model is right. The tests pass. The demo tells a real story.

What's left is the polish. The confidence. The trust.

**Fix these seven things, and I'll sign off. Don't ship beta without them.**

---

*"Design is not just what it looks like and feels like. Design is how it works."*
*— Steve Jobs*

*"The most powerful person in the world is the storyteller."*
*— Also Steve Jobs*

*CaseFile has a story to tell. It just needs to tell it clearly, confidently, and without making the user wait.*
