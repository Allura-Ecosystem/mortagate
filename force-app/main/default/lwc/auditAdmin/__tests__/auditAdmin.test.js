import { createElement } from 'lwc';
import AuditAdmin from 'c/auditAdmin';
import getOrgSummary from '@salesforce/apex/AdminController.getOrgSummary';

jest.mock(
    '@salesforce/apex/AdminController.getOrgSummary',
    () => {
        const { createApexTestWireAdapter } = require('@salesforce/sfdx-lwc-jest');
        return { default: createApexTestWireAdapter(jest.fn()) };
    },
    { virtual: true }
);

describe('c-audit-admin', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
    });

    function setup() {
        const el = createElement('c-audit-admin', { is: AuditAdmin });
        document.body.appendChild(el);
        return el;
    }

    const flush = () => Promise.resolve();

    it('renders the three governance rules in plain words', async () => {
        const el = setup();
        await flush();

        const items = el.shadowRoot.querySelectorAll('.rule-item');
        expect(items.length).toBe(3);

        const titles = [...el.shadowRoot.querySelectorAll('.rule-item__title')].map(
            (n) => n.textContent
        );
        expect(titles).toContain('Every audit action makes a receipt');
        expect(titles).toContain("Receipts can't be changed");
        expect(titles).toContain('A human makes the final call');
    });

    it('renders zero counts before data arrives', async () => {
        const el = setup();
        await flush();

        const numbers = el.shadowRoot.querySelectorAll('.count-number');
        expect(numbers.length).toBe(3);
        numbers.forEach((n) => expect(n.textContent).toBe('0'));
    });

    it('renders org summary counts from getOrgSummary', async () => {
        const el = setup();
        getOrgSummary.emit({
            policyVersionCount: 5,
            activeVersionCount: 2,
            policyRuleCount: 31
        });
        await flush();

        const numbers = [...el.shadowRoot.querySelectorAll('.count-number')].map(
            (n) => n.textContent
        );
        expect(numbers).toEqual(['5', '2', '31']);
    });
});
