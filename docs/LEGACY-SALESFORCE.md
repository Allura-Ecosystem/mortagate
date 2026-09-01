# Legacy Salesforce / Veridact Record

> [!CAUTION]
> **Deprecated on 2026-08-28 by ADR-36.** This material is historical evidence, not the current Mortgate product, backlog, architecture, installation path, or release gate.

Before ADR-36, this repository presented Veridact as a Salesforce mortgage audit replay and quality-control platform. That work included Salesforce DX metadata under `force-app/`, Apex controllers and a pure policy-evaluation kernel, Lightning Web Components, Agentforce definitions, audit-event/receipt objects, demos, and Salesforce-specific planning documents.

## Preserved historical evidence

The former public README recorded these date-scoped results as verified on 2026-06-23 against the development org alias `mortagate-de`:

- Apex `RunLocalTests`: 140/140 passing;
- LWC Jest: 53/53 passing across 12 suites;
- six auditor screens implemented;
- 629 audit cases reported in the development org;
- Agentforce Copilot activated with final action wiring still pending; and
- a `v1-demo` tag and then-current repository SHA `d715956`.

These claims describe a past environment and are preserved for provenance. They have **not** been revalidated as current operational status and must not be marketed as such.

## Archived paths

| Path | Historical purpose |
|---|---|
| `force-app/` | Salesforce DX source: Apex, LWC, objects, triggers, Agentforce metadata, permissions, and UI metadata |
| `demo/` | Next.js Veridact product-story demo |
| `apps/veridact-frontend/` | Parallel auditor cockpit |
| `sfdx-project.json` | Salesforce project configuration |
| `manifest/` | Salesforce deployment manifests |
| `mortagate.gates.json` | Former Salesforce release/readiness checks |
| `DEPLOY-REPORT.md` | Former development-org deployment record |
| most of `planning docs/` | Historical Salesforce product documents; `RISKS-AND-DECISIONS.md` remains live for ADR history |

## Rules for legacy material

- Do not add new product features under `force-app/`.
- Do not use Salesforce gates to claim current Cowork readiness.
- Do not delete or rewrite historical evidence to make the pivot look cleaner.
- Date-scope any legacy validation claim and distinguish it from a live check.
- Any future archive/removal pass must preserve provenance and update links deliberately.

The governing decision is [ADR-36](../planning%20docs/RISKS-AND-DECISIONS.md#adr-36--platform-pivot-mortagate-is-a-microsoft-copilot-cowork-plugin-only-salesforce-is-deprecated).
