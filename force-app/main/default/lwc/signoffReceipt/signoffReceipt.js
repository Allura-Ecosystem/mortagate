import { LightningElement, api, track, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { loadStyle } from 'lightning/platformResourceLoader';
import VERIDACT_TOKENS from '@salesforce/resourceUrl/veridactTokens';
import getReceipt from '@salesforce/apex/SignoffController.getReceipt';
import signOff from '@salesforce/apex/SignoffController.signOff';

/**
 * signoffReceipt — the final step of the auditor 5-screen flow. Shows the case
 * header, the latest-batch pass/violation/exception preview counts, the findings
 * total, and — once signed — the immutable receipt with its illustrative hash.
 *
 * Discipline borrowed from c-outcome-view: restrained tone, never the word
 * "denied", the receipt is offered plainly. A DemoBadge + the iteration-10
 * disclosure ("illustrative hash, not a cryptographic seal") keep the demo
 * honest. The "Sign off" button appears only when the case is Ready for Signoff
 * and no receipt exists yet; after signing, the receipt renders read-only.
 *
 * Lives on the Audit_Case__c record page via @api recordId.
 */
export default class SignoffReceipt extends LightningElement {
    @api recordId;

    // ADR-UX-02 stage 5: load the Veridact brand tokens document-wide so every
    // var(--veridact-*) reference in this bundle (and its children) resolves.
    connectedCallback() {
        loadStyle(this, VERIDACT_TOKENS).catch((e) => {
            // tokens missing → degrade to unstyled dark-on-light, still legible
            // eslint-disable-next-line no-console
            console.warn('veridactTokens failed to load — rendering unbranded', e);
        });
    }

    @track view;
    _wired;
    signing = false;

    @wire(getReceipt, { auditCaseId: '$recordId' })
    wiredView(result) {
        this._wired = result;
        if (result.data) {
            this.view = result.data;
        }
    }

    get hasView() {
        return Boolean(this.view);
    }

    get header() {
        return this.view || {};
    }

    // The signed, immutable receipt (present only after sign-off).
    get receipt() {
        return this.view ? this.view.receipt : null;
    }

    get isSigned() {
        return Boolean(this.receipt);
    }

    // Show the Sign-off button only when ready AND not yet signed.
    get canSignOff() {
        return this.hasView && this.view.isReadyForSignoff && !this.isSigned;
    }

    // A not-ready, not-signed case: explain why sign-off isn't available yet.
    get showNotReady() {
        return this.hasView && !this.view.isReadyForSignoff && !this.isSigned;
    }

    // Counts surfaced come from the receipt once signed, else the live preview.
    get passCount() {
        return this.isSigned ? this.receipt.passCount : this.view ? this.view.passCount : 0;
    }

    get violationCount() {
        return this.isSigned
            ? this.receipt.violationCount
            : this.view
            ? this.view.violationCount
            : 0;
    }

    get exceptionCount() {
        return this.isSigned
            ? this.receipt.exceptionCount
            : this.view
            ? this.view.unverifiableCount
            : 0;
    }

    get totalFindings() {
        return this.isSigned
            ? this.receipt.totalFindings
            : this.view
            ? this.view.totalFindings
            : 0;
    }

    get violationLabel() {
        const n = this.violationCount;
        return `${n} ${n === 1 ? 'violation' : 'violations'}`;
    }

    get hasViolations() {
        return this.violationCount > 0;
    }

    get summaryChipClass() {
        return this.hasViolations ? 'chip chip--findings' : 'chip chip--clear';
    }

    get summaryChipLabel() {
        return this.hasViolations ? this.violationLabel : 'No violations';
    }

    get receiptHash() {
        return this.receipt ? this.receipt.receiptHash : null;
    }

    async handleSignOff() {
        if (!this.recordId || this.signing) {
            return;
        }
        this.signing = true;
        try {
            const fresh = await signOff({ auditCaseId: this.recordId });
            this.view = fresh;
            if (this._wired) {
                await refreshApex(this._wired);
            }
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Signed off',
                    message: 'The audit receipt has been recorded and is now immutable.',
                    variant: 'success'
                })
            );
        } catch (e) {
            const message =
                (e && e.body && e.body.message) || 'The case could not be signed off.';
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Sign-off failed',
                    message,
                    variant: 'error'
                })
            );
        } finally {
            this.signing = false;
        }
    }
}
