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
 * `code` wins if both are supplied. The displayed label is the raw term/code
 * (engineers and auditors still see the canonical token); the explanation is in
 * the tooltip so the screen stays compact.
 */
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

    /** The raw token shown on screen (canonical for auditors/engineers). */
    get label() {
        return this.code || this.term || '';
    }

    /** Look up the plain-language explanation; empty when unknown. */
    get explanation() {
        const key = (this.code || this.term || '').toUpperCase();
        return DICTIONARY[key] || '';
    }

    /** Only render the help icon when we actually have an explanation. */
    get hasExplanation() {
        return this.explanation.length > 0;
    }
}
