# CaseFile — Mock Test Loans

> Eight synthetic loans for exercising the decision/replay engine across its
> boundaries. **Test data only** — load into a **pilot/sandbox** org, never the
> `mortagate-de` golden demo dataset. Loader: `scripts/load-mock-test-loans.apex`
> (idempotent; keys `MOCK-TEST-01…08`). Prepared 2026-07-05.

## Active policy thresholds (audit path, whole-number percent)

| Rule | Operator | Threshold | Kind |
|---|---|---|---|
| `DTI_MAX` | ≤ | **43** | HARD decline |
| `FICO_MIN` | ≥ | **620** | HARD decline |
| `LTV_MAX` | ≤ | **80** | HARD decline |
| `FICO_PREF` | ≥ | 680 | soft / info |
| `LTV_PREF` | ≤ | 90 | soft / info |
| `RESERVES` | ≥ | 100,000 | soft / info |

## The mock numbers

| # | Borrower | Loan amt | Property | Annual income | Monthly debt | **DTI %** | **FICO** | **LTV %** | Identity | Expected replay | Tier |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 01 | Ava Chen | 390,000 | 600,000 | 120,000 | 2,800 | **28.0** | **760** | **65.0** | Verified | all pass | **Low** |
| 02 | Marcus Bell | 400,000 | 500,000 | 100,000 | 3,583 | **43.0** | **620** | **80.0** | Verified | HARD pass at every boundary; FICO<680 soft-flag | **Low** |
| 03 | Dana Ortiz | 280,000 | 400,000 | 90,000 | 3,750 | **50.0** | 720 | 70.0 | Verified | **DTI HARD fail** | **High** |
| 04 | Priya Nair | 210,000 | 350,000 | 80,000 | 2,000 | 30.0 | **590** | 60.0 | Verified | **FICO HARD fail** | **High** |
| 05 | Sam Weber | 285,000 | 300,000 | 110,000 | 3,208 | 35.0 | 700 | **95.0** | Verified | **LTV HARD fail** | **High** |
| 06 | Ruth Okafor | 242,500 | 250,000 | 60,000 | 2,750 | **55.0** | **580** | **97.0** | Verified | **3× HARD fail** (DTI+FICO+LTV) | **Critical** |
| 07 | Leo Park | 352,000 | 400,000 | 96,000 | 3,200 | **40.0** | 650 | **88.0** | Verified | HARD all pass; FICO<680 **and** LTV 80–90 soft-flags | **Medium** |
| 08 | Nadia Farouk | 300,000 | 500,000 | 150,000 | 3,750 | 30.0 | 780 | 60.0 | **Failed** | policy clean but **KYC gate blocks** (orthogonality) | **High** |

### Notes on the math
- **DTI %** = monthly debt ÷ (annual income ÷ 12), rounded to 0.1.
- **LTV %** = loan amount ÷ property value.
- Rows 01–02 are the "clean" band (02 sits exactly on all three hard boundaries — a
  deliberate off-by-one guard: `≤43`, `≥620`, `≤80` must all read as PASS).
- Rows 03–05 isolate a **single** hard failure each (regression-friendly).
- Row 06 is the Critical multi-fail hero (mirrors the demo's AC-0001 shape).
- Row 07 passes every hard rule but trips **soft** flags only → Medium, not High.
- Row 08 proves the KYC/OFAC gate is **independent** of the policy kernel: a
  780-FICO, low-DTI, low-LTV loan still blocks on `Identity_Verification_Status = Failed`.

### Expected queue after load + `SecondPassSweepBatch`
Critical ×1 (Ruth) · High ×4 (Dana, Priya, Sam, Nadia) · Medium ×1 (Leo) · Low ×2 (Ava, Marcus).

---

## Evidence gaps

Loader: `scripts/load-mock-test-evidence.apex` (run **after** the loans loader).
Each case gets a realistic post-close document set; the **Missing** required docs are
what the copilot's *"what evidence is missing for this case?"* action surfaces, and the
trailing-doc gaps (Recorded Mortgage, Final Title Policy) feed the 90-day QC-window lens.
Status ∈ `Linked` (present) · `Missing` (gap) · `Unverifiable` (illegible).

| # | Borrower | Linked (present) | Missing (required gap) | Unverifiable |
|---|---|---|---|---|
| 01 | Ava Chen | Pay Stub, W2, Bank Stmt, Appraisal, Credit Report, Photo ID | — (none) | — |
| 02 | Marcus Bell | Pay Stub, W2, Appraisal, Credit Report | — | Bank Statement |
| 03 | Dana Ortiz | Pay Stub, Appraisal, Credit Report | **Employment Verification, W2** | — |
| 04 | Priya Nair | Pay Stub, Appraisal, Photo ID | **Credit Report, Tax Return** | — |
| 05 | Sam Weber | Pay Stub, W2, Credit Report | **Appraisal** | Purchase Agreement |
| 06 | Ruth Okafor | Pay Stub, Credit Report | **Appraisal, Recorded Mortgage, Final Title Policy** | — |
| 07 | Leo Park | Pay Stub, W2, Appraisal, Credit Report, Recorded Mortgage | **Final Title Policy** | — |
| 08 | Nadia Farouk | Pay Stub, W2, Appraisal, Credit Report | **Photo ID** | — |

**Gap design:** each gap reinforces the loan's story — Dana's DTI fail pairs with missing
income proof, Sam's LTV fail with a missing appraisal, Ruth's Critical with all trailing
docs absent, Nadia's KYC block with a missing Photo ID. Rows 01–02 are the clean control
(zero required gaps).

### Full load sequence (sandbox/pilot only)
```bash
sf apex run --target-org casefile-pilot -f scripts/load-mock-test-loans.apex
sf apex run --target-org casefile-pilot -f scripts/load-mock-test-evidence.apex
sf apex run --target-org casefile-pilot -f scripts/run-second-pass.apex   # replay + tier
```
