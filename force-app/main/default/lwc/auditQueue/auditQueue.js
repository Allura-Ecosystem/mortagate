import { LightningElement, track, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';
import getQueue from '@salesforce/apex/AuditQueueController.getQueue';
import getMetrics from '@salesforce/apex/AuditQueueController.getMetrics';

const COLUMNS = [
    { label: 'Loan', fieldName: 'loanNumber', type: 'text', cellAttributes: { class: 'loan-cell' }, sortable: true },
    { label: 'Borrower', fieldName: 'borrowerName', type: 'text', sortable: true },
    { label: 'Risk', fieldName: 'riskTier', type: 'riskBadge' },
    { label: 'Status', fieldName: 'status', type: 'text' },
    { label: 'Approver', fieldName: 'approverName', type: 'text' },
    { label: 'SLA', fieldName: 'slaLabel', type: 'text' },
    {
        type: 'button',
        fixedWidth: 110,
        typeAttributes: { label: 'Review', name: 'review', variant: 'base', iconName: 'utility:chevronright', iconPosition: 'right' }
    }
];

/**
 * auditQueue — the auditor work queue screen. Composes the metric cards,
 * filter bar, and the (tested) auditQueueDatatable over AuditQueueController
 * data. Row action / Review button navigate to the Audit_Case__c record.
 */
export default class AuditQueue extends NavigationMixin(LightningElement) {
    columns = COLUMNS;
    @track filters = {};
    searchTerm = '';

    _allRows = [];
    _queueWire; // for refreshApex
    metrics = {};

    @wire(getMetrics)
    wiredMetrics({ data }) {
        if (data) {
            this.metrics = data;
        }
    }

    @wire(getQueue, { filters: '$filters' })
    wiredQueue(result) {
        this._queueWire = result;
        if (result.data) {
            this._allRows = result.data;
        }
    }

    get rows() {
        const term = this.searchTerm.trim().toLowerCase();
        if (!term) {
            return this._allRows;
        }
        return this._allRows.filter(
            (r) =>
                (r.loanNumber && r.loanNumber.toLowerCase().includes(term)) ||
                (r.borrowerName && r.borrowerName.toLowerCase().includes(term)) ||
                (r.approverName && r.approverName.toLowerCase().includes(term))
        );
    }

    get resultLabel() {
        const n = this.rows.length;
        return `Showing ${n} of ${this._allRows.length}`;
    }

    get hasRows() {
        return this.rows.length > 0;
    }

    handleFilterChange(event) {
        // New object reference so the reactive @wire re-runs.
        this.filters = { ...event.detail };
    }

    handleSearch(event) {
        this.searchTerm = event.target.value || '';
    }

    handleRefresh() {
        return refreshApex(this._queueWire);
    }

    handleRowAction(event) {
        const row = event.detail.row;
        this.navigateToCase(row.recordId);
    }

    newAudit() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: { objectApiName: 'Audit_Case__c', actionName: 'new' }
        });
    }

    navigateToCase(recordId) {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: { recordId, objectApiName: 'Audit_Case__c', actionName: 'view' }
        });
    }
}
