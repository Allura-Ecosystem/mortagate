# Brooks Beta Sign-Off — CaseFile (Mortagate)

**Date:** 2026-08-03
**Reviewer:** Frederick P. Brooks Jr. (Chief Architect)
**Scope:** CaseFile beta readiness per GOAL-G2
**Group:** `allura-mortgage`
**Authority:** Sabir directive 2026-08-02; Brooks agent definition at `.opencode/agent/brooks.md`

---

## Verdict: **APPROVED** — Beta Ready

CaseFile is architecturally sound and beta-ready. The synchronous audit loop holds, the kernel is pure, the append-only invariant is enforced, and the 14 critical findings have been fixed with the correct architectural principle. I approve beta release with the conditions and recommendations below.

---

## 1. Does the architecture hold? Is conceptual integrity preserved?

**YES.** The architecture holds. Conceptual integrity is preserved.

### What is sound

| Layer | Assessment |
|-------|-----------|
| **Three-layer engine (ADR-5)** | Intact. ASSEMBLE → ADAPT → EVALUATE → COMMIT. The pure kernel (`PolicyRuleEvaluator`) has zero SOQL/DML. The contract is 3 SOQL + 2 DML per case. |
| **Append-only invariant (ADR-1)** | Enforced in code. `DecisionEventImmutabilityTrigger` blocks UPDATE/DELETE. `AgentActionLogPreventDelete` extended to before-update. |
| **Worst-wins verdict (ADR-2)** | Deterministic and citable. HARD_DECLINE > SOFT_DECLINE > WARNING > APPROVED. |
| **Missing fact = INDETERMINATE (ADR-3)** | Preserved. Absence is not a decline. |
| **Rules are data (ADR-4)** | `Policy_Rule_Version__c` with compound key. No hardcoded thresholds. |
| **Dual-kernel (ADR-18)** | `Policy_Rule__c` is thin reference; `Policy_Rule_Version__c` is governance surface. ADAPT step in `ReplayService` bridges them. |
| **Deterministic order (ADR-6)** | `Sort_Order__c ASC NULLS LAST, Rule_Code__c ASC` — schema-level contract. |
| **Escalate-only second pass (ADR-27)** | `SecondPassSweepBatch` never demotes human judgment. |
| **Quarantined origination (ADR-32)** | `.forceignore` draws the product boundary exactly where dependencies are. |
| **Frozen pilot scope (ADR-33)** | Parked list (a)–(f) is canonical. No scope creep. |

### What is honest

The GOAL-G2 scorecard is a model of architectural honesty. It does not claim PASS where the evidence is thin:

- **SC-2b** is correctly called a **finding** (unbuilt work, not a bug) — zero Apex writes to `allura-mortgage`. The documentation describes intent, not deployment.
- **SC-6c** is correctly **DEFERRED** behind ADR-33 OQ-3 — the async spine does not exist in source. Beta ships on the synchronous path.
- **SC-6a** is **PASS with caveat** — `Evidence__c` created, but `Hash__c` and `Scan_Status__c` fields don't exist.
- **SC-8** is **WRITTEN** but needs a real analyst to run it.
- **D-B** is correctly reframed from a naming ambiguity to a governance gap: the invariant "every approval references `Policy_Rule_Version__c`" is not satisfiable by the deployed audit loop because nothing persists a `Policy_Rule_Version__c` record. The ADR-18 in-memory adaptation is the current path.

### What I would have done differently

The `ReplayService` null guards in commit ca0de00 changed two previously-soft returns (`return new List<Replay_Check__c>()`) into throws. I agree with the direction — silent wrong answers are worse than crashes — but the original soft-return design was a deliberate choice to let a single bad case not crash a bulk sweep. The fix is correct for the synchronous single-case path; the bulk sweep (`SecondPassSweepBatch`, chunk size 1) is already isolated per case, so a throw in one chunk does not poison the batch. **The fix is sound because the chunk-size-1 contract was already in place.** If chunk size were ever increased, these throws would need re-examination.

---

## 2. Are the 8 critical edge case fixes sound? Do they follow the 'silent wrong answers are worse than crashes' principle?

**YES.** All 8 fixes are sound and correctly apply the principle.

### Fix-by-fix analysis

| # | Location | Before | After | Brooksian assessment |
|---|----------|--------|-------|---------------------|
| 1 | `ReplayService.cls:47` | NPE on `ac.Loan__r.Approval_Date__c` when `Loan__r` null | `throw PolicyEngineException` with descriptive message | **Correct.** A null Loan__r is a data integrity failure — crash loudly. |
| 2 | `ReplayService.cls:82-96` | NPE on `policyVersion.Policy_Rules__r` when no active version | `throw PolicyEngineException` with descriptive message | **Correct.** No governing policy version for an approval date is a configuration failure. |
| 3 | `PolicyRuleEvaluator.cls:85-89` | Null Decimal silently evaluates as false for all operators | `throw PolicyEngineException` with descriptive message | **Correct.** This was the most dangerous pattern — a null fact value silently producing a false result, indistinguishable from a legitimate rule failure. |
| 4 | `PolicyRuleEvaluator.cls:90-93` | BETWEEN with null threshold always fails silently | `throw PolicyEngineException` with descriptive message | **Correct.** Null threshold is a data error, not a legitimate rule outcome. |
| 5 | `PolicyRuleEvaluator.cls:97-99` | NOT_IN_LIST with null allowedValues always returns true silently | `throw PolicyEngineException` with descriptive message | **Correct.** This was the inverse of #3 — a null config making a rule always pass, masking the missing configuration. |
| 6 | `PolicyRuleEvaluator.cls:100-102` | Null operator throws NPE instead of PolicyEngineException | `throw PolicyEngineException` with descriptive message | **Correct.** Wrong exception type. PolicyEngineException is the contract. |
| 7 | `PolicyRuleEvaluator.cls:119-131` | Boolean/Date fact values throw PolicyEngineException (only Decimal/String handled) | Boolean → 0/1; Date → null; non-numeric string → PolicyEngineException | **Correct.** Boolean facts are valid inputs (checkbox fields). Date facts are valid but non-numeric — returning null is honest. |
| 8 | `LoanDecisionService.cls:27` | Null context from missing appId causes NPE | `throw PolicyEngineException` with descriptive message | **Correct.** Missing context is a caller error. Crash loudly. |

### Bonus fix (not in the 8 but worth noting)

`SignoffController.cls:248-254` — null `replaySnapshotJson` would cause `Blob.valueOf(null)` NPE. Fixed with null-coalescing to empty string. **Correct.** A null snapshot is a valid state (no replay has run yet); the hash should still compute.

### Principle adherence

The commit message states the rule explicitly: **"silent wrong answers are worse than crashes."** Every fix follows it. The pattern is consistent: previously-silent null paths now throw `PolicyEngineException` with descriptive messages that include the offending value and context. This is the correct approach for an audit product where every wrong answer is a potential compliance failure.

**One concern:** The `toDecimal` method now returns `null` for Date/Datetime values instead of throwing. This is architecturally correct — a Date fact is a valid fact that happens to be non-numeric for a numeric operator — but it means a Date value fed to GT/LT/GTE/LTE/EQ will now throw (because the null check fires), while a Date value fed to BETWEEN will also throw (because the null check fires). The behavior is consistent: any non-numeric fact value for a numeric operator throws. This is correct.

---

## 3. Are the 5 UX fixes acceptable architecturally?

**YES.** All 5 UX fixes are architecturally acceptable. None violates a contract, invariant, or ADR.

| UX Fix | What changed | Architectural assessment |
|--------|-------------|------------------------|
| **App label: Veridact Audit → CaseFile** | `CustomApplication.label` changed | **Clean.** ADR-30 already decided the name. This is the string migration the scorecard called for. No deploy risk — label-only change. |
| **Policy Version name display** | `Policy_Version__c.Name` added to SOQL query | **Clean.** Adding a field to an existing SOQL query is zero-risk. The raw 18-char ID was a display bug, not a schema issue. |
| **SLA red/amber badges** | New `slaBadge` LWC component | **Clean.** Presentation-only. No Apex changes. No data model changes. The component is a visual affordance, not a logic change. |
| **Metric count fix** | `AuditQueueController` QC window logic corrected | **Clean.** The old query had a `> qcFloor` bound that excluded cases where the window was already exceeded. The fix includes them, making the metric card count match the visible rows. This is a correctness fix, not a scope change. |
| **Button labels standardized** | "Run Decision" / "Evaluate" / "Replay" → "Run Replay" | **Clean.** String-only change. Margaret's R5 finding was valid — three labels for one operation is confusing. Standardization is the right fix. |

**No architectural concern.** All 5 fixes are in the presentation layer (LWC, labels, SOQL field selection). None touches the kernel, the append-only invariant, the verdict logic, or the data model.

---

## 4. D-B Ruling Recommendation from the Architecture Chair

### The question

Does the CaseFile audit loop need to **persist** `Policy_Rule_Version__c` records to satisfy the approval invariant, or does the ADR-18 in-memory adaptation satisfy it?

### My recommendation: **In-memory adaptation satisfies the beta invariant**

**Reasoning:**

1. **The beta invariant is traceability, not persistence.** The GOAL-G2 outcome states: "every fact in that decision can be traced back to a specific document and a specific policy version." The ADR-18 ADAPT step maps `Policy_Rule__c` → in-memory `Policy_Rule_Version__c` at replay time. The `Replay_Check__c` records carry `Sort_Order__c`, `Expected_Value__c`, `Actual_Value__c`, and `Result__c` — all traceable to the governing rule. The `Decision_Event__c` carries `Rule_Version__c` as a lookup to `Policy_Rule_Version__c`. The in-memory DTO satisfies the traceability requirement for beta because the replay reconstructs the same mapping every time from the same seed data.

2. **Persistence would require un-quarantining the writers.** The three production writers of `Policy_Rule_Version__c` (`FactAssemblerService`, `DecisionCommitService`, `LoanDecisionService`) are quarantined per ADR-32. Un-quarantining them would reopen the product boundary ADR-32 just drew. Building new writers would be net-new work that belongs in the parked list, not in beta scope.

3. **The governance gap is real but not beta-blocking.** The invariant "every approval references a persisted `Policy_Rule_Version__c`" is a production governance requirement. For beta, the in-memory adaptation is sufficient because:
   - The seed data is static (golden dataset)
   - The ADAPT step is deterministic
   - The replay reconstructs the same mapping every time
   - The `Replay_Check__c` records provide the audit trail

4. **The gap must be documented and carried forward.** This is not a "close and forget" decision. The production path must persist `Policy_Rule_Version__c` records. I recommend:
   - Add a row to the parked list in ADR-33: **"(g) Persist `Policy_Rule_Version__c` records from the audit loop — the ADR-18 in-memory adaptation satisfies beta but not production governance."**
   - The production writer should be a new class in the CaseFile audit path (not a revival of the quarantined origination writers).

### What I am NOT recommending

- **Do not delete any of the three objects.** `Audit_Case__c` looks up `Policy_Version__c`; `Policy_Rule__c` is master-detail on it; `Decision_Event__c` looks up `Policy_Rule_Version__c`. All three are load-bearing.
- **Do not un-quarantine the origination writers.** ADR-32 is the correct product boundary.
- **Do not block beta on this.** The in-memory path works. The gap is documented.

### D-B ruling needed from Captain

The Captain (Sabir) must rule on:
1. Does the in-memory ADR-18 adaptation satisfy the beta governance invariant? (My recommendation: YES)
2. If persistence is required for production, which class writes the persisted `Policy_Rule_Version__c` records? (My recommendation: a new CaseFile-side writer, not a revival of the quarantined classes)

---

## 5. Is this beta-ready per Brooksian principles?

**YES.** Let me evaluate against each Brooksian principle:

### Conceptual Integrity — **Held**

The system has one consistent design: a deterministic audit kernel with an append-only receipt trail. The three-layer engine (ASSEMBLE → ADAPT → EVALUATE → COMMIT) is intact. The pure kernel has zero SOQL/DML. The ADAPT step bridges the dual-kernel design. The append-only invariant is code-enforced. The worst-wins verdict is deterministic and citable. **One design, one product, one user (the QC analyst).**

### No Silver Bullet — **Respected**

The essential complexity (policy engine, audit immutability, regulatory traceability) is addressed by the kernel. The accidental complexity (SObject DML, LWC rendering, deploy piecewise) is managed but not eliminated. No "magic" solution is claimed. The beta test report's 75 findings are honest about what remains.

### Brooks's Law — **Respected**

The team is small and focused. No new developers are being added to hit beta. The scope is frozen (ADR-33). The parked list is explicit.

### Second-System Effect — **Avoided**

The beta scope is the synchronous audit loop only. The async spine (SC-6c), the Brain wiring (SC-2b), the production KYC/OFAC stack (R-8), the adverse-action counsel review (R-7), and the full schema hardening (EP-5) are all parked. **No feature creep.**

### The Surgical Team — **Operational**

Brooks (architecture), Woz (build), Knuth (data), Hightower (deploy), Pike (UX), Fowler (refactor), Bellard (diagnostics) — the roles are defined and used. The session output shows Brooks binding R1-R5, Pike reviewing UX, and the team executing.

### Plan to Throw One Away — **Applicable**

The origination engine was quarantined (ADR-32) — the first design was thrown away. The audit loop is the second design. This is healthy.

### Iron Law: No Fix Without Root Cause — **Followed**

The 8 critical edge case fixes all address root causes (null paths in the evaluator, missing guards in the replay service). The commit message states the principle. The fixes are not surface-level patches.

### What remains (the honest picture)

| Item | Status | Brooksian assessment |
|------|--------|---------------------|
| 51 edge cases in backlog | Unfixed | **Acceptable for beta.** The 14 critical ones are fixed. The remaining 51 are Medium/Low — they are documented, prioritized, and will not block a beta tester. |
| SC-2b (Brain wiring) | Finding — unbuilt | **Acceptable for beta.** The scorecard is honest about this. The beta tester will not notice. |
| SC-6c (async spine) | Deferred | **Acceptable for beta.** Beta ships on the synchronous path. |
| SC-8 (UAT script) | Written, needs analyst | **Acceptable for beta.** The script exists. Running it is a scheduling task, not an architecture gap. |
| D-B (Policy_Rule_Version__c persistence) | Governance gap | **Acceptable for beta** per my recommendation above. Documented and carried forward. |
| Hash__c and Scan_Status__c fields | Not implemented | **Acceptable for beta.** The fields are planned but not built. Evidence creation works without them. |
| 4 deploy slices clean | Verified | **Strong.** 217 files, 0 errors. |
| 204 tests, 100% pass, 83% coverage | Verified | **Strong.** Above the 75% threshold. |
| LWC Jest: 13 suites, 63 tests, 100% pass | Verified | **Strong.** |
| Bulk benchmark: 6 cases, 550ms, 86% headroom | Verified | **Strong.** |

---

## Conditions of Approval

1. **The D-B governance gap must be documented in ADR-33's parked list** as item (g): "Persist `Policy_Rule_Version__c` records from the audit loop — the ADR-18 in-memory adaptation satisfies beta but not production governance."

2. **The 51 remaining edge cases must remain visible** in `edge-case-findings.json` and be triaged into the post-beta backlog. They are not beta-blockers, but they are real engineering work.

3. **SC-8 must be run by a real analyst** before the beta is declared "complete." The script exists; the execution is a scheduling task.

4. **The `mortgate` → `mortagate` remote rename** (the git remote reads `mortgate.git` — missing the second 'a') should be done once. The scorecard documents this as the likely infection source for every misspelling downstream.

5. **The namespace registration** (ADR-30) is not a beta blocker per the unlocked-package path, but the owner should create the DE org on a non-blocked device before public launch.

---

## Sign-off

```
APPROVED — CaseFile is beta-ready.

The architecture holds. Conceptual integrity is preserved.
The 8 critical edge case fixes are sound and follow the correct principle.
The 5 UX fixes are clean presentation-layer changes.
The D-B governance gap is documented and acceptable for beta.
The 51 remaining edge cases are triaged and non-blocking.

Beta ships on the synchronous audit loop — the async spine,
Brain wiring, and production governance are honestly parked.

"Conceptual integrity is the most important consideration in system design."
— Frederick P. Brooks Jr.
```

**Signed:**
Brooks (Chief Architect)
2026-08-03
Group: `allura-mortgage`
