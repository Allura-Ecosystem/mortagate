// Clean junk Audit_Case__c rows (Loan__c = null) that have NO guarded children.
// Guarded children (Audit_Event__c, Replay_Check__c) are append-only per Allura governance —
// cases holding them are left untouched. Deletes go to the recycle bin (reversible).
Set<Id> protectedIds = new Set<Id>();
for (Audit_Event__c e : [SELECT Audit_Case__c FROM Audit_Event__c WHERE Audit_Case__r.Loan__c = null]) {
    protectedIds.add(e.Audit_Case__c);
}
for (Replay_Check__c r : [SELECT Audit_Case__c FROM Replay_Check__c WHERE Audit_Case__r.Loan__c = null]) {
    protectedIds.add(r.Audit_Case__c);
}
List<Audit_Case__c> junk = [
    SELECT Id FROM Audit_Case__c
    WHERE Loan__c = null AND Id NOT IN :protectedIds
];
System.debug('Deleting ' + junk.size() + ' junk cases; skipping ' + protectedIds.size() + ' guarded.');
delete junk;
System.debug('Done. Guarded junk remaining: ' + protectedIds.size());
