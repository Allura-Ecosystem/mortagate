/**
 * RuleNarration — shared plain-language helpers for the Agentforce "second pass"
 * copilot actions (CaseSummaryService, FindingDraftService). Centralises the
 * rule-code → plain-name vocabulary and the number formatting so every governed
 * action narrates a replay check the same way (the "Leo" plain-language rule).
 *
 * Pure: no SOQL, no DML — safe to call inside Phase-2 compute.
 *
 * NOTE (known debt): LoanDiagnosisService predates this helper and keeps its own
 * private copy of the same vocabulary. New actions funnel through here so there
 * is one source of truth for everything built after ADR-26; folding the
 * diagnosis service onto this helper is a follow-up refactor (Fowler).
 *
 * @group Agentforce
 */
public with sharing class RuleNarration {

    // Code → plain NAME (the Leo flip: lead with the plain name, keep the code as
    // a parenthetical badge). Unknown codes fall back to the raw code, never blank.
    private static final Map<String, String> PLAIN_NAME = new Map<String, String>{
        'DTI_MAX'    => 'Debt vs. income too high',
        'DTI_WARN'   => 'Debt vs. income is getting high',
        'FICO_MIN'   => 'Credit score too low',
        'LTV_MAX'    => 'Loan too big vs. home value',
        'INCOME_MIN' => 'Income is below the minimum needed',
        'EMPLOY_MIN' => 'Has not worked at the job long enough',
        'ASSET_MIN'  => 'Not enough savings in the bank',
        'DEBT_MAX'   => 'Total debt is over the limit',
        'FICO_PREF'  => 'Credit score is below the preferred level',
        'LTV_PREF'   => 'Loan is bigger than the preferred level vs. home value'
    };

    /** Plain NAME for a rule code; unknown code falls back to the raw code. */
    public static String plainName(String code) {
        if (String.isBlank(code)) { return 'A rule'; }
        String key = code.toUpperCase();
        return PLAIN_NAME.containsKey(key) ? PLAIN_NAME.get(key) : code;
    }

    /**
     * Direction phrase derived from the code suffix so numbers read clearly to a
     * non-expert: ceilings say "the most allowed is", floors say "the lowest
     * allowed is", anything else "the limit is".
     */
    public static String directionPhrase(String code) {
        if (String.isBlank(code)) { return 'the limit is'; }
        String key = code.toUpperCase();
        if (key.endsWith('_MAX') || key.endsWith('_WARN')
            || key == 'DEBT_MAX' || key.startsWith('DTI_')) {
            return 'the most allowed is';
        }
        if (key.endsWith('_MIN') || key.endsWith('_PREF')) {
            return 'the lowest allowed is';
        }
        return 'the limit is';
    }

    /**
     * Format a stored numeric string for plain reading: drop trailing zeros so
     * "43.0000" reads as "43" and "44.80" as "44.8". Non-numeric falls back.
     */
    public static String prettyNum(String v) {
        if (String.isBlank(v)) { return 'n/a'; }
        try {
            return Decimal.valueOf(v).stripTrailingZeros().toPlainString();
        } catch (Exception e) {
            return v;
        }
    }

    /** Whole-number-percent display for a stored Percent(5,2) fact (e.g. 44.8 → "44.8%"). */
    public static String pct(Decimal v) {
        if (v == null) { return null; }
        return v.stripTrailingZeros().toPlainString() + '%';
    }

    /** De-underscore a picklist API value for display ("In_Review" → "In Review"). */
    public static String label(String apiValue) {
        return (apiValue == null) ? null : apiValue.replace('_', ' ');
    }
}
