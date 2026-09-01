# Mortgate Evidence Review

**Mortgate Evidence Review for Microsoft Copilot Cowork** is a human-supervised mortgage evidence-review package. The canonical product source is [`microsoft-cowork/`](microsoft-cowork/).

Mortgate helps an authorized employee inventory supplied loan-file documents, identify missing or conflicting evidence, compare a supplied deterministic policy replay, and draft an audit packet. It does **not** approve or deny credit, set pricing, issue notices, contact borrowers, or write to a loan system of record.

> [!IMPORTANT]
> ADR-36 made the Microsoft Copilot Cowork package the entire current product on 2026-08-28. The Salesforce/Veridact implementation under [`force-app/`](force-app/) is retained only as historical evidence and is not supported for new development or deployment.

## Product at a glance

| Surface | Status | Purpose |
|---|---|---|
| [`microsoft-cowork/appPackage/`](microsoft-cowork/appPackage/) | **Current product** | Microsoft 365 app manifest, icons, and four Agent Skills |
| [`microsoft-cowork/scripts/validate_package.py`](microsoft-cowork/scripts/validate_package.py) | **Current validator** | Offline package and archive validation |
| [`catalog-export.json`](catalog-export.json) | **Canonical export contract** | Exact allowlist for a future generated catalog package |
| [`mortagate-cowork.gates.json`](mortagate-cowork.gates.json) | **Current gates** | Cowork product readiness checks |
| [`force-app/`](force-app/) and `mortagate.gates.json` | **Deprecated legacy** | Historical Salesforce/Veridact implementation and its former gates |

The four current skills are:

- `mortgage-case-onboarding`
- `loan-file-evidence-review`
- `policy-replay-review`
- `audit-packet-draft`

## Install

This repository is the canonical standalone source. Validate and package it locally:

```bash
python3 microsoft-cowork/scripts/validate_package.py \
  --package-root microsoft-cowork/appPackage

cd microsoft-cowork
npx --yes @microsoft/m365agentstoolkit-cli package \
  --manifest-file appPackage/manifest.json \
  --output-package-file dist/mortgate-evidence-review.zip \
  --interactive false
```

For private upload and tenant requirements, see [Installation](docs/INSTALLATION.md). Copilot Cowork is a Frontier preview, so a licensed human and a suitable tenant are required for the final upload gate.

## Validate

```bash
npm run validate:cowork
npm run validate:export
npm run test:catalog-export
npm run docs:links
```

The complete local and tenant validation matrix is in [Validation](docs/VALIDATION.md).

## Architecture and configuration

- [Architecture](docs/ARCHITECTURE.md)
- [Installation](docs/INSTALLATION.md)
- [Configuration](docs/CONFIGURATION.md)
- [Validation](docs/VALIDATION.md)
- [Ecosystem relationships](docs/ECOSYSTEM.md)
- [Legacy Salesforce/Veridact record](docs/LEGACY-SALESFORCE.md)
- [ADR-36](planning%20docs/RISKS-AND-DECISIONS.md#adr-36--platform-pivot-mortagate-is-a-microsoft-copilot-cowork-plugin-only-salesforce-is-deprecated)

## Canonical source and future catalog package

This repository remains authoritative for Mortgate product content. [`catalog-export.json`](catalog-export.json) defines the only files eligible for a later generated export into [`allura-plugins/packages/mortagate-cowork`](https://github.com/Allura-Ecosystem/allura-plugins/tree/main/packages/mortagate-cowork). That destination is a **future install path**, not a current published package. Do not edit a generated catalog copy as source, and do not write into `allura-plugins` from this repository's exporter validation.

## Ecosystem

Mortgate is a product repository, not a replacement for shared ecosystem services:

- [Allura Memory](https://github.com/Allura-Ecosystem/Allura_Memory) provides optional governed memory infrastructure; the employee-facing Cowork skills remain memory-free.
- [allura-plugins](https://github.com/Allura-Ecosystem/allura-plugins) is the future generated catalog consumer; Mortgate remains canonical.
- [Team RAM](https://github.com/Allura-Ecosystem/allura-team-ram) may provide the internal engineering harness; it has no mortgage decision authority.
- [Team Durham](https://github.com/Allura-Ecosystem/team-durham) may govern brand production; it does not govern evidence findings or releases.

See [Ecosystem relationships](docs/ECOSYSTEM.md) for both directions of each relationship and degraded behavior.

## Historical Salesforce evidence

The deprecated Veridact/Salesforce implementation is intentionally preserved so prior work and validation claims remain auditable. Historical claims are date-scoped, not current operational claims. See [Legacy Salesforce/Veridact record](docs/LEGACY-SALESFORCE.md) and the warning in [`force-app/README.md`](force-app/README.md).

## License

Proprietary. All rights reserved. © Allura Ecosystem.
