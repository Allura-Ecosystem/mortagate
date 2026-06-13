# Mortagate

Product monorepo for **Veridact / Mortagate** — mortgage audit replay & QC, plus the
Salesforce/Agentforce workflow layer and the planning and governance docs behind it.

The auditor-facing app, the enterprise Salesforce layer, the policies, and the planning
artifacts all live together here so the whole product story stays in one canonical repo.

## Repository structure

```
mortagate/
  apps/
    veridact-frontend/   # Next.js auditor cockpit (replay checks, evidence, findings, sealed receipts)
  force-app/             # Salesforce DX source (objects, Agentforce, automation)
  my-project/            # BMAD policies and skills
  planning docs/         # Blueprint, requirements, data dictionary, risks & decisions
  _bmad-output/          # BMAD planning output (epics, stories, design, readiness reports)
  docs/                  # Cross-cutting documentation
  scripts/               # Data and build scripts
  sfdx-project.json      # Salesforce DX project config
```

## What each part is

| Area | What it is |
|------|------------|
| `apps/veridact-frontend` | The Next.js auditor cockpit — the UI auditors use to re-run a closed loan against the policy in force at approval, review evidence, record findings, and seal a tamper-evident receipt. |
| `force-app/` + `sfdx-project.json` | The Salesforce DX / Agentforce layer — objects, automation, and the enterprise workflow side of the same product. |
| `my-project/`, `planning docs/`, `_bmad-output/` | BMAD planning, policies, and governance — workflow, requirements, and roadmap. |

## Sources of truth

- **Code** — this repository.
- **Product & governance** — Notion.
- **Visual design** — Figma.

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
