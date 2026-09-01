# Mortgate Evidence Review for Copilot Cowork

A native Microsoft Copilot Cowork skills package for internal, human-supervised mortgage evidence review.

It helps an authorized employee:

- onboard an evidence-review task;
- inventory uploaded loan-file documents;
- identify missing, ambiguous, and conflicting evidence;
- compare a supplied deterministic policy replay; and
- draft an audit packet for human review.

It does **not** approve or deny credit, set pricing or rate, issue notices, send communications, or update a loan-origination system.

## Why Microsoft Copilot Cowork

This package is for people already working in Microsoft 365. Cowork provides the employee workspace; this package contributes domain-specific skills. The employee sees a simple workflow, not an internal multi-agent framework.

```text
Employee request + attached evidence
        ↓
Copilot Cowork
        ↓
Mortgate Evidence Review skills
        ↓
Human-review draft and cited findings
        ↓
Authorized employee uses the approved system of record
```

## Current release: skills only

`appPackage/` is a Microsoft 365 app package source. The four skills are standard Agent Skills and require no live API, credential, connector, or data store.

| Skill | Employee request it supports |
|---|---|
| `mortgage-case-onboarding` | Start a review and identify needed materials |
| `loan-file-evidence-review` | Summarize supplied evidence and identify gaps |
| `policy-replay-review` | Compare supplied expected and actual replay results |
| `audit-packet-draft` | Prepare a human-review handoff packet |

## Local validation and packaging

Microsoft 365 Agents Toolkit CLI is the package validator.

```bash
(
  cd microsoft-cowork/appPackage
  npx --yes @microsoft/m365agentstoolkit-cli validate \
    --manifest-file manifest.json \
    --validate-method validation-rules \
    --interactive false
)

(
  cd microsoft-cowork
  npx --yes @microsoft/m365agentstoolkit-cli package \
    --manifest-file appPackage/manifest.json \
    --output-package-file dist/mortgate-evidence-review.zip \
    --interactive false
)

python3 microsoft-cowork/scripts/validate_package.py \
  --package-root microsoft-cowork/appPackage \
  --archive microsoft-cowork/dist/mortgate-evidence-review.zip
```

The local package can be uploaded privately in Cowork: **+ → Customize → Plugins → Upload plugin → Only you**. A tenant administrator controls any pilot-group deployment.

## Connector phase: deliberately not included yet

A future connector must be a remote Streamable HTTP MCP service over HTTPS and use Microsoft Entra/OAuth. It must expose only a small, explicit, tenant-scoped tool surface such as:

```text
get_case_summary(case_id)
list_case_documents(case_id)
get_evidence_packet(case_id)
get_policy_replay(case_id, replay_id)
```

It must not expose approval, denial, pricing, rate-setting, notice issuance, or policy override tools. See `docs/CONNECTOR-ROADMAP.md`.

## Reference architecture lessons

- Confluent’s workshop is a useful reference for event ingestion and reproducible infrastructure, but its automated decisioning model is out of scope here.
- Red Hat’s quickstart is useful for RBAC, PII masking, compliance-source tiering, audit chains, and evaluation patterns. Its mortgage compliance content is simulated; it is not imported as policy.

See `docs/REFERENCE-ARCHITECTURE.md`.

## Canonical source and catalog relationship

This directory is the current product source inside the canonical [Mortgate repository](https://github.com/Allura-Ecosystem/mortagate). The root [`catalog-export.json`](../catalog-export.json) allowlists reusable files for a future generated [`allura-plugins/packages/mortagate-cowork`](https://github.com/Allura-Ecosystem/allura-plugins/tree/main/packages/mortagate-cowork) package. That catalog path is not published yet, and downstream copies must send fixes back to Mortgate before regeneration.

## Microsoft sources

- [Build plugins for Copilot Cowork](https://learn.microsoft.com/en-us/microsoft-365/copilot/cowork/cowork-plugin-development)
- [Use plugins with Copilot Cowork](https://learn.microsoft.com/en-us/microsoft-365/copilot/cowork/cowork-plugins)
- [Manage plugins for Copilot Cowork](https://learn.microsoft.com/en-us/microsoft-365/copilot/cowork/cowork-manage-plugins)

> Copilot Cowork is a Frontier preview. A controlled tenant pilot and current Microsoft validation are required before production use.
