import { LightningElement, track, wire } from 'lwc';
import { loadStyle } from 'lightning/platformResourceLoader';
import VERIDACT_TOKENS from '@salesforce/resourceUrl/veridactTokens';
import getAnalytics from '@salesforce/apex/AnalyticsController.getAnalytics';

/**
 * auditAnalytics — the portfolio analytics screen (screen 5). Sits on an App /
 * Home page (no recordId). It reuses c-audit-metric-cards for the headline
 * numbers (violation rate / exception rate / missing evidence / open cases) and
 * renders an approver-drift table (who keeps shipping loans that don't replay
 * clean), tone-coded with the same High/Medium/Low language as c-risk-badge.
 *
 * Read-only: a single cacheable getAnalytics wire, no writes.
 */
export default class AuditAnalytics extends LightningElement {
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
    error;

    @wire(getAnalytics)
    wiredAnalytics({ data, error }) {
        if (data) {
            this.view = data;
            this.error = undefined;
        } else if (error) {
            this.error = (error.body && error.body.message) || 'Analytics could not load.';
        }
    }

    get hasData() {
        return this.view != null;
    }

    // Headline cards fed into the reused c-audit-metric-cards.
    get headlineCards() {
        const v = this.view || {};
        return [
            { key: 'violationRate', label: 'Violation rate', value: `${v.violationRate ?? 0}%`, tone: 'rail-red' },
            { key: 'exceptionRate', label: 'Exception rate', value: `${v.exceptionRate ?? 0}%`, tone: 'rail-amber' },
            { key: 'missingEvidence', label: 'Missing evidence', value: v.missingEvidenceCount ?? 0, tone: 'rail-orange' },
            { key: 'openCases', label: 'Open cases', value: v.openCaseCount ?? 0, tone: 'rail-blue' },
            { key: 'totalChecks', label: 'Current checks', value: v.totalChecks ?? 0, tone: 'rail-green' }
        ];
    }

    get driftRows() {
        if (!this.view || !this.view.approverDrift) {
            return [];
        }
        return this.view.approverDrift.map((r) => ({
            ...r,
            failRateLabel: `${r.failRate}%`,
            toneClass: this.toneClass(r.tone)
        }));
    }

    get hasDrift() {
        return this.driftRows.length > 0;
    }

    // Reuse the c-risk-badge tone language (High/Medium/Low).
    toneClass(tone) {
        const base = 'drift-badge';
        switch (tone) {
            case 'High':
                return `${base} drift-badge--high`;
            case 'Medium':
                return `${base} drift-badge--medium`;
            default:
                return `${base} drift-badge--low`;
        }
    }
}
