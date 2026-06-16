import { createElement } from 'lwc';
import AuditQueueFilters from 'c/auditQueueFilters';

describe('c-audit-queue-filters', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
    });

    function setup() {
        const el = createElement('c-audit-queue-filters', { is: AuditQueueFilters });
        document.body.appendChild(el);
        return el;
    }

    function comboByLabel(el, label) {
        return [...el.shadowRoot.querySelectorAll('lightning-combobox')].find(
            (c) => c.label === label
        );
    }

    it('emits filterchange with the selected status', () => {
        const el = setup();
        const handler = jest.fn();
        el.addEventListener('filterchange', handler);

        const status = comboByLabel(el, 'Status');
        status.dispatchEvent(new CustomEvent('change', { detail: { value: 'Evidence_Needed' } }));

        expect(handler).toHaveBeenCalledTimes(1);
        expect(handler.mock.calls[0][0].detail.status).toBe('Evidence_Needed');
    });

    it('toggles myCasesOnly when My cases is pressed', () => {
        const el = setup();
        const handler = jest.fn();
        el.addEventListener('filterchange', handler);

        const buttons = el.shadowRoot.querySelectorAll('.toggle-btn');
        const myBtn = [...buttons].find((b) => b.textContent.includes('My cases'));
        myBtn.click();

        expect(handler).toHaveBeenCalled();
        expect(handler.mock.calls[0][0].detail.myCasesOnly).toBe(true);
    });

    it('clear resets all filters and emits', () => {
        const el = setup();
        const risk = comboByLabel(el, 'Risk Tier');
        risk.dispatchEvent(new CustomEvent('change', { detail: { value: 'High' } }));

        const handler = jest.fn();
        el.addEventListener('filterchange', handler);
        el.shadowRoot.querySelector('.clear-btn').click();

        return Promise.resolve().then(() => {
            const detail = handler.mock.calls[0][0].detail;
            expect(detail.riskTier).toBe('');
            expect(detail.status).toBe('');
            expect(detail.myCasesOnly).toBe(false);
        });
    });
});
