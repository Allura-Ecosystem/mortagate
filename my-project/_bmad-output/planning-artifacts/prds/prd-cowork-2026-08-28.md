# PRD: Mortgate Evidence Review for Microsoft Copilot Cowork

> [!NOTE]
> **AI-Assisted Documentation**
> Drafted with AI assistance from the shipped module source, PR #6, and ADR-34.
> Requirements below are reverse-specified from working code — they describe what the
> module does, and each is checkable against it. Closes EP-6/US-6.2.

**Created:** 2026-08-28 · **Owner:** Sabir Asheed · **Epic:** EP-6 · **Goal:** G-3
**Brief:** `../product-brief-cowork.md` · **Governing ADR:** ADR-34 (Cowork outside the
ADR-33 pilot-scope freeze)

> **Separate from the CaseFile PRD.** `prd-Mortagate-2026-06-14/prd.md` covers the
> Salesforce audit product and its 28 FRs. This PRD's requirements are numbered
> **CW-n** so the two namespaces never collide. Nothing here touches `mortagate-de`.

---

## 1. Vision

An authorized mortgage employee reviews a loan file's evidence inside Microsoft 365,
in plain language, and gets back an accurate picture of what is present, missing,
ambiguous, or conflicting — plus a draft audit packet for a human reviewer. The tool
never decides.

## 2. Target User

Internal mortgage employee (processor, QC staff, reviewer) on a Frontier-enabled
Microsoft 365 Copilot tenant. Non-engineer. Expected to know mortgage documents, not
the implementation. First cohort is the pilot group defined in
`../../planning/DESIGN-cowork-pilot-onboarding.md`.

## 3. Functional Requirements

### Skill 1 — Mortgage case onboarding

| ID | Requirement | Acceptance criteria |
|---|---|---|
| CW-1 | Start an evidence-review task from a plain-language request | Employee types "start an evidence review for this file" with documents attached; module confirms the task scope without requiring framework vocabulary |
| CW-2 | State scope and boundaries at onboarding | The employee is told, in the first exchange, what the module will and will not do — specifically that it does not decide, price, or notify |
| CW-3 | Operate on user-attached documents only | No request for a case ID, system credential, or external lookup; module never claims access to a loan system |

### Skill 2 — Loan file evidence review

| ID | Requirement | Acceptance criteria |
|---|---|---|
| CW-4 | Inventory attached documents | Every attached document is listed with its identified type; unidentifiable documents are reported as unidentified, not guessed |
| CW-5 | Identify missing evidence | Against a known-incomplete synthetic file, the missing-document list is accurate — no fabricated "missing" items, no silent omissions |
| CW-6 | Identify ambiguous evidence | Documents that are illegible, undated, or unattributable are flagged rather than treated as valid |
| CW-7 | Identify conflicting evidence | Where two documents disagree on a material fact (e.g. income), both sources and the conflict are reported |
| CW-8 | Never infer a fact from absent evidence | A missing document yields "missing", never an assumed value — mirrors ADR-3's INDETERMINATE discipline on the CaseFile side |

### Skill 3 — Policy replay review

| ID | Requirement | Acceptance criteria |
|---|---|---|
| CW-9 | Compare a **supplied** policy replay against evidence | Module reads replay results provided by the employee; it does not compute, evaluate, or originate policy outcomes |
| CW-10 | Map each replay result to its supporting evidence | Each compared result cites the document(s) supporting or failing to support it |
| CW-11 | Report unsupported replay results | A replay result with no corresponding evidence is reported as unsupported, not accepted |
| CW-12 | Never restate a replay result as a decision | Output language distinguishes "the supplied replay reports X" from any endorsement of X |

### Skill 4 — Audit packet draft

| ID | Requirement | Acceptance criteria |
|---|---|---|
| CW-13 | Draft a reviewer-ready audit packet | Packet contains document inventory, missing/ambiguous/conflicting findings, and replay comparison |
| CW-14 | Mark every packet as a draft for human review | No packet presents itself as final, approved, or authoritative |
| CW-15 | Cite evidence for every finding | Each finding references the document it came from; no uncited assertions |

### Cross-cutting — refusal boundaries

| ID | Requirement | Acceptance criteria |
|---|---|---|
| CW-16 | Refuse to approve or deny a loan | Request to approve/deny is declined with a clear reason; no conditional or hedged approval |
| CW-17 | Refuse to set a rate or credit term | As above |
| CW-18 | Refuse to override policy | As above |
| CW-19 | Refuse to issue an adverse-action notice | As above — ECOA/Reg B exposure; cf. ADR-10 and the R-7 counsel gate on the CaseFile side |
| CW-20 | Refuse to send a borrower message | As above; module never communicates outside the employee's session |
| CW-21 | Refuse to write to a loan system | As above; no write path exists to Salesforce or any LOS |
| CW-22 | Refusals are understandable to a non-engineer | Refusal explains the boundary in plain language, and where possible names what the employee *can* do instead |

## 4. Non-Goals (Explicit)

- Any credit decision, pricing, or term-setting
- Adverse-action notice generation or delivery
- Borrower-facing communication of any kind
- Writing to Salesforce, an LOS, or any system of record
- Computing policy outcomes (only comparing supplied ones)
- Live case/evidence retrieval — gated behind the Entra-secured read-only MCP connector, which is unbuilt and requires its own ADR per ADR-34
- Production borrower data during pilot

## 5. MVP Scope

The four skills above, distributed as a Cowork app package, validated on a
Frontier-enabled tenant, exercised by the pilot cohort against synthetic documents in
a private "Only you" workspace. Skills-only — no connector, no live data, no
production credentials.

## 6. Constraints and Guardrails

| Constraint | Impact |
|---|---|
| Cowork is a Frontier preview | Requires Frontier-enabled tenant + licensed user; not GA |
| Tenant-side validation unrun | Needs interactive M365 sign-in (US-6.6) — cannot be automated or agent-executed |
| Synthetic documents only during pilot | Private "Only you" upload; no production borrower data |
| No Allura Brain integration | Module has zero `group_id` usage and no MCP memory calls — verified by grep, recorded in ADR-34 |

## 7. Verification Status

| Check | Result |
|---|---|
| Microsoft 365 Agents Toolkit manifest validation | Pass |
| Cowork ZIP package build | Pass |
| Offline package structural validator | Pass |
| Mortgate LWC unit tests | Pass — 13 suites / 72 tests |
| GitHub secret scan | Pass |
| GitHub Salesforce metadata validation | Pass |
| GitHub agent-definition validation | Pass |
| GitHub LWC unit-test CI | Pass |
| **Tenant-side package validation** | **NOT RUN** — US-6.6, requires interactive M365 sign-in |

> The CW-n acceptance criteria above are **specified, not yet independently tested**.
> The passing checks are build/CI-level; behavioural verification of CW-1..CW-22 is
> pilot work (US-6.7).

## 8. Open Questions

1. Who provisions Frontier-tenant access per pilot-cohort member? (US-6.4)
2. Shared synthetic-document fixture set, or self-supplied? (US-6.4)
3. Where does pilot feedback get captured to feed US-6.8? (US-6.4)
4. Does the connector go/no-go need counsel review before live evidence retrieval, given it moves the module closer to production data? (US-6.8)

## 9. Traceability

| Requirement group | Story | Skill source |
|---|---|---|
| CW-1..CW-3 | EP-6 (module shipped in PR #6) | `microsoft-cowork/appPackage/skills/mortgage-case-onboarding/` |
| CW-4..CW-8 | EP-6 | `.../loan-file-evidence-review/` |
| CW-9..CW-12 | EP-6 | `.../policy-replay-review/` |
| CW-13..CW-15 | EP-6 | `.../audit-packet-draft/` |
| CW-16..CW-22 | EP-6 | `.../*/references/safety-boundaries.md` (all four skills) |
