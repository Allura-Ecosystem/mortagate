/**
 * AuditSoql — the shared read primitive for the Veridact auditor UI controllers.
 *
 * Pulls the "safe read" pattern out of AuditQueueController so every read-only
 * controller (AuditQueueController, CaseReviewController, …) enforces the same
 * three guarantees by construction:
 *
 *   1. USER_MODE   — every query runs at AccessLevel.USER_MODE, so FLS + sharing
 *                    are honoured and an auditor can never see a record (or
 *                    field) they lack access to. Pairs with `with sharing` on
 *                    the calling controller.
 *   2. BOUND BINDS — values reach SOQL only as bind variables (never string
 *                    concatenation), removing the SOQL-injection surface.
 *   3. SORT ALLOWLIST — an external sort key is resolved against a caller-owned
 *                    allowlist; anything unknown falls back to a safe default,
 *                    so the ORDER BY clause can never carry attacker input.
 *
 * This class holds NO object-specific knowledge — callers own their SELECT,
 * FROM, allowlist, and default. That keeps it reusable across objects while the
 * safety posture stays identical everywhere.
 *
 * @group Audit Shared
 */
public with sharing class AuditSoql {

    /** Absolute ceiling on rows any single audit-UI query may return. */
    @TestVisible public static final Integer MAX_LIMIT = 200;

    /**
     * Run a bound, user-mode query and return the rows.
     *
     * @param soql  the full SOQL string. All values MUST be expressed as bind
     *              variables (`:name`) present in `binds` — never concatenated.
     * @param binds bind variable name → value map.
     * @return the queried SObjects (user-mode; FLS/sharing enforced).
     */
    public static List<SObject> query(String soql, Map<String, Object> binds) {
        return Database.queryWithBinds(
            soql,
            (binds == null) ? new Map<String, Object>() : binds,
            AccessLevel.USER_MODE
        );
    }

    /**
     * Run a bound, user-mode COUNT() query.
     *
     * @param soql  a `SELECT COUNT() …` string using only bind variables.
     * @param binds bind variable name → value map.
     * @return the matching row count (user-mode).
     */
    public static Integer count(String soql, Map<String, Object> binds) {
        return Database.countQueryWithBinds(
            soql,
            (binds == null) ? new Map<String, Object>() : binds,
            AccessLevel.USER_MODE
        );
    }

    /**
     * Resolve an external sort key against an allowlist into a real SObject
     * field name. Unknown / null keys collapse to `defaultField`, so the ORDER
     * BY clause is always one of the caller's vetted fields.
     *
     * @param allowlist    external key → SObject field API name.
     * @param requestedKey the (untrusted) key from the client.
     * @param defaultField the field to use when the key is absent/unknown.
     */
    public static String resolveSortField(Map<String, String> allowlist,
                                          String requestedKey,
                                          String defaultField) {
        if (allowlist != null && requestedKey != null && allowlist.containsKey(requestedKey)) {
            return allowlist.get(requestedKey);
        }
        return defaultField;
    }

    /**
     * Normalise a requested sort direction to a safe `ASC`/`DESC` literal.
     * Only an explicit 'desc' yields DESC; everything else is ASC.
     */
    public static String resolveDirection(String requested) {
        return ('desc'.equalsIgnoreCase(requested)) ? 'DESC' : 'ASC';
    }

    /**
     * Clamp a requested page size into (0, MAX_LIMIT]. Null/non-positive values
     * fall back to `defaultLimit`; anything above MAX_LIMIT is capped. The
     * result is a sanitized Integer, safe to inline into a LIMIT clause.
     */
    public static Integer resolveLimit(Integer requested, Integer defaultLimit) {
        if (requested != null && requested > 0) {
            return Math.min(requested, MAX_LIMIT);
        }
        return defaultLimit;
    }

    // ── Replay-check supersede-by-query (R-11) ───────────────────────────

    /**
     * Replay_Check__c is part of the append-only audit trail — every replay run
     * INSERTS a fresh batch and prior batches are NEVER deleted. So a case that
     * has been replayed twice carries two stacked batches of checks. For any
     * *display* of "current" checks we must show only the LATEST batch, keyed by
     * the maximum Replay_Timestamp__c for that Audit_Case__c.
     *
     * This is the single, reusable definition of "current checks" so Case
     * Review, the sign-off receipt, and the diagnosis agent all agree on what a
     * re-run case currently looks like (Sabir replayed twice => 10 checks /
     * 2 fails, never 20 / 4).
     *
     * Bulk-safe: 2 SOQL total regardless of case count (1 aggregate to find the
     * per-case max timestamp, 1 to fetch that batch's rows), USER_MODE on both.
     *
     * @param caseIds the Audit_Case__c ids to resolve current checks for.
     * @return caseId -> the latest batch's Replay_Check__c rows
     *         (ordered by Sort_Order__c ASC). Cases with no checks are absent.
     */
    public static Map<Id, List<Replay_Check__c>> latestChecksFor(Set<Id> caseIds) {
        Map<Id, List<Replay_Check__c>> result = new Map<Id, List<Replay_Check__c>>();
        if (caseIds == null || caseIds.isEmpty()) {
            return result;
        }

        // 1) Per-case latest replay timestamp (the "current" batch marker).
        Map<Id, Datetime> latestByCase = new Map<Id, Datetime>();
        for (AggregateResult ar : [
            SELECT Audit_Case__c caseId, MAX(Replay_Timestamp__c) maxTs
            FROM Replay_Check__c
            WHERE Audit_Case__c IN :caseIds
            WITH USER_MODE
            GROUP BY Audit_Case__c
        ]) {
            latestByCase.put((Id) ar.get('caseId'), (Datetime) ar.get('maxTs'));
        }
        if (latestByCase.isEmpty()) {
            return result;
        }

        // 2) Fetch every check, then keep only those whose timestamp matches the
        //    per-case max. (A single bound query; the per-case timestamp equality
        //    is applied in-memory so we never issue a query per case.)
        Set<Datetime> latestStamps = new Set<Datetime>(latestByCase.values());
        for (Replay_Check__c rc : [
            SELECT Id, Audit_Case__c, Rule_Name__c, Result__c,
                   Expected_Value__c, Actual_Value__c, Rationale__c,
                   Sort_Order__c, Replay_Timestamp__c
            FROM Replay_Check__c
            WHERE Audit_Case__c IN :caseIds
              AND Replay_Timestamp__c IN :latestStamps
            WITH USER_MODE
            ORDER BY Sort_Order__c ASC NULLS LAST
        ]) {
            // Guard against the rare case where two different cases share a stamp:
            // only accept a row if it equals THIS case's max.
            if (rc.Replay_Timestamp__c == latestByCase.get(rc.Audit_Case__c)) {
                if (!result.containsKey(rc.Audit_Case__c)) {
                    result.put(rc.Audit_Case__c, new List<Replay_Check__c>());
                }
                result.get(rc.Audit_Case__c).add(rc);
            }
        }
        return result;
    }

    /**
     * Convenience single-case overload — returns the latest batch's checks for
     * one Audit_Case__c (empty list if none).
     */
    public static List<Replay_Check__c> latestChecksFor(Id caseId) {
        if (caseId == null) {
            return new List<Replay_Check__c>();
        }
        List<Replay_Check__c> checks = latestChecksFor(new Set<Id>{ caseId }).get(caseId);
        return (checks == null) ? new List<Replay_Check__c>() : checks;
    }
}
