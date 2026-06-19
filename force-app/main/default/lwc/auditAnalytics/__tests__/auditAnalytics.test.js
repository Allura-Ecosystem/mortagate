import { createElement } from 'lwc';
import AuditAnalytics from 'c/auditAnalytics';
import getAnalytics from '@salesforce/apex/AnalyticsController.getAnalytics';

jest.mock(
    '@salesforce/apex/AnalyticsController.getAnalytics',
    () => {
        const { createApexTestWireAdapter } = require('@salesforce/sfdx-lwc-jest');
        return { default: createApexTestWireAdapter(jest.fn()) };
    },
    { virtual: true }
);

const VIEW = {
    openCaseCount: 3,
    totalChecks: 30,
    violationRate: 20,
    exceptionRate: 27,
    missingEvidenceCount: 2,
    approverDrift: [
        { approverName: 'Janet Chen', totalChecks: 10, failCount: 6, failRate: 60, tone: 'High' },
        { approverName: 'Marcus Webb', totalChecks: 20, failCount: 0, failRate: 0, tone: 'Low' }
    ]
};

function flush() {
    return Promise.resolve();
}

describe('c-audit-analytics', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
    });

    function build() {
        const el = createElement('c-audit-analytics', { is: AuditAnalytics });
        document.body.appendChild(el);
        return el;
    }

    it('renders the metric cards and drift table from the wire', async () => {
        const el = build();
        getAnalytics.emit(VIEW);
        await flush();

        const cards = el.shadowRoot.querySelector('c-audit-metric-cards');
        expect(cards).not.toBeNull();
        expect(cards.cards.length).toBe(5);
        expect(cards.cards[0].value).toBe('20%');

        const rows = el.shadowRoot.querySelectorAll('.drift-table tbody tr');
        expect(rows.length).toBe(2);
    });

    it('tone-codes the highest-fail approver as high', async () => {
        const el = build();
        getAnalytics.emit(VIEW);
        await flush();

        const badge = el.shadowRoot.querySelector('.drift-badge');
        expect(badge.className).toContain('drift-badge--high');
        expect(badge.textContent).toBe('60%');
    });

    it('shows the empty state with no drift rows', async () => {
        const el = build();
        getAnalytics.emit({
            openCaseCount: 0,
            totalChecks: 0,
            violationRate: 0,
            exceptionRate: 0,
            missingEvidenceCount: 0,
            approverDrift: []
        });
        await flush();

        const empty = el.shadowRoot.querySelector('.empty-state');
        expect(empty).not.toBeNull();
    });

    it('surfaces a wire error', async () => {
        const el = build();
        getAnalytics.error({ message: 'nope' });
        await flush();

        const err = el.shadowRoot.querySelector('.error-banner');
        expect(err.textContent).toBe('nope');
    });
});
