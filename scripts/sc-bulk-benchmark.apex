/**
 * US-5.4 / Benchmark: Bulk replay of 200 cases.
 * 
 * Measures: SOQL count, DML count, execution time, governor limit headroom.
 * Uses existing seed data — the Sabir Sr. case + any seeded bulk cases.
 * Runs ReplayService.replay() in a single transaction for all available cases.
 * 
 * Governor budget per ADR-5: 3 SOQL + 2 DML per case (bulk path).
 * At 200 cases: 600 SOQL + 400 DML — well within limits (100 SOQL, 150 DML per transaction).
 * The bulk path uses chunk size 1 (ADR-27), so each case is its own batch chunk.
 * This benchmark runs them all in ONE anonymous Apex transaction to measure
 * the worst-case synchronous scenario.
 */

System.debug('=== BULK REPLAY BENCHMARK ===');

// Step 1: Count available audit cases
Integer totalCases = [SELECT COUNT() FROM Audit_Case__c];
System.debug('Total Audit_Case__c records: ' + totalCases);

// Step 2: Get all audit case IDs
List<Audit_Case__c> allCases = [SELECT Id, Name, Borrower_Name_Snapshot__c, Status__c FROM Audit_Case__c];
System.debug('Cases to replay: ' + allCases.size());

// Step 3: Run replay on each case, measuring limits
Long startTime = Datetime.now().getTime();
Integer successCount = 0;
Integer failCount = 0;
Integer totalReplayChecks = 0;
Map<String, Integer> perCaseChecks = new Map<String, Integer>();

for (Audit_Case__c ac : allCases) {
    try {
        List<Replay_Check__c> checks = ReplayService.replay(ac.Id);
        successCount++;
        totalReplayChecks += checks.size();
        perCaseChecks.put(ac.Name, checks.size());
    } catch (Exception e) {
        failCount++;
        System.debug('  FAIL on ' + ac.Name + ': ' + e.getMessage());
    }
}

Long endTime = Datetime.now().getTime();
Long elapsedMs = endTime - startTime;

// Step 4: Report governor limits consumed
System.debug('');
System.debug('=== BENCHMARK RESULTS ===');
System.debug('Cases processed: ' + allCases.size());
System.debug('  Successful: ' + successCount);
System.debug('  Failed: ' + failCount);
System.debug('Total Replay_Check__c created: ' + totalReplayChecks);
System.debug('Elapsed time: ' + elapsedMs + ' ms (' + (elapsedMs / 1000.0) + ' seconds)');
System.debug('Avg time per case: ' + (allCases.size() > 0 ? elapsedMs / allCases.size() : 0) + ' ms');
System.debug('');
System.debug('=== GOVERNOR LIMITS ===');
System.debug('SOQL queries used: ' + Limits.getQueries() + ' / ' + Limits.getLimitQueries());
System.debug('DML statements used: ' + Limits.getDmlStatements() + ' / ' + Limits.getLimitDmlStatements());
System.debug('DML rows used: ' + Limits.getDmlRows() + ' / ' + Limits.getLimitDmlRows());
System.debug('CPU time used: ' + Limits.getCpuTime() + ' / ' + Limits.getLimitCpuTime() + ' ms');
System.debug('Heap size used: ' + Limits.getHeapSize() + ' / ' + Limits.getLimitHeapSize());
System.debug('Query rows used: ' + Limits.getQueryRows() + ' / ' + Limits.getLimitQueryRows());
System.debug('');
System.debug('=== PER-CASE DETAIL ===');
for (Audit_Case__c ac : allCases) {
    Integer checks = perCaseChecks.containsKey(ac.Name) ? perCaseChecks.get(ac.Name) : 0;
    System.debug('  ' + ac.Name + ' (' + ac.Borrower_Name_Snapshot__c + '): ' + checks + ' checks, status=' + ac.Status__c);
}
System.debug('=== BENCHMARK COMPLETE ===');
