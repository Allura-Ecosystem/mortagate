# Mortgage Approval Engine

This file provides Claude Code and Claude Desktop project context for the Salesforce Community Mortgage Approval Engine.

## Source Of Truth

- Primary project reference: `copilot-instructions.md`
- Documentation standard: Carlos Guidelines
- Memory group: `allura-mortgage`
- Salesforce org alias: `mortagate-de`

Before implementation, create or update the required Carlos artifacts:

- `planning docs/BLUEPRINT.md`
- `planning docs/SOLUTION-ARCHITECTURE.md`
- `planning docs/REQUIREMENTS-MATRIX.md`
- `planning docs/RISKS-AND-DECISIONS.md`
- `planning docs/DATA-DICTIONARY.md`
- `planning docs/copilot-instructions.md`

DESIGN-* deep dives, epics, readiness reports, and other BMad artifacts live in `my-project/_bmad-output/planning/`.

If documentation conflicts with Salesforce metadata, Apex, Flow XML, LWC source, or JSON schema, defer to source code or schema first.

## Project Structure

This is a **BMad project**, not Superpowers. All output follows BMad conventions:

- `planning docs/` — 6 Carlos docs (flat, gate-checked)
- `my-project/_bmad-output/planning/` — specs, designs, epics, readiness reports
- `my-project/_bmad-output/implementation/` — demo data, scripts, seed artifacts
- `my-project/_bmad-output/test/` — test artifacts
- `my-project/policies/` — invariant guardrails (always-on)
- `my-project/skills/` — actionable agent workflows
- `my-project/.github/prompts/` — Copilot wrappers

Never write output to `docs/superpowers/`, `superpowers/specs/`, or any Superpowers path. If a skill defaults to a Superpowers path, override it to the BMad path above.

## Current Runtime Gate

`mortagate.gates.json` defines phase-0 through phase-2 gate checks. Salesforce CLI commands require an authenticated org:

```bash
sf org login web --alias mortagate-de --set-default
sf org display --target-org mortagate-de
```

Sandbox orgs should use:

```bash
sf org login web --alias mortagate-de --instance-url https://test.salesforce.com --set-default
```

Do not claim Salesforce gate completion until the commands in `mortagate.gates.json` pass against `mortagate-de`.
