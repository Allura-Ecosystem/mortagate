# Mortagate

Product monorepo for **Veridact / Mortagate** — mortgage audit replay & QC, plus the
Salesforce/Agentforce workflow layer and the planning and governance docs behind it.

> _"Every decision has a receipt."_ Veridact lets a bank QC analyst take an
> already-approved loan, replay the exact policy rules in force at approval time, map each
> rule to its supporting evidence, record pass/exception/violation findings, and seal an
> immutable audit receipt ready for regulators.

The auditor-facing app, the enterprise Salesforce layer, the policies, and the planning
artifacts all live together here so the whole product story stays in one canonical repo.

The shipping pilot surface is the **Salesforce (LWC + Agentforce) app** under `force-app/`
— the full auditor workflow (Queue → Case Review → Finding → Sign-off, plus Analytics,
Policy Versions, and Admin) backed by an append-only audit kernel and Apex + Jest tests.
The Next.js app under `apps/veridact-frontend/` is a parallel auditor cockpit.

## Repository structure

```
mortagate/
  force-app/main/default/ # Salesforce DX source — the shipping pilot app
    lwc/                  #   auditor UI: auditQueue, caseReview, findingDetail,
                          #   signoffReceipt, auditAnalytics, policyVersions, auditAdmin (+ helpers)
    classes/              #   Apex: replay kernel, controllers, services
    objects/              #   SObjects (Audit_Case__c, Replay_Check__c, Audit_Receipt__c, ...)
    bots/ genAiPlugins/   #   Agentforce agents + topics (Veridact Auditor variants)
    genAiPlannerBundles/
  apps/
    veridact-frontend/    # Next.js auditor cockpit (parallel surface)
  my-project/             # BMAD policies and skills
  planning docs/          # Blueprint, requirements, data dictionary, risks & decisions
  specs/                  # Agentforce agent specs (YAML)
  manifest/               # Salesforce deploy manifests (package.xml)
  scripts/                # Data and build scripts
  mortagate.gates.json    # Phase gate checks
  sfdx-project.json       # Salesforce DX project config
```

## What each part is

| Area | What it is |
|------|------------|
| `force-app/` + `sfdx-project.json` | The shipping Salesforce DX / Agentforce app — SObjects, the append-only replay kernel, Apex controllers, the LWC auditor screens, and the governed Agentforce agents. This is the pilot surface. |
| `apps/veridact-frontend` | The Next.js auditor cockpit — a parallel surface for re-running a closed loan against the policy in force at approval, reviewing evidence, recording findings, and sealing a tamper-evident receipt. |
| `my-project/`, `planning docs/`, `_bmad-output/` | BMAD planning, policies, and governance — workflow, requirements, and roadmap. |

## Sources of truth

- **Code** — this repository.
- **Product & governance** — Notion.
- **Visual design** — Figma.

## Working in the Salesforce app

The pilot app deploys to the `mortagate-de` org. Authenticate, then deploy and test.

```bash
sf org login web --alias mortagate-de --set-default   # sandbox: add --instance-url https://test.salesforce.com
sf org display --target-org mortagate-de

npm install
npm run test:unit            # LWC Jest (sfdx-lwc-jest)

sf project deploy start --target-org mortagate-de      # deploy metadata
sf apex run test --target-org mortagate-de --test-level RunLocalTests --code-coverage
```

Gate checks (`mortagate.gates.json`) must pass against `mortagate-de` before claiming
Salesforce gate completion. Agentforce features require Setup-side enablement on the org.

## Working in the frontend app

```bash
cd apps/veridact-frontend
npm install
npx tsc --noEmit   # type-check (no dedicated "typecheck" script yet)
npm test           # vitest
npm run dev        # local dev server
```

## Roadmap (structure)

The intended end-state groups the codebase as `apps/`, `salesforce/` (housing `force-app/`),
`docs/`, and `packages/shared/` for cross-cutting types. The Salesforce tree has not been
moved yet — that reshuffle is deferred so existing paths and tooling stay stable.
