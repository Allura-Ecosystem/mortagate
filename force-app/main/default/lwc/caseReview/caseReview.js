import { LightningElement, api, track, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { loadStyle } from 'lightning/platformResourceLoader';
import VERIDACT_TOKENS from '@salesforce/resourceUrl/veridactTokens';
import getCaseDetail from '@salesforce/apex/CaseReviewController.getCaseDetail';
import rerunReplay from '@salesforce/apex/CaseReviewController.rerunReplay';
import signOff from '@salesforce/apex/SignoffController.signOff';

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
    isLoading = false;
    spinnerMessage = '';
    showSignoffModal = false;
    signoffApproverName = '';

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

    // ── Inline decision summary ──────────────────────────────────────────

    /** Whether the decision summary banner should be shown. */
    get showSummary() {
        return this.hasChecks && !this.isLoading;
    }

    /** Total pass count from the checks array. */
    get summaryPassCount() {
        if (!this.detail || !this.detail.checks) {
            return 0;
        }
        return this.detail.checks.filter((c) => c.result === 'Pass').length;
    }

    /** Total fail count from the checks array. */
    get summaryFailCount() {
        if (!this.detail || !this.detail.checks) {
            return 0;
        }
        return this.detail.checks.filter((c) => c.result === 'Fail').length;
    }

    /** True when the summary should show the green (all-pass) variant. */
    get summaryPassed() {
        return this.summaryFailCount === 0;
    }

    /** Whether there are any failing rules to list. */
    get hasFailingRules() {
        return this.failingRules.length > 0;
    }

    /** Named list of failing rules with their detail (actual vs expected). */
    get failingRules() {
        if (!this.detail || !this.detail.checks) {
            return [];
        }
        return this.detail.checks
            .filter((c) => c.result === 'Fail')
            .map((c) => ({
                ruleName: c.ruleName,
                detail: c.rationale || `${c.ruleName} exceeded threshold (${c.actualValue} > ${c.expectedValue})`
            }));
    }

    // ── Run Replay with progress spinner ────────────────────────────────

    async handleRerun() {
        if (!this.recordId) {
            return;
        }
        this.isLoading = true;
        this.rerunning = true;
        this.spinnerMessage = 'Running audit replay...';

        // Simulate progressive rule evaluation messages.
        // The replay runs ~10 rules in ~500ms; we show a quick progression.
        const totalRules = 10;
        const progressInterval = setInterval(() => {
            const current = this._progressStep || 0;
            if (current < totalRules) {
                this._progressStep = current + 1;
                this.spinnerMessage = `Evaluating rule ${this._progressStep} of ${totalRules}...`;
            }
        }, 45);

        try {
            const fresh = await rerunReplay({ auditCaseId: this.recordId });
            clearInterval(progressInterval);
            this._progressStep = 0;
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
            clearInterval(progressInterval);
            this._progressStep = 0;
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
            this.isLoading = false;
            this.rerunning = false;
        }
    }

    // ── Sign-off confirmation modal ─────────────────────────────────────

    /**
     * Called from the parent or a child sign-off button. Submits the case for
     * sign-off and shows the confirmation modal on success.
     */
    @api
    async handleSignOff() {
        if (!this.recordId) {
            return;
        }
        try {
            const result = await signOff({ auditCaseId: this.recordId });
            // Refresh detail so the UI reflects the closed status.
            if (result) {
                this.detail = result;
            }
            if (this._wired) {
                await refreshApex(this._wired);
            }
            // Determine the approver name from the header or fall back.
            this.signoffApproverName =
                (this.header && this.header.approverName) || 'the designated approver';
            this.showSignoffModal = true;
        } catch (e) {
            const message =
                (e && e.body && e.body.message) || 'Sign-off could not be completed.';
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Sign-off failed',
                    message,
                    variant: 'error'
                })
            );
        }
    }

    /** Dismiss the sign-off confirmation modal. */
    handleSignoffDone() {
        this.showSignoffModal = false;
    }

    /** Clicking the backdrop also dismisses the modal. */
    handleModalBackdrop(e) {
        if (e.target.classList.contains('modal-backdrop')) {
            this.showSignoffModal = false;
        }
    }
}
