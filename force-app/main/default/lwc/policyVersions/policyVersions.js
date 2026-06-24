import { LightningElement, track, wire } from 'lwc';
import getVersions from '@salesforce/apex/PolicyVersionsController.getVersions';
import getRules from '@salesforce/apex/PolicyVersionsController.getRules';

/**
 * policyVersions — the Policy Versions screen. LEFT pane lists every policy
 * version (newest first); clicking one loads that version's rules into the
 * RIGHT pane. Read-only: policy authoring is governance's job, not this view.
 *
 * App-page component (no @api): lives on the Veridact_Policy_Versions FlexiPage.
 * Plain ~6th-grade labels (the "Leo" rule).
 */
export default class PolicyVersions extends LightningElement {
    @track versions = [];
    @track rules = [];
    selectedId;
    selectedLabel;

    @wire(getVersions)
    wiredVersions({ data }) {
        if (data) {
            this.versions = data;
            // Auto-select the newest version so the RIGHT pane is never empty.
            if (!this.selectedId && data.length > 0) {
                this.selectVersion(data[0]);
            }
        }
    }

    @wire(getRules, { policyVersionId: '$selectedId' })
    wiredRules({ data }) {
        if (data) {
            this.rules = data.map((r) => ({
                ...r,
                severityClass: this.severityClass(r.severityApi)
            }));
        }
    }

    // Decorate each version with a selected-state class for the list.
    get versionRows() {
        return this.versions.map((v) => ({
            ...v,
            rowClass:
                v.recordId === this.selectedId
                    ? 'version-row version-row--selected'
                    : 'version-row',
            statusLabel: v.isActive ? 'In use now' : 'Not in use',
            statusClass: v.isActive ? 'status-chip status-chip--active' : 'status-chip',
            ruleCountLabel: `${v.ruleCount} ${v.ruleCount === 1 ? 'rule' : 'rules'}`
        }));
    }

    get hasVersions() {
        return this.versions.length > 0;
    }

    get hasRules() {
        return this.rules.length > 0;
    }

    get rulesHeading() {
        return this.selectedLabel
            ? `Rules in ${this.selectedLabel}`
            : 'Rules';
    }

    severityClass(severityApi) {
        const base = 'severity-pill';
        switch (severityApi) {
            case 'Hard_Decline':
                return `${base} severity-pill--hard`;
            case 'Soft_Decline':
                return `${base} severity-pill--soft`;
            case 'Warning':
                return `${base} severity-pill--warning`;
            default:
                return `${base} severity-pill--info`;
        }
    }

    handleSelect(event) {
        const id = event.currentTarget.dataset.id;
        const version = this.versions.find((v) => v.recordId === id);
        if (version) {
            this.selectVersion(version);
        }
    }

    selectVersion(version) {
        this.selectedId = version.recordId;
        this.selectedLabel = version.versionLabel || version.name;
    }
}
