---
name: carlos-guidelines
description: "Carlos Guidelines documentation discipline. Six required docs (BLUEPRINT, SOLUTION-ARCHITECTURE, DESIGN-*, REQUIREMENTS-MATRIX, RISKS-AND-DECISIONS, DATA-DICTIONARY) with AI disclosure, B#/F# traceability, and cross-references. Load BEFORE writing any code in the Mortgate project."
---

# Carlos Guidelines — Documentation Discipline

The Carlos Guidelines is the documentation standard for the **Mortgage Approval Engine** project. Six artifacts must exist and be kept in sync with code.

> **AI-Assisted Documentation**
> Portions of this skill were drafted with AI assistance. Defer to source code and team consensus.

---

## When to Use This Skill

Load this skill whenever:

- Starting a new Mortgate story or feature
- Reviewing a PR that touches code, schema, or APIs
- Updating the Requirements Matrix or Data Dictionary
- Writing an ADR
- Auditing documentation drift

If a task ships code in the Mortgate project, this skill applies.

---

## The Six Required Docs

| Document | Purpose | Owner | Update Trigger |
|---|---|---|---|
| `BLUEPRINT.md` | Single source of design intent — B#/F#, data model, architecture | Brooks | Story start, B# change |
| `SOLUTION-ARCHITECTURE.md` | System topology, external actors, interface catalogue, risk traceability | Brooks | Architecture change |
| `DESIGN-*.md` | Per-area deep dive: API contracts, state machines, business rules | Knuth / Woz | Per-area design |
| `REQUIREMENTS-MATRIX.md` | B# → F# → Use Case → API traceability | Brooks | B#/F# change |
| `RISKS-AND-DECISIONS.md` | AD-## decisions + RK-## risk register | Brooks | ADR, risk added |
| `DATA-DICTIONARY.md` | Canonical field-level reference for every entity and event | Knuth | SObject field change |

**Rules:**

- Every AI-drafted doc must include the AI disclosure notice
- Cross-reference all documents with relative Markdown links
- Requirements Matrix and Data Dictionary updated **in the same PR** as schema/API changes
- Defer to JSON schemas and source code over documentation when conflicts arise

---

## Document Skeletons

### BLUEPRINT.md

```markdown
# {Project} — Blueprint

> [!NOTE]
> **AI-Assisted Documentation**
> ...

## B1. Project Identity
{project, brand, platform, org, alias, owner, memory}

## B2. Design Principles
{7-10 principles, e.g., Mobile-first, One-thing-per-screen, Append-only audit}

## B3. User Journey
{per-screen breakdown with LWCs and decision logic}

## B4. Data Model
{core SObjects and their relationships}

## B5. B# / F# Catalogue
| B# | Description | F# | Implementation |
|---|---|---|---|
| B-001 | Borrower can capture intent | F-001, F-002 | c-intent-capture LWC + IntentController Apex |
```

### SOLUTION-ARCHITECTURE.md

```markdown
# {Project} — Solution Architecture

## 1. System Topology
{Experience Cloud, LWC, Apex, Flows, integrations}

## 2. External Actors
{borrower, loan officer, underwriter, doc provider, credit bureau}

## 3. Interface Catalogue
| ID | Type | Endpoint / Method | Auth | Owner |
|---|---|---|---|---|
| API-001 | REST | /services/apexrest/Application | OAuth | Knuth |

## 4. Risk Traceability
{RK-## → mitigation → ADR reference}
```

### REQUIREMENTS-MATRIX.md

```markdown
# Requirements Matrix

## B# → F# → Use Case → API → Test
| B# | F# | Use Case | API / Component | Apex Test | LWC Test |
|---|---|---|---|---|---|
| B-001 | F-001 | UC-001: Capture intent | IntentController.capture | IntentControllerTest.testCapture | intent-capture.test.js |
```

### RISKS-AND-DECISIONS.md

```markdown
# Risks and Decisions

## AD-## Decisions (append-only)
| ID | Date | Title | Status | Owner | Rationale |
|---|---|---|---|---|---|
| AD-001 | 2026-04-01 | Use append-only audit for Decision_Event__c | Accepted | Brooks | {rationale} |

## RK-## Risk Register
| ID | Risk | Likelihood | Impact | Mitigation | Owner |
|---|---|---|---|---|---|
| RK-001 | Trigger cascade on Application__c update | Medium | High | Use before-save Flow + bulkification | Woz |
```

### DATA-DICTIONARY.md

```markdown
# Data Dictionary

## {SObject Name}

| Field | API Name | Type | Length | Required | Description | Notes |
|---|---|---|---|---|---|---|
| {Label} | {API_Name__c} | Picklist | - | Yes | {desc} | {options} |
```

### DESIGN-{area}.md

```markdown
# {Area} Design — {Aspect}

## State Machine
{states, transitions, guards}

## API Contracts
{per endpoint: request, response, errors}

## Business Rules
{numbered, traceable to B#/F#}

## Edge Cases
{boundary conditions, what to do}
```

---

## Cross-Referencing Rules

- Every doc must link to its peers (BLUEPRINT ↔ MATRIX ↔ DATA-DICT ↔ RISKS)
- Use relative links: `[BLUEPRINT](BLUEPRINT.md#b5-b-f-catalogue)`
- No orphan documents
- When a B# changes, the matrix updates in the same PR
- When a SObject field changes, the data dictionary updates in the same PR

---

## Source of Truth

When in doubt:

1. **Schema** (SObject metadata, package.xml)
2. **Code** (Apex, LWC, Flow XML)
3. **Docs**

Code wins over docs. Docs are a map; code is the territory.

---

## AI Disclosure Notice

Every AI-drafted doc must start with:

```markdown
> [!NOTE]
> **AI-Assisted Documentation**
> Portions of this document were drafted with the assistance of an AI language model.
> Content has not yet been fully reviewed — this is a working design reference, not a final specification.
```

Once reviewed, the disclosure stays (transparency > removal).

---

## Mortgate-Specific Templates

The project has these existing design docs:

- `DESIGN-onboarding-ux.md` — 6-screen borrower journey
- `DESIGN-policy-engine.md` — rules-as-data architecture
- `DESIGN-adverse-action.md` — adverse action notice workflow

When creating new DESIGN-*.md files, follow the same skeleton as these.

---

## Non-Negotiables

- Six docs exist before any code lands
- AI disclosure notice on AI-drafted content
- Cross-references, no orphans
- Source of truth: Schema > Code > Docs
- Risk Register and Decision Log are append-only
- Risks & Decisions updated when architectural decisions are made
