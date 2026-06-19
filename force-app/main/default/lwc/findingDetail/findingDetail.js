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
// Plain-language display labels (the "Leo rule"); stored `value` is unchanged
// so the Finding__c picklist values stay exactly the same.
const SEVERITY_OPTIONS = [
    { label: 'No problem (Pass)', value: 'Pass' },
    { label: 'Rule bent, with sign-off (Exception)', value: 'Exception' },
    { label: 'Rule broken (Violation)', value: 'Violation' }
];
const CATEGORY_OPTIONS = [
    { label: 'Income', value: 'Income' },
    { label: 'Credit', value: 'Credit' },
    { label: 'The home (Collateral)', value: 'Collateral' },
    { label: 'Job (Employment)', value: 'Employment' },
    { label: 'Paperwork (Documentation)', value: 'Documentation' },
    { label: 'Other', value: 'Other' }
];
const DISPOSITION_OPTIONS = [
    { label: 'Still open (Open)', value: 'Open' },
    { label: 'Seen, not fixed yet (Acknowledged)', value: 'Acknowledged' },
    { label: 'Fixed (Remediated)', value: 'Remediated' },
    { label: 'Done (Closed)', value: 'Closed' }
];

// Stored picklist value → plain label for read-back (the saved-findings list).
// Mirrors the dropdown display copy above so reading a finding matches writing it.
const PLAIN_LABEL = {
    Pass: 'No problem (Pass)',
    Exception: 'Rule bent, with sign-off (Exception)',
    Violation: 'Rule broken (Violation)',
    Collateral: 'The home (Collateral)',
    Employment: 'Job (Employment)',
    Documentation: 'Paperwork (Documentation)'
};

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
                severityClass: this.severityClass(f.severity),
                // Plain-language read-back (the "Leo rule"): show the saved value
                // in plain words; fall back to the raw stored value if unmapped.
                severityPlain: PLAIN_LABEL[f.severity] || f.severity,
                categoryPlain: PLAIN_LABEL[f.category] || f.category
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
