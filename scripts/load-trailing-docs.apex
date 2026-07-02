// load-trailing-docs.apex — additive seed of required trailing-doc evidence.
// Run: sf apex run --target-org mortagate-de -f scripts/load-trailing-docs.apex
//
// Idempotent & non-destructive: inserts the two trailing-doc Evidence_Item__c
// children on the Sabir Sr. hero case ONLY if they are not already present.
// Existing records are never modified or deleted. Bulk-safe (no DML in loops).
// Represents "required trailing docs missing post-close" per DESIGN-second-pass-data.md.
// ADR-3: Status = Missing is an investigation trigger, never an auto-fail.

final String HERO = 'Sabir Asheed Sr.';
final Map<String, String> TRAILING = new Map<String, String>{
    'Recorded_Mortgage'  => 'Recorded Mortgage',
    'Final_Title_Policy' => 'Final Title Policy'
};

List<Audit_Case__c> cases = [
    SELECT Id FROM Audit_Case__c WHERE Borrower_Name_Snapshot__c = :HERO LIMIT 1
];
if (cases.isEmpty()) {
    System.debug('ABORT: hero case not found for ' + HERO);
} else {
    Id caseId = cases[0].Id;

    Set<String> existingTypes = new Set<String>();
    for (Evidence_Item__c ei : [
        SELECT Document_Type__c FROM Evidence_Item__c
        WHERE Audit_Case__c = :caseId AND Document_Type__c IN :TRAILING.keySet()
    ]) {
        existingTypes.add(ei.Document_Type__c);
    }

    List<Evidence_Item__c> toInsert = new List<Evidence_Item__c>();
    for (String docType : TRAILING.keySet()) {
        if (!existingTypes.contains(docType)) {
            toInsert.add(new Evidence_Item__c(
                Audit_Case__c    = caseId,
                Document_Type__c = docType,
                Status__c        = 'Missing',   // trailing doc not yet received post-close
                Required__c      = true
            ));
        }
    }

    if (toInsert.isEmpty()) {
        System.debug('No-op: trailing docs already present on case ' + caseId);
    } else {
        insert toInsert;
        System.debug('Inserted ' + toInsert.size() + ' trailing-doc Evidence_Item__c on ' + caseId);
    }
}
