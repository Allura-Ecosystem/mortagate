import { createElement } from 'lwc';
import AuditQueue from 'c/auditQueue';
import getQueue from '@salesforce/apex/AuditQueueController.getQueue';
import getMetrics from '@salesforce/apex/AuditQueueController.getMetrics';

jest.mock(
    '@salesforce/apex/AuditQueueController.getQueue',
    () => {
        const { createApexTestWireAdapter } = require('@salesforce/sfdx-lwc-jest');
        return { default: createApexTestWireAdapter(jest.fn()) };
    },
    { virtual: true }
);
jest.mock(
    '@salesforce/apex/AuditQueueController.getMetrics',
    () => {
        const { createApexTestWireAdapter } = require('@salesforce/sfdx-lwc-jest');
        return { default: createApexTestWireAdapter(jest.fn()) };
    },
    { virtual: true }
);

const ROWS = [
    { recordId: '500x1', loanNumber: 'LA-558823', borrowerName: 'Sabir Asheed Sr.', riskTier: 'High', status: 'In Review', approverName: 'Janet Chen', slaLabel: 'Overdue 2d' },
    { recordId: '500x2', loanNumber: 'LA-559184', borrowerName: 'Marcus Bellweather', riskTier: 'High', status: 'In Review', approverName: 'Priya Raman', slaLabel: 'Due today' }
];

const METRICS = { assignedToMe: 14, highRisk: 23, evidenceNeeded: 9, readyForSignoff: 6, slaAtRisk: 4 };

describe('c-audit-queue', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
    });

    function setup() {
        const el = createElement('c-audit-queue', { is: AuditQueue });
        document.body.appendChild(el);
        return el;
    }

    async function flush() {
        return Promise.resolve();
    }

    it('passes queue rows to the datatable and metrics to the cards', async () => {
        const el = setup();
        getMetrics.emit(METRICS);
        getQueue.emit(ROWS);
        await flush();

        const table = el.shadowRoot.querySelector('c-audit-queue-datatable');
        expect(table).not.toBeNull();
        expect(table.data.length).toBe(2);

        const cards = el.shadowRoot.querySelector('c-audit-metric-cards');
        expect(cards.metrics.highRisk).toBe(23);
    });

    it('filters rows client-side by the search term', async () => {
        const el = setup();
        getQueue.emit(ROWS);
        await flush();

        const search = el.shadowRoot.querySelector('lightning-input');
        search.value = 'sabir';
        search.dispatchEvent(new CustomEvent('change'));
        await flush();

        const table = el.shadowRoot.querySelector('c-audit-queue-datatable');
        expect(table.data.length).toBe(1);
        expect(table.data[0].borrowerName).toBe('Sabir Asheed Sr.');
    });

    it('shows the result count label', async () => {
        const el = setup();
        getQueue.emit(ROWS);
        await flush();
        const count = el.shadowRoot.querySelector('.table-count');
        expect(count.textContent).toContain('Showing 2 of 2');
    });
});
