import { LightningElement, api } from 'lwc';

/**
 * auditMetricCards — presentational dashboard cards with a coloured left accent
 * bar (the Figma "rail"). Two ways to feed it, both supported:
 *
 *   • metrics  — an AuditQueueController.AuditMetrics object; renders the five
 *                fixed Audit Queue cards (assigned to me / high risk / …). This
 *                is the original Audit Queue contract, unchanged.
 *   • cards    — an explicit [{ key, label, value, tone }] array, so other
 *                screens (e.g. c-audit-analytics) can reuse the exact card
 *                visual with their own headline numbers. When `cards` is set it
 *                takes precedence over `metrics`.
 */
export default class AuditMetricCards extends LightningElement {
    @api
    get metrics() {
        return this._metrics;
    }
    set metrics(value) {
        this._metrics = value || {};
    }
    _metrics = {};

    @api
    get cards() {
        if (this._cards && this._cards.length) {
            return this._cards.map((c) => ({
                ...c,
                cssClass: `metric-card ${c.tone || 'rail-blue'}`
            }));
        }
        const m = this._metrics;
        return [
            { key: 'assignedToMe', label: 'Assigned to me', value: m.assignedToMe ?? 0, tone: 'rail-blue' },
            { key: 'highRisk', label: 'High risk', value: m.highRisk ?? 0, tone: 'rail-orange' },
            { key: 'evidenceNeeded', label: 'Evidence needed', value: m.evidenceNeeded ?? 0, tone: 'rail-amber' },
            { key: 'readyForSignoff', label: 'Ready for signoff', value: m.readyForSignoff ?? 0, tone: 'rail-green' },
            { key: 'slaAtRisk', label: 'SLA at risk', value: m.slaAtRisk ?? 0, tone: 'rail-red' }
        ].map((c) => ({ ...c, cssClass: `metric-card ${c.tone}` }));
    }
    set cards(value) {
        this._cards = value || null;
    }
    _cards = null;
}
