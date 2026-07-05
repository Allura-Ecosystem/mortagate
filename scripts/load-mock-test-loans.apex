// load-mock-test-loans.apex — idempotent loader for 8 synthetic test loans.
// Run against a PILOT/SANDBOX org ONLY — never the mortagate-de golden demo dataset:
//   sf apex run --target-org casefile-pilot -f scripts/load-mock-test-loans.apex
//
// Reference: my-project/_bmad-output/test/MOCK-TEST-LOANS.md
// Units: audit-path whole-number percent (DTI 43.0 == 43%, NOT 0.43).
// Idempotent: gated by Loan__c.LOS_Loan_Id__c = 'MOCK-TEST-NN'. Re-running inserts nothing new.
// Bulk-safe: list-based inserts, no DML/SOQL inside loops. Ledger objects untouched.

final Date APPR = Date.today().addDays(-20);
final Datetime DUE = Datetime.now().addDays(70);   // inside the 90-day QC window

// key, name, loanAmt, propVal, annualIncome, monthlyDebt, dti%, fico, ltv%, identity, tier
List<List<Object>> ROWS = new List<List<Object>>{
    new List<Object>{'MOCK-TEST-01','Ava Chen',    390000,600000,120000, 2800, 28.0, 760, 65.0, 'Verified','Low'},
    new List<Object>{'MOCK-TEST-02','Marcus Bell', 400000,500000,100000, 3583, 43.0, 620, 80.0, 'Verified','Low'},
    new List<Object>{'MOCK-TEST-03','Dana Ortiz',  280000,400000, 90000, 3750, 50.0, 720, 70.0, 'Verified','High'},
    new List<Object>{'MOCK-TEST-04','Priya Nair',  210000,350000, 80000, 2000, 30.0, 590, 60.0, 'Verified','High'},
    new List<Object>{'MOCK-TEST-05','Sam Weber',   285000,300000,110000, 3208, 35.0, 700, 95.0, 'Verified','High'},
    new List<Object>{'MOCK-TEST-06','Ruth Okafor', 242500,250000, 60000, 2750, 55.0, 580, 97.0, 'Verified','Critical'},
    new List<Object>{'MOCK-TEST-07','Leo Park',    352000,400000, 96000, 3200, 40.0, 650, 88.0, 'Verified','Medium'},
    new List<Object>{'MOCK-TEST-08','Nadia Farouk',300000,500000,150000, 3750, 30.0, 780, 60.0, 'Failed',  'High'}
};

// ── Idempotency: which keys already exist? ──────────────────────────────────────
Set<String> keys = new Set<String>();
for (List<Object> r : ROWS) { keys.add((String) r[0]); }
Map<String, Id> existingLoanByKey = new Map<String, Id>();
for (Loan__c l : [SELECT Id, LOS_Loan_Id__c FROM Loan__c WHERE LOS_Loan_Id__c IN :keys]) {
    existingLoanByKey.put(l.LOS_Loan_Id__c, l.Id);
}

// ── 1. Loans (insert absent) ────────────────────────────────────────────────────
List<Loan__c> newLoans = new List<Loan__c>();
List<List<Object>> toBuild = new List<List<Object>>();
for (List<Object> r : ROWS) {
    if (existingLoanByKey.containsKey((String) r[0])) continue;
    toBuild.add(r);
    newLoans.add(new Loan__c(
        LOS_Loan_Id__c    = (String) r[0],
        Borrower_Name__c  = (String) r[1],
        Loan_Amount__c    = (Decimal) r[2],
        Property_Value__c = (Decimal) r[3],
        Annual_Income__c  = (Decimal) r[4],
        Loan_Type__c      = 'Conventional',
        Purpose__c        = 'Purchase',
        Approval_Date__c  = APPR,
        Approver_Name__c  = 'Mock Test Loader',
        Originating_Branch__c = 'Sandbox',
        DTI_At_Approval__c  = (Decimal) r[6],
        FICO_At_Approval__c = (Integer) r[7],
        LTV_At_Approval__c  = (Decimal) r[8],
        Identity_Verification_Status__c = (String) r[9]
    ));
}
if (!newLoans.isEmpty()) insert newLoans;
for (Integer i = 0; i < newLoans.size(); i++) {
    existingLoanByKey.put((String) toBuild[i][0], newLoans[i].Id);
}
System.debug('Loans: ' + newLoans.size() + ' inserted, ' + (ROWS.size() - newLoans.size()) + ' already present');

// ── 2. Audit cases (insert if none links the loan) ──────────────────────────────
Set<Id> loanIds = new Set<Id>(existingLoanByKey.values());
Set<Id> loansWithCase = new Set<Id>();
for (Audit_Case__c c : [SELECT Loan__c FROM Audit_Case__c WHERE Loan__c IN :loanIds]) {
    loansWithCase.add(c.Loan__c);
}
List<Audit_Case__c> newCases = new List<Audit_Case__c>();
Map<Id, List<Object>> rowByLoanId = new Map<Id, List<Object>>();
for (List<Object> r : ROWS) {
    Id loanId = existingLoanByKey.get((String) r[0]);
    rowByLoanId.put(loanId, r);
    if (loanId == null || loansWithCase.contains(loanId)) continue;
    newCases.add(new Audit_Case__c(
        Loan__c                 = loanId,
        Loan_Application__c     = loanId,                 // Text(18) ref, required
        Borrower_Name_Snapshot__c = (String) r[1],
        Approval_Timestamp__c   = APPR,
        Due_At__c               = DUE,
        Risk_Tier__c            = (String) r[10],
        Status__c               = 'In_Review'
    ));
}
if (!newCases.isEmpty()) insert newCases;
System.debug('Audit cases: ' + newCases.size() + ' inserted');

// ── 3. Borrower snapshots (Credit + Asset) for cases that have none ──────────────
Map<Id, Id> caseByLoan = new Map<Id, Id>();
for (Audit_Case__c c : [SELECT Id, Loan__c FROM Audit_Case__c WHERE Loan__c IN :loanIds]) {
    caseByLoan.put(c.Loan__c, c.Id);
}
Set<Id> caseIds = new Set<Id>(caseByLoan.values());
Set<Id> casesWithSnap = new Set<Id>();
for (Borrower_Snapshot__c s : [SELECT Audit_Case__c FROM Borrower_Snapshot__c WHERE Audit_Case__c IN :caseIds]) {
    casesWithSnap.add(s.Audit_Case__c);
}
List<Borrower_Snapshot__c> newSnaps = new List<Borrower_Snapshot__c>();
for (Id loanId : rowByLoanId.keySet()) {
    Id caseId = caseByLoan.get(loanId);
    if (caseId == null || casesWithSnap.contains(caseId)) continue;
    List<Object> r = rowByLoanId.get(loanId);
    Decimal moIncome = ((Decimal) r[4]) / 12;
    newSnaps.add(new Borrower_Snapshot__c(
        Audit_Case__c = caseId, Fact_Category__c = 'Credit',
        FICO_Score__c = (Integer) r[7], DTI_Ratio__c = (Decimal) r[6],
        Monthly_Income__c = moIncome.setScale(0), Monthly_Debt__c = (Decimal) r[5],
        Confidence__c = 95, Verified__c = true, Extractor_Version__c = 'mock-test'
    ));
    newSnaps.add(new Borrower_Snapshot__c(
        Audit_Case__c = caseId, Fact_Category__c = 'Asset',
        LTV_Ratio__c = (Decimal) r[8], Asset_Value__c = 60000,
        Annual_Income__c = (Decimal) r[4],
        Confidence__c = 95, Verified__c = true, Extractor_Version__c = 'mock-test'
    ));
}
if (!newSnaps.isEmpty()) insert newSnaps;
System.debug('Borrower snapshots: ' + newSnaps.size() + ' inserted');
System.debug('DONE. Run SecondPassSweepBatch (scripts/run-second-pass.apex) to replay + tier the queue.');
