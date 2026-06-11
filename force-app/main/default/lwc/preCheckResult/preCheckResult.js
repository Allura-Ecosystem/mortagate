import { LightningElement, api, track } from 'lwc';
import getBand from '@salesforce/apex/PreFlightController.getBand';

/**
 * c-pre-check-result — Screen 3 (Soft Pre-Check), the payoff.
 *
 * Takes the three answers from c-intent-capture, calls the SAME kernel that
 * governs the real decision (PreFlightController.getBand), and shows an honest
 * estimated range. No Loan_Application record is created. Only after the borrower
 * sees value do we ask for an email (progressive identity).
 */
export default class PreCheckResult extends LightningElement {
    @api loanPurpose;
    @api propertyValue;
    @api annualIncome;
    @api loanType = 'CONVENTIONAL';

    @track loading = true;
    @track error = false;
    @track band; // { eligibility, lowEstimate, highEstimate, guidance }
    email = '';

    connectedCallback() {
        this.runCheck();
    }

    async runCheck() {
        this.loading = true;
        this.error = false;
        try {
            this.band = await getBand({
                annualIncome: this.annualIncome,
                propertyValue: this.propertyValue,
                loanType: this.loanType
            });
        } catch (e) {
            this.error = true;
        } finally {
            this.loading = false;
        }
    }

    get rangeLabel() {
        if (!this.band) return '';
        return `${this.currency(this.band.lowEstimate)} – ${this.currency(this.band.highEstimate)}`;
    }

    get guidance() {
        return this.band ? this.band.guidance : '';
    }

    // Semantic chip class — green owns approval, never amber (Glaser's rule).
    get chipClass() {
        const base = 'chip';
        if (!this.band) return base;
        switch (this.band.eligibility) {
            case 'LIKELY_ELIGIBLE': return `${base} chip--eligible`;
            case 'BORDERLINE': return `${base} chip--borderline`;
            default: return `${base} chip--unlikely`;
        }
    }

    get chipLabel() {
        if (!this.band) return '';
        switch (this.band.eligibility) {
            case 'LIKELY_ELIGIBLE': return 'Likely in range';
            case 'BORDERLINE': return 'Worth a closer look';
            default: return 'More information needed';
        }
    }

    get canContinue() {
        return Boolean(this.email) && /\S+@\S+\.\S+/.test(this.email);
    }

    get cannotContinue() {
        return !this.canContinue;
    }

    handleEmail(event) {
        this.email = event.target.value;
    }

    handleRetry() {
        this.runCheck();
    }

    handleContinue() {
        if (!this.canContinue) return;
        this.dispatchEvent(
            new CustomEvent('emailcaptured', {
                bubbles: true,
                composed: true,
                detail: { email: this.email, eligibility: this.band.eligibility }
            })
        );
    }

    currency(value) {
        return new Intl.NumberFormat('en-US', {
            style: 'currency',
            currency: 'USD',
            maximumFractionDigits: 0
        }).format(Number(value) || 0);
    }
}
