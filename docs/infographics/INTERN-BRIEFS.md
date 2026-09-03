# Mortgate Infographic Briefs — Intern Handoff

Two new infographics to complete the Mortgate visual family. Match the style of the existing six (same brand system, same layout language). All claims below are **source-grounded** — do not add, soften, or strengthen anything. If a claim feels wrong, ask before drawing.

---

## Style spec (match the existing family)

| Element | Spec |
|---|---|
| Background | Soft cream / off-white (`#FAF9F6`-family) |
| Primary text | Dark navy / near-black (`#1A2B4A`-family) |
| Accents | Bright blue, warm orange, forest green — one color per semantic group |
| Headline | Large, bold, dark sans-serif (Inter-family) |
| Subhead | Smaller, regular weight, with a short orange horizontal accent line |
| Containers | Soft rounded "blob" shapes, flat fills, thin borders |
| Icons | Simple flat line-art, color-matched to their section |
| Decorative | Abstract arch + circle shapes in top-right and bottom-right corners only |
| Footer | `allura` logo · Allura™ 2024 · All rights reserved. · allurama.com (left) · Implementation references: github.com/Allura-Ecosystem (right) |
| Spelling | **Mortgate** is the product name (no "a" — intentional). Do not "fix" it. |

---

## Brief 7 — "Research first. Decisions documented."

**Purpose:** Show the engineering-leadership story: we researched the landscape, studied reference architectures, and made documented trade-offs. This is the "go-to reference" evidence.

**Headline options (pick one):**
- *Research first. Decisions documented.*
- *What we studied. What we kept. What we rejected.*

**Subhead:** *Mortgate's design comes from market research and reference-architecture analysis — with every adoption and rejection recorded.*

### Layout: three panels, left to right

**Panel 1 — Market research** (blue accent)
- Icon: magnifying glass over documents
- Copy:
  - *6 parallel searches (Tavily + Exa), 40+ sources analyzed*
  - *Mortgage QC landscape: ACES, Black Knight, TRUE.ai, MetaSource, TENA*
  - *Regulatory context: consent-order history, audit-program requirements*
  - *Source-verified: every claim traced to a dated source*

**Panel 2 — Reference architectures** (orange accent)
- Icon: two overlapping blueprints
- Copy — **Adopted:**
  - *Provenance and evidence tracing*
  - *Role-scoped access and PII masking*
  - *Hash-chained audit-event design*
  - *Evaluation / UI / API / test separation*
- Copy — **Rejected:**
  - *Automated final mortgage decisioning*
  - *Their stacks (OpenShift, Keycloak, MLflow, MinIO, Bedrock)*
  - *Simulated compliance content as policy*

**Panel 3 — Design outcome** (green accent)
- Icon: document with checkmark
- Copy:
  - *Skills-only package — no connector, no database, no decision engine*
  - *Read-only by design*
  - *Human-supervised evidence review*
  - *Future connector: Entra-secured, read-only MCP surface*

**Bottom tagline:** *The methodology is the product. The decisions are on record.*

**Allowed claims:** everything above. **Forbidden:** any claim that the reference projects' code, policies, or data were imported; any claim of production deployment; any vendor affiliation.

---

## Brief 8 — "The enterprise way."

**Purpose:** Show how we ship governed agentic work: a four-phase release gate, automated validation, and an explicitly human-only final gate. This is the harness/governance evidence.

**Headline options (pick one):**
- *The enterprise way.*
- *How Mortgate ships: gates, validation, and a human at the end.*

**Subhead:** *A four-phase release gate — automated where possible, human where it must be.*

### Layout: four phase cards, left to right, with a status strip

**Phase 1 — Package structure** (blue accent)
- Icon: puzzle piece / package box
- Copy: *Manifest parses · four skills with frontmatter · icon assets valid*

**Phase 2 — Planning docs** (orange accent)
- Icon: clipboard with checklist
- Copy: *Product brief · PRD with numbered requirements · epic in live backlog*

**Phase 3 — Build & local CI** (green accent)
- Icon: gear / terminal
- Copy: *Microsoft 365 Agents Toolkit validation · package builds to zip · offline package + catalog-export validators · doc-link checks · gitleaks secret scan*

**Phase 4 — Tenant validation** (dark navy accent, marked **MANUAL**)
- Icon: person with checkmark
- Copy: *Upload to a Frontier-enabled tenant · all four skills invocable · licensed human required — cannot be automated*

**Bottom strip — the discipline:**
- *ADR decision records: every pivot documented (ADR-36)*
- *Evidence-metadata contract: provenance shape fixed before the connector exists*
- *Catalog export: pinned source commit, allowlisted files, fixes return upstream*

**Bottom tagline:** *Automated where possible. Human where it must be.*

**Allowed claims:** everything above. **Forbidden:** claiming the tenant gate has passed (it is manual and pending); claiming CI runs the toolkit validation (it is local-only today); any "production-ready" language.

---

## Delivery notes

- Output: PNG at 1600px+ wide, matching the family's aspect ratio.
- Keep the human-review step visually distinct (dotted connector) in both — it is the brand's safety signal.
- Both briefs must read as *engineering evidence*, not marketing. No superlatives.
- Deliver source files (Figma/SVG) alongside the PNGs so copy can be edited without redrawing.
