# Configuration

## Current release

Mortgate Evidence Review is skills-only. Configuration is intentionally limited to the checked-in Microsoft 365 package source:

| File | Purpose |
|---|---|
| `microsoft-cowork/appPackage/manifest.json` | App identity, descriptions, icons, and skill registration |
| `microsoft-cowork/m365agents.yml` | Local Microsoft 365 Agents Toolkit package workflow |
| `microsoft-cowork/appPackage/skills/*/SKILL.md` | Skill instructions and triggering descriptions |

No environment variable or runtime secret is required by the employee-facing package.

## Local tool configuration

Repository-local `.mcp.json`, OpenCode configuration, Team RAM files, and BMad artifacts are internal engineering surfaces. They are not part of the Cowork package and are excluded from [`catalog-export.json`](../catalog-export.json).

Never commit tokens or resolved credentials. Environment placeholders may document names, but secrets belong in the operator's approved secret store. `.mcp.json` is not part of the product export.

## Optional Allura Memory

Allura Memory is an optional engineering/governance companion using Mortgate's declared memory group `allura-mortgage`. It is not a dependency of the four employee-facing skills, and a missing Memory connection must degrade visibly rather than produce a fabricated receipt.

## Future connector configuration

A future connector requires a separate approved design. At minimum it must define:

- Entra/OAuth identity and tenant scope;
- an HTTPS Streamable HTTP MCP endpoint;
- read-only tool allowlists;
- audit and privacy controls;
- explicit degraded behavior; and
- tenant-side validation evidence.

Do not add connector URLs, client secrets, Salesforce credentials, write tools, or production identifiers to the current package.
