import { LightningElement, track } from 'lwc';

const STATUS_OPTIONS = [
    { label: 'All', value: '' },
    { label: 'In Review', value: 'In_Review' },
    { label: 'Evidence Needed', value: 'Evidence_Needed' },
    { label: 'Ready for Signoff', value: 'Ready_for_Signoff' },
    { label: 'Closed', value: 'Closed' }
];

const PRODUCT_OPTIONS = [
    { label: 'All', value: '' },
    { label: 'Conventional', value: 'Conventional' },
    { label: 'FHA', value: 'FHA' },
    { label: 'VA', value: 'VA' },
    { label: 'USDA', value: 'USDA' }
];

const RISK_OPTIONS = [
    { label: 'All', value: '' },
    { label: 'High', value: 'High' },
    { label: 'Medium', value: 'Medium' },
    { label: 'Low', value: 'Low' }
];

/**
 * auditQueueFilters — the Audit Queue filter bar. Owns local filter state and
 * emits a single `filterchange` event (detail = the filter object) whenever a
 * control changes or Clear is pressed. The parent owns data fetching.
 */
export default class AuditQueueFilters extends LightningElement {
    statusOptions = STATUS_OPTIONS;
    productOptions = PRODUCT_OPTIONS;
    riskOptions = RISK_OPTIONS;

    @track filters = {
        status: '',
        productType: '',
        riskTier: '',
        myCasesOnly: false
    };

    get allToggleClass() {
        return this.filters.myCasesOnly ? 'toggle-btn' : 'toggle-btn toggle-btn--active';
    }
    get myToggleClass() {
        return this.filters.myCasesOnly ? 'toggle-btn toggle-btn--active' : 'toggle-btn';
    }

    handleStatus(event) {
        this.filters = { ...this.filters, status: event.detail.value };
        this.emit();
    }
    handleProduct(event) {
        this.filters = { ...this.filters, productType: event.detail.value };
        this.emit();
    }
    handleRisk(event) {
        this.filters = { ...this.filters, riskTier: event.detail.value };
        this.emit();
    }
    selectAll() {
        if (this.filters.myCasesOnly) {
            this.filters = { ...this.filters, myCasesOnly: false };
            this.emit();
        }
    }
    selectMine() {
        if (!this.filters.myCasesOnly) {
            this.filters = { ...this.filters, myCasesOnly: true };
            this.emit();
        }
    }
    clear() {
        this.filters = { status: '', productType: '', riskTier: '', myCasesOnly: false };
        this.emit();
    }

    emit() {
        this.dispatchEvent(
            new CustomEvent('filterchange', { detail: { ...this.filters } })
        );
    }
}
