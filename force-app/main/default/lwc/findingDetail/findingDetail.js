import { LightningElement, api, track, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getFindings from '@salesforce/apex/FindingController.getFindings';
import saveFinding from '@salesforce/apex/FindingController.saveFinding';

/**
 * findingDetail — the auditor's Finding Detail surface (screen 4). Sits on a
 * record page (Finding__c or Audit_Case__c) via @api recordId. It lets an
 * auditor:
 *   • see the rule violation context (from the source replay check) and the
 *     finding's severity / category / disposition;
 *   • document a Violation, an approved Exception (with reason + approver), or a
 *     missing-evidence note;
 *   • accept or edit an AI-drafted finding — saving through this surface stamps
 *     AI_Draft_Accepted__c server-side (SM-C2).
 *
 * The editor uses a single saveFinding Apex write (NOT cacheable). The list of
 * findings for the case is a cacheable read, refreshed after each save.
 */
const SEVERITY_OPTIONS = [
    { label: 'Pass', value: 'Pass' },
    { label: 'Exception', value: 'Exception' },
    { label: 'Violation', value: 'Violation' }
];
const CATEGORY_OPTIONS = [
    { label: 'Income', value: 'Income' },
    { label: 'Credit', value: 'Credit' },
    { label: 'Collateral', value: 'Collateral' },
    { label: 'Employment', value: 'Employment' },
    { label: 'Documentation', value: 'Documentation' },
    { label: 'Other', value: 'Other' }
];
const DISPOSITION_OPTIONS = [
    { label: 'Open', value: 'Open' },
    { label: 'Acknowledged', value: 'Acknowledged' },
    { label: 'Remediated', value: 'Remediated' },
    { label: 'Closed', value: 'Closed' }
];

export default class FindingDetail extends LightningElement {
    @api recordId;

    @track findings = [];
    @track draft = this.emptyDraft();
    _wired;
    saving = false;

    severityOptions = SEVERITY_OPTIONS;
    categoryOptions = CATEGORY_OPTIONS;
    dispositionOptions = DISPOSITION_OPTIONS;

    @wire(getFindings, { auditCaseId: '$recordId' })
    wiredFindings(result) {
        this._wired = result;
        if (result.data) {
            this.findings = result.data.map((f) => ({
                ...f,
                severityClass: this.severityClass(f.severity)
            }));
        }
    }

    emptyDraft() {
        return {
            recordId: null,
            replayCheckId: null,
            severity: 'Violation',
            category: 'Income',
            disposition: 'Open',
            description: '',
            exceptionReason: '',
            exceptionApprover: '',
            closedReason: '',
            remediationNotes: '',
            remediationDueAt: null,
            aiDrafted: false,
            aiDraftAccepted: false,
            ruleName: null,
            ruleResult: null,
            expectedValue: null,
            actualValue: null,
            ruleRationale: null
        };
    }

    get hasFindings() {
        return this.findings && this.findings.length > 0;
    }

    get isException() {
        return this.draft.severity === 'Exception';
    }

    get isEditing() {
        return this.draft.recordId != null;
    }

    get showAiBanner() {
        return this.draft.aiDrafted && !this.draft.aiDraftAccepted;
    }

    get editorTitle() {
        return this.isEditing ? 'Edit finding' : 'Document a finding';
    }

    get saveLabel() {
        if (this.saving) {
            return 'Saving…';
        }
        return this.draft.aiDrafted ? 'Accept & save' : 'Save finding';
    }

    get hasRuleContext() {
        return this.draft.ruleName != null;
    }

    severityClass(severity) {
        const base = 'sev-pill';
        switch (severity) {
            case 'Violation':
                return `${base} sev-pill--violation`;
            case 'Exception':
                return `${base} sev-pill--exception`;
            default:
                return `${base} sev-pill--pass`;
        }
    }

    // ── List interactions ──

    handleNew() {
        this.draft = this.emptyDraft();
    }

    handleEdit(event) {
        const id = event.currentTarget.dataset.id;
        const found = this.findings.find((f) => f.recordId === id);
        if (found) {
            this.draft = { ...this.emptyDraft(), ...found };
        }
    }

    // ── Form field changes ──

    handleField(event) {
        const field = event.target.dataset.field;
        this.draft = { ...this.draft, [field]: event.target.value };
    }

    // ── Save (the only write) ──

    async handleSave() {
        if (!this.draft.severity) {
            this.toast('Severity required', 'Choose a severity before saving.', 'warning');
            return;
        }
        this.saving = true;
        const input = {
            recordId: this.draft.recordId,
            auditCaseId: this.draft.recordId ? null : this.recordId,
            replayCheckId: this.draft.replayCheckId,
            category: this.draft.category,
            severity: this.draft.severity,
            disposition: this.draft.disposition,
            description: this.draft.description,
            exceptionReason: this.draft.exceptionReason,
            exceptionApprover: this.draft.exceptionApprover,
            closedReason: this.draft.closedReason,
            remediationNotes: this.draft.remediationNotes,
            remediationDueAt: this.draft.remediationDueAt
        };
        try {
            const saved = await saveFinding({ input });
            this.draft = { ...this.emptyDraft(), ...saved };
            if (this._wired) {
                await refreshApex(this._wired);
            }
            this.toast(
                'Finding saved',
                `${saved.severity} finding recorded.`,
                'success'
            );
        } catch (e) {
            const message =
                (e && e.body && e.body.message) || 'The finding could not be saved.';
            this.toast('Save failed', message, 'error');
        } finally {
            this.saving = false;
        }
    }

    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
