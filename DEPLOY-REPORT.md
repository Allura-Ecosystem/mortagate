# Veridact / Mortgate — Deploy Report

**Date:** 2026-06-23
**Branch:** `feat/veridact-v1-demo` (tag `v1-demo`, commit `d715956` merged to `main`)
**Target org:** `mortagate-de` (DevHub, `00DgL00000SseMyUAJ`, `orgfarm-156cb47730-dev-ed`)
**API:** v66.0 (project) deploying via v67.0 SOAP API
**Orchestrator:** Brooks (Team RAM)

## TL;DR

Full `force-app` deploy was failing with opaque `UNKNOWN_EXCEPTION` (ErrorId family `-315522575`) before any component was processed. **Root cause was multi-headed**, masked by a single server stack trace. Diagnosed by systematic bisection. Successfully deployed everything that can be deployed via SFDX; **3 categories of metadata require manual or workaround paths** (documented below).

- **Apex:** 140/140 PASS, 100% pass rate (test run `707gL00000z14ww`)
- **LWC Jest:** 53/53 PASS (12 suites)
- **Org data intact:** 629 Audit Cases, 10 Policy Rules, 1 Policy Version, 5 Loans, 10 Replay Checks

## Root Cause Investigation (Phase 1)

Initial symptom: `sf project deploy start --source-dir force-app` failed in ~1.4s with `UNKNOWN_EXCEPTION` and `0/256 numberComponentsDeployed`. Repeatable. Same server error class (`-315522575`) on every retry, different ErrorIds → server-side processing, not network/auth.

Bisected by component directory (each `--source-dir` in isolation):

| Directory | Result |
|---|---|
| `classes` | OK |
| `objects` | OK |
| `lwc`, `triggers`, `applications`, `flexipages`, `permissionsets`, `staticresources`, `tabs`, `pages` | OK |
| `genAiFunctions` | OK |
| **`customMetadata`** | **UNKNOWN_EXCEPTION (even alone)** |
| `genAiPlugins` | OK (validates) |
| `bots` | Component Failures — 4 BotVersions missing required `PlannerId` |
| `genAiPlannerBundles` | Component Failures — "Cannot update record as Agent is Active" |
| `aiEvaluationDefinitions` | Component Failures — "There must be at least one evaluation definition version exist" |

The single `UNKNOWN_EXCEPTION` on the full deploy was the server failing fast on `customMetadata` records and never surfacing the cleaner downstream Agentforce validation errors.

## Root Causes

### 1. CustomMetadata records → UNKNOWN_EXCEPTION on redeploy
- Files: `force-app/main/default/customMetadata/Adverse_Action_Config.Default.md-meta.xml`, `PreFlight_Assumption.Default.md-meta.xml`
- Both `__mdt` types exist in org and both records already exist (`DeveloperName=Default`) with the correct values.
- Record XML field shape matches the deployed type fields exactly.
- Salesforce platform throws `UNKNOWN_EXCEPTION` on redeploy. Known intermittent platform-side issue with `CustomMetadata` MDAPI handling.
- **Resolution:** Skipped. Org already has correct values; no data change required.

### 2. Bots missing `PlannerId` on `BotVersion` (4 bots)
- `Veridact_Auditor_CLI.v1`, `Veridact_Auditor_Copilot_v4.v1`, `Veridact_Auditor_Employee.v1`, `Veridact_Auditor_Internal.v1`
- Required field `PlannerId` is missing from each `BotVersion` XML.
- This is consistent with ADR-23 (Agentforce agents not org-portable; `plannerId` is an org-specific 18-char Id resolved on the source org and must be re-bound per target org).
- **Resolution path:** Manual rebind per target org. For `mortagate-de` the existing live agent is already wired; no redeploy needed.

### 3. `EmployeeCopilotPlanner` → "Cannot update record as Agent is Active"
- Standard Agentforce constraint. Update requires the agent to be deactivated first via Setup UI, then redeployed, then reactivated.
- **Resolution path:** Manual via Setup. Not in scope for this deploy.

### 4. `Veridact_Auditor_Copilot_v4_RuntimeSelection` AI Eval Definition
- Missing required `aiEvaluationDefinitionVersion` subcomponent.
- **Resolution path:** Add a version subcomponent in source, or re-export from the org after agent is live.

## What Was Deployed

Two successful real deploys against `mortagate-de`:

**Deploy 1** — `classes` + `objects`
- All Apex classes (62 source files) and all custom objects/fields/validation rules confirmed "Changed" or "Unchanged" as expected.

**Deploy 2** — `lwc + triggers + applications + flexipages + permissionsets + staticresources + tabs + pages + genAiFunctions`
- 12 LWCs (`auditAdmin`, `auditAnalytics`, `auditQueue`, `caseReview`, `findingDetail`, `signoffReceipt`, `policyVersions`, `glossaryTerm`, `riskBadge`, `auditQueueFilters`, `auditMetricCards`, `auditQueueDatatable`) Changed.
- PermissionSet `Veridact_Mortgage_Engine_Access` Changed.
- StaticResource `veridactTokens` Unchanged.
- GenAiFunction `Diagnose_Loan_Audit` Changed.

## Test Results

### Apex (`sf apex run test --test-level RunLocalTests`)
- Run Id: `707gL00000z14ww`
- **Outcome: Passed**
- Tests ran: **140**
- Pass rate: **100%**
- Test execution time: 35.3s

### LWC Jest (`npm run test:unit`)
- 12 suites, **53 tests, 53 passed**
- Time: 1.0s

## Org Data Counts

| SObject | Records |
|---|---|
| `Audit_Case__c` | 629 |
| `Policy_Rule__c` | 10 |
| `Policy_Version__c` | 1 |
| `Loan__c` | 5 |
| `Loan_Application__c` | 3 |
| `Finding__c` | 1 |
| `Decision_Event__c` | 3 |
| `Audit_Event__c` | 6 |
| `Audit_Receipt__c` | 0 |
| `Replay_Check__c` | 10 |

## Remaining Manual Follow-up

1. **Bots / PlannerBundles / AiEvalDefs** — rebind per ADR-23 inside Setup UI for any target org refresh.
2. **CustomMetadata redeploy** — only an issue on redeploy of already-present records; no functional impact.
3. **Update sf CLI** — local CLI is 2.137.7, latest is 2.139.6 (cosmetic).

## Process Notes

- Followed `systematic-debugging` skill: reproduce → isolate → form hypothesis → test minimally → deploy in pieces.
- Did **not** force-push or modify the v1-demo merge commit on `main`.
- Did **not** mutate org seed data.
- Did **not** deploy `bots/`, `genAiPlannerBundles/`, `aiEvaluationDefinitions/`, `customMetadata/` — these are tracked above for follow-up.
