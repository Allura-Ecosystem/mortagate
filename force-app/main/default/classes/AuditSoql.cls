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
}
