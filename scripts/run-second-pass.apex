/*
 * run-second-pass.apex — kick the automated Second Pass sweep on demand.
 *
 * Replays every eligible (open, never-replayed OR stale) Audit_Case__c through
 * the deterministic kernel and routes exceptions into the queue by risk tier.
 * Chunk size 1 = one ReplayService budget (~3 SOQL + 2 DML) per case.
 *
 *   sf apex run --file scripts/run-second-pass.apex --target-org mortagate-de
 *
 * To schedule it nightly instead of running once:
 *   SecondPassSweepBatch.schedule('Veridact Second Pass - Nightly', '0 0 2 * * ?');
 */
Id jobId = Database.executeBatch(new SecondPassSweepBatch(), 1);
System.debug('Second Pass sweep enqueued: ' + jobId);
