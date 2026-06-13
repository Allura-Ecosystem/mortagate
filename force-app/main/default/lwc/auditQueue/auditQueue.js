import { LightningElement, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import Id from '@salesforce/user/Id';
import getQueue from '@salesforce/apex/AuditQueueController.getQueue';
import getMetrics from '@salesforce/apex/AuditQueueController.getMetrics';
import getApprovers from '@salesforce/apex/AuditQueueController.getApprovers';

const COLUMNS = [
    { label: 'Loan', fieldName: 'loanNumber', type: 'text', sortable: true },
    // Borrower bound to the write-once snapshot field (ADR-001 accepted, Option C).
    { label: 'Borrower', fieldName: 'borrowerName', type: 'text', sortable: true },
    // Custom `riskBadge` cell type (auditQueueDatatable) renders the tier word +
    // colour + shape sigil via the c-risk-badge child, whose own stylesheet
    // reaches the cell. A plain `text` column with a cellAttributes class could
    // not be styled — the datatable renders cells in its own shadow DOM.
    { label: 'Risk', fieldName: 'riskTier', type: 'riskBadge', sortable: true },
    { label: 'Status', fieldName: 'status', type: 'text', sortable: true },
    { label: 'Approver', fieldName: 'approverName', type: 'text', sortable: true },
    { label: 'SLA', fieldName: 'slaRemaining', type: 'text', sortable: true },
    {
        type: 'action',
        typeAttributes: {
            rowActions: [{ label: 'Review', name: 'review' }]
        }
    }
];

// Allow-list of sortable column property names, derived from the columns
// themselves. handleSort rejects any field not in this set, so an unexpected
// `onsort` payload can never sort by an arbitrary property.
const SORTABLE_FIELDS = new Set(
    COLUMNS.filter((c) => c.fieldName).map((c) => c.fieldName)
);

export default class AuditQueue extends NavigationMixin(LightningElement) {
    columns = COLUMNS;
    currentUserId = Id;

    // Filter state
    // Product/Branch controls were removed in v1 (A5): there is no
    // Loan_Product__c / Branch__c field on Audit_Case__c, so the controls
    // could never narrow the query. Shipping inert controls that silently
    // discard input erodes trust in the filters that do work. They re-enter
    // in v2 once the data model + backfill exist.
    @track filterStatus = '';
    @track filterApprover = '';
    @track filterRiskTier = '';
    @track filterApprovalDate = '';
    @track filterSamplingReason = '';
    @track filterAuditor = '';
    @track filterDueBefore = '';

    // Sort state (F-04). Drives the datatable's sorted-by/sorted-direction and
    // re-sorts queueData reactively when either changes.
    @track sortedBy = '';
    @track sortDirection = 'asc';

    // Wire: metrics
    @wire(getMetrics)
    metricsResult;

    // Wire: distinct approvers, to populate the Approver filter options (F1).
    // Without this the control only offered "All approvers" and could never
    // narrow the query — a visible-but-inert filter.
    @wire(getApprovers)
    approversResult;

    // Wire: queue data (reactive to filters).
    // Every control with a backing Audit_Case__c field is wired here so the
    // filter UI actually narrows the server query (F-01). (Product/Branch
    // controls were removed in v1 — A5 — for lack of a backing field; see the
    // filter-state comment above.)
    @wire(getQueue, {
        filterStatus: '$filterStatus',
        filterRiskTier: '$filterRiskTier',
        filterApproverId: '$filterApprover',
        filterSamplingReason: '$filterSamplingReason',
        filterApprovalDays: '$filterApprovalDate',
        filterAuditorId: '$resolvedAuditorId',
        filterDueBefore: '$resolvedDueBefore'
    })
    queueResult;

    // --- Computed: metrics ---
    get metricsData() {
        const d = this.metricsResult?.data;
        return {
            assignedToMe: d?.assignedToMe ?? 0,
            highRisk: d?.highRisk ?? 0,
            evidenceNeeded: d?.evidenceNeeded ?? 0,
            readyForSignoff: d?.readyForSignoff ?? 0,
            slaAtRisk: d?.slaAtRisk ?? 0
        };
    }

    // --- Computed: queue ---
    // Maps raw Audit_Case__c SObject API fields → the property names the
    // datatable COLUMNS bind to. This mapping is the contract; the Jest test
    // in __tests__ asserts every non-action column.fieldName is produced here.
    get queueData() {
        const rows = this.queueResult?.data;
        if (!rows) return [];
        const mapped = rows.map(row => {
            const riskTier = row.Risk_Tier__c;
            return {
                id: row.Id,
                loanNumber: row.Loan_Application__c,
                borrowerName: row.Borrower_Name_Snapshot__c || '',
                riskTier,
                status: this.humanizeStatus(row.Status__c),
                approverName: row.Original_Approver__r
                    ? row.Original_Approver__r.Name
                    : '',
                slaRemaining: this.formatSla(row.Due_At__c)
            };
        });
        return this.sortRows(mapped);
    }

    // Client-side sort over the already-mapped property names (F-04). Stable for
    // ties via the decorate/index tiebreaker, so equal rows keep server order.
    sortRows(rows) {
        const field = this.sortedBy;
        if (!field || !SORTABLE_FIELDS.has(field)) {
            return rows;
        }
        const dir = this.sortDirection === 'desc' ? -1 : 1;
        return rows
            .map((row, index) => ({ row, index }))
            .sort((a, b) => {
                const cmp = this.compareValues(a.row[field], b.row[field]);
                return cmp !== 0 ? cmp * dir : a.index - b.index;
            })
            .map((d) => d.row);
    }

    compareValues(a, b) {
        const av = a === undefined || a === null ? '' : a;
        const bv = b === undefined || b === null ? '' : b;
        if (typeof av === 'number' && typeof bv === 'number') {
            return av - bv;
        }
        return String(av).localeCompare(String(bv), undefined, {
            numeric: true,
            sensitivity: 'base'
        });
    }

    // Picklist API values use underscores (e.g. Evidence_Needed) — humanize for display.
    humanizeStatus(status) {
        return status ? status.replace(/_/g, ' ') : '';
    }

    // Days remaining until Due_At__c, computed client-side so it stays live.
    formatSla(dueAt) {
        if (!dueAt) return '\u2014';
        const ms = new Date(dueAt).getTime() - Date.now();
        const days = Math.ceil(ms / 86400000);
        if (ms < 0) return `Overdue ${Math.abs(days)}d`;
        if (days === 0) return 'Due today';
        return `${days}d`;
    }

    get isLoading() {
        return !this.queueResult?.data && !this.queueResult?.error;
    }

    get hasError() {
        return !!this.queueResult?.error;
    }

    get hasData() {
        return !!this.queueResult?.data;
    }

    // True when the query succeeded and returned at least one row — the only
    // case where the datatable should render.
    get hasRows() {
        return this.hasData && this.queueData.length > 0;
    }

    // True when the query succeeded but returned zero rows (e.g. a filter that
    // narrows everything out) — drives the empty-state message (P5).
    get isEmpty() {
        return this.hasData && this.queueData.length === 0;
    }

    get errorMessage() {
        const err = this.queueResult?.error;
        if (!err) return '';
        if (Array.isArray(err.body)) {
            return err.body.map(e => e.message).join(', ');
        }
        return err.body?.message ?? 'An error occurred loading the audit queue.';
    }

    // Resolved auditor ID: empty string when "All", current user ID when "My Cases"
    get resolvedAuditorId() {
        if (this.filterAuditor === 'mine') {
            return this.currentUserId;
        }
        return this.filterAuditor;
    }

    // Resolved due-before bound: null when blank so the empty string never
    // reaches the Apex `Date` param (which would fail to coerce). A real
    // 'yyyy-mm-dd' value passes through and Aura coerces it to an Apex Date.
    get resolvedDueBefore() {
        return this.filterDueBefore ? this.filterDueBefore : null;
    }

    // --- Filter options ---
    // Approver options are sourced from the getApprovers wire (the distinct
    // approvers on open cases). The leading "All approvers" sentinel maps to an
    // empty value, which the wire treats as "no approver filter" (F1 fix).
    get approverOptions() {
        const options = [{ label: 'All approvers', value: '' }];
        const approvers = this.approversResult?.data;
        if (approvers) {
            approvers.forEach((a) => {
                options.push({ label: a.name, value: a.id });
            });
        }
        return options;
    }

    get riskTierOptions() {
        // Values must match the Risk_Tier__c picklist exactly (Low/Medium/High/Critical),
        // otherwise the SOQL equality filter matches zero rows.
        return [
            { label: 'All risk tiers', value: '' },
            { label: 'Critical', value: 'Critical' },
            { label: 'High', value: 'High' },
            { label: 'Medium', value: 'Medium' },
            { label: 'Low', value: 'Low' }
        ];
    }

    get approvalDateOptions() {
        return [
            { label: 'Any date', value: '' },
            { label: 'Last 7 days', value: '7' },
            { label: 'Last 30 days', value: '30' },
            { label: 'Last 90 days', value: '90' }
        ];
    }

    get samplingReasonOptions() {
        return [
            { label: 'All reasons', value: '' },
            { label: 'Random', value: 'Random' },
            { label: 'Risk-based', value: 'Risk_Based' },
            { label: 'Targeted', value: 'Targeted' },
            { label: 'Ad hoc', value: 'Ad_Hoc' }
        ];
    }

    get auditorOptions() {
        return [
            { label: 'All auditors', value: '' },
            { label: 'My cases', value: 'mine' }
        ];
    }

    // --- Handlers ---
    handleFilterChange(event) {
        const field = event.target.dataset.field;
        const value = event.detail.value;
        switch (field) {
            case 'status':
                this.filterStatus = value;
                break;
            case 'approver':
                this.filterApprover = value;
                break;
            case 'riskTier':
                this.filterRiskTier = value;
                break;
            case 'approvalDate':
                this.filterApprovalDate = value;
                break;
            case 'samplingReason':
                this.filterSamplingReason = value;
                break;
            case 'auditor':
                this.filterAuditor = value;
                break;
            case 'dueBefore':
                this.filterDueBefore = value;
                break;
            default:
                break;
        }
    }

    // Column sort (F-04). Guards the incoming field against the allow-list
    // before accepting it, then updates the tracked sort state — queueData
    // re-sorts reactively and lightning-datatable reflects the new order.
    handleSort(event) {
        const { fieldName, sortDirection } = event.detail;
        if (!SORTABLE_FIELDS.has(fieldName)) {
            return;
        }
        this.sortedBy = fieldName;
        this.sortDirection = sortDirection === 'desc' ? 'desc' : 'asc';
    }

    handleRowClick(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;
        if (actionName === 'review') {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: row.id,
                    objectApiName: 'Audit_Case__c',
                    actionName: 'view'
                }
            });
        }
    }

    handleNewAudit() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: {
                objectApiName: 'Audit_Case__c',
                actionName: 'new'
            }
        });
    }

    // Export CSV is a deliberate MVP no-op (backend deferred to v2). It shows
    // an informational toast so the control is discoverable without throwing.
    handleExportCsv() {
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Export queued',
                message: 'CSV export is coming in a future release.',
                variant: 'info'
            })
        );
    }
}