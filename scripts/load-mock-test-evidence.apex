// load-mock-test-evidence.apex — idempotent evidence-gap loader for the 8 mock test loans.
// Run AFTER load-mock-test-loans.apex, against a PILOT/SANDBOX org ONLY:
//   sf apex run --target-org casefile-pilot -f scripts/load-mock-test-evidence.apex
//
// Reference: my-project/_bmad-output/test/MOCK-TEST-LOANS.md (§ Evidence gaps).
// Each mock case gets a realistic post-close document set — a mix of Linked (present),
// Missing (a required gap the copilot's "what evidence is missing?" action will surface),
// and Unverifiable — with the gaps chosen to match each loan's failure story.
//
// Idempotent: gated by (Audit_Case__c, Document_Type__c) pairs; re-running inserts nothing new.
// Bulk-safe: list-based inserts, no DML/SOQL in loops. Ledger objects untouched.

final Datetime RECEIVED = Datetime.now().addDays(-18);   // received just after approval, inside QC window

// Evidence plan per mock loan key: docType : status : required
// status ∈ Linked | Missing | Unverifiable
Map<String, List<String>> PLAN = new Map<String, List<String>>{
    // 01 Ava — clean/Low: fully documented, zero required gaps
    'MOCK-TEST-01' => new List<String>{
        'Pay_Stub:Linked:true','W2:Linked:true','Bank_Statement:Linked:true',
        'Appraisal:Linked:true','Credit_Report:Linked:true','Photo_ID:Linked:true'},
    // 02 Marcus — boundary/Low: mostly present, one illegible
    'MOCK-TEST-02' => new List<String>{
        'Pay_Stub:Linked:true','W2:Linked:true','Appraisal:Linked:true',
        'Credit_Report:Linked:true','Bank_Statement:Unverifiable:true'},
    // 03 Dana — DTI fail/High: income unverified compounds the DTI story
    'MOCK-TEST-03' => new List<String>{
        'Pay_Stub:Linked:true','Appraisal:Linked:true','Credit_Report:Linked:true',
        'Employment_Verification:Missing:true','W2:Missing:true'},
    // 04 Priya — FICO fail/High: credit + tax gaps
    'MOCK-TEST-04' => new List<String>{
        'Pay_Stub:Linked:true','Appraisal:Linked:true','Photo_ID:Linked:true',
        'Credit_Report:Missing:true','Tax_Return:Missing:true'},
    // 05 Sam — LTV fail/High: no appraisal → LTV cannot be substantiated
    'MOCK-TEST-05' => new List<String>{
        'Pay_Stub:Linked:true','W2:Linked:true','Credit_Report:Linked:true',
        'Appraisal:Missing:true','Purchase_Agreement:Unverifiable:true'},
    // 06 Ruth — triple fail/Critical: the worst trailing-doc gaps
    'MOCK-TEST-06' => new List<String>{
        'Pay_Stub:Linked:true','Credit_Report:Linked:true',
        'Appraisal:Missing:true','Recorded_Mortgage:Missing:true','Final_Title_Policy:Missing:true'},
    // 07 Leo — soft/Medium: one trailing doc outstanding (QC-window relevant)
    'MOCK-TEST-07' => new List<String>{
        'Pay_Stub:Linked:true','W2:Linked:true','Appraisal:Linked:true',
        'Credit_Report:Linked:true','Recorded_Mortgage:Linked:true','Final_Title_Policy:Missing:true'},
    // 08 Nadia — KYC block/High: identity doc missing, ties to the failed verification
    'MOCK-TEST-08' => new List<String>{
        'Pay_Stub:Linked:true','W2:Linked:true','Appraisal:Linked:true',
        'Credit_Report:Linked:true','Photo_ID:Missing:true'}
};

// ── Resolve mock loans → cases ──────────────────────────────────────────────────
Map<String, Id> loanKeyToId = new Map<String, Id>();
for (Loan__c l : [SELECT Id, LOS_Loan_Id__c FROM Loan__c WHERE LOS_Loan_Id__c IN :PLAN.keySet()]) {
    loanKeyToId.put(l.LOS_Loan_Id__c, l.Id);
}
if (loanKeyToId.isEmpty()) {
    System.debug('ABORT: no MOCK-TEST loans found. Run scripts/load-mock-test-loans.apex first.');
    return;
}
Map<Id, String> caseIdToKey = new Map<Id, String>();
Map<String, Id> keyToCaseId = new Map<String, Id>();
for (Audit_Case__c c : [SELECT Id, Loan__c, Loan__r.LOS_Loan_Id__c
                        FROM Audit_Case__c WHERE Loan__c IN :loanKeyToId.values()]) {
    keyToCaseId.put(c.Loan__r.LOS_Loan_Id__c, c.Id);
    caseIdToKey.put(c.Id, c.Loan__r.LOS_Loan_Id__c);
}

// ── Idempotency: existing (case, docType) pairs ─────────────────────────────────
Set<String> existingPairs = new Set<String>();
for (Evidence_Item__c e : [SELECT Audit_Case__c, Document_Type__c
                           FROM Evidence_Item__c WHERE Audit_Case__c IN :caseIdToKey.keySet()]) {
    existingPairs.add(e.Audit_Case__c + '|' + e.Document_Type__c);
}

// ── Build evidence rows ─────────────────────────────────────────────────────────
List<Evidence_Item__c> toInsert = new List<Evidence_Item__c>();
for (String loanKey : PLAN.keySet()) {
    Id caseId = keyToCaseId.get(loanKey);
    if (caseId == null) continue;
    for (String spec : PLAN.get(loanKey)) {
        List<String> parts = spec.split(':');
        String docType = parts[0];
        String status  = parts[1];
        Boolean required = Boolean.valueOf(parts[2]);
        if (existingPairs.contains(caseId + '|' + docType)) continue;
        Evidence_Item__c ei = new Evidence_Item__c(
            Audit_Case__c    = caseId,
            Document_Type__c = docType,
            Status__c        = status,
            Required__c      = required
        );
        if (status == 'Linked') {
            ei.Received_Timestamp__c = RECEIVED;
            ei.Notes__c = 'Mock test evidence (present).';
        } else if (status == 'Missing') {
            ei.Notes__c = 'Mock test evidence gap — required document not on file.';
        } else {
            ei.Notes__c = 'Mock test evidence — received but illegible/unverifiable.';
        }
        toInsert.add(ei);
    }
}
if (!toInsert.isEmpty()) insert toInsert;
System.debug('Evidence items: ' + toInsert.size() + ' inserted across ' + keyToCaseId.size() + ' mock cases.');
System.debug('DONE. The "what evidence is missing?" copilot action + QC-window lens now have gaps to surface.');
