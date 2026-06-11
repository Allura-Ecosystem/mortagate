import { LightningElement, api, track } from 'lwc';

/**
 * c-intent-capture — Screen 2 of borrower onboarding (BLUEPRINT §B3).
 *
 * Three questions, one at a time, slide-in/slide-out. Not a form — a conversation.
 * Fires `intentcaptured` with { loanPurpose, propertyValue, annualIncome } once
 * all three are answered. Honors prefers-reduced-motion (timing comes from the
 * Veridact token --veridact-transition, which is 0s under reduced-motion).
 */
export default class IntentCapture extends LightningElement {
    @api loanPurposeOptions = ['buying', 'refinancing'];
    @api maxPropertyValue = 5000000;
    @api maxIncome = 1000000;

    @track step = 0; // 0 = purpose, 1 = property value, 2 = income

    loanPurpose;
    // No defaults: a pre-filled number would fake a "personalized" answer the
    // borrower never gave. The value is null until they actually tell us.
    propertyValue = null;
    annualIncome = null;
    @track propertyTouched = false;
    @track incomeTouched = false;

    // ---- derived view state -------------------------------------------------
    get isPurposeStep() { return this.step === 0; }
    get isPropertyStep() { return this.step === 1; }
    get isIncomeStep() { return this.step === 2; }

    get progressLabel() {
        return `Question ${this.step + 1} of 3`;
    }

    get trackStyle() {
        // Slide the 3-panel track left by one viewport width per answered step.
        return `transform: translateX(-${this.step * 100}%);`;
    }

    get buyingSelected() { return this.loanPurpose === 'buying'; }
    get refinancingSelected() { return this.loanPurpose === 'refinancing'; }

    // Until the borrower touches the control, show a prompt — never a fake number.
    get formattedProperty() {
        return this.propertyTouched ? this.currency(this.propertyValue) : 'Set your estimate';
    }
    get formattedIncome() {
        return this.incomeTouched ? this.currency(this.annualIncome) : 'Set your estimate';
    }

    // Continue stays disabled until the human has actually answered.
    get propertyIncomplete() { return !this.propertyTouched; }
    get incomeIncomplete() { return !this.incomeTouched; }

    // ---- handlers -----------------------------------------------------------
    handlePurpose(event) {
        this.loanPurpose = event.currentTarget.dataset.value;
        this.advance();
    }

    handlePropertyInput(event) {
        this.propertyValue = this.clampNumber(event.target.value, 0, this.maxPropertyValue);
        this.propertyTouched = true;
    }

    handleIncomeInput(event) {
        this.annualIncome = this.clampNumber(event.target.value, 0, this.maxIncome);
        this.incomeTouched = true;
    }

    handlePropertyNext() {
        if (this.propertyTouched) { this.advance(); }
    }

    handleIncomeNext() {
        if (this.incomeTouched) { this.finish(); }
    }

    handleBack() {
        if (this.step > 0) {
            this.step -= 1;
            this.focusActivePanel();
        }
    }

    // ---- flow ---------------------------------------------------------------
    advance() {
        if (this.step < 2) {
            this.step += 1;
            this.focusActivePanel();
        }
    }

    finish() {
        this.dispatchEvent(
            new CustomEvent('intentcaptured', {
                bubbles: true,
                composed: true,
                detail: {
                    loanPurpose: this.loanPurpose,
                    propertyValue: Number(this.propertyValue),
                    annualIncome: Number(this.annualIncome)
                }
            })
        );
    }

    // ---- a11y: move focus to the active panel's primary control -------------
    renderedCallback() {
        if (this._pendingFocus) {
            this._pendingFocus = false;
            const el = this.template.querySelector('[data-autofocus="true"]:not([hidden])');
            if (el) {
                el.focus();
            }
        }
    }

    focusActivePanel() {
        this._pendingFocus = true;
    }

    // ---- helpers ------------------------------------------------------------
    clampNumber(value, min, max) {
        const n = Number(value);
        if (Number.isNaN(n)) return min;
        return Math.min(Math.max(n, min), max);
    }

    currency(value) {
        return new Intl.NumberFormat('en-US', {
            style: 'currency',
            currency: 'USD',
            maximumFractionDigits: 0
        }).format(Number(value) || 0);
    }
}
