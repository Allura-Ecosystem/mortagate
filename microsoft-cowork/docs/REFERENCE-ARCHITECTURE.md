# Reference Architecture Notes

This package uses public reference projects for design lessons only. It does not copy their lending logic, policies, data, credentials, or deployment configuration.

## Confluent mortgage-underwriting workshop

Source: <https://github.com/confluentinc/workshop-mortgage-underwriting-agentic-system>

Useful lessons:

- Separate event ingestion, enrichment, and application workflows.
- Treat infrastructure setup as reproducible code rather than a manual demo.
- Make resource cleanup explicit for cloud demonstration environments.

Not adopted:

- Automated final mortgage decisioning.
- Any cloud credentials, Terraform, data-generation assets, or Bedrock setup.

Reason: this Cowork package is an employee evidence-review experience. It is not a real-time decision engine.

## Red Hat multi-agent loan-origination quickstart

Source: <https://github.com/rh-ai-quickstart/multi-agent-loan-origination>

Useful lessons:

- Role-scoped routing and access boundaries.
- PII masking and demographic-data isolation.
- Regulatory source tiering and document-grounded review.
- Hash-chained audit-event design.
- Evaluation, UI, API, and end-to-end test separation.

Not adopted:

- Its fictional lender domain model.
- Its underwriting recommendation/approval flow.
- Its simulated compliance content as operational policy.
- Its OpenShift, Keycloak, MLflow, MinIO, or predictive-model stack.

Reason: a Microsoft Cowork plugin should begin with Cowork skills and a minimal, Entra-secured, read-only connector—not a full separate agent platform.

## Design outcome

```text
Reference architectures
        ↓
Reusable lessons: provenance, RBAC, evidence, audit, evaluation
        ↓
Cowork skills-only package
        ↓
Future Entra-secured, read-only MCP connector
        ↓
Human-supervised evidence review
```
