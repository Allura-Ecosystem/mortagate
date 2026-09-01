# Architecture

## Product boundary

ADR-36 defines `microsoft-cowork/` as the entire current Mortgate product. The product is a Microsoft 365 app package containing four declarative Agent Skills and no live connector, credential, database, or decision engine.

```text
Authorized employee + supplied documents/replay
                    |
                    v
         Microsoft Copilot Cowork
                    |
                    v
      Mortgate Agent Skills (4, read-only)
                    |
                    v
     Cited draft / evidence-review handoff
                    |
                    v
          Authorized human reviewer
```

The skills can organize evidence and draft findings. They cannot approve or deny credit, set price or rate, issue borrower communications, override policy, or mutate a system of record.

## Source layout

| Path | Authority |
|---|---|
| `microsoft-cowork/appPackage/manifest.json` | Microsoft 365 package identity and skill registration |
| `microsoft-cowork/appPackage/skills/*/SKILL.md` | Employee-facing behavior contracts |
| `microsoft-cowork/appPackage/skills/*/references/` | Shared safety boundaries used by each skill |
| `microsoft-cowork/scripts/validate_package.py` | Offline package structural validation |
| `catalog-export.json` | Exact future catalog-export allowlist and provenance contract |
| `mortagate-cowork.gates.json` | Current readiness gate definition |
| `planning docs/RISKS-AND-DECISIONS.md` | Live decision record, including ADR-36 |

If prose conflicts with a manifest, skill, schema, or validator, source/schema wins and the prose must be corrected.

## Trust boundaries

1. **Human authority:** A human reviewer owns interpretation, approval, and any action in an approved system of record.
2. **No hidden connectivity:** The current release has no connector and requires no runtime secret.
3. **Evidence-only outputs:** Findings and packets are drafts grounded in supplied material.
4. **Pilot data:** Use synthetic/nonproduction files until tenant, policy, privacy, and security approval exists.
5. **Optional ecosystem services:** Allura Memory, Team RAM, and Durham are engineering/governance companions, not employee-facing product dependencies.

## Future connector

A future connector, if separately approved, must be tenant-scoped, read-only, Entra/OAuth protected, and exposed through a small Streamable HTTP MCP tool surface. Write, decision, pricing, notice, and policy-override tools remain prohibited. See [`microsoft-cowork/docs/CONNECTOR-ROADMAP.md`](../microsoft-cowork/docs/CONNECTOR-ROADMAP.md).

## Distribution architecture

```text
mortagate (canonical source)
  catalog-export.json + exact source commit
                    |
                    v
allura-plugins/packages/mortagate-cowork (future generated copy)
                    |
                    v
           runtime installation
```

The downstream package must pin the source repository and commit, copy only allowlisted files, record provenance, and send edits upstream to Mortgate before regeneration. The validator in this repository only validates the contract; it does not write into `allura-plugins`.

## Legacy boundary

`force-app/`, the Salesforce demos, and `mortagate.gates.json` are historical evidence. They remain readable but are outside current architecture and release gates. See [Legacy Salesforce/Veridact record](LEGACY-SALESFORCE.md).
