# Installation

## Prerequisites

- Python 3.10 or newer for offline validation.
- Node.js and `npx` for Microsoft 365 Agents Toolkit validation/packaging.
- A Frontier-enabled Microsoft 365 Copilot tenant and licensed human for private upload and tenant validation.

The current skills-only package needs no API key, connector credential, database, Salesforce org, or Allura Memory connection.

## Clone and validate the canonical source

```bash
git clone https://github.com/Allura-Ecosystem/mortagate.git
cd mortagate
python3 microsoft-cowork/scripts/validate_package.py \
  --package-root microsoft-cowork/appPackage
python3 scripts/validate_catalog_export.py
```

## Validate with Microsoft tooling

```bash
cd microsoft-cowork/appPackage
npx --yes @microsoft/m365agentstoolkit-cli validate \
  --manifest-file manifest.json \
  --validate-method validation-rules \
  --interactive false
```

## Build the upload archive

```bash
cd microsoft-cowork
npx --yes @microsoft/m365agentstoolkit-cli package \
  --manifest-file appPackage/manifest.json \
  --output-package-file dist/mortgate-evidence-review.zip \
  --interactive false

cd ..
python3 microsoft-cowork/scripts/validate_package.py \
  --package-root microsoft-cowork/appPackage \
  --archive microsoft-cowork/dist/mortgate-evidence-review.zip
```

`microsoft-cowork/dist/` is generated output and is not source.

## Private tenant upload

In Copilot Cowork, use **+ → Customize → Plugins → Upload plugin → Only you**. Tenant administrators control pilot-group distribution. The upload is a manual gate: do not claim tenant readiness from local validation alone.

## Future catalog install path

The planned generated catalog destination is [`allura-plugins/packages/mortagate-cowork`](https://github.com/Allura-Ecosystem/allura-plugins/tree/main/packages/mortagate-cowork). It does not exist as a supported install path yet. [`catalog-export.json`](../catalog-export.json) defines its future source boundary; this repository remains canonical.

## Do not install the legacy product

Salesforce setup and deploy commands in historical documents refer to the deprecated Veridact implementation. They are preserved as evidence, not current installation instructions. See [Legacy Salesforce/Veridact record](LEGACY-SALESFORCE.md).
