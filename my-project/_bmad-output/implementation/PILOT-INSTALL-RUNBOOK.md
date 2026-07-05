# CaseFile — Pilot Install Runbook

> How to stand up the **CaseFile** post-close mortgage-audit app in a fresh
> Salesforce **sandbox / scratch / Developer Edition** org from the built
> unlocked package. Pilot scope only — see §0.
>
> Owner: Sabir. Prepared by Brooks (Team RAM), 2026-07-05. Carlos Guidelines apply.
> Source of truth for packageability: `DESIGN-packaging.md`; for governance
> gates: `planning docs/RISKS-AND-DECISIONS.md`.

---

## 0. Scope & preconditions

- **This installs the pilot build**, package version **CaseFile 0.1.0.1**,
  SubscriberPackageVersionId **`04tgL000000IMEzQAO`** (unlocked, **no namespace**).
- The version is **`ValidationSkipped: true` / `IsReleased: false`** → installable
  in **scratch / sandbox / Developer Edition only**, **not production**. A
  validated, released build is required before any production install (that build
  runs install-and-test at ≥75% coverage and is where the Agentforce org-Id
  bindings get exercised — see §5).
- **Pilot runs on demo data only** — no real applicants, no real SSNs, no
  delivered adverse-action notices. Under that scope R-7 (counsel) and R-8
  (compliance/vault) raise **no obligation** (RISKS-AND-DECISIONS.md, R-7/R-8 rows).
  Do **not** put real borrower data in a pilot org — that would trip the
  production gates that are deliberately still held.
- Prereqs on the workstation: `sf` CLI ≥ 2.137, authenticated access to the
  target org, this repo checked out (for the post-install scripts + specs).

---

## 1. Install the package

Target a sandbox/DE org aliased `casefile-pilot` (substitute your alias).

```bash
# Unlocked, no install key
sf package install \
  --package 04tgL000000IMEzQAO \
  --target-org casefile-pilot \
  --wait 20 --publish-wait 20 \
  --security-type AdminsOnly

# Verify
sf package installed list --target-org casefile-pilot
```

If installing by version alias from this repo instead of the raw Id:
`--package "CaseFile@0.1.0-1"` (resolves via `sfdx-project.json` `packageAliases`).

---

## 2. Post-install steps (manual — no InstallHandler ships yet)

The package carries **definitions**; runtime wiring is manual for the pilot
(the `InstallHandler` is greenfield — DESIGN-packaging.md §4). Do these in order.

1. **Assign permission sets** (assignment is runtime, not packaged):
   ```bash
   sf org assign permset --name Veridact_Mortgage_Engine_Access --target-org casefile-pilot
   # KYC officer access is need-to-know — assign only to designated users:
   # sf org assign permset --name Veridact_KYC_Officer_Access --target-org casefile-pilot
   ```

2. **Schedule the nightly Second-Pass sweep** (runtime state, not metadata —
   `SecondPassSweepBatch` is `Schedulable`, helper at `SecondPassSweepBatch.cls:221`):
   ```bash
   sf apex run --target-org casefile-pilot \
     --file scripts/run-second-pass.apex
   # or schedule directly:
   echo "SecondPassSweepBatch.schedule('CaseFile Second Pass - Nightly','0 0 2 * * ?');" \
     | sf apex run --target-org casefile-pilot
   ```

3. **Deployment Settings toggle** (Setup-UI only, one-time; needed if you later
   deploy over the org while the batch is scheduled / a bot is Active):
   Setup → **Deployment Settings** → enable **"Allow deployments of components
   when corresponding Apex jobs are pending or in progress."**

4. **Seed demo data** (golden dataset — the pilot's cases/loans/policies):
   Load the committed demo artifacts under `my-project/_bmad-output/implementation/`.
   **Never run `seed-data.apex`** against an org that already has data — it creates
   600+ junk cases (project hard rule). Use the idempotent loaders instead.

---

## 3. Agentforce copilot (optional for pilot — the app works without it)

The 6-screen auditor app (Queue · Case Review · Sign-off · Finding · Analytics ·
Policy Versions) is fully functional **without** the copilot. The conversational
copilot layer is **excluded from the package** by design (org-Id bindings don't
travel — ADR-23): bots carry org-specific `<botUser>`, genAiPlugins carry org-Id
developer-name prefixes, planner bundles are retrieve-broken.

To enable the copilot in the pilot org (manual, per ADR-23 rebind runbook):

1. Setup → enable **Einstein / Agentforce** platform prefs.
2. Recreate the agent against the target org (fresh `botUser` = an in-org
   `EinsteinServiceAgent` user; the R-10 pattern in RISKS-AND-DECISIONS.md).
3. Author the 6 GenAiFunction bundles' topic bindings in Agent Builder
   (attach-time snapshots the I/O schema — re-add after any schema change; the
   decisive "bundle needs input/output schema.json" doctrine from loop item #1).
4. Verify with the headless eval:
   ```bash
   sf agent test run-eval --spec specs/Veridact_Auditor_Copilot_v4-testSpec.yaml \
     --target-org casefile-pilot
   ```

---

## 4. Smoke test (pilot acceptance)

- App launcher → **CaseFile** app → **Audit Queue** loads with demo cases.
- Open the hero case → **Case Review** shows the DTI violation + missing trailing
  docs; **Sign-off** receipt renders.
- Confirm the nightly sweep is scheduled: Setup → **Scheduled Jobs** →
  "CaseFile Second Pass - Nightly" present.
- (If copilot enabled) ask *"What evidence is missing for audit case &lt;id&gt;?"* →
  a governed action fires and writes an `Agent_Action_Log__c` row (ledger is the
  only verification truth).

---

## 5. Path to production (NOT part of the pilot)

Held gates — each needs an accountable human, deliberately not delegated:

1. **Validated/released package build** — `sf package version create` **without**
   `--skip-validation`, then `sf package version promote`. Runs install-and-test
   (≥75% coverage) and is where the excluded Agentforce metadata must be resolved
   (exclude-with-rebind, DESIGN-packaging.md §2/§7 blocker #2).
2. **R-7 — counsel signature** on adverse-action wording before any real notice
   is delivered (R7-ADVERSE-ACTION-SIGNOFF-PACKET.md is the 10-minute review packet).
3. **R-8 — compliance/security sign-offs** + external tokenization vault +
   token encryption before any real SSN is handled (R8-DECISION-MEMO.md;
   backlog rows R8-1-a…R8-7-c).
4. **Managed 2GP + namespace** — only if AppExchange distribution is pursued;
   register `casefile` in a fresh DE org (created on a non-blocked device), then
   `sf org login device` + DevHub link (ADR-30).
5. **AppExchange security review** (~$2,700 pilot gate, ADR-17).

---

*Cross-refs: `DESIGN-packaging.md`, `RISKS-AND-DECISIONS.md` (ADR-30, R-7, R-8,
Confidence Caps), `sfdx-project.json` (`packageAliases.CaseFile`),
`specs/Veridact_Auditor_Copilot_v4-testSpec.yaml`.*
