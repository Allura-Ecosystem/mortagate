import { LightningElement, api } from 'lwc';

/**
 * c-outcome-view — Screen 6. The verdict.
 *
 * Brand law enforced here:
 *  - Green (#16734a) owns the approved screen. Amber NEVER decorates approval.
 *  - The amber accent bar still sits at the bottom of EVERY state, including
 *    declined — the receipt exists regardless of the answer.
 *  - Never the word "denied." Declines carry a specific reason and next steps.
 */
export default class OutcomeView extends LightningElement {
    @api outcome;          // APPROVED | APPROVED_WITH_CONDITIONS | PENDING_REVIEW | HARD_DECLINED
    @api amount;           // approved loan amount
    @api rate;             // illustrative rate
    @api declineReason;    // from Rule_Explanation__c
    @api decisionEventId;  // when present, the borrower can open their receipt PDF

    // The receipt exists regardless of the answer — surface it on every outcome.
    get hasReceipt() {
        return Boolean(this.decisionEventId);
    }

    // On a decline, the borrower is owed the formal ECOA / Reg B notice of action
    // taken (the specific-reasons letter). Offer it only on the declined outcome.
    get hasAdverseNotice() {
        return this.isDeclined && Boolean(this.decisionEventId);
    }

    get isApproved() {
        return this.outcome === 'APPROVED' || this.outcome === 'APPROVED_WITH_CONDITIONS';
    }
    get isConditions() { return this.outcome === 'APPROVED_WITH_CONDITIONS'; }
    get isPending() { return this.outcome === 'PENDING_REVIEW'; }
    get isDeclined() { return this.outcome === 'HARD_DECLINED'; }

    get chipClass() {
        switch (this.outcome) {
            case 'APPROVED': return 'chip chip--approved';
            case 'APPROVED_WITH_CONDITIONS': return 'chip chip--conditions';
            case 'PENDING_REVIEW': return 'chip chip--review';
            case 'HARD_DECLINED': return 'chip chip--declined';
            default: return 'chip';
        }
    }

    get chipLabel() {
        switch (this.outcome) {
            case 'APPROVED': return 'Approved';
            case 'APPROVED_WITH_CONDITIONS': return 'Approved with conditions';
            case 'PENDING_REVIEW': return 'In review';
            case 'HARD_DECLINED': return 'Not approved';
            default: return '';
        }
    }

    get verdictHeadline() {
        if (this.isApproved) return 'You\u2019re approved.';
        if (this.isPending) return 'Your application is under review.';
        return 'We weren\u2019t able to approve this application at this time.';
    }

    get formattedAmount() {
        return new Intl.NumberFormat('en-US', {
            style: 'currency', currency: 'USD', maximumFractionDigits: 0
        }).format(Number(this.amount) || 0);
    }

    handleScheduleCall() {
        this.dispatchEvent(new CustomEvent('schedulecall', { bubbles: true, composed: true }));
    }

    handleNextSteps() {
        this.dispatchEvent(new CustomEvent('nextsteps', { bubbles: true, composed: true }));
    }

    // Hands the Decision_Event__c Id up so the host (Flow/Experience page) can open
    // the Visualforce receipt at /apex/DecisionReceipt?id={decisionEventId}.
    handleViewReceipt() {
        this.dispatchEvent(
            new CustomEvent('viewreceipt', {
                bubbles: true,
                composed: true,
                detail: { decisionEventId: this.decisionEventId }
            })
        );
    }

    // Opens the formal notice at /apex/AdverseActionNotice?id={decisionEventId}.
    handleViewNotice() {
        this.dispatchEvent(
            new CustomEvent('viewnotice', {
                bubbles: true,
                composed: true,
                detail: { decisionEventId: this.decisionEventId }
            })
        );
    }
}
