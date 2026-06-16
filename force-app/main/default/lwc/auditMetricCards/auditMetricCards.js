import { LightningElement, api } from 'lwc';

/**
 * auditMetricCards — the five Audit Queue dashboard cards. Presentational:
 * the parent passes an AuditQueueController.AuditMetrics object; this only
 * renders. Each card has a coloured left accent bar (the Figma "rail").
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

    get cards() {
        const m = this._metrics;
        return [
            { key: 'assignedToMe', label: 'Assigned to me', value: m.assignedToMe ?? 0, tone: 'rail-blue' },
            { key: 'highRisk', label: 'High risk', value: m.highRisk ?? 0, tone: 'rail-orange' },
            { key: 'evidenceNeeded', label: 'Evidence needed', value: m.evidenceNeeded ?? 0, tone: 'rail-amber' },
            { key: 'readyForSignoff', label: 'Ready for signoff', value: m.readyForSignoff ?? 0, tone: 'rail-green' },
            { key: 'slaAtRisk', label: 'SLA at risk', value: m.slaAtRisk ?? 0, tone: 'rail-red' }
        ].map((c) => ({ ...c, cssClass: `metric-card ${c.tone}` }));
    }
}
