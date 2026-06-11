---
name: sf-deploy
description: "Salesforce DevOps for Mortgate. sf CLI commands, org auth (mortgate-de), scratch orgs, metadata deploy, mortgate.gates.json execution, and CI gate receipts. Load when deploying, validating gates, or setting up Salesforce org access in the Mortgage project."
---

# sf-deploy — Salesforce DevOps for Mortgate

This skill is the gateway to all Salesforce CLI operations for the **Mortgage Approval Engine** project.

> **AI-Assisted Documentation**
> Portions of this skill were drafted with AI assistance.

---

## When to Use This Skill

Load this skill whenever:

- Authenticating to a Salesforce org
- Deploying metadata via `sf project deploy`
- Running `mortgate.gates.json` checks
- Setting up a scratch org
- Validating a deploy package
- Reviewing CI gate receipts

---

## Org Authentication

**Production / Dev org:**

```bash
sf org login web --alias mortgate-de --set-default
sf org display --target-org mortgate-de
```

**Sandbox org:**

```bash
sf org login web --alias mortgate-de --instance-url https://test.salesforce.com --set-default
```

**Scratch org (for development):**

```bash
sf org create scratch --definition-file config/project-scratch-def.json --alias mortgate-scratch --duration-days 30
sf org display --target-org mortgate-scratch
```

---

## Deploy Commands

**Deploy to default org:**

```bash
sf project deploy start --source-dir force-app
```

**Deploy specific metadata:**

```bash
sf project deploy start --metadata ApexClass:IntentController --target-org mortgate-de
```

**Quick deploy (when a validation has already passed):**

```bash
sf project deploy start --validated-deploy-request-id <id> --target-org mortgate-de
```

**Validate only (no deploy):**

```bash
sf project deploy validate --source-dir force-app --target-org mortgate-de
```

---

## Retrieve Commands

**Pull metadata from org:**

```bash
sf project retrieve start --metadata ApexClass --target-org mortgate-de
```

**Pull specific package:**

```bash
sf project retrieve start --package-name "Mortgate v1" --target-org mortgate-de
```

---

## Gate Execution (`mortgate.gates.json`)

`mortgate.gates.json` defines phase-0 → phase-2 gate checks. **Do not claim gate completion** until these commands pass against `mortgate-de`.

**Read the gate file first:**

```bash
cat mortgate.gates.json
```

**Typical gates to expect:**

| Phase | Gate | Command |
|---|---|---|
| 0 | Org auth | `sf org display --target-org mortgate-de` |
| 0 | Metadata compile | `sf project deploy validate --source-dir force-app` |
| 1 | Apex tests | `sf apex run test --code-coverage --result-format human` |
| 1 | Flow tests | `sf flow run test --test-name <Flow_Test_Name>` |
| 2 | Bulk test (200+ records) | Custom script in `scripts/bulk-test.sh` |

**Receipt format:**

```json
{
  "phase": 0,
  "gate": "metadata-compile",
  "command": "sf project deploy validate --source-dir force-app",
  "exit_code": 0,
  "duration_ms": 12345,
  "timestamp": "2026-04-05T10:30:00Z",
  "org": "mortgate-de"
}
```

---

## Test Execution

**Run all Apex tests:**

```bash
sf apex run test --code-coverage --result-format human --target-org mortgate-de
```

**Run specific test class:**

```bash
sf apex run test --class-names IntentControllerTest --result-format human --target-org mortgate-de
```

**Run LWC jest tests:**

```bash
npm test
# or for a specific LWC:
npm test -- --testPathPattern=c-welcome-gate
```

---

## Data Operations

**Bulk insert (mortgate.gates.json phase-2):**

```bash
sf data bulk import --sobjecttype Application__c --file data/bulk-test-200.csv --target-org mortgate-de
```

**Query (SOQL):**

```bash
sf data query --query "SELECT Id, Name FROM Application__c LIMIT 10" --target-org mortgate-de
```

---

## Common Pitfalls

| Symptom | Likely Cause | Fix |
|---|---|---|
| `INVALID_LOGIN` | Org not authenticated | `sf org login web --alias mortgate-de` |
| `INSUFFICIENT_ACCESS_OR_READONLY` | Profile lacks permission | Update profile or run as admin |
| `DUPLICATES_DETECTED` | Apex trigger blocking | Check `Decision_Event__c` immutability |
| `STORAGE_LIMIT_EXCEEDED` | Bulk insert too large | Use Bulk API 2.0 batching |
| `CANNOT_INSERT_UPDATE_ACTIVATE_ENTITY` | Flow validation failed | Run `sf flow list` and check status |

---

## Mortgate-Specific Notes

- **Org alias:** `mortgate-de` (per `CLAUDE.md`)
- **Default org:** `mortgate-de` (set with `--set-default`)
- **Bulk safety:** All Apex must handle 200+ records
- **Decision_Event__c is append-only** — UPDATE/DELETE forbidden
- **All automations go through `mortgate.gates.json`** — no shadow deploys

---

## Security / Secrets

- Never commit `~/.sfdx/`, `sfdx-url.json`, or session IDs
- Use `varlock` skill for secret management
- Use a CI service principal (e.g., `sfdx auth:jwt:grant`) for headless deploys

---

## Output Format

When Hightower runs gates, log a receipt to:

```javascript
allura-brain_memory_add({
  group_id: "allura-mortgage",
  user_id: "hightower-devops-mortgage",
  content: "DEPLOY_OUTCOME: {gate, command, exit_code, duration_ms}",
  metadata: { source: "gate-run", agent_id: "hightower-devops-mortgage", event_type: "DEPLOY_GATE" }
})
```
