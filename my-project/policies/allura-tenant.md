# Allura Tenant — Mortgate

Mortgate uses `group_id: allura-mortgage` on every DB operation. General Allura invariants (append-only Postgres, Neo4j SUPERSEDES, HITL promotion, MCP_DOCKER-only DB ops, allura-* namespace) are enforced by the governance-preflight hook. This policy documents the Mortgate-specific identifiers only.

**Agent IDs:**
- `brooks-architect-mortgage` — Chief Architect
- `woz-builder-mortgage` — Primary Builder
- `knuth-data-architect-mortgage` — Data Architect
- `hightower-devops-mortgage` — DevOps
- `pike-interface-review-mortgage` — UX Review
- `fowler-refactor-gate-mortgage` — Refactor Gate
- `bellard-diagnostics-perf-mortgage` — Diagnostics

**Enforcement:** `governance-preflight.py` hook blocks any DB operation missing `group_id` or using a non-allura namespace.

**Source:** CLAUDE.md, Brooks agent definition.
