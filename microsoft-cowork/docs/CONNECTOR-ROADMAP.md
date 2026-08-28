# Connector Roadmap

The initial Cowork package contains skills only. Do not add a connector until the sponsoring organization has a tenant, an approved system-of-record integration, and security approval.

## Target architecture

```text
Copilot Cowork
  ↓ Microsoft 365 app package
Mortgate skills + remote MCP connector
  ↓ Entra SSO / OAuthPluginVault
Mortgage evidence API
  ↓
Approved document vault / deterministic replay service
```

## Required controls

1. **Identity** — Microsoft Entra SSO or OAuth 2.1. No embedded API keys or secrets in the package.
2. **Scope enforcement** — The server must derive tenant, user, role, and case scope from a verified token. Prompts never authorize access.
3. **Read-first tools** — Start with the explicit tools below. Each tool receives a validated case identifier and returns structured JSON with source metadata.
4. **Evidence metadata** — Each returned fact should include source system, document ID, document hash, page/section, extraction version, confidence, and freshness.
5. **Audit** — Record connector tool use through the sponsoring organization’s approved audit pathway. Microsoft Purview captures Cowork activity; the system of record must retain its own business audit trail.
6. **Safety annotations** — Every MCP tool must publish annotations. Read-only tools use `readOnlyHint: true`. Any write action requires human confirmation and separate business authorization.
7. **Availability** — A store-published remote connector should meet Microsoft’s recommended 99.9% availability and less-than-30-second tool response target.

## Initial allowed tools

```text
get_case_summary(case_id)
list_case_documents(case_id)
get_evidence_packet(case_id)
get_policy_replay(case_id, replay_id)
```

## Explicitly prohibited tools

```text
approve_loan()
deny_loan()
set_rate()
set_terms()
issue_adverse_action_notice()
send_borrower_message()
override_policy()
```

## Human authorization

A later write capability can be considered only after a risk assessment, role design, tool-specific user confirmation, and an approved system-of-record workflow. It is not a v1 requirement.

## Microsoft deployment sequence

1. Validate the package with Microsoft 365 Agents Toolkit.
2. Upload privately in Cowork and test with synthetic/nonproduction material.
3. Deploy to a small security group through Microsoft 365 admin center.
4. Add Entra/OAuth authentication and a read-only MCP connector in a nonproduction environment.
5. Verify access boundaries, Purview audit records, and error handling.
6. Obtain security, privacy, compliance, and business-owner approval before broader deployment.
