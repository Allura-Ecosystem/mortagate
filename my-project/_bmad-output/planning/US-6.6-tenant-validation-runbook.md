# US-6.6 — Tenant-Side Package Validation Runbook

**Status:** Ready for Sabir · **Date:** 2026-08-28 · **Owner:** Sabir
**Why this can't be agent-run:** Requires an interactive Microsoft 365 sign-in on a
Frontier-enabled Copilot tenant with a licensed user. Brooks cannot authenticate as a
human tenant admin — this is the US-6.6 hard gate (per `GOAL-G3-cowork-pilot-readiness.md`
and the EP-6 story ACs).

**Prerequisites (from the COWORK PRD §6 "Constraints and Guardrails"):**
- [ ] Frontier-enabled Microsoft 365 Copilot tenant (Cowork is a Frontier preview)
- [ ] A licensed user with Copilot for Microsoft 365
- [ ] The built package: the merged `microsoft-cowork/` on `main` (or a built ZIP via
      `microsoft-cowork/scripts/validate_package.py` → the M365 Agents Toolkit build)

---

## Step 1 — Build the package (5 min)

From the repo root (main branch):

```bash
cd microsoft-cowork
python3 scripts/validate_package.py      # offline structural check (PASS expected)
# then build the ZIP with the M365 Agents Toolkit:
#   VS Code → Microsoft 365 Agents Toolkit → Package
# (or `m365agents` CLI if configured)
```

Expected: `appPackage/` contents zipped, no manifest/permission errors.
The offline validator must exit 0 **before** any tenant work.

## Step 2 — Upload the package (10 min)

1. Open [Microsoft 365 admin center](https://admin.microsoft.com) as tenant admin
2. **Teams admin center → Teams apps → Manage apps → Upload new app** (or the
   equivalent Copilot Cowork upload path for your tenant build)
3. Upload the built ZIP from Step 1
4. **Record the exact result** — success screen, any manifest errors, permission
   prompts. Per the US-6.6 AC: "Any validation failure is recorded with the exact
   error, not summarised."

## Step 3 — Verify the four skills are invocable (15 min)

In Microsoft Copilot **Cowork**, as the licensed pilot user:

| Skill | Trigger phrase to test | Expected |
|---|---|---|
| Mortgage case onboarding | “Start an evidence review for this file” (attach the synthetic incomplete file) | Intake card: Review purpose / Files available / Missing inputs / Next safe action (**CW-1, CW-2**) |
| Loan file evidence review | “What documents are missing?” | The 3 planted gaps reported as `missing`; nothing fabricated (**CW-5**) |
| Policy replay review | “Compare the supplied policy replay results” (attach the synthetic replay from `pilot-fixtures/README.md`, if you also draft one) | Comparison table; explicit non-decision language (**CW-9..12**) |
| Audit packet draft | “Prepare an audit packet for my reviewer” | `DRAFT — HUMAN REVIEW REQUIRED` header; cited findings (**CW-13..15**) |

If a skill does not appear or won't invoke, **record the exact error** and paste it
back here / into the session — the fix is then a repo change, not a re-run.

## Step 4 — Record the outcome

Paste the validation result into the pilot-feedback doc (see
`US-6.4-pilot-decisions-brief.md`, Decision 3 template) or reply in the session:

```markdown
**US-6.6 result:**
- Tenant: <name>
- Upload: PASS / FAIL <exact error>
- Skills visible: all 4 / <which missing>
- Skills invocable: all 4 / <which failed>
- Manifest/permission warnings: <none / exact text>
```

**Gate closes when:** all four skills appear **and** are invocable, with zero manifest
or permission errors, and the result is recorded verbatim. Then US-6.7 (private pilot
upload with the `pilot-fixtures/` pack) is unblocked.

---

## If something breaks

- **Manifest error on upload:** paste it verbatim — it maps straight to a fix in
  `microsoft-cowork/appPackage/manifest.json` (the repo already has CI: "Validate agent
  definitions" + "Validate Salesforce metadata" run on every PR, so a manifest failure
  here is likely tenant-version-specific).
- **Skill not invocable:** check the license is Copilot for M365 + Frontier preview and
  the user is in the allowed group (Decision 1 from `US-6.4-pilot-decisions-brief.md`).
- **Anything else:** do not guess — record the exact behavior and the loop resumes from
  the evidence.
