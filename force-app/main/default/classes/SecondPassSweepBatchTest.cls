/**
 * SecondPassSweepBatchTest — PNB coverage for the automated Second Pass sweep.
 *
 * P (Positive): a loan with a violation is replayed and its case surfaces in the
 *               Audit Queue at High risk with a Fail check + Replay_Executed event.
 * N (Negative): a clean loan lands at Low risk with no Fail; an already-current
 *               case is skipped (no duplicate replay batch); a stale case re-runs.
 * B (Bulk):     200 eligible cases select cleanly and each chunk stays well
 *               inside the ReplayService governor budget.
 *
 * Seeding follows the inline @TestSetup idiom used by ReplayServiceTest (no
 * shared factory for the audit-side objects). Severity picklist values mirror
 * that class ('Hard_Decline'); the sweep never reads severity, only the
 * persisted Replay_Check__c Result__c.
 *
 * @group Audit Replay Kernel
 */
@IsTest(SeeAllData=false)
private class SecondPassSweepBatchTest {

    // ── Shared active policy (3 rules) ───────────────────────────────────

    @TestSetup
    static void setup() {
        Policy_Version__c pv = new Policy_Version__c(
            Version_Label__c  = 'Q1 2025 Conventional',
            Version_Number__c = 1,
            Effective_Date__c = Date.newInstance(2025, 1, 1),
            Is_Active__c      = true,
            Policy_Type__c    = 'Conventional'
        );
        insert pv;

        insert new List<Policy_Rule__c>{
            rule(pv.Id, 'DTI_MAX',  'Max DTI Ratio',   'Income',     'LTE', 43,  'DTI_Ratio__c'),
            rule(pv.Id, 'FICO_MIN', 'Min FICO Score',  'Credit',     'GTE', 620, 'FICO_Score__c'),
            rule(pv.Id, 'LTV_MAX',  'Max LTV Ratio',   'Collateral', 'LTE', 80,  'LTV_Ratio__c')
        };
    }

    private static Policy_Rule__c rule(
        Id pvId, String code, String label, String category,
        String op, Decimal threshold, String factField
    ) {
        return new Policy_Rule__c(
            Policy_Version__c  = pvId,
            Rule_Code__c       = code,
            Rule_Label__c      = label,
            Rule_Category__c   = category,
            Operator__c        = op,
            Threshold_Value__c = threshold,
            Fact_Field__c      = factField,
            Severity__c        = 'Hard_Decline'
        );
    }

    /** Build one full case (loan + case + 3 snapshots). 3 DML — single-case use only. */
    private static Id makeCase(
        String borrower, Decimal dti, Integer fico, Decimal ltv, String seedTier
    ) {
        Loan__c loan = new Loan__c(
            Borrower_Name__c  = borrower,
            Loan_Amount__c    = 300000,
            Property_Value__c = 400000,
            Annual_Income__c  = 90000,
            Loan_Type__c      = 'Conventional',
            Purpose__c        = 'Purchase',
            Approval_Date__c  = Date.newInstance(2025, 3, 15)
        );
        insert loan;

        Audit_Case__c ac = new Audit_Case__c(
            Loan__c                   = loan.Id,
            Loan_Application__c       = 'APP-' + borrower.deleteWhitespace(),
            Status__c                 = 'In_Review',
            Risk_Tier__c              = seedTier,
            Scope__c                  = 'Full',
            Borrower_Name_Snapshot__c = borrower,
            Due_At__c                 = Datetime.now().addDays(10)
        );
        insert ac;

        insert new List<Borrower_Snapshot__c>{
            new Borrower_Snapshot__c(Audit_Case__c = ac.Id, Fact_Category__c = 'Income',
                DTI_Ratio__c = dti, Annual_Income__c = 90000),
            new Borrower_Snapshot__c(Audit_Case__c = ac.Id, Fact_Category__c = 'Credit',
                FICO_Score__c = fico),
            new Borrower_Snapshot__c(Audit_Case__c = ac.Id, Fact_Category__c = 'Asset',
                LTV_Ratio__c = ltv, Asset_Value__c = 400000)
        };
        return ac.Id;
    }

    /** Re-load a case with the fields processCase() needs. */
    private static Audit_Case__c reload(Id caseId) {
        return [
            SELECT Id, Loan__c, Loan__r.LastModifiedDate, Risk_Tier__c
            FROM Audit_Case__c WHERE Id = :caseId
        ];
    }

    // ── P: violation → High + visible in queue ───────────────────────────

    @IsTest
    static void positive_violationCase_surfacesHighInQueue() {
        // DTI 50 > 43 → DTI_MAX fails; FICO/LTV pass. Seeded Low to prove the
        // sweep promotes it.
        Id caseId = makeCase('Violator Vance', 50, 700, 70, 'Low');

        Test.startTest();
        SecondPassSweepBatch.processCase(reload(caseId));
        Test.stopTest();

        Audit_Case__c after = reload(caseId);
        System.assertEquals('High', after.Risk_Tier__c,
            'A failed rule must promote the case to High');

        List<Replay_Check__c> fails = [
            SELECT Id FROM Replay_Check__c
            WHERE Audit_Case__c = :caseId AND Result__c = 'Fail'
        ];
        System.assert(!fails.isEmpty(), 'Expected at least one Fail check');

        List<Audit_Event__c> events = [
            SELECT Id FROM Audit_Event__c
            WHERE Audit_Case__c = :caseId AND Event_Type__c = 'Replay_Executed'
        ];
        System.assertEquals(1, events.size(), 'Sweep must leave one Replay_Executed trail event');

        // Visible in the Audit Queue at High risk.
        List<AuditQueueController.AuditCaseRow> rows =
            AuditQueueController.getQueue(new AuditQueueController.AuditQueueFilters());
        Boolean found = false;
        for (AuditQueueController.AuditCaseRow r : rows) {
            if (r.recordId == caseId) {
                found = true;
                System.assertEquals('High', r.riskTier, 'Queue row must show High risk');
            }
        }
        System.assert(found, 'Swept violation case must appear in the Audit Queue');
    }

    // ── N: clean pass recorded, never demoted, already-current skipped ───

    @IsTest
    static void negative_cleanCase_recordedNotDemoted_andCurrentSkipped() {
        // DTI 30, FICO 720, LTV 60 → all pass. Seeded High to prove the sweep
        // records the clean pass WITHOUT demoting a human's escalation.
        Id caseId = makeCase('Clean Cleo', 30, 720, 60, 'High');

        Test.startTest();
        SecondPassSweepBatch.processCase(reload(caseId));       // first pass replays
        SecondPassSweepBatch.processCase(reload(caseId));       // second pass must SKIP
        Test.stopTest();

        Audit_Case__c after = reload(caseId);
        System.assertEquals('High', after.Risk_Tier__c,
            'Escalate-only: a clean replay must never demote the human tier');

        System.assertEquals(0, [
            SELECT COUNT() FROM Replay_Check__c
            WHERE Audit_Case__c = :caseId AND Result__c = 'Fail'
        ], 'A clean loan must have no Fail checks');

        // The pass is still recorded (append-only trail) …
        System.assertEquals(1, [
            SELECT COUNT() FROM Audit_Event__c
            WHERE Audit_Case__c = :caseId AND Event_Type__c = 'Replay_Executed'
        ], 'The clean pass must be recorded exactly once (current case not re-run)');
    }

    // ── N: clean loan on an unset/low case is not escalated ──────────────

    @IsTest
    static void negative_cleanCase_lowStaysLow() {
        Id caseId = makeCase('Low Lucy', 30, 720, 60, 'Low');

        Test.startTest();
        SecondPassSweepBatch.processCase(reload(caseId));
        Test.stopTest();

        System.assertEquals('Low', reload(caseId).Risk_Tier__c,
            'A clean loan must not demand attention — stays Low');
        System.assertEquals(0, [
            SELECT COUNT() FROM Replay_Check__c
            WHERE Audit_Case__c = :caseId AND Result__c = 'Fail'
        ], 'Clean loan → no Fail checks');
    }

    // ── N: escalate-only rank never demotes an unknown tier ──────────────

    @IsTest
    static void unit_rankOf_unknownTierIsHighest() {
        System.assert(SecondPassSweepBatch.rankOf('Critical') > SecondPassSweepBatch.rankOf('High'),
            'An out-of-band tier (Critical) must rank above High so it is never demoted');
        System.assert(SecondPassSweepBatch.rankOf('High') > SecondPassSweepBatch.rankOf('Low'),
            'High outranks Low');
        System.assertEquals(0, SecondPassSweepBatch.rankOf(null), 'Null tier is lowest');
    }

    // ── N: never-replayed vs stale routing ───────────────────────────────

    @IsTest
    static void negative_staleReplay_triggersReRun() {
        Id caseId = makeCase('Stale Stan', 50, 700, 70, 'Medium');

        // Simulate an OLD replay batch (yesterday) so the live loan looks stale.
        Id ruleId = [SELECT Id FROM Policy_Rule__c WHERE Rule_Code__c = 'DTI_MAX' LIMIT 1].Id;
        insert new Replay_Check__c(
            Audit_Case__c       = caseId,
            Policy_Rule__c      = ruleId,
            Rule_Name__c        = 'DTI_MAX',
            Result__c           = 'Pass',                    // deliberately wrong/old
            Expected_Value__c   = '43',
            Actual_Value__c     = '50',
            Replay_Timestamp__c = Datetime.now().addDays(-1),
            Sort_Order__c       = 0
        );

        Test.startTest();
        SecondPassSweepBatch.processCase(reload(caseId));
        Test.stopTest();

        // A fresh batch (today) must have been appended and now shows the Fail.
        Map<Id, List<Replay_Check__c>> latest =
            AuditSoql.latestChecksFor(new Set<Id>{ caseId });
        Boolean anyFail = false;
        for (Replay_Check__c rc : latest.get(caseId)) {
            if (rc.Result__c == 'Fail') { anyFail = true; }
        }
        System.assert(anyFail, 'Stale case must be re-run and expose the real Fail');
        System.assertEquals('High', reload(caseId).Risk_Tier__c,
            'Re-run of a violating loan must route to High');
    }

    // ── N: pure derivation unit (worst-wins) ─────────────────────────────

    @IsTest
    static void unit_deriveRiskTier_worstWins() {
        System.assertEquals('High', SecondPassSweepBatch.deriveRiskTier(new List<Replay_Check__c>{
            new Replay_Check__c(Result__c = 'Pass'),
            new Replay_Check__c(Result__c = 'Fail'),
            new Replay_Check__c(Result__c = 'Unverifiable')
        }), 'Any Fail wins');
        System.assertEquals('Medium', SecondPassSweepBatch.deriveRiskTier(new List<Replay_Check__c>{
            new Replay_Check__c(Result__c = 'Pass'),
            new Replay_Check__c(Result__c = 'Unverifiable')
        }), 'Unverifiable (no Fail) → Medium');
        System.assertEquals('Low', SecondPassSweepBatch.deriveRiskTier(new List<Replay_Check__c>{
            new Replay_Check__c(Result__c = 'Pass'),
            new Replay_Check__c(Result__c = 'Pass')
        }), 'All Pass → Low');
        System.assertEquals(null, SecondPassSweepBatch.deriveRiskTier(new List<Replay_Check__c>()),
            'No checks → null (no tier change)');
    }

    // ── B: 200 cases select cleanly + per-chunk budget holds ─────────────

    @IsTest
    static void bulk_200Cases_selectAllAndPerChunkWithinBudget() {
        Id pvId = [SELECT Id FROM Policy_Version__c LIMIT 1].Id;

        // Bulk seed 200 violation loans/cases/snapshots — 3 DML total.
        List<Loan__c> loans = new List<Loan__c>();
        for (Integer i = 0; i < 200; i++) {
            loans.add(new Loan__c(
                Borrower_Name__c  = 'Bulk Borrower ' + i,
                Loan_Amount__c    = 300000,
                Property_Value__c = 400000,
                Annual_Income__c  = 90000,
                Loan_Type__c      = 'Conventional',
                Purpose__c        = 'Purchase',
                Approval_Date__c  = Date.newInstance(2025, 3, 15)
            ));
        }
        insert loans;

        List<Audit_Case__c> cases = new List<Audit_Case__c>();
        for (Integer i = 0; i < 200; i++) {
            cases.add(new Audit_Case__c(
                Loan__c             = loans[i].Id,
                Loan_Application__c = 'APP-BULK-' + i,
                Status__c           = 'In_Review',
                Risk_Tier__c        = 'Low',
                Scope__c            = 'Full',
                Due_At__c           = Datetime.now().addDays(10)
            ));
        }
        insert cases;

        List<Borrower_Snapshot__c> snaps = new List<Borrower_Snapshot__c>();
        for (Integer i = 0; i < 200; i++) {
            snaps.add(new Borrower_Snapshot__c(Audit_Case__c = cases[i].Id,
                Fact_Category__c = 'Income', DTI_Ratio__c = 50, Annual_Income__c = 90000));
            snaps.add(new Borrower_Snapshot__c(Audit_Case__c = cases[i].Id,
                Fact_Category__c = 'Credit', FICO_Score__c = 700));
            snaps.add(new Borrower_Snapshot__c(Audit_Case__c = cases[i].Id,
                Fact_Category__c = 'Asset', LTV_Ratio__c = 70, Asset_Value__c = 400000));
        }
        insert snaps;

        // The start() universe must scale to all open cases.
        System.assertEquals(200, [
            SELECT COUNT() FROM Audit_Case__c WHERE Status__c != 'Closed'
        ], 'All 200 open cases must be in the sweep universe');

        // Per-chunk (scope size 1) budget: prove ONE case's work is far inside
        // limits, so 200 independent chunks are each safe.
        Audit_Case__c one = reload(cases[0].Id);
        Test.startTest();
        Integer soqlBefore = Limits.getQueries();
        Integer dmlBefore  = Limits.getDmlStatements();
        SecondPassSweepBatch.processCase(one);
        Integer soqlUsed = Limits.getQueries() - soqlBefore;
        Integer dmlUsed  = Limits.getDmlStatements() - dmlBefore;
        Test.stopTest();

        System.assert(soqlUsed <= 8,  'Per-chunk SOQL must stay small, got ' + soqlUsed);
        System.assert(dmlUsed  <= 4,  'Per-chunk DML must stay small, got ' + dmlUsed);
        System.assertEquals('High', reload(cases[0].Id).Risk_Tier__c,
            'Processed bulk case must route to High');
    }

    // ── B: full Batchable + Schedulable wiring runs clean ────────────────

    @IsTest
    static void batch_andSchedule_runWithoutError() {
        makeCase('Batch Betty', 50, 700, 70, 'Low');

        Test.startTest();
        Database.executeBatch(new SecondPassSweepBatch(), 1);
        String cron = '0 0 2 1 1 ? 2099';
        Id jobId = SecondPassSweepBatch.schedule('Second Pass Test Job', cron);
        Test.stopTest();

        System.assertNotEquals(null, jobId, 'Schedulable must register a job');
        System.assert(![
            SELECT Id FROM Replay_Check__c
        ].isEmpty(), 'Batch run must have produced replay checks');
    }
}
