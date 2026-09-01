# Validation

## Local required checks

Run from the repository root:

```bash
# Current Cowork package structure
python3 microsoft-cowork/scripts/validate_package.py \
  --package-root microsoft-cowork/appPackage

# Export contract and its negative/positive fixtures
python3 scripts/validate_catalog_export.py
python3 -m unittest discover -s tests -p 'test_*.py'

# Repository-local Markdown targets
python3 scripts/check_markdown_links.py

# Diff hygiene
git diff --check
```

Equivalent npm aliases are `validate:cowork`, `validate:export`, `test:catalog-export`, and `docs:links`.

## Gate file

[`mortagate-cowork.gates.json`](../mortagate-cowork.gates.json) is the current product gate definition. `mortagate.gates.json` is legacy Salesforce evidence and does not gate this product.

The gate has four phases:

1. package structure;
2. planning documentation;
3. local package build/validation; and
4. manual tenant upload and invocation.

The final phase cannot be automated. A local pass is not proof of Microsoft tenant readiness.

## Microsoft validation and archive build

```bash
cd microsoft-cowork/appPackage
npx --yes @microsoft/m365agentstoolkit-cli validate \
  --manifest-file manifest.json \
  --validate-method validation-rules \
  --interactive false

cd ..
npx --yes @microsoft/m365agentstoolkit-cli package \
  --manifest-file appPackage/manifest.json \
  --output-package-file dist/mortgate-evidence-review.zip \
  --interactive false
```

Then pass the archive to `validate_package.py --archive`.

## Secret scanning

Run gitleaks against the changed/export surfaces before release. A recommended clean-worktree check is:

```bash
gitleaks detect --no-git --source . --redact --exit-code 1
```

Generated dependency trees such as `node_modules/` are never release source and must not be staged.

## CI

The `cowork-product` GitHub Actions job runs the offline package validator, export-contract validator, Python tests, and Markdown link checker. `no-secrets` runs gitleaks against the repository checkout. Microsoft tenant validation remains manual.
