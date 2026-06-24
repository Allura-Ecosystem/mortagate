import { LightningElement, api } from 'lwc';

/**
 * glossaryTerm — the "Leo rule" plain-language helper.
 *
 * Presentational ONLY: no server call, no wire. It shows a piece of mortgage
 * jargon (a term word OR a rule code) and an accessible info tooltip whose text
 * comes from a STATIC dictionary kept right here in the component. The copy is
 * kept ~6th-grade so a non-expert (Leo) can read it.
 *
 * Why static (no Glossary__mdt): creating a CMDT with seed records GACKs on the
 * veridact-af org family (R-9). A presentational LWC sidesteps the data-deploy
 * entirely while still closing the plain-language finding.
 *
 * Usage:
 *   <c-glossary-term term="DTI"></c-glossary-term>      // looks up a term word
 *   <c-glossary-term code="DTI_MAX"></c-glossary-term>  // looks up a rule code
 *
 * `code` wins if both are supplied.
 *
 * THE LEO FLIP (UX panel, all 4 personas): the PLAIN NAME is now the primary
 * on-screen label; the raw code is demoted to a small muted mono badge beside
 * it (auditors/engineers still see the canonical token). The longer jargon
 * sentence stays in the "?" tooltip. An UNKNOWN code shows the code as-is
 * (no badge, no tooltip) so nothing ever silently disappears.
 */

// code/term → short plain NAME shown as the primary label (the Leo flip).
const PLAIN_NAME = {
    DTI_MAX: 'Debt vs. income too high',
    DTI_WARN: 'Debt vs. income is getting high',
    FICO_MIN: 'Credit score too low',
    LTV_MAX: 'Loan too big vs. home value',
    INCOME_MIN: 'Income is below the minimum needed',
    EMPLOY_MIN: 'Has not worked at the job long enough',
    ASSET_MIN: 'Not enough savings in the bank',
    DEBT_MAX: 'Total debt is over the limit',
    FICO_PREF: 'Credit score is below the preferred level',
    LTV_PREF: 'Loan is bigger than the preferred level vs. home value'
};

// code/term → longer jargon sentence kept in the "?" tooltip.
const DICTIONARY = {
    // ── Common jargon (terms) ──
    DTI: 'Debt-to-income: how much of monthly pay goes to debt.',
    LTV: 'Loan-to-value: loan amount vs. home value.',
    FICO: 'Credit score.',
    REPLAY: 'Re-run the original rules on the loan.',
    EXCEPTION: 'A rule was bent on purpose, with sign-off.',
    VIOLATION: 'A rule was broken.',
    // ── Rule codes ──
    DTI_MAX: 'Debt vs. income too high.',
    DTI_WARN: 'Debt vs. income is getting high.',
    FICO_MIN: 'Credit score too low.',
    LTV_MAX: 'Loan too big vs. home value.',
    INCOME_MIN: 'Income is below the minimum needed.',
    EMPLOY_MIN: 'Has not worked at the job long enough.',
    ASSET_MIN: 'Not enough savings in the bank.',
    DEBT_MAX: 'Total debt is over the limit.',
    FICO_PREF: 'Credit score is below the preferred level.',
    LTV_PREF: 'Loan is bigger than the preferred level vs. home value.'
};

export default class GlossaryTerm extends LightningElement {
    /** A jargon term word, e.g. "DTI". */
    @api term;
    /** A rule code, e.g. "DTI_MAX". Takes priority over `term`. */
    @api code;

    /** The raw token (canonical for auditors/engineers). */
    get token() {
        return this.code || this.term || '';
    }

    /** Is the token one we have a plain NAME for? */
    get hasPlainName() {
        return PLAIN_NAME[this.token.toUpperCase()] !== undefined;
    }

    /**
     * PRIMARY visible label. Known token → its plain name; unknown → the raw
     * token itself (never blank, never silently dropped).
     */
    get label() {
        return PLAIN_NAME[this.token.toUpperCase()] || this.token;
    }

    /** The raw code shown as a small secondary badge — only when we flipped. */
    get codeBadge() {
        return this.hasPlainName ? this.token : '';
    }

    /** Render the badge only when the primary label is the plain name. */
    get hasCodeBadge() {
        return this.codeBadge.length > 0;
    }

    /** Look up the longer jargon explanation for the tooltip; empty when none. */
    get explanation() {
        return DICTIONARY[this.token.toUpperCase()] || '';
    }

    /** Only render the help icon when we actually have an explanation. */
    get hasExplanation() {
        return this.explanation.length > 0;
    }
}
