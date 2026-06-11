# Pre-Check Smoke Test

**Trigger:** After changes to `PreFlightEvaluator`, `PreFlightController`, or `intentCapture` LWC.

---

## Steps

1. Run `PreFlightEvaluator.evaluate()` with Karim Hassan inputs (income $97,803, property ~$350k, CONVENTIONAL): expect LIKELY_ELIGIBLE.
2. Run with James O'Brien inputs (income $80,393, high DTI property): expect UNLIKELY.
3. Verify NO `Loan_Application__c` record created (ADR-7).
4. Verify evaluator uses live INCOME + COLLATERAL rules only (same kernel, ADR-7).
5. Run `PreFlightEvaluatorTest` and `PreFlightControllerTest`: all pass.
6. Verify `intentCapture` LWC: no pre-filled defaults (ADR-8), Continue disabled until touched.

**Source:** ADR-7, ADR-8, FR-4, FR-5.
