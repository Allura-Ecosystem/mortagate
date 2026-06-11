import { createElement } from 'lwc';
import OutcomeView from 'c/outcomeView';

describe('c-outcome-view', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
    });

    function setup(props = {}) {
        const el = createElement('c-outcome-view', { is: OutcomeView });
        Object.assign(el, props);
        document.body.appendChild(el);
        return el;
    }

    it('shows the approved amount with the green chip', () => {
        const el = setup({ outcome: 'APPROVED', amount: 350000 });
        const chip = el.shadowRoot.querySelector('.chip');
        expect(chip.className).toContain('chip--approved');
        const amount = el.shadowRoot.querySelector('.amount');
        expect(amount.textContent).toContain('$350,000');
    });

    it('never says denied and surfaces the specific reason on decline', () => {
        const el = setup({
            outcome: 'HARD_DECLINED',
            declineReason: 'Your debt-to-income ratio exceeds our current threshold of 43%.'
        });
        const verdict = el.shadowRoot.querySelector('.verdict').textContent.toLowerCase();
        expect(verdict).not.toContain('denied');
        const reason = el.shadowRoot.querySelector('.reason');
        expect(reason.textContent).toContain('43%');
        // Declined screen uses the restrained rust chip.
        expect(el.shadowRoot.querySelector('.chip').className).toContain('chip--declined');
    });

    it('always renders the amber accent bar, even when declined', () => {
        const el = setup({ outcome: 'HARD_DECLINED' });
        expect(el.shadowRoot.querySelector('.accent-bar')).not.toBeNull();
    });

    it('offers the receipt only when a decision event id is present', () => {
        const without = setup({ outcome: 'APPROVED', amount: 350000 });
        expect(without.shadowRoot.querySelector('.receipt-link')).toBeNull();

        const withId = setup({ outcome: 'APPROVED', amount: 350000, decisionEventId: 'a01000000000001AAA' });
        expect(withId.shadowRoot.querySelector('.receipt-link')).not.toBeNull();
    });

    it('fires viewreceipt with the decision event id', () => {
        const el = setup({ outcome: 'HARD_DECLINED', decisionEventId: 'a01000000000001AAA' });
        const handler = jest.fn();
        el.addEventListener('viewreceipt', handler);

        el.shadowRoot.querySelector('.receipt-link').click();

        expect(handler).toHaveBeenCalledTimes(1);
        expect(handler.mock.calls[0][0].detail.decisionEventId).toBe('a01000000000001AAA');
    });

    it('offers the notice of action taken only on a decline with an event id', () => {
        // Approved: a receipt, but never an adverse-action notice.
        const approved = setup({ outcome: 'APPROVED', amount: 350000, decisionEventId: 'a01000000000001AAA' });
        expect(approved.shadowRoot.querySelector('.notice-link')).toBeNull();

        // Declined without an id: no notice link to open.
        const declinedNoId = setup({ outcome: 'HARD_DECLINED' });
        expect(declinedNoId.shadowRoot.querySelector('.notice-link')).toBeNull();

        // Declined with an id: the notice is offered.
        const declined = setup({ outcome: 'HARD_DECLINED', decisionEventId: 'a01000000000001AAA' });
        expect(declined.shadowRoot.querySelector('.notice-link')).not.toBeNull();
    });

    it('fires viewnotice with the decision event id on a decline', () => {
        const el = setup({ outcome: 'HARD_DECLINED', decisionEventId: 'a01000000000001AAA' });
        const handler = jest.fn();
        el.addEventListener('viewnotice', handler);

        el.shadowRoot.querySelector('.notice-link').click();

        expect(handler).toHaveBeenCalledTimes(1);
        expect(handler.mock.calls[0][0].detail.decisionEventId).toBe('a01000000000001AAA');
    });
});
