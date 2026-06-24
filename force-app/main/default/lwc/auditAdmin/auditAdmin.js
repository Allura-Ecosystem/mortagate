import { LightningElement, wire } from 'lwc';
import getOrgSummary from '@salesforce/apex/AdminController.getOrgSummary';

/**
 * auditAdmin — the Admin / settings screen. A simple, presentational page that
 * tells an auditor what this app is, the three rules it always follows (in
 * plain words), and a small at-a-glance count of policy versions and rules.
 *
 * App-page component (no @api): lives on the Veridact_Admin FlexiPage.
 * One thing per screen, plain ~6th-grade language (the "Leo" rule).
 */
export default class AuditAdmin extends LightningElement {
    summary = {};

    // The governance promises, in plain words. Static content.
    rules = [
        {
            id: 'receipt',
            title: 'Every audit action makes a receipt',
            body: 'When something happens on a case, the app writes it down.'
        },
        {
            id: 'immutable',
            title: "Receipts can't be changed",
            body: 'Once a receipt is written, no one can edit or delete it.'
        },
        {
            id: 'human',
            title: 'A human makes the final call',
            body: 'The app helps and checks, but a person signs off on the result.'
        }
    ];

    @wire(getOrgSummary)
    wiredSummary({ data }) {
        if (data) {
            this.summary = data;
        }
    }

    get policyVersionCount() {
        return this.summary.policyVersionCount ?? 0;
    }

    get activeVersionCount() {
        return this.summary.activeVersionCount ?? 0;
    }

    get policyRuleCount() {
        return this.summary.policyRuleCount ?? 0;
    }
}
