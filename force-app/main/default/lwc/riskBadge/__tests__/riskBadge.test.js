import { createElement } from 'lwc';
import RiskBadge from 'c/riskBadge';

/**
 * riskBadge — renders the tier word as text (WCAG 1.4.1: never colour alone)
 * and applies the tier-specific class that drives the colour + shape sigil.
 * This is the single source of truth for the tier→class map that the audit
 * queue datatable's custom `riskBadge` cell type depends on.
 */
describe('c-risk-badge', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
    });

    function render(tier) {
        const el = createElement('c-risk-badge', { is: RiskBadge });
        el.tier = tier;
        document.body.appendChild(el);
        return el.shadowRoot.querySelector('span');
    }

    it.each([
        ['Critical', 'risk-badge--critical'],
        ['High', 'risk-badge--high'],
        ['Medium', 'risk-badge--medium'],
        ['Low', 'risk-badge--low']
    ])('renders the %s tier word with its badge class', (tier, expectedClass) => {
        const span = render(tier);
        // The tier WORD is always rendered as text (not colour alone).
        expect(span.textContent).toBe(tier);
        expect(span.className).toContain('risk-badge');
        expect(span.className).toContain(expectedClass);
    });

    it('falls back to the base class for an unknown tier', () => {
        const span = render('Unknown');
        expect(span.className.trim()).toBe('risk-badge');
        expect(span.textContent).toBe('Unknown');
    });
});
