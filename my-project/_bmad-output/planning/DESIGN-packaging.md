# DESIGN-packaging — Managed-Package (2GP) Readiness Spike

> **AI-Assisted Documentation** — This document was drafted by an AI agent
> (Hightower / DevOps persona, Team RAM) as a **report-only** readiness spike.
> No package was published; no 2GP package or version was created against the
> DevHub namespace. Evidence is cited as `file:line` or command output.
> Carlos Guidelines apply. Loop item #10, 2026-07-03.

---

## 0. Scope & Verdict

**Goal:** enumerate, with evidence, everything between this repo
(`feat/veridact-v1-demo`, org `mortagate-de`) and an AppExchange-ready
**2GP managed package**. Product frame: Path A / ADR-17 (all-Salesforce, single
trust boundary; the ~$2,700 AppExchange security review is the pilot gate) and
ADR-23 (Agentforce metadata portability limits).

**Verdict:** the *core* app (19 SObjects, 128 Apex classes, 66 LWC, 12 triggers,
flexipages/tabs/pages/permsets/staticresources) is **packageable with modest
remediation**. The **Agentforce layer is not packageable as-is** and must ship
**excluded-with-runbook + post-install rebind** (ADR-23/25). Two hard human
gates remain: **namespace registration** (irreversible) and the **security
review**. No InstallHandler exists yet — the post-install automation surface is
**greenfield**.

---

## 1. `sfdx-project.json` Readiness

Current file (evidence: `sfdx-project.json`):

```json
{
  "packageDirectories": [ { "path": "force-app", "default": true } ],
  "namespace": "",
  "sfdcLoginUrl": "https://login.salesforce.com",
  "oauthLocalPort": 1919,
  "sourceApiVersion": "66.0",
  "packageAliases": {}
}
```

| Attribute | State | 2GP requirement | Delta |
|---|---|---|---|
| `packageDirectories` | single `force-app`, default | A package dir must carry `package`, `versionName`, `versionNumber` after `sf package create` | Needs a **named package entry** written back |
| `namespace` | **empty string** | Managed 2GP **requires a registered namespace linked to the DevHub** | **BLOCKED-HUMAN** — see §7 blocker #1 |
| `packageAliases` | `{}` | Populated by `sf package create` with the `0Ho…` package Id | Empty — no package exists |
| `sourceApiVersion` | 66.0 | Org runs 67.0 (evidence: `sf org display` → `"apiVersion":"67.0"`) | Minor drift; bump at packaging time |

**DevHub status (report only, evidence: `sf org list --json`, `sf org display`):**
`mortagate-de` → `"isDevHub": true`, org Id `00DgL00000SseMyUAJ`,
instance `orgfarm-156cb47730-dev-ed`, `connectedStatus: Connected`.
DevHub is present and API-reachable. **Second-Generation Packaging is enabled by
default on modern DevHubs**, but **no namespace is linked** and **no package
entries exist**. `isDefaultDevHubUsername: false` — the alias is not the default
DevHub, so packaging commands must pass `--target-dev-hub mortagate-de`.

**What `sf package create --package-type Managed` would require here:**

```bash
# NOT RUN — creates an org-side Package2 (0Ho…) record in the DevHub and
# requires a namespace already linked. Documented per spike constraints.
sf package create \
  --name "Veridact Mortgage Audit" \
  --package-type Managed \
  --path force-app \
  --target-dev-hub mortagate-de
```

- **Why not run:** this command is **not** a dry-run. It writes a persistent
  `0Ho…` Package2 container record into the DevHub org (org-side state) and, for
  `--package-type Managed`, **fails outright unless a namespace is registered and
  linked** to the DevHub. Both conditions violate the "creates nothing org-side"
  bar, so it is documented, not executed.
- **Preconditions before it can succeed:** (1) register a namespace in a
  Namespace Registry org; (2) link that org to `mortagate-de` via *Setup → Package
  Manager / Namespace Registries*; (3) set `"namespace": "<ns>"` in
  `sfdx-project.json`. Only then does `sf package create` succeed and populate
  `packageAliases`. `sf package version create` (which *does* build an artifact)
  is a separate, later step and remains **BLOCKED-HUMAN** for this spike.

---

## 2. Namespace Audit (constructs that break under a namespace)

When a managed namespace `ns` is applied, every custom object/field API name
becomes `ns__Object__c` / `ns__Field__c` at runtime. String-literal references
that are **not** resolved by the Apex/LWC compiler break. Hit list:

| # | File:line | Construct | Risk | Action |
|---|---|---|---|---|
| N-1 | `force-app/main/default/lwc/auditQueue/auditQueue.js:109` | `attributes: { objectApiName: 'Audit_Case__c', actionName: 'new' }` | **HIGH** — NavigationMixin resolves the literal against the runtime name `ns__Audit_Case__c`; the unqualified literal will not resolve in-package | Replace with `@salesforce/schema` import or namespace-aware token |
| N-2 | `force-app/main/default/lwc/auditQueue/auditQueue.js:116` | `attributes: { recordId, objectApiName: 'Audit_Case__c', actionName: 'view' }` | **HIGH** — same as N-1 | Same fix |
| N-3 | `force-app/main/default/classes/AuditSoql.cls:38` | `Database.queryWithBinds(soql, …, USER_MODE)` with caller-supplied SOQL | **LOW** — dynamic SOQL inside a namespaced Apex class resolves unqualified object/field names to the **local** namespace automatically; safe *provided* callers never hardcode a foreign namespace | Audit each caller's `SELECT/FROM` string; keep names unqualified |

**Systemic finding:** `grep '@salesforce/schema' lwc` → **0 hits**. The LWC layer
does **not** use the namespace-safe schema-import pattern anywhere. This is the
single highest-leverage remediation: importing object/field references via
`@salesforce/schema/Audit_Case__c` makes them compiler-resolved and
namespace-transparent, and eliminates N-1/N-2 by construction.

**Clean signals (evidence):**
- Hardcoded 15/18-char Ids in Apex (`classes`, `triggers`): **0 hits**.
- Hardcoded `https://` URLs, `callout:`, `NamedCredential`, secrets/keys in
  Apex: **0 hits**.

---

## 3. Metadata Packageability Sweep

Per-type disposition. Counts from `force-app/main/default/`.

| Component (count) | Packageable? | Evidence | Action |
|---|---|---|---|
| `objects/` (19 SObjects, 239 files) | **Yes** | core schema | Ship in package |
| `classes/` (128) | **Yes** | Apex, no hardcoded Ids/secrets | Ship; API bump to 67 |
| `triggers/` (12) | **Yes** | thin triggers | Ship |
| `lwc/` (66) | **Yes, after N-1/N-2 fix** | §2 | Fix nav literals, then ship |
| `flexipages/`, `tabs/` (7), `pages/` (4), `applications/` (1), `staticresources/` (2) | **Yes** | standard UI metadata | Ship |
| `permissionsets/` (2: `Veridact_Mortgage_Engine_Access`, `Veridact_KYC_Officer_Access`) | **Yes (definition)** | assignment is runtime, not metadata | Ship def; **assignment = post-install/admin** |
| `customMetadata/` (2: `Adverse_Action_Config.Default`, `PreFlight_Assumption.Default`) | **Yes (records ship in 2GP)** | `xmlns:xsd` fix present on both (evidence: grep) | Ship; note redeploy-to-same-org throws `UNKNOWN_EXCEPTION` (fresh-install target unaffected) |
| `genAiFunctions/` (6 fns, 18 files) | **Probably** — clean names (`Diagnose_Loan_Audit`, `Draft_Finding_Text`, …) | no org-id prefixes | Validate Apex/action bindings resolve under namespace |
| `genAiPlugins/` (6) | **No, as-is** | names carry org-Id prefix `p_16jgL000001liY5_…`, `p_16jgL000001lj7Z_…`, `p_16jgL000001ljKT_…` (evidence: `ls genAiPlugins`) | **Exclude**; regenerate against target org post-install |
| `genAiPlannerBundles/` (5, incl. stock `EmployeeCopilotPlanner`) | **No** | retrieve-broken; "Cannot update record as Agent is Active"; `EmployeeCopilotPlanner*` .forceignore-quarantined | **Exclude-with-runbook** (ADR-23) |
| `bots/` (4: CLI, Copilot_v4, Employee, Internal) | **No** | `<botUser>` embeds org Id — `veridact_auditor_employee@00dgl00000ssemy1855459510.ext` etc. (evidence: `bots/*/*.bot-meta.xml:11`); missing `PlannerId` (DEPLOY-REPORT §2) | **Exclude-with-runbook**; post-install rebind per target org (ADR-23) |
| `aiEvaluationDefinitions/` (1: `Veridact_Auditor_Copilot_v4_RuntimeSelection`) | **No** | Testing-API-only; no authorable version XML; both deploy & `agent test create` fail "…at least one evaluation definition version exist" (evidence: `.forceignore`, ADR-25) | **Exclude**; runnable via `sf agent test run-eval --spec specs/…testSpec.yaml` |
| CronTrigger / `SecondPassSweepBatch` schedule | **No — runtime state, not metadata** | `SecondPassSweepBatch.cls:60` `implements Schedulable`; `System.schedule` at `:221` | **Post-install script** must schedule it |

**.forceignore quarantines (evidence: `.forceignore`)** already exclude
`EmployeeCopilotPlanner*` (planner+bot) and
`aiEvaluationDefinitions/Veridact_Auditor_Copilot_v4_RuntimeSelection*`. The
packaging exclusion set must **extend** this to all 4 custom bots, all custom
planner bundles, and all 6 org-Id-prefixed genAiPlugins.

---

## 4. Post-Install Surface (runbook draft)

**Finding: no `InstallHandler`/`UninstallHandler` Apex class exists**
(evidence: `grep InstallHandler classes` → NONE). The post-install automation is
greenfield. A 2GP managed package should ship a post-install Apex script; the
remainder are admin-manual steps a setup wizard/README must cover.

**Automatable (post-install Apex `InstallHandler`):**
1. **Schedule `SecondPassSweepBatch`** — `System.schedule('Veridact Second Pass - Nightly', <cron>, new SecondPassSweepBatch())` (the class is `System.schedule`-ready; helper at `SecondPassSweepBatch.cls:221`).
2. **Seed CMDT** *only if* the 2 CustomMetadata records are excluded from the package (they are shippable, so this is a fallback).
3. **Assign permission sets to the installing admin** (broad user assignment stays a manual/admin task).

**Admin-manual (cannot be scripted — wizard/README + runbook):**
4. **Deployment Settings toggle** — "Allow deployments of components when
   corresponding Apex jobs are pending" is a **Setup-UI org setting, not in
   `ApexSettings` metadata** (evidence: gates `p2-002` notes). Not committable.
5. **Enable Einstein / Agentforce** platform prefs (admin, per ADR-23 notes).
6. **Agentforce rebind** (ADR-23 runbook): recreate/rebind the 4 bots + planner
   bundles against the target org (new `botUser` ext users, new `PlannerId`,
   regenerated `p_<orgfrag>_…` genAiPlugin names), then **activate** the default
   agent (last-mile is Setup-UI-only per MEMORY: internal-copilot enablement).
7. **AI eval version** — create server-side via Testing Center / `sf agent test`.

---

## 5. Security-Review Checklist Deltas (pilot gate, ~$2,700)

| Item | Posture | Evidence | Reviewer note |
|---|---|---|---|
| CRUD/FLS enforcement | **Strong, broad** | `WITH USER_MODE` / `AccessLevel.USER_MODE` = **42 hits** in `classes`; `AuditSoql` enforces USER_MODE + bound binds + sort allowlist (`AuditSoql.cls:24-58`) | Lead with this |
| SOQL injection surface | **Closed** | `AuditSoql` uses `Database.queryWithBinds` only; no string concatenation | — |
| **Deliberate system-mode read/write** | **2 documented paths** | (a) `AuditEventService.logEvents` uses plain `insert events` — **system-mode DML** for the append-only audit log (`AuditEventService.cls:53-64`); (b) `IdentityGateService` sanctions-screening read (`IdentityGateService.cls`) | **Write explicit justification** — reviewer *will* ask why these bypass USER_MODE. Both classes are `with sharing`; the audit-log insert is intentionally system-mode so an auditor's FLS can't suppress an immutable event. |
| Hardcoded Ids | **None** | grep §2 → 0 | — |
| Secrets / endpoints | **None** | grep §3 → 0 | — |
| Accessibility (a11y) | **Plus** | `jest.setup.a11y.js`, `jest.config.js`, sa11y wired | Cite as quality signal |
| CustomMetadata redeploy | **Watch** | `UNKNOWN_EXCEPTION` on same-org redeploy (DEPLOY-REPORT §1) | Fresh install unaffected; note in known-issues |

---

## 6. Phased Recommendation

**Now (pre-namespace, in-repo — no org/human gate):**
- Fix N-1/N-2: replace hardcoded `objectApiName: 'Audit_Case__c'` in
  `auditQueue.js` with `@salesforce/schema` imports; adopt the schema-import
  pattern across LWC.
- Author the `InstallHandler` Apex (schedule `SecondPassSweepBatch`; assign
  permsets to admin) + PNB tests.
- Write the "deliberate system-mode" justification block into
  `RISKS-AND-DECISIONS.md` for §5(a)/(b).
- Audit every `AuditSoql` caller's `SELECT/FROM` string for foreign-namespace
  qualifiers.
- Define the packaging `.forceignore` / exclusion set (all custom bots, all
  planner bundles, all `p_<orgfrag>_` genAiPlugins, the AiEvalDef).

**At pilot-gate (human-authorized, org-side):**
- Register + link a namespace to a DevHub; set `sfdx-project.json.namespace`;
  bump `sourceApiVersion` to 67.
- `sf package create --package-type Managed` (writes `0Ho…` + aliases), then
  `sf package version create` against the core (Agentforce-excluded) source.
- Run a security scanner (Checkmarx/PMD AppExchange ruleset); submit the
  ~$2,700 AppExchange security review.

**At listing:**
- Finalize the ADR-23 Agentforce rebind runbook as an install wizard.
- Partner Business Org + AppExchange listing metadata; uninstall handler.

---

## 7. Top-5 Blockers (ranked)

1. **No namespace linked to DevHub** (`sfdx-project.json.namespace: ""`; DevHub
   has no registered namespace). Managed 2GP is impossible until this
   irreversible human decision is made. **BLOCKED-HUMAN.**
2. **Agentforce layer not packageable** — bots carry org-Id `botUser` bindings +
   missing `PlannerId`; genAiPlugins carry org-Id-prefixed developer names;
   planner bundles retrieve-broken/active; AiEvalDef is Testing-API-only.
   Requires exclude + post-install rebind runbook (ADR-23/25).
3. **No InstallHandler / post-install automation exists** — the nightly
   `SecondPassSweepBatch` schedule, permset assignment, and CMDT seeding are
   unautomated; the schedule is runtime state that no package carries.
4. **Namespace-breaking LWC literals** — `auditQueue.js:109,116` hardcode
   `Audit_Case__c`; **zero** `@salesforce/schema` adoption across 66 LWCs.
5. **Security-review CRUD/FLS deltas** — two deliberate system-mode paths
   (`AuditEventService.logEvents` insert, `IdentityGateService` sanctions read)
   need written justification; plus non-committable org dependencies (Deployment
   Settings toggle, Einstein/Agentforce enablement) must be documented as manual
   install steps.

---

*Cross-refs: ADR-17 (Path A), ADR-23 (Agentforce portability), ADR-25 (AiEval
Testing-API), `DEPLOY-REPORT.md`, `mortagate.gates.json` (p2-002), `.forceignore`.*
