import { LightningElement, api, track } from 'lwc';

/**
 * c-evidence-queue — Screen 4. ONE document at a time, not a checklist of 14.
 * After each success an encouraging line appears and the next document reveals
 * after a short, intentional delay. Borrowers never see raw field names.
 */
const QUEUE = [
    { type: 'PAY_STUB', label: 'your most recent pay stub', done: 'Got it. That\u2019s the hardest one.' },
    { type: 'W2', label: 'your W-2 or 1099', done: 'Nice. Income confirmed.' },
    { type: 'BANK_STATEMENT', label: 'your last 2 bank statements', done: 'Two more to go.' },
    { type: 'PHOTO_ID', label: 'a government-issued photo ID', done: 'Almost there.' }
];

const REVEAL_DELAY_MS = 1500;

export default class EvidenceQueue extends LightningElement {
    @api recordId; // Loan_Application__c Id — accepted documents attach here

    @track index = 0;
    @track uploading = false;
    @track justCompleted = false;
    @track errorMessage = '';

    get current() {
        return QUEUE[this.index] || null;
    }
    get orientation() {
        return `Document ${this.index + 1} of ${QUEUE.length}`;
    }
    get prompt() {
        return this.current ? `Upload ${this.current.label}.` : '';
    }
    get encouragement() {
        return this.current ? this.current.done : '';
    }
    get isComplete() {
        return this.index >= QUEUE.length;
    }
    get acceptedFormats() {
        return ['.pdf', '.png', '.jpg', '.jpeg'];
    }
    get hasError() {
        return Boolean(this.errorMessage);
    }

    handleUploadFinished() {
        this.uploading = false;
        this.errorMessage = '';
        this.justCompleted = true;
        // Reveal the next document after an intentional pause — feels deliberate.
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this._timer = setTimeout(() => {
            this.justCompleted = false;
            this.index += 1;
            if (this.index >= QUEUE.length) {
                this.dispatchEvent(new CustomEvent('queuecomplete', {
                    bubbles: true, composed: true
                }));
            }
        }, REVEAL_DELAY_MS);
    }

    handleUploadError() {
        this.uploading = false;
        this.errorMessage = 'That file didn\u2019t go through. Try again?';
    }

    handleRetry() {
        this.errorMessage = '';
    }

    disconnectedCallback() {
        if (this._timer) clearTimeout(this._timer);
    }
}
