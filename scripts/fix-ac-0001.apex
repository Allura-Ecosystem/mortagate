// fix-ac-0001.apex — additive, idempotent repair of the AC-0001 "Priya Nair" data-quality gap.
// Run: sf apex run --target-org mortagate-de -f scripts/fix-ac-0001.apex
//
// PROBLEM (loop item #3): Audit_Case__c AC-0001 (Risk_Tier__c='Critical', In_Review) has an
// EMPTY Loan__c lookup and NO Borrower_Snapshot__c children, so ReplayService.replay() early-returns
// (null Loan__r.Approval_Date__c) and produces zero Replay_Check__c rows. It is the FIRST row an
// audience sees in the queue, so it must replay into a compelling Critical story.
//
// FIX (additive only): give AC-0001 a Loan__c consistent with a Critical-tier decline, a set of
// Borrower_Snapshot__c facts that trip multiple HARD-decline rules, and one required-Missing evidence
// gap. Units follow the audit-path doctrine (whole-number percentage points; see planning docs/
// DATA-DICTIONARY.md §2.5 and §2.2/§2.3) — DTI 52.0 means 52.0%, NOT 0.52.
//
// GUARANTEES:
//   * Idempotent — re-running inserts nothing new (gated by Loan LOS key / snapshot Fact_Category /
//     evidence Document_Type). Existing records are never modified or deleted.
//   * Bulk-safe — no DML inside loops; list-based inserts.
//   * Work-object updates only — sets Audit_Case__c.Loan__c (a lookup). Risk_Tier__c and Status__c
//     are NEVER touched (escalate-only tier logic + human-owned Status stay intact).
//   * Ledger objects (Audit_Event__c / Audit_Receipt__c / Agent_Action_Log__c) are not touched.
//
// Governing active policy (PV-000000, effective 2025-01-01) HARD_DECLINE rules this data trips:
//   DTI_MAX  LTE 43  -> 52.0 FAIL   FICO_MIN GTE 620 -> 600 FAIL   LTV_MAX LTE 80 -> 85 FAIL

final String CASE_KEY = 'Priya Nair';         // Audit_Case__c.Borrower_Name_Snapshot__c
final String LOAN_KEY = 'VERIDACT-AC-0001';   // Loan__c.LOS_Loan_Id__c idempotency handle

List<Audit_Case__c> cases = [
    SELECT Id, Loan__c, Approval_Timestamp__c, Original_Approver__c, Risk_Tier__c, Status__c
    FROM Audit_Case__c
    WHERE Borrower_Name_Snapshot__c = :CASE_KEY
    LIMIT 1
];
if (cases.isEmpty()) {
    System.debug('ABORT: AC-0001 not found for borrower ' + CASE_KEY);
} else {
    Audit_Case__c ac = cases[0];
    Id caseId = ac.Id;
    System.debug('AC-0001 = ' + caseId + ' | Risk_Tier=' + ac.Risk_Tier__c + ' | Status=' + ac.Status__c);

    // ── 1. LOAN (insert-if-absent, then link the case) ──────────────────────────────
    Id loanId = ac.Loan__c;
    if (loanId == null) {
        List<Loan__c> existingLoan = [SELECT Id FROM Loan__c WHERE LOS_Loan_Id__c = :LOAN_KEY LIMIT 1];
        loanId = existingLoan.isEmpty() ? null : existingLoan[0].Id;
    }
    if (loanId == null) {
        // Approval date drives ReplayService policy resolution; mirror the case snapshot timestamp.
        Date apprDate = ac.Approval_Timestamp__c != null
            ? ac.Approval_Timestamp__c.date()
            : Date.newInstance(2026, 5, 13);
        // LTV 85% story: 425,000 loan on a 500,000 property.
        Loan__c ln = new Loan__c(
            Borrower_Name__c    = CASE_KEY,
            Loan_Amount__c      = 425000,
            Property_Value__c   = 500000,
            Annual_Income__c    = 90000,
            Loan_Type__c        = 'Conventional',
            Purpose__c          = 'Purchase',
            Approval_Date__c    = apprDate,
            Approver_Name__c    = 'OrgFarm EPIC',
            Originating_Branch__c = 'Downtown',
            DTI_At_Approval__c  = 52.0,   // whole-number percent
            FICO_At_Approval__c = 600,
            LTV_At_Approval__c  = 85.0,   // whole-number percent
            LOS_Loan_Id__c      = LOAN_KEY
        );
        insert ln;
        loanId = ln.Id;
        System.debug('Inserted Loan__c ' + loanId);
    } else {
        System.debug('Loan__c already present: ' + loanId);
    }
    if (ac.Loan__c != loanId) {
        update new Audit_Case__c(Id = caseId, Loan__c = loanId);  // WORK-object lookup update only
        System.debug('Linked AC-0001.Loan__c -> ' + loanId);
    }

    // ── 2. BORROWER SNAPSHOTS (insert-if-category-absent) ───────────────────────────
    // ReplayService merges every snapshot's typed fields into one fact map, keyed by API name.
    Set<String> haveCats = new Set<String>();
    for (Borrower_Snapshot__c bs : [
        SELECT Fact_Category__c FROM Borrower_Snapshot__c WHERE Audit_Case__c = :caseId
    ]) {
        haveCats.add(bs.Fact_Category__c);
    }
    List<Borrower_Snapshot__c> newSnaps = new List<Borrower_Snapshot__c>();
    if (!haveCats.contains('Credit')) {
        newSnaps.add(new Borrower_Snapshot__c(
            Audit_Case__c    = caseId,
            Fact_Category__c = 'Credit',
            FICO_Score__c    = 600,     // GTE 620 -> HARD FAIL (also GTE 680 pref -> info fail)
            DTI_Ratio__c     = 52.0,    // LTE 43  -> HARD FAIL  (52.0% not 0.52)
            Monthly_Income__c = 7500,
            Monthly_Debt__c  = 3900,
            Confidence__c    = 95,
            Verified__c      = false,
            Extractor_Version__c = 'fix-ac-0001'
        ));
    }
    if (!haveCats.contains('Asset')) {
        newSnaps.add(new Borrower_Snapshot__c(
            Audit_Case__c    = caseId,
            Fact_Category__c = 'Asset',
            LTV_Ratio__c     = 85.0,    // LTE 80  -> HARD FAIL  (LTE 90 pref -> pass)
            Asset_Value__c   = 45000,   // GTE 100000 -> info fail (reserves shortfall)
            Annual_Income__c = 90000,
            Confidence__c    = 95,
            Verified__c      = false,
            Extractor_Version__c = 'fix-ac-0001'
        ));
    }
    if (!newSnaps.isEmpty()) {
        insert newSnaps;
        System.debug('Inserted ' + newSnaps.size() + ' Borrower_Snapshot__c');
    } else {
        System.debug('Borrower_Snapshot__c already present; no-op');
    }

    // ── 3. EVIDENCE GAPS (insert-if-doctype-absent; at least one required-Missing) ───
    Set<String> haveDocs = new Set<String>();
    for (Evidence_Item__c ei : [
        SELECT Document_Type__c FROM Evidence_Item__c WHERE Audit_Case__c = :caseId
    ]) {
        haveDocs.add(ei.Document_Type__c);
    }
    // Required post-approval docs that are missing on this Critical case (investigation triggers,
    // never auto-fails — ADR-3). Status uses the canonical Evidence_Item__c.Status__c value 'Missing'.
    final Set<String> REQUIRED_MISSING = new Set<String>{'Employment_Verification', 'Tax_Return'};
    List<Evidence_Item__c> newEvidence = new List<Evidence_Item__c>();
    for (String docType : REQUIRED_MISSING) {
        if (!haveDocs.contains(docType)) {
            newEvidence.add(new Evidence_Item__c(
                Audit_Case__c    = caseId,
                Document_Type__c = docType,
                Status__c        = 'Missing',
                Required__c      = true
            ));
        }
    }
    if (!newEvidence.isEmpty()) {
        insert newEvidence;
        System.debug('Inserted ' + newEvidence.size() + ' required-Missing Evidence_Item__c');
    } else {
        System.debug('Required-Missing evidence already present; no-op');
    }

    System.debug('DONE: AC-0001 repaired and replay-ready. Risk_Tier untouched = ' + ac.Risk_Tier__c);
}
