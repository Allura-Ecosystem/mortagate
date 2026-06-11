# ENTERPRISE READINESS ROADMAP

> [!NOTE]
> **AI-Assisted Documentation**
> Portions of this document were drafted with the assistance of an AI language model.

The honest distance between what exists today (a well-architected proof-of-concept) and a system that could originate a real mortgage at an enterprise. This is not a punch list of code — several gaps are **vendor contracts** or **legal/compliance** dependencies that no amount of Apex closes.

---

## 1. Where We Actually Are

| Layer | State | Verified? |
|---|---|---|
| Decision kernel (3-layer Apex) | Built | ❌ never run (no org) |
| Append-only audit + rule versioning | Built | ❌ tests written, not executed |
| 6 LWC screens + brand skin | Built | 🟡 8 Jest tests green; never on a device |
| Decision Receipt PDF (FR-18) | Built | 🟡 controller tests written, not run |
| Borrower journey (Flow orchestration) | **Not built** | — |
| Compliance — Adverse Action Notice (ECOA/Reg B + FCRA) | 🟡 generator built (FR-19) | ❌ tests written, not run; ⚖️ counsel sign-off pending |
| Compliance — rest (Fair Lending, HMDA, GLBA, licensing) / security / PII | **Not started** | — |
| Integrations (bureau, income, docs, e-sign) | **Not started** | — |
| Ops / CI-CD / monitoring | **Not started** | — |

**Realistic completeness for an enterprise mortgage origination system: ~15–25%.** The architecture is enterprise-quality; the surface area covered is a vertical slice, and that slice is unverified.

**Dependency legend:** 🧱 code (we can do it) · 🤝 vendor (contract/procurement) · ⚖️ legal/compliance (counsel/officer sign-off) · 🔑 human action (e.g. org login)

---

## 2. The Gate (blocks everything below)

**R-1 — Authenticate an org.** `sf org login web --alias mortagate-de` → deploy → `sf apex run test -l RunLocalTests`. 🔑 ~15 min, human-only. Until this passes, *nothing* in this repo is verified and no phase below can begin. **This is the single highest-leverage action.**

---

## 3. Phases

### P0 — Verify what exists (days) 🔑🧱
Make the current slice real before adding to it.
- Authenticate org, deploy all metadata, resolve deploy errors.
- Run full Apex suite; reach a real coverage number (target ≥85% on kernel).
- Build + activate the `Mortagate_Borrower_Journey` Screen Flow and the internal Decision-Promotion (HITL) Flow; validate fault paths and the 200-record bulk path *against the org*.
- Tap the journey on a real phone (375px).
- **Exit:** every 🟡 in §1 flips to ✅ or a logged defect.

### P1 — Compliance (weeks–months) ⚖️🧱 — *the true blocker for a lending product*
None of this is optional for a regulated mortgage system.
- **Adverse Action Notice (ECOA / Reg B):** 🟡 **partially built** — the compliant *notice generator* now exists (`AdverseActionService` + `AdverseActionNoticeController` + `AdverseActionNotice.page` PDF + `Adverse_Action_Config__mdt`; specific reasons from rule explanations, verbatim §701(a) notice, FCRA score block; FR-19 / CR-1..4; see DESIGN-adverse-action.md). Still owned by compliance/legal: **counsel sign-off** that the wording is sufficient, **delivery + proof within 30 days** (HITL), and the **consumer reporting agency identity** (arrives with P3). The code half is done with no vendor; the ⚖️ half remains. ⚖️🧱
- **Fair Lending / disparate-impact** review of the rule set; document that no rule uses a prohibited basis. ⚖️
- **HMDA** data capture + reporting fields. ⚖️🧱
- **GLBA safeguards**, record-retention schedule, consent capture. ⚖️🧱
- **State lending licensing** applicability review. ⚖️
- **Exit:** compliance officer sign-off; adverse-action artifact generated from a real decline.

### P2 — Security & PII (weeks) 🧱
- Permission sets + profiles; least-privilege model for borrower / officer / admin / guest.
- Experience Cloud guest-user sharing model for the public site (the welcome/pre-check path).
- **Shield Platform Encryption** (or equivalent) for SSN, income, assets. 🤝 (Shield is a paid add-on)
- FLS/CRUD audit across **all** Apex (kernel currently relies on `with sharing`; only the receipt controller enforces FLS explicitly).
- Secrets/Named Credentials for any callout.
- **Exit:** security review passes; PII encrypted at rest; FLS enforced end-to-end.

### P3 — Integrations (months) 🤝🧱 — *most of real origination*
Today, facts like FICO are *assumed to already exist*. Real systems fetch them.
- **Credit bureau** pull (Experian/Equifax/TransUnion or a broker). 🤝
- **Income/asset verification** (Plaid, AccountChek, The Work Number). 🤝
- **Document extraction** (OQ-2 — OCR/AI for paystubs, W-2s, bank statements). 🤝🧱
- **e-Sign** (DocuSign/Adobe). 🤝
- **LOS / core integration** — nCino (in-org SOQL/Apex) or Fiserv (API/ETL), per the integration analysis. 🤝🧱
- **Exit:** a decision runs on *fetched* facts, not seeded ones.

### P4 — Data model depth (weeks) 🧱
- Co-borrower / joint applications; full assets, liabilities, employment-history, property structures.
- **Exit:** model supports a realistic multi-borrower file.

### P5 — Operational readiness (weeks) 🧱
- Logging/error framework (e.g. Nebula Logger or platform-event logging).
- **CI/CD pipeline** (GitHub Actions: validate → scratch-org test → deploy); branch strategy; packaging (unlocked package).
- Monitoring/observability, DR plan, runbook, SLA, support model.
- Accessibility audit (screen reader + axe), not just Jest.
- **Exit:** changes ship through a gated pipeline; the system is observable and recoverable.

---

## 4. Allura Governance Wiring (cross-cutting) 🧱
Today the Allura invariants (group_id contract, append-only Postgres, Neo4j SUPERSEDES, HITL promotion) are **mirrored in the Salesforce design but not wired**. If Allura is the system of record/governance, P1–P5 each need: explicit `group_id` (`allura-mortgage`) stamping, the decision-event mirror into append-only Postgres, the rule-version mirror into Neo4j SUPERSEDES, and the curator:approve HITL hook on promotion.

---

## 5. The Distance, Summarized

| Phase | Theme | Rough size | Hardest dependency |
|---|---|---|---|
| P0 | Verify the slice | days | 🔑 org login |
| P1 | Compliance | weeks–months | ⚖️ legal sign-off |
| P2 | Security & PII | weeks | 🤝 Shield licensing |
| P3 | Integrations | months | 🤝 vendor contracts |
| P4 | Data model depth | weeks | 🧱 |
| P5 | Ops / CI-CD | weeks | 🧱 |

**Bottom line:** the build is a credible foundation and an excellent demo. Reaching enterprise is a **multi-quarter, multi-person program**, and its critical path runs through **legal/compliance (P1)** and **vendor integrations (P3)** — not through more Apex. The most valuable next step remains P0: log in and verify what's already here.
