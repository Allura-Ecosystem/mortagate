# SC-8 — Analyst UAT Script

**Goal:** Take a loan application from intake to signed decision.
**Who follows this:** A bank analyst who has never seen the codebase.
**Reading level:** 6th grade. Simple sentences. No jargon.
**Org:** mortagate-de
**Product name:** CaseFile (but org labels still say "Veridact" — see note at Step 2)

---

## Before You Start

- You need a **Salesforce login** for the mortagate-de org.
- You need a **PDF file** to upload. Any PDF will do. A sample loan document is best.
- This whole test takes about 10–15 minutes.
- If something does not look right, write down what you see and keep going. Do not stop.

---

## Step 1: Log In to the Org

- [ ] Open your web browser.
- [ ] Go to the Salesforce login page for your org.
- [ ] Type your username and password.
- [ ] Click **Log In**.
- [ ] If you get a code by text or app, enter it now.

> **You should see:** The Salesforce home page with your name in the top right.

---

## Step 2: Open the Audit Console

The app is called **"Veridact Audit"** in the org. The real product name is **CaseFile** (ADR-30). The org labels have not been updated yet. This is a known cosmetic mismatch — it is honest and does not affect the test.

- [ ] Click the **App Launcher** (the 9 dots grid icon in the top left).
- [ ] Type **"Veridact Audit"** in the search box.
- [ ] Click **"Veridact Audit"** to open it.

> **You should see:** The Audit Console. On the left is a list of audit cases. On the right is a dashboard with metric cards showing counts.

---

## Step 3: Find an Audit Case to Work On

- [ ] Look at the list of audit cases on the left side of the screen.
- [ ] Find a case with **Status = "Open"** or **"In Review"**.
- [ ] Click the case name to open it.

> **You should see:** The Case Review screen. It has two panes:
> - Left pane: Case information and evidence items
> - Right pane: Replay findings (may be empty if no replay has run yet)

> **Note:** If there are no open cases, ask your admin to create one, or use a case that is already in progress.

---

## Step 4: Upload a Document (Evidence)

- [ ] On the Case Review screen, look for the **"Evidence"** section.
- [ ] Click the **"Upload"** or **"Add Evidence"** button.
- [ ] In the file picker, find the PDF file on your computer and select it.
- [ ] Click **Open** or **Upload**.
- [ ] Wait a few seconds for the upload to finish.

> **You should see:** The document appears in the evidence list. Its status should say **"Uploaded"** or **"Pending"**.

> **Behind the scenes:** The system creates an `Evidence__c` record with a file hash and scan status. This is the first step in the sync path: upload → Evidence__c → rule evaluation → Decision_Event__c → Audit Replay.

---

## Step 5: Run a Decision

Now you will run the policy rules against this case.

- [ ] Look for a **"Run Decision"** or **"Evaluate"** or **"Replay"** button on the Case Review screen.
- [ ] Click that button.
- [ ] Wait for the system to finish. This may take a few seconds.

> **You should see:** A message saying the decision is complete. The system has checked the case against the policy rules and created a decision record.

> **Behind the scenes:** The system runs the policy kernel (FactAssemblerService → PolicyRuleEvaluator → DecisionCommitService). It creates an immutable `Decision_Event__c` record. This is the synchronous path — no platform events are involved (SC-6c is deferred behind ADR-33 OQ-3).

---

## Step 6: View the Decision Receipt

Every decision has a receipt. This is a printable document you can save or email.

- [ ] After the decision runs, look for a **"View Receipt"** or **"Receipt"** button.
- [ ] Click it.

> **You should see:** The Decision Receipt page. It shows:
> - The decision outcome (e.g., "PASS", "FAIL", "HARD_DECLINED")
> - The date and time of the decision
> - A list of each rule that was checked, with pass/fail for each
> - The policy version that was used

- [ ] (Optional) Click **"Print"** or **"Download PDF"** to save a copy.

> **Note:** The receipt page says "Veridact — every decision has a receipt" at the bottom. This is the same cosmetic mismatch as the app name. The product is CaseFile.

---

## Step 7: Run Audit Replay

Audit Replay reconstructs the decision from stored evidence alone. It proves the decision can be recreated without the original session.

- [ ] Go back to the Case Review screen.
- [ ] Look for a **"Run Replay"** or **"Audit Replay"** button.
- [ ] Click it.
- [ ] Wait for the replay to finish.

> **You should see:** A list of replay check results. Each check shows:
> - The rule that was checked
> - Whether it passed or failed
> - The fact value that was used
> - The threshold it was compared against

- [ ] Compare the replay results to the original decision receipt from Step 6.

> **The replay results should match the original decision.** If they do not match, write down what is different.

> **Behind the scenes:** ReplayService assembles the case data (Audit_Case__c → Borrower_Snapshot__c → Evidence_Item__c), adapts Policy_Rule__c records into in-memory Policy_Rule_Version__c objects, runs the same PolicyRuleEvaluator kernel, and commits Replay_Check__c records via ReplayCommitService. All from stored data — no access to the original session.

---

## Step 8: Sign Off (Optional — Completes the Loop)

If the decision looks correct, you can sign off on it.

- [ ] Look for a **"Sign Off"** or **"Approve"** button.
- [ ] Click it.
- [ ] If asked, type a comment or reason for your sign-off.
- [ ] Confirm.

> **You should see:** The case status changes to **"Signed Off"** or **"Completed"**.

---

## Test Complete

You have taken a loan application from intake to a signed decision. Every fact in that decision can be traced back to a specific document and a specific policy version.

### What You Should Have Seen

| Step | What Happened | Record Created |
|------|---------------|----------------|
| Step 4 | Document uploaded | `Evidence__c` |
| Step 5 | Decision run | `Decision_Event__c` |
| Step 6 | Receipt viewed | PDF/printable document |
| Step 7 | Audit Replay run | `Replay_Check__c` records |
| Step 8 | Sign-off (optional) | Status change |

### Known Notes

1. **"Veridact" labels everywhere.** The org still says "Veridact Audit" and "Veridact Analytics." The real product name is **CaseFile** (decided in ADR-30 on 2026-07-03). The org labels have not been updated yet. This is a cosmetic mismatch only — it does not affect how the system works.

2. **No platform events.** The system runs on the synchronous path only. There is no `Intake_Received__e` event. This is deferred behind ADR-33 OQ-3 and does not block the beta test.

3. **No Allura Brain wiring.** The system does not write to Allura Brain during this flow. Allura Brain is used for development orchestration only (ADR-17). See SC-2b-brain-wiring-finding.md for details.

4. **Three policy objects.** The system uses `Policy_Rule__c`, `Policy_Version__c`, and `Policy_Rule_Version__c`. The replay path uses the normalized pair (`Policy_Rule__c` + `Policy_Version__c`) and adapts them in memory. This is a documented design (ADR-18), not drift.

---

**Script written:** 2026-08-03
**Cross-ref:** GOAL-G2-beta-readiness.md (SC-8), ADR-17, ADR-30, ADR-33
