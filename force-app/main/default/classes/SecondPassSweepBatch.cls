/**
 * SecondPassSweepBatch — the "automated second pass behind the human auditor".
 *
 * The product promise is a machine re-check that runs on a schedule, replays
 * every eligible loan through the EXISTING deterministic kernel, and surfaces
 * exceptions in the Audit Queue. There is NO LLM anywhere in this path
 * (ADR-21: the kernel decides, the agent only narrates). This batch is the one
 * place — unlike the read-only LoanDiagnosisService — that is allowed to WRITE,
 * because a scheduled pass legitimately (re)commits replay results.
 *
 * ── What "eligible" means ────────────────────────────────────────────────
 * Replay is case-centric: Borrower_Snapshot__c (the facts) and Evidence_Item__c
 * hang off Audit_Case__c, and ReplayService.replay(auditCaseId) reads them. A
 * loan with no case has no snapshots, so it cannot be replayed without an
 * origination step that is out of scope here. So the sweep's universe is the
 * cases already in the system, and a case is eligible when it is OPEN
 * (Status != Closed) AND either:
 *   • it has NEVER been replayed (no Replay_Check__c), or
 *   • its latest replay is STALE — the loan was edited after the last replay
 *     (Loan.LastModifiedDate > newest Replay_Timestamp__c).
 * The staleness concept is the same one LoanDiagnosisService.narrate() uses to
 * warn "this loan changed after the last check".
 *
 * ── Why chunk size 1 ─────────────────────────────────────────────────────
 * ReplayService.replay is a single-case orchestrator with a fixed budget of
 * ~3 SOQL + 2 DML per case. To honour the "no SOQL/DML in loops" invariant and
 * keep every batch chunk inside governor limits, this batch MUST run at scope
 * size 1 — one Audit_Case__c per execute() transaction, each with its own fresh
 * governor context. Both entry points (the Schedulable and the runner script)
 * pass CHUNK_SIZE explicitly. Reusing ReplayService unchanged (rather than
 * re-implementing a bulk assembler) keeps the kernel contract in exactly one
 * place.
 *
 * ── Governance ───────────────────────────────────────────────────────────
 * Every replayed case gets the append-only 'Replay_Executed' Audit_Event__c
 * that ReplayService/ReplayCommitService already write — that IS the sweep's
 * audit trail. There is no orphan "sweep started/summary" event because
 * Audit_Event__c.Audit_Case__c is a REQUIRED lookup (a sweep-level event has no
 * legal parent) and Event_Type__c is a restricted picklist with no sweep value.
 *
 * ── Exception routing (escalate-only) ────────────────────────────────────
 * After a fresh replay, the sweep derives a worst-wins tier from the new
 * results: any Fail -> High (a violation the auditor must see), else any
 * Unverifiable -> Medium (papers missing), else Low (clean). It then RAISES the
 * case's Risk_Tier__c to that tier ONLY IF it is higher than the current tier.
 * It never LOWERS a tier. This is the "behind the human" contract: an automated
 * pass may surface something a person missed (escalate), but it must never
 * override a human's judgment downward — a manually escalated case (including
 * an out-of-band value such as 'Critical' that this code doesn't itself assign)
 * is treated as highest and is never demoted. A clean loan therefore has its
 * pass recorded via the 'Replay_Executed' event without demanding new attention;
 * it is not re-tiered down. Status is left entirely to the human workflow — the
 * sweep never closes or reassigns a person's case.
 *
 * @group Audit Replay Kernel
 * @see ReplayService
 * @see LoanDiagnosisService (read-only sibling; this is the write-side pass)
 * @see AuditSoql#latestChecksFor
 */
public with sharing class SecondPassSweepBatch implements Database.Batchable<SObject>, Schedulable {

    /**
     * One case per execute() transaction. This is REQUIRED for governor safety,
     * not a tuning knob: ReplayService spends ~2 SOQL + 2 DML per case, so any
     * chunk > 1 would multiply SOQL/DML across cases in a single transaction.
     */
    @TestVisible
    private static final Integer CHUNK_SIZE = 1;

    /**
     * Tier ordering for the escalate-only routing. Any value NOT in this map
     * (e.g. an out-of-band 'Critical') ranks above everything the sweep assigns,
     * so it is never demoted — see rankOf().
     */
    private static final Map<String, Integer> TIER_RANK = new Map<String, Integer>{
        'Low' => 1, 'Medium' => 2, 'High' => 3
    };

    // ── Schedulable entry (System.schedule-ready) ────────────────────────
    //
    // Sample cron — run nightly at 02:00:
    //   System.schedule('Veridact Second Pass - Nightly',
    //                   '0 0 2 * * ?', new SecondPassSweepBatch());
    // or use the schedule() helper below.
    public void execute(SchedulableContext sc) {
        Database.executeBatch(new SecondPassSweepBatch(), CHUNK_SIZE);
    }

    // ── Batchable ────────────────────────────────────────────────────────

    /**
     * Candidate universe: every OPEN audit case. Staleness / never-replayed
     * eligibility is decided per case in execute(), because it compares the
     * loan's LastModifiedDate to the per-case newest replay timestamp — a
     * per-case aggregate a single QueryLocator cannot express.
     */
    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT Id, Loan__c, Loan__r.LastModifiedDate, Risk_Tier__c
            FROM Audit_Case__c
            WHERE Status__c != 'Closed'
            ORDER BY CreatedDate ASC
        ]);
    }

    /**
     * CHUNK_SIZE = 1, so `scope` holds exactly one case. The loop keeps the
     * method correct for any chunk size, but the per-chunk governor budget is
     * only guaranteed at size 1 (see class header).
     */
    public void execute(Database.BatchableContext bc, List<Audit_Case__c> scope) {
        for (Audit_Case__c ac : scope) {
            processCase(ac);
        }
    }

    public void finish(Database.BatchableContext bc) {
        // No orphan summary event by design (required parent + restricted
        // picklist). The per-case 'Replay_Executed' events are the trail.
    }

    // ── Core per-case work (one ReplayService budget) ────────────────────

    /**
     * Replay one case if it is eligible, then route the outcome by risk tier.
     * Budget when eligible: 2 SOQL (staleness) + 2 SOQL (replay) + up to 3 DML
     * (2 replay commit + 1 tier update) — comfortably inside a single chunk.
     *
     * @param ac the case, pre-loaded with Loan__r.LastModifiedDate + Risk_Tier__c.
     */
    @TestVisible
    private static void processCase(Audit_Case__c ac) {
        if (ac == null) { return; }

        // 1. Eligibility — never replayed OR latest replay stale vs loan edit.
        List<Replay_Check__c> existing = AuditSoql.latestChecksFor(ac.Id);   // 2 SOQL
        Datetime newestReplay = null;
        for (Replay_Check__c rc : existing) {
            if (newestReplay == null || rc.Replay_Timestamp__c > newestReplay) {
                newestReplay = rc.Replay_Timestamp__c;
            }
        }
        Boolean neverReplayed = (newestReplay == null);
        Datetime loanTouched = (ac.Loan__r == null) ? null : ac.Loan__r.LastModifiedDate;
        Boolean stale = (!neverReplayed && loanTouched != null && loanTouched > newestReplay);
        if (!neverReplayed && !stale) {
            return; // already current — the human's pass reflects the latest loan state
        }

        // 2. Replay through the EXISTING deterministic kernel. This appends a
        //    fresh Replay_Check__c batch + one 'Replay_Executed' Audit_Event__c
        //    (the governance trail). 3 SOQL + 2 DML.
        List<Replay_Check__c> fresh = ReplayService.replay(ac.Id);
        if (fresh == null || fresh.isEmpty()) {
            return; // nothing to score (no approval date / no governing rules yet)
        }

        // 3. Exception routing — escalate-only. Raise to the worst-wins tier from
        //    the fresh results, but never demote a human's (or unknown) tier.
        String tier = deriveRiskTier(fresh);
        if (tier != null && rankOf(tier) > rankOf(ac.Risk_Tier__c)) {
            update new Audit_Case__c(Id = ac.Id, Risk_Tier__c = tier);       // 1 DML
        }
    }

    /**
     * Rank a tier for the escalate-only comparison. Null (unset) is lowest;
     * any unrecognised value (e.g. 'Critical') is treated as highest so the
     * sweep never demotes a tier it did not itself assign.
     */
    @TestVisible
    private static Integer rankOf(String tier) {
        if (tier == null) { return 0; }
        Integer r = TIER_RANK.get(tier);
        return (r == null) ? 99 : r;
    }

    /**
     * Worst-wins over the fresh replay results, using the values actually
     * persisted on Replay_Check__c (Pass / Fail / Unverifiable). Severity is
     * not stored per check, so a violation (Fail) is the strongest signal the
     * sweep can route on — which is exactly the auditor-facing intent: any
     * failed rule is an exception that must surface as High.
     *
     *   any Fail          -> High   (exception — needs auditor attention)
     *   else any Unverif. -> Medium (papers missing)
     *   else (all Pass)   -> Low    (clean pass — recorded, not demanding)
     *
     * Generic to whatever rules exist: it never names a rule code.
     */
    @TestVisible
    private static String deriveRiskTier(List<Replay_Check__c> checks) {
        if (checks == null || checks.isEmpty()) { return null; }
        Boolean anyFail = false;
        Boolean anyUnverifiable = false;
        for (Replay_Check__c rc : checks) {
            if (rc.Result__c == 'Fail') {
                anyFail = true;
            } else if (rc.Result__c == 'Unverifiable') {
                anyUnverifiable = true;
            }
        }
        if (anyFail) { return 'High'; }
        if (anyUnverifiable) { return 'Medium'; }
        return 'Low';
    }

    // ── Scheduling helper ────────────────────────────────────────────────

    /**
     * Convenience wrapper so callers don't have to remember the class handle.
     *
     *   SecondPassSweepBatch.schedule(
     *       'Veridact Second Pass - Nightly', '0 0 2 * * ?');
     *
     * @param jobName        display name for the scheduled job
     * @param cronExpression a Salesforce 6- or 7-field cron expression
     * @return the CronTrigger Id of the scheduled job
     */
    public static Id schedule(String jobName, String cronExpression) {
        return System.schedule(jobName, cronExpression, new SecondPassSweepBatch());
    }
}
