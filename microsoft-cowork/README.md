# Mortgate Evidence Review for Copilot Cowork

> **AI-Assisted Documentation** — portions of this guide were drafted with AI assistance. Package manifests, schemas, and current validation evidence remain authoritative.

Review supplied mortgage-file evidence and prepare a cited draft for a human reviewer in Microsoft Copilot Cowork.

Mortgate helps an authorized employee inventory documents, identify gaps and conflicts, compare supplied policy-replay results, and draft an audit packet. The current release contains four Agent Skills. It requires no live API, connector, credential, or data store.

The skills do not approve or deny credit, set pricing or rates, issue notices, send communications, or update a loan-origination system. An authorized person makes decisions and uses the approved system of record.

## Choose the task

| Skill | Employee request |
|---|---|
| `mortgage-case-onboarding` | Start a review and identify the materials needed |
| `loan-file-evidence-review` | Summarize supplied evidence and identify gaps or conflicts |
| `policy-replay-review` | Compare supplied expected and actual replay results |
| `audit-packet-draft` | Prepare a cited handoff packet for human review |

For example:

> Review these supplied loan documents. Inventory what is present, cite gaps and conflicting facts, and prepare questions for the human reviewer. Do not infer missing evidence or make a credit decision.

The host works from the supplied material. A policy-replay review compares provided results; it does not execute a live policy engine or establish regulatory compliance.

## Review workflow

```text
Employee request and attached evidence
  → Confirm the task and relevant source versions
  → Inventory documents and compare evidence
  → Identify gaps, conflicts, and cited findings
  → Draft a review packet
  → Human review and action in the approved system of record
```

Version `0.2.1` lets the four skills reuse cited evidence for the same case and source versions. Changed inputs require refreshed findings. Clear tasks proceed directly without repeating intake or launching a specialist for each skill. See [change management](docs/CHANGE-MANAGEMENT.md) for evaluation limits.

## Validate, package, and install

`appPackage/` contains the Microsoft 365 app package source. Run these commands from the directory containing this README: `microsoft-cowork/` in the source repository, or `packages/mortagate-cowork/` in the catalog export.

```bash
(
  cd appPackage
  npx --yes @microsoft/m365agentstoolkit-cli validate \
    --manifest-file manifest.json \
    --validate-method validation-rules \
    --interactive false
)

npx --yes @microsoft/m365agentstoolkit-cli package \
  --manifest-file appPackage/manifest.json \
  --output-package-file dist/mortgate-evidence-review.zip \
  --interactive false

python3 scripts/validate_package.py \
  --package-root appPackage \
  --archive dist/mortgate-evidence-review.zip
```

The Microsoft 365 Agents Toolkit CLI validates and packages the app; the Python script checks local structure and the generated archive. Passing these checks does not prove that a tenant has enabled the plugin or that a live review succeeded.

Where plugin upload is enabled, upload the archive privately in Cowork: **+ → Customize → Plugins → Upload plugin → Only you**. A tenant administrator controls pilot-group deployment. Confirm current availability and requirements in the [Microsoft plugin documentation](https://learn.microsoft.com/en-us/microsoft-365/copilot/cowork/cowork-plugins).

## What is not included

There is no live case connector in this release. The [connector roadmap](docs/CONNECTOR-ROADMAP.md) describes a future remote Streamable HTTP MCP service over HTTPS with Microsoft Entra/OAuth and a small, explicit tool surface such as case summaries, document lists, evidence packets, and policy-replay retrieval.

That future surface must exclude credit approval or denial, pricing, rate setting, notice issuance, and policy overrides. Current skills do not gain those capabilities from the roadmap.

Copilot Cowork is the canonical product surface under ADR-36. ChatGPT and Codex packaging remain future direction unless separately released. The legacy Salesforce implementation is outside this package.

## Source and catalog

This directory is the product source in the [Mortgate repository](https://github.com/Allura-Ecosystem/mortagate). The [catalog export contract](https://github.com/Allura-Ecosystem/mortagate/blob/main/catalog-export.json) allowlists reusable files for the published [Allura catalog distribution](https://github.com/Allura-Ecosystem/allura-plugins/tree/main/packages/mortagate-cowork).

The catalog records an exact source commit and file hashes. Send content changes to Mortgate, then regenerate the catalog package. Publication in the catalog does not install or enable the package in a Microsoft tenant.

## Further reading

- [Change management](docs/CHANGE-MANAGEMENT.md)
- [Reference architecture](docs/REFERENCE-ARCHITECTURE.md) — external examples are design references, not imported mortgage policy
- [Privacy](PRIVACY.md) and [terms](TERMS.md)
- [Build plugins for Copilot Cowork](https://learn.microsoft.com/en-us/microsoft-365/copilot/cowork/cowork-plugin-development)
- [Use plugins with Copilot Cowork](https://learn.microsoft.com/en-us/microsoft-365/copilot/cowork/cowork-plugins)
- [Manage plugins for Copilot Cowork](https://learn.microsoft.com/en-us/microsoft-365/copilot/cowork/cowork-manage-plugins)
