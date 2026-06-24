# Veridact — Mortgage Audit Replay & QC Platform

> _"Every decision has a receipt."_

Veridact is a governed mortgage audit replay and quality-control platform built on Salesforce. It enables a bank QC analyst to take an already-approved loan, replay the exact policy rules in force at approval time, map each rule to its supporting evidence, record pass/exception/violation findings, and seal an immutable audit receipt ready for regulators.

---

## Table of Contents

- [Product Overview](#product-overview)
- [Architecture](#architecture)
- [Repository Structure](#repository-structure)
- [Salesforce Application](#salesforce-application)
- [Agentforce AI Copilot](#agentforce-ai-copilot)
- [Demo Frontend](#demo-frontend)
- [Testing](#testing)
- [Deployment](#deployment)
- [Governance & Compliance](#governance--compliance)
- [Planning Documentation](#planning-documentation)
- [Development Setup](#development-setup)
- [Roadmap](#roadmap)
- [Operational Status](#operational-status)

---

## Product Overview

Veridact addresses a critical gap in mortgage lending: the inability to demonstrate, after the fact, that a loan decision was made correctly against the rules in force at the time. Traditional systems record the outcome but not the reasoning. Veridact records both.

### Core Capabilities

| Capability | Description |
|-----------|-------------|
| **Policy Replay** | Re-runs the exact versioned policy rules against stored loan facts to produce deterministic, reproducible results |
| **Evidence Mapping** | Maps each rule check to its supporting evidence document with SHA-256 hash verification |
| **Finding Management** | Records violations, exceptions, and missing-evidence findings with AI-drafted summaries |
| **Immutable Audit Trail** | Append-only `Decision_Event__c` and `Audit_Event__c` records — no UPDATE or DELETE permitted |
| **Audit Receipts** | Tamper-evident `Audit_Receipt__c` sealed at sign-off with illustrative hash for chain-of-custody |
| **Agentforce Copilot** | AI assistant that reads stored replay checks and explains findings in plain language (6th-grade reading level) |
| **Adverse Action Notices** | ECOA / Reg B compliant notices with specific principal reasons, FCRA score disclosure, and creditor identification |

### Regulatory Alignment

| Regulation | Coverage |
|------------|----------|
| **SR 11-7** (Model Governance) | Versioned `Policy_Version__c` with supersession chain and immutability after reference |
| **ECOA / Reg B** (12 CFR 1002.9) | Adverse Action Notice with specific principal reasons, anti-discrimination notice, creditor identity |
| **FCRA** (15 U.S.C. 1681m) | Score disclosure when consumer report is used |
| **ADA / Section 508** | WCAG 2.1 AA contrast, semantic color chips, `prefers-reduced-motion` support |

---

## Architecture

### Three-Layer Engine (ADR-5)

```
┌─────────────────────────────────────────────────────┐
│  LWC Auditor UI (6 screens)                         │
│  Queue → Case Review → Findings → Sign-off          │
│  + Analytics + Policy Versions + Admin              │
├─────────────────────────────────────────────────────┤
│  Apex Controllers (FLS-safe, USER_MODE)              │
│  AuditQueueController, CaseReviewController,        │
│  FindingController, SignoffController,               │
│  AnalyticsController, PolicyVersionsController       │
├─────────────────────────────────────────────────────┤
│  Pure Kernel (no DML, no SOQL)                      │
│  PolicyRuleEvaluator — 8 operators, worst-wins      │
│  AdverseActionService — ECOA/Reg B composition       │
│  LoanDiagnosisService — read-only agent narration   │
└─────────────────────────────────────────────────────┘
```

### Data Model

| SObject | Purpose | Records (live org) |
|---------|---------|-------------------|
| `Audit_Case__c` | A loan under audit | 629 |
| `Policy_Version__c` | Versioned rule set with supersession chain | 1 |
| `Policy_Rule__c` | Individual rules within a version | 10 |
| `Replay_Check__c` | Per-rule evaluation result with evidence | 10 |
| `Evidence_Item__c` | Document reference with SHA-256 hash | — |
| `Finding__c` | Violation/exception/missing-evidence | 1 |
| `Decision_Event__c` | Append-only audit event log | 3 |
| `Audit_Event__c` | Append-only system event log | 6 |
| `Audit_Receipt__c` | Tamper-evident sign-off receipt | 0 |
| `Agent_Action_Log__c` | AI agent action governance log | — |

### Key Architectural Decisions

| ADR | Decision |
|-----|----------|
| ADR-1 | Append-only audit, enforced in code (not field history) |
| ADR-2 | Worst-wins verdict precedence |
| ADR-3 | Missing fact → INDETERMINATE, never decline |
| ADR-4 | Rules are data, not code |
| ADR-5 | Three-layer engine with a pure kernel |
| ADR-6 | Deterministic governing-rule order |
| ADR-7 | Pre-check runs the same kernel, creates no record |
| ADR-9 | Semantic colors are chips, not text |
| ADR-20 | Auditor demo surface is LWC on Lightning Page |
| ADR-21 | Kernel decides; agent only narrates (read-only) |
| ADR-22 | Piecewise deploy for Agentforce on Dev Edition |
| ADR-23 | Agentforce agents not org-portable; manual re-bind |
| ADR-24 | KYC/OFAC are gating preconditions outside the kernel |

See `planning docs/RISKS-AND-DECISIONS.md` for full ADR registry and risk register.

---

## Repository Structure

```
mortagate/
├── force-app/main/default/      # Salesforce DX source — the shipping pilot app
│   ├── lwc/                      #   14 LWC auditor UI components
│   ├── classes/                  #   Apex: replay kernel, controllers, services
│   ├── objects/                  #   10 custom SObjects with fields, validation, triggers
│   ├── triggers/                 #   Immutability and versioning triggers
│   ├── bots/                     #   Agentforce agent definitions (4 variants)
│   ├── genAiPlugins/            #   Agentforce topic plugins
│   ├── genAiPlannerBundles/      #   Agentforce planner configurations
│   ├── genAiFunctions/           #   Invocable AI functions
│   ├── customMetadata/           #   Adverse Action config, pre-flight assumptions
│   ├── applications/             #   Salesforce app definitions
│   ├── flexipages/               #   Lightning page layouts
│   ├── permissionsets/           #   Veridact_Mortgage_Engine_Access
│   ├── staticresources/          #   Veridact brand tokens (CSS)
│   ├── tabs/                     #   Custom tabs
│   └── pages/                    #   Visualforce pages (receipts, notices)
├── demo/                         # Next.js demo frontend (9 pages)
│   ├── src/app/                  #   Landing, journey, scenarios, audit-gap,
│   │                             #   contact, notice, receipt, architecture
│   ├── src/components/veridact/  #   AccentBar, CtaButton, StatusChip
│   ├── src/engine/               #   Policy evaluator, personas
│   └── src/lib/                  #   Utilities
├── apps/veridact-frontend/       # Next.js auditor cockpit (parallel surface)
├── planning docs/                # Blueprint, requirements, architecture, risks
├── specs/                        # Agentforce agent specs (YAML)
├── manifest/                     # Salesforce deploy manifests
├── scripts/                      # Data and build scripts
├── my-project/                   # BMAD policies, skills, output
├── DEPLOY-REPORT.md              # Latest deploy report (2026-06-23)
├── mortagate.gates.json          # Phase gate checks
├── sfdx-project.json             # Salesforce DX project config
├── jest.config.js                # LWC Jest configuration
└── AGENTS.md                     # Team RAM harness configuration
```

---

## Salesforce Application

### Auditor Screens (6/6 built, verified on `mortagate-de`)

| Screen | LWC Component | Controller | Tests |
|--------|--------------|------------|-------|
| **Audit Queue** | `auditQueue` + `auditMetricCards` + `auditQueueFilters` + `auditQueueDatatable` | `AuditQueueController` | 6 Apex + 9 Jest |
| **Case Review** | `caseReview` | `CaseReviewController` | Jest + on-org |
| **Finding Detail** | `findingDetail` | `FindingController` | 11 Apex + Jest |
| **Sign-off Receipt** | `signoffReceipt` | `SignoffController` | Apex + Jest |
| **Analytics** | `auditAnalytics` | `AnalyticsController` | 5 Apex + Jest |
| **Policy Versions + Admin** | `policyVersions` + `auditAdmin` | `PolicyVersionsController` + `AdminController` | 8 Apex + 8 Jest |

### Supporting Components

| Component | Purpose |
|-----------|---------|
| `riskBadge` | Visual risk-tier chip (HIGH/MEDIUM/LOW) |
| `glossaryTerm` | Plain-language tooltip for jargon (DTI, LTV, FICO, rule codes) |

---

## Agentforce AI Copilot

The Veridact Auditor Copilot (`Veridact_Auditor_Copilot_v4`) is a Salesforce Agentforce agent that provides plain-language explanations of audit findings.

### How It Works

1. The agent reads stored `Replay_Check__c` records (never re-runs the replay)
2. It composes a plain-language summary of what's wrong with the loan
3. Every action writes an append-only `Agent_Action_Log__c` record
4. The agent is read-only — it cannot approve, reject, or modify any record

### Agent Variants

| Agent | Target User | Bot |
|-------|-------------|-----|
| `Veridact_Auditor_Copilot_v4` | Internal auditor | `Veridact_Auditor_Copilot_v4` |
| `Veridact_Auditor_CLI` | CLI/API consumer | `Veridact_Auditor_CLI` |
| `Veridact_Auditor_Employee` | Employee portal | `Veridact_Auditor_Employee` |
| `Veridact_Auditor_Internal` | Internal tools | `Veridact_Auditor_Internal` |

### R-10 (Open)

Final action-wiring to `LoanDiagnosisService` requires Agent Builder 3-click handoff in Salesforce Setup UI. No code change — configuration only.

---

## Demo Frontend

A Next.js demo application in `demo/` showcases the Veridact product story with 9 pages:

| Page | Route | Purpose |
|------|-------|---------|
| Landing | `/` | Product overview with CTA |
| Journey | `/journey` | Auditor workflow visualization |
| Scenarios | `/scenarios` | Example audit scenarios with personas |
| Scenario Detail | `/scenarios/[id]` | Individual scenario walkthrough |
| Audit Gap | `/audit-gap` | Gap analysis |
| Architecture | `/architecture` | System architecture overview |
| Notice | `/notice/[id]` | Adverse action notice preview |
| Receipt | `/receipt/[id]` | Audit receipt preview |
| Contact | `/contact` | Contact page |

---

## Testing

### Test Results (verified 2026-06-23 on `mortagate-de`)

| Suite | Tests | Pass Rate | Time |
|-------|-------|-----------|------|
| Apex `RunLocalTests` | 140 | 100% | 35.3s |
| LWC Jest | 53 (12 suites) | 100% | 1.0s |

### Running Tests

```bash
# LWC Jest unit tests
npm run test:unit

# Apex tests on org
sf apex run test --target-org mortagate-de --test-level RunLocalTests --result-format human

# Apex tests with code coverage
sf apex run test --target-org mortagate-de --test-level RunLocalTests --code-coverage
```

---

## Deployment

### Deploy to `mortagate-de`

```bash
# Authenticate
sf org login web --alias mortagate-de --set-default

# Deploy (piecewise strategy — see DEPLOY-REPORT.md)
sf project deploy start --target-org mortagate-de --source-dir force-app/main/default/classes
sf project deploy start --target-org mortagate-de --source-dir force-app/main/default/objects
sf project deploy start --target-org mortagate-de --source-dir force-app/main/default/lwc
# ... see DEPLOY-REPORT.md for full piecewise deploy procedure

# Verify
sf apex run test --target-org mortagate-de --test-level RunLocalTests
sf data query --target-org mortagate-de --query "SELECT COUNT() FROM Audit_Case__c"
```

### Piecewise Deploy (ADR-22)

Agentforce metadata (`bots`, `genAiPlannerBundles`, `aiEvaluationDefinitions`) requires manual Setup UI configuration per org (ADR-23). Standard `sf project deploy start` with the full `force-app/` directory may fail with `UNKNOWN_EXCEPTION` due to cross-references in the Agentforce metadata graph. Deploy non-Agentforce metadata first, then configure Agentforce via Setup UI.

See `DEPLOY-REPORT.md` for the full piecewise deploy procedure and troubleshooting.

---

## Governance & Compliance

### Carlos Guidelines

All development follows the Professor Carlos documentation kata:
1. Blueprint / Product Intent
2. Solution Architecture
3. Design Documents
4. Requirements Matrix
5. Risks & Decisions
6. Data Dictionary

No implementation without source-of-truth alignment. No "done" without evidence.

### Allura Brain Integration

All agent actions log to Allura Brain with `group_id: allura-mortgage`. Memory operations are append-only and governed by RuVix policy.

### Audit Immutability (ADR-1)

- `Decision_Event__c` — INSERT only; UPDATE and DELETE blocked by trigger
- `Audit_Event__c` — INSERT only; UPDATE and DELETE blocked by trigger
- `Audit_Receipt__c` — Single guarded write at sign-off; no second receipt permitted
- `Agent_Action_Log__c` — Every AI agent action logged

---

## Planning Documentation

All planning artifacts live in `planning docs/`:

| Document | Purpose | Last Updated |
|----------|---------|-------------|
| `BLUEPRINT.md` | Product vision, identity, and scope | 2026-06-23 |
| `SOLUTION-ARCHITECTURE.md` | System architecture, data flow, boundaries | 2026-06-23 |
| `REQUIREMENTS-MATRIX.md` | Requirement → implementation → verification traceability | 2026-06-23 |
| `RISKS-AND-DECISIONS.md` | ADR registry and risk register | 2026-06-23 |
| `DATA-DICTIONARY.md` | Canonical field definitions, enums, relationships | 2026-06-23 |
| `copilot-instructions.md` | AI agent operating instructions | 2026-06-11 |

Design deep-dives in `my-project/_bmad-output/planning/`:
- `DESIGN-onboarding-ux.md`
- `DESIGN-policy-engine.md`
- `DESIGN-adverse-action.md`
- `DESIGN-kyc-ofac.md`

---

## Development Setup

### Prerequisites

- Node.js 24+ and npm
- Salesforce CLI (`sf`) v2.137+
- `@salesforce/sfdx-lwc-jest` (installed via `npm install`)

### Install

```bash
cd mortagate
npm install
```

### Authenticate Org

```bash
sf org login web --alias mortagate-de --set-default
sf org display --target-org mortagate-de
```

### Run Tests

```bash
npm run test:unit            # LWC Jest
sf apex run test --target-org mortagate-de --test-level RunLocalTests
```

### Deploy

```bash
sf project deploy start --target-org mortagate-de --source-dir force-app
```

### Demo Frontend

```bash
cd demo
npm install
npm run dev        # local dev server
npm run build      # production build
npm run lint       # eslint
```

### Parallel Next.js Cockpit

```bash
cd apps/veridact-frontend
npm install
npx tsc --noEmit    # type-check
npm test            # vitest
npm run dev         # local dev server
```

---

## Roadmap

### Completed

- ✅ 6/6 auditor screens (Queue, Case Review, Findings, Sign-off, Analytics, Policy Versions + Admin)
- ✅ Append-only audit kernel with 8-operator policy evaluator
- ✅ Agentforce Copilot agent (4 variants) — created, activated, plain-language topics
- ✅ Adverse Action Notice (ECOA / Reg B / FCRA) — CR-1 through CR-4
- ✅ Full deployment to `mortagate-de` — 140/140 Apex tests, 53/53 Jest tests
- ✅ Demo Next.js frontend (9 pages)
- ✅ Git merge to main, v1-demo tag

### In Progress

- 🟡 R-10: Agentforce action-wiring (Setup UI 3-click handoff)
- 🟡 R-Leo: Plain-language persona re-test (UX panel)
- 🟡 Demo frontend deployment (Vercel or Salesforce Community)

### Deferred

- ⬜ CR-5: Adverse Action delivery + 30-day proof mechanism
- ⬜ CI/CD pipeline for Salesforce metadata
- ⬜ Security review / penetration test
- ⬜ Production org provisioning (Dev Edition → Enterprise)
- ⬜ Borrower surface (FR-1 through FR-9 — deprecated, pending product decision)

---

## Operational Status

**Last verified:** 2026-06-23

| Component | Status |
|-----------|--------|
| Salesforce org `mortagate-de` | ✅ Connected, 629 audit cases |
| Apex tests (RunLocalTests) | ✅ 140/140 PASS (100%) |
| LWC Jest tests | ✅ 53/53 PASS (12 suites) |
| Agentforce Copilot | ✅ Activated (R-10 wiring pending) |
| GitHub repo | ✅ `main` at `d715956`, tag `v1-demo` |
| Demo frontend | ✅ Built (9 pages, not deployed) |
| Planning docs | ✅ All 6 Carlos docs present and current |

---

## Sources of Truth

- **Code** — this repository
- **Product & governance** — Notion
- **Visual design** — Figma
- **Agent memory** — Allura Brain (`allura-mortgage`)

---

## License

Proprietary. All rights reserved. © Veridact / Allura-Ecosystem.