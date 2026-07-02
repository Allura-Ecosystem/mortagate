# DESIGN — Second-Pass Data: LTV Rule Verification & Trailing-Docs Check

> Author: Knuth (data architect). Date: 2026-07-02. Branch: `feat/veridact-v1-demo`.
> Scope: close the two pitch gaps so the demo can flag **DTI, LTV, or missing trailing docs**.
> Governing model: the three-zone active audit schema (Inputs / Work / Ledger). Legacy
> pre-pivot objects (`Loan_Application__c`, `Extracted_Facts__c`, `Policy_Rule_Version__c`,
> `Decision_Event__c`, `Evidence__c`) are out of scope — inactive scaffold.

---

## 1. LTV_MAX — VERIFICATION FINDING (no change required)

**Premise in the task ("if no LTV fact field exists, add it") is FALSE.** Verified against
both the metadata and the live `mortagate-de` org:

- **Fact field the active kernel reads:** `Borrower_Snapshot__c.LTV_Ratio__c`
  (`Percent(5,2)`). `ReplayService.replay()` (the active audit path) projects it into the
  fact map keyed by API name (`ReplayService` lines 60/66) and the pure evaluator
  (`PolicyRuleEvaluator`) looks it up by `Policy_Rule__c.Fact_Field__c`.
- **LTV_MAX rule already exists** in the governing active version `PV-Q1 2025 Conventional`
  (`Version_Number__c = 1`, `Is_Active__c = true`, effective `2025-01-01`, no expiration):

  | Rule_Code | Fact_Field | Operator | Threshold_Value | Severity | Category |
  |-----------|-----------|----------|-----------------|----------|----------|
  | `LTV_MAX` | `LTV_Ratio__c` | `LTE` | **80** | `Hard_Decline` | `Collateral` |
  | `LTV_PREF` | `LTV_Ratio__c` | `LTE` | 90 | `Info` | `Collateral` |

### 1.1 The units trap — RESOLVED

The task warned of a "43 vs 0.43" units bug and (mis)described the precedent as "fraction
units." **The actual, live precedent is whole-number percentage points, not fractions:**

- `DTI_MAX.Threshold_Value__c = 43`, evaluated against `Borrower_Snapshot__c.DTI_Ratio__c = 44.8`
  → `44.8 <= 43` is false → **Fail** (this is the working DTI demo flag).
- `LTV_MAX.Threshold_Value__c = 80`, evaluated against `LTV_Ratio__c = 80` → `80 <= 80`
  → **Pass**.

Authoring LTV_MAX at `0.80` (as the task literally requested) would have been the bug:
`80 <= 0.80` is false → **every** loan would spuriously fail LTV. The correct,
precedent-consistent threshold is **80** — and it is already what the golden dataset holds.
`Borrower_Snapshot__c.LTV_Ratio__c` / `DTI_Ratio__c` are `Percent(5,2)`, so the stored/Apex
value equals the whole-number percentage (e.g. `80` means 80%). **No field, no rule, no data
change is made for LTV.** Creating a second `LTV_MAX` under the active version would violate
the documented `Rule_Code__c`-unique-within-version invariant (Open Design Decision #5).

### 1.2 Severity note (recommendation only — NOT executed)

The task requested `Soft_Decline` (route to review) rather than `Hard_Decline`. Two reasons
this is deliberately **not** changed here:

1. **It does not affect audit-side flagging.** `ReplayService` persists a per-rule
   `Replay_Check__c` with `Result__c ∈ {Pass, Fail, Unverifiable}` and discards the aggregate
   verdict. `Severity__c` is not persisted on `Replay_Check__c` and does not change whether
   LTV shows as a Fail. Severity only influences the legacy origination verdict
   (`PolicyRuleEvaluator.deriveVerdict` → `LoanDiagnosisService`), not the audit replay.
2. **Active rules are edit-locked (ADR-4).** Flipping the severity requires a *new*
   `Policy_Version__c` superseding v1 — which re-opens governing-version resolution for every
   approval date and risks the working DTI demo. That cost is unjustified for a cosmetic,
   audit-irrelevant change.

**Recommendation for a future policy pass (not this PR):** if VA/FHA loans (LTV routinely
>80%) are ever given `Borrower_Snapshot__c` records, supersede v1 with a v2 whose `LTV_MAX`
is `Soft_Decline` for Conventional (LTV>80 = PMI/exception, not a decline). Deferred to Brooks.

---

## 2. Trailing-documents check — DESIGN (implemented)

### 2.1 Problem

"Required trailing docs missing post-close" (e.g. the **recorded mortgage** and the
**final title policy** that arrive after funding) must be representable and flaggable. Today:

- `Evidence_Item__c.Document_Type__c` has no value for either trailing doc.
- The replay kernel evaluates **only** numeric `Borrower_Snapshot__c` facts. It reads the
  evidence status map but `PolicyRuleEvaluator` never consumes it, so evidence gaps are
  **not** turned into Pass/Fail — which is exactly what ADR-3 requires.

### 2.2 Options considered

| Option | Description | Verdict |
|--------|-------------|---------|
| **A — evidence-derived policy rule** | Add a `Documentation`-category `Policy_Rule__c` whose `Fact_Field__c` points at an evidence-derived fact | **Rejected.** The kernel does not project evidence into the fact map, so the rule would be **inert dead data** — it would violate "rules are data the *engine reads*." Wiring evidence into the evaluator is a code change beyond this data pass, and would risk turning a missing doc into an auto-fail, breaking ADR-3. |
| **B — minimal additive schema + data** | Add two `Document_Type__c` picklist values and represent "required trailing doc missing" with the **existing** `Required__c = true` + `Status__c = Missing` | **Chosen.** Smallest correct change. Honors ADR-3 by construction. |

### 2.3 Chosen design (Option B)

**Schema (additive, restricted picklist):** add to `Evidence_Item__c.Document_Type__c`:

| API value | Label |
|-----------|-------|
| `Recorded_Mortgage` | Recorded Mortgage |
| `Final_Title_Policy` | Final Title Policy |

**Required-doc concept:** already exists — `Evidence_Item__c.Required__c` (Checkbox, default
true). A "required trailing doc" is simply an `Evidence_Item__c` of the trailing-doc type with
`Required__c = true`. No new field is needed.

**Data (additive, existing records untouched):** append two `Evidence_Item__c` children to the
hero case (Sabir Asheed Sr., `AC-…`, In_Review):

| Document_Type__c | Status__c | Required__c | Meaning |
|------------------|-----------|-------------|---------|
| `Recorded_Mortgage` | `Missing` | true | Trailing doc not yet received post-close |
| `Final_Title_Policy` | `Missing` | true | Trailing doc not yet received post-close |

### 2.4 ADR-3 compliance (absence → investigation, never auto-fail)

- `Status__c = Missing` is a first-class evidence state, not an error.
- The kernel never evaluates evidence into a policy `Fail`; missing required evidence surfaces
  as an **evidence-panel gap** (`CaseReviewController` returns every `Evidence_Item__c` with
  its status to the Case Review LWC left pane) and increments `auditAnalytics.missingEvidenceCount`.
  This drives an auditor to investigate — it is **Unverifiable / INDETERMINATE** in spirit, not
  a decline. ADR-3 is satisfied by construction: there is no code path that converts a missing
  trailing doc into an approval failure.

### 2.5 Why the hero case

Sabir already demonstrates the DTI flag (`DTI 44.8 > 43` → Fail) and one missing doc
(`Appraisal = Missing`). Adding the two trailing docs lets the single hero case narrate the
full pitch — **DTI violation + missing trailing docs** — in one screen. LTV on Sabir passes
(`80 <= 80`), which is the correct, honest result; the LTV *rule* is proven present and wired,
and would fire for any snapshot with `LTV_Ratio__c > 80`.

---

## 3. Deliverable-to-change map

| Task deliverable | Outcome |
|------------------|---------|
| 1. LTV_MAX rule + fact field | **Verified present & correct.** No change (would duplicate / mis-unit). Severity change deferred with rationale. |
| 2. Trailing-docs check | **Implemented.** +2 `Document_Type__c` picklist values, +2 seeded `Evidence_Item__c` (Missing, Required) on hero case. |
| 3. DATA-DICTIONARY update | §2.6 picklist values added; DTI/LTV `Percent` scale corrected to match schema; units note added. |
| 4. Idempotent load | `scripts/load-trailing-docs.apex` — insert-if-absent, existing records untouched, verified by query. |
| 5. Tests | No kernel fact field added → no evaluator/assembler test change required (per PNB conditional). Touched classes (`ReplayServiceTest`, `CaseReviewControllerTest`) re-run on org to confirm the picklist addition is non-breaking. |

## 4. Doc-vs-schema conflicts found (schema wins)

1. `Borrower_Snapshot__c.DTI_Ratio__c` / `LTV_Ratio__c` and `Loan__c.*_At_Approval__c` are
   `Percent(5,2)` in metadata, but DATA-DICTIONARY said `Percent(5,4)`. **Corrected the dict.**
2. `Policy_Rule__c` deployed with 8 fields (`Rule_Code__c, Rule_Label__c, Rule_Category__c,
   Operator__c, Threshold_Value__c, Fact_Field__c, Severity__c, Policy_Version__c`) — the
   dictionary lists many more (`Threshold_High__c, Rule_Explanation__c, Allowed_Values__c,
   Regulatory_Citation__c, Override_*`, `Sort_Order__c`). Those columns do **not** exist on the
   active `Policy_Rule__c`; the replay adapter defaults them to null (`ReplayService` lines
   99–103). **Reported, not silently rewritten** — full object-spec reconciliation is a larger
   pass for Brooks. Consequence: there is **no `Rule_Explanation__c` field** to populate on the
   active `Policy_Rule__c`, so the requested "read-aloud explanation text" cannot live on the
   rule record; it lives here in the DESIGN note and in `Rule_Label__c` ("Maximum LTV Ratio").
3. Severity picklist is title-case (`Soft_Decline`) while `PolicyRuleEvaluator` switches on
   `SOFT_DECLINE`. Apex `switch on` string matching is case-insensitive, so this works — but the
   casing divergence is noted.
4. Org holds **10** active rules, not the "4–6" the task assumed.
</content>
</invoke>
