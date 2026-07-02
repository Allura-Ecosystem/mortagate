import { LightningElement, api, track, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { loadStyle } from 'lightning/platformResourceLoader';
import VERIDACT_TOKENS from '@salesforce/resourceUrl/veridactTokens';
import getCaseDetail from '@salesforce/apex/CaseReviewController.getCaseDetail';
import rerunReplay from '@salesforce/apex/CaseReviewController.rerunReplay';

/**
 * caseReview — the two-pane Case Review drill-in reached from the queue's
 * "Review ›". LEFT pane is the evidence pack; RIGHT pane is the replay
 * checks/findings, with FAIL rows visually surfaced. A staleness banner warns
 * when the loan changed after the last replay, and a single "Re-run replay"
 * button (the only write path) re-evaluates the historical policy.
 *
 * Lives on the Audit_Case__c record page via @api recordId.
 */
export default class CaseReview extends LightningElement {
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

    @track detail;
    _wired;
    rerunning = false;

    @wire(getCaseDetail, { auditCaseId: '$recordId' })
    wiredDetail(result) {
        this._wired = result;
        if (result.data) {
            this.detail = result.data;
        }
    }

    get header() {
        return this.detail ? this.detail.header : null;
    }

    get evidence() {
        return this.detail ? this.detail.evidence : [];
    }

    get hasEvidence() {
        return this.evidence.length > 0;
    }

    // Decorate each check with presentation helpers (pill class, row class).
    get checks() {
        if (!this.detail || !this.detail.checks) {
            return [];
        }
        return this.detail.checks.map((c) => ({
            ...c,
            rowClass: c.isFail ? 'check-row check-row--fail' : 'check-row',
            pillClass: this.pillClass(c.result)
        }));
    }

    get hasChecks() {
        return this.detail && this.detail.hasReplay;
    }

    get isStale() {
        return this.detail && this.detail.replayStale === true;
    }

    get failCount() {
        return this.detail ? this.detail.failCount : 0;
    }

    get findingsLabel() {
        const n = this.failCount;
        return `${n} ${n === 1 ? 'finding' : 'findings'}`;
    }

    pillClass(result) {
        const base = 'status-pill';
        switch (result) {
            case 'Fail':
                return `${base} status-pill--fail`;
            case 'Pass':
                return `${base} status-pill--pass`;
            default:
                return `${base} status-pill--unverifiable`;
        }
    }

    async handleRerun() {
        if (!this.recordId) {
            return;
        }
        this.rerunning = true;
        try {
            const fresh = await rerunReplay({ auditCaseId: this.recordId });
            this.detail = fresh;
            // Keep the cached wire in sync so a later navigation shows fresh data.
            if (this._wired) {
                await refreshApex(this._wired);
            }
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Replay complete',
                    message: `${fresh.checks.length} checks evaluated, ${fresh.failCount} findings.`,
                    variant: 'success'
                })
            );
        } catch (e) {
            const message =
                (e && e.body && e.body.message) || 'The replay could not be re-run.';
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Replay failed',
                    message,
                    variant: 'error'
                })
            );
        } finally {
            this.rerunning = false;
        }
    }
}
