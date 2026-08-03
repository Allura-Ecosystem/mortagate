# SC-2b — Brain Wiring Gap: Finding Document

**Status:** Finding (unbuilt work, not a bug)
**Established:** 2026-08-03
**Owner:** Sabir Asheed
**Workstream:** WS-3 (Beta Readiness)
**Cross-ref:** GOAL-G2-beta-readiness.md (SC-2b definition), ADR-17, ENTERPRISE-READINESS-ROADMAP.md §4

---

## 1. The Finding

**The Allura-governed memory described throughout this project's documentation is NOT wired in the deployed Salesforce application.**

The project's documentation, policies, and agent definitions consistently describe a system where every audit decision, every agent action, and every significant event writes to Allura Brain under `group_id: allura-mortgage`. This is documented in:

- `README.md` — "All agent actions log to Allura Brain with `group_id: allura-mortgage`"
- `AGENTS.md` — "Brooks → Scout hydration → Allura Brain (group_id: allura-mortgage) → Skills → Route"
- `CLAUDE.md` — "Memory group: `allura-mortgage`"
- `mortagate.gates.json` — `"memory_group_id": "allura-mortgage"`
- `my-project/policies/allura-tenant.md` — "Mortgate uses `group_id: allura-mortgage` on every DB operation"
- `my-project/policies/brooks-response-protocol.md` — "Memory `group_id` for this project is `allura-mortgage`"
- `my-project/policies/symphony-workflow.md` — "`group_id: allura-mortgage` on every memory/DB op"
- `planning docs/SOLUTION-ARCHITECTURE.md` — Layer 4: Allura Brain with MCP (`allura-mortgage` group)
- `planning docs/BLUEPRINT.md` — "Memory: allura-mortgage"
- `EPICS-AND-STORIES.md` — US-5.3: "I can read and write audit context to Allura Brain via MCP (group: allura-mortgage)"

**None of this wiring exists in the deployed Salesforce application.**

---

## 2. Evidence

A repository-wide search for `allura-mortgage` returns **44 files** — every single one is documentation, policy, skill definition, or agent configuration. **Zero hits exist under `force-app/`.**

| Artifact | Count | Location |
|----------|-------|----------|
| Documentation/policy files referencing `allura-mortgage` | 44 | `README.md`, `AGENTS.md`, `CLAUDE.md`, `planning docs/`, `my-project/policies/`, `my-project/skills/`, `my-project/_bmad-output/planning/` |
| Apex classes referencing `allura-mortgage` or `group_id` | **0** | `force-app/main/default/classes/` (72 classes) |
| LWC components referencing `allura-mortgage` or `group_id` | **0** | `force-app/main/default/lwc/` (16 component directories) |
| Flow definitions | **0** | `force-app/main/default/flows/` (directory does not exist) |
| Apex callouts (`HttpRequest`, `Http`, `@future(callout=true)`) | **0** | All 72 classes are pure SOQL/DML |
| Named Credentials, External Credentials, Remote Site Settings | **0 each** | Not present in source |
| `externalServices/`, `restResources/` | **absent** | Directories do not exist |

The two Apex comments that mention "Allura" are explanatory only:

- `LoanDecisionService.cls:65` — `// Allura HITL: anything that could promote an application...` (comment only, no callout)
- `DecisionReceiptController.cls:7` — `// so it cannot mutate the append-only event (Allura immutability holds by construction)` (comment only, no callout)

---

## 3. Why This Is Unbuilt Work, Not a Bug

ADR-17 (2026-06-14) explicitly states the production architecture decision:

> **"Production = Salesforce only (SObjects, Apex, Agentforce, Flows, LWC, VF). Allura Brain is used for development orchestration and session memory only — it is never in the production stack and never appears in customer-facing materials."**

The Allura Brain wiring was never scoped for the current pilot. The documentation describing it as wired reflects aspirational design intent, not deployed reality. The gap is a scope finding — the work was planned but not built.

---

## 4. What Would Need to Be Built

To wire Allura Brain into the CaseFile audit loop, the following would need to be created:

### 4.1 Apex Integration Class

A new Apex class (e.g., `AlluraBrainService.cls`) that:

1. **Makes an HTTP callout** to the Allura Brain MCP endpoint (configured via Named Credential)
2. **Accepts a structured payload** containing:
   - `group_id`: `"allura-mortgage"`
   - `user_id`: The agent or system identifier (e.g., `"brooks-architect-mortgage"`)
   - `content`: The decision event, finding, or trace to record
   - `score`: Optional relevance score for semantic retrieval
3. **Handles authentication** via Named Credential or Auth Provider
4. **Implements retry logic** with exponential backoff for transient failures
5. **Logs failures** to a custom object or platform event for observability

**Signature sketch:**

```apex
public with sharing class AlluraBrainService {
    @future(callout=true)
    public static void recordMemory(String groupId, String userId, String content, Double score) {
        // 1. Build HTTP request to Allura Brain MCP endpoint
        // 2. Set auth headers from Named Credential
        // 3. POST JSON payload
        // 4. Handle response / log failure
    }
}
```

### 4.2 Integration Points

The callout should be inserted at these decision-path locations:

| Integration Point | Class | Trigger | What to Write |
|-------------------|-------|---------|---------------|
| Decision committed | `DecisionCommitService` | After `insert decisionEvents` | Decision outcome, rule results, application ID |
| Replay completed | `ReplayCommitService` | After `insert replayChecks` | Replay check results, pass/fail summary |
| Finding created | `FindingDraftService` or `FindingController` | After finding persisted | Finding details, severity, category |
| Sign-off completed | `SignoffController` | After sign-off committed | Signer, outcome, timestamp |
| Case status change | `AuditEventService` | After status transition | Old status, new status, trigger |

### 4.3 Alternative: Flow-Based Integration

If an Apex class is undesirable, a **Platform Flow** (Autolaunched Flow) could be created that:

1. Accepts the same payload as input variables
2. Uses a **Callout** action to POST to the Allura Brain MCP endpoint
3. Is invoked from Apex via `Flow.Interview` or from a Process Builder

### 4.4 Prerequisites

Before either approach works, the Salesforce org needs:

- **Remote Site Setting** or **Named Credential** for the Allura Brain MCP endpoint URL
- **Apex Callout permission** on the running user's profile (if using Apex)
- **Network access** from Salesforce to the Allura Brain host

---

## 5. Impact on Beta Readiness

SC-2b is defined as:

> **"Trace one Mortagate decision path to an actual Brain write. A named Apex class or Flow writes `group_id = allura-mortgage`. If none exists, this is unbuilt work, not a bug."**

**SC-2b cannot pass today.** It is not a test failure — it is a test of unbuilt work. The criterion documents the gap honestly so it is not discovered during SC-8 with an analyst in the room.

**Revised sequencing (from GOAL-G2):** SC-4 → SC-2a → SC-2b. Confirm vectors are non-zero, then confirm search federates against data known to exist, then confirm the application produces that data on its own.

---

## 6. Recommendation

1. **Do not build this before beta.** ADR-17 is the governing decision. Allura Brain is dev-only for the pilot.
2. **Keep SC-2b as a documented finding**, not a pass/fail gate. It records the gap for the post-pilot roadmap.
3. **When Allura Brain wiring is scoped** (post-pilot, likely P3/P4 on the enterprise readiness roadmap), use this document as the build specification.
4. **Update the documentation** that implies Allura Brain is wired in production (README.md, AGENTS.md) to clarify that it is development orchestration only, per ADR-17.

---

**Source:** Repository-wide grep 2026-08-03; ADR-17; GOAL-G2-beta-readiness.md; ENTERPRISE-READINESS-ROADMAP.md §4.
