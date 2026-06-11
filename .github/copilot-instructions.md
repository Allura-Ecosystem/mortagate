# Mortgage Approval Engine — AI Instructions

> [!NOTE]
> **AI-Assisted Documentation**
> Portions of this document were drafted with the assistance of an AI language model (GitHub Copilot).
> Content has not yet been fully reviewed — this is a working design reference, not a final specification.

---

## Project Context

**Project:** Salesforce Community Mortgage Approval Engine (Allura Tuned)
**Platform:** Salesforce (Experience Cloud, Flows, Apex, LWC)
**Documentation Standard:** Carlos Guidelines (AI-GUIDELINES.md)

---

## 1. Documentation Requirements (Carlos Guidelines)

Before writing any code, produce these six artifacts using the templates in `guidelines/templates/`:

| Document | Purpose |
|----------|---------|
| `planning docs/BLUEPRINT.md` | Single source of design intent — B#/F# requirements, data model, architecture |
| `planning docs/SOLUTION-ARCHITECTURE.md` | System topology, external actors, interface catalogue, risk traceability |
| `planning docs/REQUIREMENTS-MATRIX.md` | B# → F# → Use Case → API traceability |
| `planning docs/RISKS-AND-DECISIONS.md` | AD-## decisions + RK-## risk register with status |
| `planning docs/DATA-DICTIONARY.md` | Canonical field-level reference for every entity and event |
| `planning docs/copilot-instructions.md` | AI instructions, Flow/LWC/Apex standards, governance |

DESIGN-* deep dives and other BMad artifacts live in `my-project/_bmad-output/planning/`.

**This is a BMad project.** All output goes to `my-project/_bmad-output/` (planning/, implementation/, test/). Never write to `superpowers/` or `docs/superpowers/`.

**Rules:**
- Every AI-drafted doc must include the AI disclosure notice
- Cross-reference all documents with relative Markdown links
- Requirements Matrix and Data Dictionary updated in the same PR as schema/API changes
- Defer to JSON schemas and source code over documentation when conflicts arise

---

## 2. Salesforce Flow Development Standards

### Phase 1 — Confirm Flow is the Right Tool

| Requirement fits... | Use instead |
|---|---|
| Simple field calculation with no side effects | Formula field |
| Input validation on record save | Validation rule |
| Aggregate/rollup across child records | Roll-up Summary field or trigger |
| Complex Apex logic, callouts, or high-volume processing | Apex (Queueable / Batch) |
| All of the above ruled out | **Flow** ✓ |

### Phase 2 — Choose the Right Flow Type

| Trigger / Use case | Flow type |
|---|---|
| Update fields on the same record before save | Before-save Record-Triggered Flow |
| Create/update related records, send emails, callouts | After-save Record-Triggered Flow |
| Guide a user through a multi-step process | Screen Flow |
| Reusable background logic | Autolaunched (Subflow) |
| Called from Apex `@InvocableMethod` | Autolaunched (Invocable) |
| Time-based recurring processing | Scheduled Flow |
| Platform events / CDC | Platform Event–Triggered Flow |

### ⛔ Non-Negotiable Quality Gates

**Bulk Safety:**
- ❌ No DML inside loops
- ❌ No Get Records inside loops
- ❌ No looping on `$Record` collection — use collection variables
- ✅ Collect outside loop, process inside, DML once after

**Fault Paths:**
- Every DML, email, or callout element **must** have a fault connector
- Route faults to a dedicated fault handler — never loop back to main flow
- On fault: log to custom object or Platform Event, show user-friendly message, exit cleanly

**Deployment:**
- Deploy as Draft first
- Validate with 200+ records for record-triggered flows
- Check automation density — no overlapping Process Builder / Workflow Rule / other Flow

**Definition of Done:**
- [ ] Flow type appropriate for use case
- [ ] No DML/Get Records in loops
- [ ] Fault connectors on all data-changing elements
- [ ] Tested single record + bulk (200+)
- [ ] Automation density checked
- [ ] Activates without errors in sandbox
- [ ] Output summary provided

### ❓ Ask, Don't Assume
- Never assume trigger conditions, decision logic, or DML operations
- Batch all questions at once — don't ask one at a time
- Present options when multiple valid flow types exist

---

## 3. Salesforce Component Quality Standards

### LWC Standards

**Data Access:**
- `@wire(getRecord)` for single-record reactive reads
- `<lightning-record-form>` for standard CRUD
- `@wire(apexMethod)` for cacheable queries
- Imperative Apex for user-triggered DML
- Lightning Message Service for cross-component communication

**Security:**
- ❌ Never `innerHTML` with user data — use template bindings `{expression}`
- ✅ Apex methods enforce CRUD/FLS with `WITH USER_MODE` or `Schema.sObjectType` checks
- ❌ No hardcoded org-specific IDs in component JS
- ✅ Validate `@api` properties before use

**SLDS 2 / Styling:**
- ❌ Never hardcode hex colours — use SLDS CSS custom properties
- ❌ Never `!important` on SLDS classes
- ✅ Use `<lightning-*>` base components wherever they exist
- ✅ Test in both light and dark mode

**Accessibility (WCAG 2.1 AA):**
- [ ] All inputs have `<label>` or `aria-label`
- [ ] Icon-only buttons have `alternative-text` or `aria-label`
- [ ] All interactive elements keyboard-operable (Tab, Enter, Space, Escape)
- [ ] Colour not the only status indicator
- [ ] Error messages associated via `aria-describedby`
- [ ] Focus management correct in modals

**Component Communication:**
| Direction | Mechanism |
|---|---|
| Parent → Child | `@api` property or method |
| Child → Parent | `CustomEvent` with `bubbles: true, composed: true` |
| Sibling / unrelated | Lightning Message Service |
| ❌ Never | `document.querySelector`, `window.*` |

**Performance:**
- No side effects in `connectedCallback`
- Guard `renderedCallback` with boolean to prevent infinite loops
- Paginate or stream large datasets

**Jest Tests (minimum):**
- Renders with correct title
- Calls Apex and displays results (wire mock)
- Dispatches event on button click
- Shows error state on Apex failure

### Aura Standards
- New components: **always LWC** unless Aura-only context
- `@AuraEnabled` methods: `with sharing` + CRUD/FLS enforcement
- Component events for parent-child; application events only when necessary
- Hybrid stacks: use LMS, not Aura application events

### Visualforce Standards
- ❌ Never `escape="false"` on user data
- ✅ Use `<apex:form>` for CSRF protection
- ✅ Bind variables in SOQL — never concatenate URL params
- ✅ `with sharing` + FLS checks in custom controllers
- ✅ View state under 135 KB; use `transient` and `readonly="true"`

---

## 4. Allura Memory Governance

- Store significant design decisions and lessons learned to Allura Brain
- Use `group_id: allura-mortgage` for this project
- Write trace summaries after substantive work sessions
- ADRs mandatory for all architectural decisions

---

## 5. Conflict Resolution

| Conflict between... | Defer to... |
|---|---|
| Document vs JSON schema | JSON schema |
| Document vs Apex/Flow metadata | Source code |
| Two documents | BLUEPRINT.md, then team consensus |
| AI suggestion vs any above | Source of truth |
