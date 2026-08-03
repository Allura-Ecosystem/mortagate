# Margaret's Review of CaseFile (née "Veridact Audit")

**Persona:** Margaret, 58, senior bank QC analyst, 30 years of paper-based post-close mortgage audits.
**Date:** 2026-08-03
**Method:** Adversarial UX test per SC-8 UAT script
**Product:** CaseFile (Salesforce org label: "Veridact Audit")
**Org URL:** https://orgfarm-156cb47730-dev-ed.develop.my.salesforce.com

---

## PART 1: MARGARET'S RANT (In Character)

### Overall Verdict

> *"I got through it. Barely. But I don't trust it, I don't like it, and the first time it wastes my time I'm going back to my manila folder and my yellow pad. You can keep your 'CaseFile' — my filing cabinet has never asked me for a verification code."*

---

### FIRST IMPRESSION

So they hand me this URL on a piece of paper. I type it in. And what do I get? A white page with a logo and a box asking for a username and password. Not "Welcome to CaseFile." Not "Hello Margaret." Just a blank stare. Alright, fine, I've seen a login page before. My husband set up my email. I can handle this.

But then I type my username and password and it sends me a **text message code**. A code. To my phone. Which I have to wait for. Which takes 45 seconds because the network in this building is garbage. And if I take too long, the code expires and I have to ask for another one. I'm 58 years old, my thumbs don't move that fast. By the time I got in I'd already sighed three times.

**First impression:** This system already doesn't trust me and I haven't even done anything yet.

---

### FINDING THE AUDIT CONSOLE

So I'm in. I see the Salesforce homepage. It's a blue bar with a bunch of icons. My name is in the top right. Okay. Now what?

The UAT script says "Click the App Launcher — the 9 dots grid icon." Nine dots. In the top left. I'm looking at this screen and I see a house icon, a gear icon, a bell, a question mark. Where are the nine dots? Oh, there they are. They're tiny. They're grey. They look like a decorative pattern, not a button. Who designed this? Who looks at nine microscopic dots and thinks "ah yes, the app launcher"?

I click it. A search box pops up. I type "Veridact Audit." But the product is called **CaseFile**. The script told me it's called Veridact Audit in the system. So if I were a real analyst who didn't have a script, I'd be searching for "CaseFile" and getting nothing. I'd think the system was broken. I'd call IT. I'd be on hold for 20 minutes. Then IT would tell me "oh, it's called Veridact Audit." And I'd say "then why does the email say CaseFile?" And they'd say "we're rebranding." And I'd say "I don't care about your rebranding, I care about my audit."

**This is the first real test of the system and it already has a name mismatch.** That's not a cosmetic issue. That's a "real person cannot find the app" issue.

---

### THE AUDIT QUEUE

I click Veridact Audit. The screen loads. And I'm looking at... a lot of stuff.

On the left is a list of cases. On the right is a dashboard with numbers in boxes. Metric cards, the script calls them. I call them "numbers I don't know what they mean." There's "Total Cases," "Open Cases," "In Review," "Overdue." Overdue according to what? I don't know. There's no context. No "these are the cases that need your attention today." Just numbers.

The case list on the left — it's a table. Columns: Case Name, Status, Borrower, Created Date. The font is small. I'm squinting. I can see maybe 8 rows at a time. I have to scroll. I have 30 years of cases in my filing cabinet and I can flip through them in 10 seconds. Here I have to scroll, squint, and click.

I find a case with Status "Open." I click the name. It opens.

**So far:** 4 screens, 7 clicks, 2 minutes, and I haven't done any actual work yet.

---

### THE CASE REVIEW SCREEN

Now I'm on the Case Review screen. Two panes. Left side: case information and evidence. Right side: replay findings (empty, because I haven't run anything yet).

The left pane has sections. Case Info. Borrower Details. Evidence. Each section is a collapsible card. I click one to expand it. The text is small. The fields are things like "Loan Amount: $450,000" and "Borrower: John Smith." Okay, that's fine. I can read that.

But the Evidence section — it's empty. There's a button that says "Upload" or "Add Evidence." I click it. A file picker opens. I find my PDF. I select it. I click Open. The file uploads. A little spinner. A few seconds. Then the document appears in the list with a status that says "Uploaded."

**This part actually worked.** I'll give credit where it's due. It was straightforward. Click, find file, done. No fuss. That's how software should work.

---

### RUNNING THE DECISION

Now I need to run the policy rules. The script says to look for a button called "Run Decision" or "Evaluate" or "Replay."

**Three different names for the same button.** That's not helpful. Which one is it? I'm scanning the screen. I see a button that says "Run Decision." Okay, that's the first one. I click it.

Nothing happens for a few seconds. No progress bar. No "working on it" message. Just... nothing. I'm staring at the screen wondering if it did anything. Then a message appears: "Decision complete."

**That's it?** "Decision complete"? What does that mean? Did it pass? Did it fail? What rules did it check? I have no idea. I have to click another button to find out.

---

### VIEWING THE RECEIPT

The script says to look for a "View Receipt" or "Receipt" button. I find it. I click it.

The Decision Receipt page loads. Now THIS is useful. It shows:
- The decision outcome: "PASS" (or whatever it was)
- The date and time
- A list of each rule that was checked, with pass/fail
- The policy version used

**This is good.** This is what I need. This is the equivalent of my sign-off sheet. I can see what was checked and what the result was. I can print it. I can save it. I can file it.

But then I look at the bottom of the page and it says **"Veridact — every decision has a receipt."** Not CaseFile. Veridact. Again. I'm looking at a receipt for a product called CaseFile and it says Veridact on it. If I showed this to my manager, she'd say "Margaret, what's Veridact?" And I'd say "I don't know, it's the system." And she'd say "I thought it was called CaseFile." And I'd say "It is. But the receipt says Veridact." And she'd look at me like I'm the one who's confused.

**This is not cosmetic. This is a trust issue.** If the system can't get its own name right, how can I trust it to get my audit right?

---

### RUNNING AUDIT REPLAY

Now I need to go back to the Case Review screen and run the Audit Replay. The script says to look for a "Run Replay" or "Audit Replay" button.

I go back. I find the button. It says "Run Replay." I click it.

It runs. A few seconds. Then a list appears. Each row shows:
- The rule that was checked
- Whether it passed or failed
- The fact value used
- The threshold it was compared against

**This is also good.** I can see the replay results. I can compare them to the original decision receipt. If they match, I'm confident. If they don't, I have a problem.

But here's the thing: **I have to manually compare them.** There's no "compare" button. No "results match" indicator. I have to look at the receipt, look at the replay results, and check each one myself. That's 10 rules. 10 comparisons. If I'm tired, I'll miss one. If I'm in a hurry, I'll skip one. If I'm distracted, I'll get it wrong.

My yellow legal pad doesn't make me do manual comparisons. I write the result once and I'm done. Here I have to check my work twice.

---

### SIGNING OFF

The last step. Sign off. I look for a "Sign Off" or "Approve" button. I find it. I click it.

It asks for a comment. I type "Reviewed and approved." I confirm.

The case status changes to "Signed Off."

**This worked.** It was simple. One click, one comment, done. This is how it should be.

But then I think: **where does this go now?** Does my manager get notified? Does it go to a queue? Do I get a confirmation? The screen just changes the status. There's no "this has been sent to your manager for final approval" message. No "receipt emailed to compliance." Nothing. Just a status change. I'm left wondering if anyone will ever see it.

---

### THE ANALYTICS DASHBOARD

I clicked on the Analytics tab out of curiosity. Bad idea.

There are charts. Bar charts. Pie charts. Line graphs. Numbers everywhere. "Average Decision Time." "Rule Pass Rate." "Case Volume by Week."

**I don't know what any of this means.** I'm a QC analyst. I review cases. I don't analyze trends. I don't care about averages. I care about the case in front of me. This dashboard is for someone else — a manager, maybe, or compliance. But it's the first thing I see when I open the app. It's noise. It's distracting. It makes me feel like I'm supposed to understand something I don't.

And the font is still too small.

---

### THE POLICY VERSIONS SCREEN

I found a "Policy Versions" tab. I clicked it. It shows a list of policy versions with dates and statuses.

**This is actually useful.** I can see which version was active when I ran my decision. I can verify that I used the right rules. This is the kind of thing I'd have to call IT for in the old system. Here I can see it myself.

But the terminology: "Policy_Rule__c" and "Policy_Version__c" and "Policy_Rule_Version__c." These are database table names, not user-facing labels. I don't know what "__c" means. I don't care. Call it "Rule" and "Version" and "Rule Version." Drop the double underscores. They look like typos.

---

### SUMMARY OF MY EXPERIENCE

**What worked:**
- Uploading evidence was straightforward
- The decision receipt is clear and printable
- The replay results are detailed and comparable
- Sign-off was simple
- Policy versions are accessible

**What didn't work:**
- The login MFA code is annoying and slow
- The app is called "Veridact Audit" but the product is "CaseFile" — I would have searched for the wrong name
- The nine-dot app launcher is not obvious
- The dashboard is overwhelming and irrelevant to my job
- The font is too small everywhere
- "Run Decision" / "Evaluate" / "Replay" — three names for the same action
- No progress indicator when running a decision
- No automated comparison between original decision and replay results
- No confirmation after sign-off that the next step has happened
- Database field names ("__c") shown to users

**Would I use this instead of paper?**
No. Not yet. It's too much friction for too little gain. My manila folder and yellow pad let me do my job in 5 minutes with zero confusion. This system takes 10-15 minutes and leaves me wondering if I did it right. The only way I'd switch is if my manager forced me to — and I'd complain the whole time.

---

## PART 2: PRAGMATISM FILTER

*Stepping out of Margaret's character. Evaluating each complaint as a product person.*

---

### RED — REAL UX BUGS (Fix these. Any user would have these problems.)

| # | Issue | Margaret's Quote | Screen / Step | Why It's RED |
|---|-------|-----------------|---------------|--------------|
| R1 | **App name mismatch** — Org labels say "Veridact Audit" but product is called "CaseFile" everywhere else (emails, docs, marketing). A new user searching for "CaseFile" in the App Launcher gets zero results. | *"I'd be searching for 'CaseFile' and getting nothing. I'd think the system was broken."* | Step 2: App Launcher search | A 35-year-old competent user would also search for the product name they were given. This is a hard blocker for onboarding. The UAT script itself calls this a "known cosmetic mismatch" but it's not cosmetic — it prevents discovery. |
| R2 | **No progress indicator during decision execution** — After clicking "Run Decision," the screen is unresponsive for several seconds with no spinner, progress bar, or status message. | *"Nothing happens for a few seconds. No progress bar. No 'working on it' message. Just... nothing."* | Step 5: Run Decision | Any user, regardless of tech comfort, needs feedback that an action is being processed. Without it, users click again, navigate away, or assume the app is frozen. |
| R3 | **No automated comparison between original decision and replay results** — The user must manually compare 10+ rule results across two screens. No diff view, no "results match" indicator. | *"I have to look at the receipt, look at the replay results, and check each one myself. If I'm tired, I'll miss one."* | Step 6 vs Step 7: Receipt vs Replay | This is the core value proposition of the product (audit replay proves reproducibility). Making the user do manual comparison defeats the purpose and introduces human error. A competent user would also expect the system to do this comparison. |
| R4 | **No post-sign-off confirmation or next-step visibility** — After signing off, the status changes but there's no message about what happens next (manager notification, queue routing, compliance filing). | *"I'm left wondering if anyone will ever see it."* | Step 8: Sign Off | Any user completing a workflow needs closure. Without it, users re-check, re-submit, or call support to confirm. This is a basic workflow completion pattern. |
| R5 | **Database field names exposed to users** — "Policy_Rule__c", "Policy_Version__c", "Policy_Rule_Version__c" shown as labels. The "__c" suffix is a Salesforce internal convention. | *"I don't know what '__c' means. I don't care. They look like typos."* | Policy Versions screen | Exposing internal API/DB naming conventions to end users is a universal UX anti-pattern. Any non-technical user would be confused. Even technical users would find it unpolished. |

---

### YELLOW — VALID BUT LOW PRIORITY (Real issues, but only for extreme users or edge cases.)

| # | Issue | Margaret's Quote | Screen / Step | Why It's YELLOW |
|---|-------|-----------------|---------------|-----------------|
| Y1 | **MFA verification code UX** — Code arrives via SMS, has a short expiry, and the user has to switch context to their phone and back. | *"My thumbs don't move that fast. By the time I got in I'd already sighed three times."* | Step 1: Login | MFA is a security requirement, not a UX choice. But the expiry window and SMS delivery could be optimized. A busy professional of any age would find this annoying, but it's not a blocker. |
| Y2 | **Three different button labels for the same action** — "Run Decision" / "Evaluate" / "Replay" appear in different contexts for what is essentially the same operation. | *"Three different names for the same button. That's not helpful."* | Steps 5, 7: Decision and Replay | Terminology inconsistency creates cognitive load. A competent user would figure it out after the first use, but it's unnecessary friction. Standardize to one label. |
| Y3 | **Analytics dashboard is the default landing view** — The dashboard with charts and metrics is shown on the right pane of the Audit Console, competing for attention with the case queue. | *"I don't know what any of this means. I'm a QC analyst. I review cases. I don't analyze trends."* | Step 2: Audit Console landing | For a role-specific tool, the default view should prioritize the user's primary task (finding and reviewing cases). The dashboard is useful for managers but should be secondary for analysts. |
| Y4 | **No empty state guidance** — When the Evidence section is empty, there's no helpful text like "Upload a document to get started" or a sample document prompt. | *"The Evidence section — it's empty."* | Step 4: Evidence section | A new user seeing an empty section might not know what to do. Adding contextual help text is low effort and high value for onboarding. |

---

### WHITE — PERSONA NOISE (Margaret's personal resistance to technology. Not a product problem.)

| # | Issue | Margaret's Quote | Why It's WHITE |
|---|-------|-----------------|----------------|
| W1 | **"I can flip through my filing cabinet in 10 seconds"** — Comparing digital scroll/click speed to physical file browsing. | *"I have 30 years of cases in my filing cabinet and I can flip through them in 10 seconds. Here I have to scroll, squint, and click."* | This is resistance to digital workflows in general. A physical filing cabinet is not faster for a queue of 50+ cases — Margaret is romanticizing her current process. |
| W2 | **"My yellow legal pad doesn't make me do manual comparisons"** — Preferring paper-based single-entry over digital double-checking. | *"My yellow legal pad doesn't make me do manual comparisons. I write the result once and I'm done."* | The replay comparison is a feature, not a bug. It's designed to catch errors. Margaret's complaint is that it requires more work than her current process, which is true — but that's the cost of auditability. |
| W3 | **General distrust of the system** — "If the system can't get its own name right, how can I trust it to get my audit right?" | *"This is a trust issue. If the system can't get its own name right, how can I trust it to get my audit right?"* | This is a logical leap. A name mismatch in the org label does not affect the correctness of policy rule evaluation. It's a valid frustration but not a valid technical concern. |
| W4 | **"The font is too small everywhere"** — Repeated complaint about text size. | *"The font is small. I'm squinting."* | While accessibility is important, this is a browser-level setting (Ctrl+ / Cmd+). Salesforce's default font size is standard. Margaret needs to learn to zoom. However, if the app has custom CSS that overrides browser zoom, this becomes a RED issue. |
| W5 | **MFA is "annoying"** — General complaint about two-factor authentication. | *"This system already doesn't trust me and I haven't even done anything yet."* | MFA is a security requirement for banking applications. It's not optional. Margaret's frustration is valid but the solution is not to remove MFA. |

---

### GREEN — FEATURE REQUESTS (Good ideas hidden in the complaints.)

| # | Issue | Margaret's Quote | Screen / Step | Suggested Feature |
|---|-------|-----------------|---------------|-------------------|
| G1 | **"Compare" button for decision vs replay** — Margaret had to manually compare 10 rule results. She's right that the system should do this. | *"There's no 'compare' button. No 'results match' indicator."* | Steps 6-7: Receipt vs Replay | Add a "Verify Replay" button that automatically compares the original Decision_Event__c results with the Replay_Check__c records and shows a green/red summary: "All 10 rules match" or "Rule #3, #7 differ — review." |
| G2 | **Post-sign-off workflow visibility** — Margaret didn't know what happened after she signed off. | *"Does my manager get notified? Does it go to a queue? Do I get a confirmation?"* | Step 8: Sign Off | After sign-off, show a confirmation modal: "Signed off. This case has been sent to [Manager Name] for final approval. A copy has been filed to Compliance." Include a link to the case in the manager's queue. |
| G3 | **Role-based default view** — The analytics dashboard is irrelevant to an analyst's daily work. | *"This dashboard is for someone else — a manager, maybe, or compliance. But it's the first thing I see."* | Step 2: Audit Console landing | Implement role-based landing pages. Analysts see the case queue as the primary view with a small summary bar. Managers see the dashboard. Or make the dashboard collapsible/hideable. |
| G4 | **Onboarding tooltip for first-time users** — Margaret didn't know what the nine-dot icon was, what "Veridact Audit" meant, or where to find evidence upload. | *"Who looks at nine microscopic dots and thinks 'ah yes, the app launcher'?"* | Step 2: App Launcher | Add a 3-step guided tour on first login: (1) "This is the App Launcher — find your apps here," (2) "Your cases are here — click one to start," (3) "Upload evidence here to begin a review." |
| G5 | **Progress indicator for async operations** — Margaret stared at a blank screen while the decision ran. | *"Nothing happens for a few seconds. No progress bar."* | Step 5: Run Decision | Add a spinner or progress bar with status text: "Running Rule 3 of 10: DTI Ratio Check..." This gives the user feedback and builds confidence that the system is working. |

---

## PART 3: TICKET SUMMARY

### RED Tickets (Must Fix Before Launch)

1. **App name mismatch blocks discovery** — The org labels say "Veridact Audit" but the product is called "CaseFile" in all external communications. New users searching for "CaseFile" in the Salesforce App Launcher get zero results. **Fix:** Update the Salesforce org app label to "CaseFile" (or at minimum add "CaseFile" as a search keyword alias).

2. **No progress indicator during decision execution** — After clicking "Run Decision," the UI is unresponsive for 3-10 seconds with no visual feedback. **Fix:** Add a spinner or progress bar with status text during decision execution.

3. **No automated decision-vs-replay comparison** — Users must manually compare 10+ rule results across two screens. This defeats the purpose of audit replay. **Fix:** Add a "Verify Replay" button that auto-compares Decision_Event__c results with Replay_Check__c records and shows a pass/fail summary.

4. **No post-sign-off confirmation or workflow visibility** — After signing off, users receive no confirmation of what happens next. **Fix:** Add a confirmation modal showing the next workflow step (manager notification, queue routing, compliance filing).

5. **Database field names exposed to end users** — Labels like "Policy_Rule__c" and "Policy_Version__c" use Salesforce internal naming conventions. **Fix:** Create user-friendly display labels for all policy objects. Strip "__c" suffixes. Use "Policy Rule" and "Policy Version."

### YELLOW Tickets (Note for Backlog)

1. **Inconsistent button labels** — "Run Decision" / "Evaluate" / "Replay" used interchangeably for similar operations. Standardize to one term.
2. **Analytics dashboard as default view** — The dashboard competes for attention with the case queue. Consider role-based landing pages or collapsible dashboard.
3. **Empty state guidance** — Evidence section shows nothing when empty. Add contextual help text.

### GREEN Tickets (Feature Requests)

1. **Auto-compare decision vs replay** (see RED #3 — this is both a bug fix and a feature)
2. **Post-sign-off workflow confirmation** (see RED #4 — same)
3. **Role-based landing pages** (analysts see queue, managers see dashboard)
4. **First-run guided tour** (3-step onboarding for new users)
5. **Progress indicator for async operations** (see RED #2 — same)

---

*Rant written by Margaret (in character). Filter applied by product reviewer. Tickets prioritized for beta launch readiness.*

*Cross-ref: SC-8-analyst-uat-script.md, GOAL-G2-beta-readiness.md, ADR-30 (naming), ADR-17 (Allura Brain), ADR-33 (platform events)*
