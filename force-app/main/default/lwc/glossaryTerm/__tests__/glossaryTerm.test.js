import { createElement } from 'lwc';
import GlossaryTerm from 'c/glossaryTerm';

/**
 * glossaryTerm — the "Leo rule" plain-language helper. Presentational only:
 * it renders the raw token (term word or rule code) plus a help tooltip whose
 * text comes from a static ~6th-grade dictionary baked into the component.
 */
describe('c-glossary-term', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
    });

    function render({ term, code } = {}) {
        const el = createElement('c-glossary-term', { is: GlossaryTerm });
        if (term !== undefined) {
            el.term = term;
        }
        if (code !== undefined) {
            el.code = code;
        }
        document.body.appendChild(el);
        return el;
    }

    it('renders the raw term word as the on-screen label', () => {
        const el = render({ term: 'DTI' });
        const label = el.shadowRoot.querySelector('.glossary-label');
        expect(label.textContent).toBe('DTI');
    });

    it('shows a help tooltip with the plain-language explanation for a term', () => {
        const el = render({ term: 'DTI' });
        const help = el.shadowRoot.querySelector('lightning-helptext');
        expect(help).not.toBeNull();
        expect(help.content).toBe(
            'Debt-to-income: how much of monthly pay goes to debt.'
        );
    });

    it('looks up a rule code and explains it', () => {
        const el = render({ code: 'DTI_MAX' });
        const label = el.shadowRoot.querySelector('.glossary-label');
        const help = el.shadowRoot.querySelector('lightning-helptext');
        expect(label.textContent).toBe('DTI_MAX');
        expect(help.content).toBe('Debt vs. income too high.');
    });

    it('prefers code over term when both are supplied', () => {
        const el = render({ term: 'DTI', code: 'FICO_MIN' });
        const label = el.shadowRoot.querySelector('.glossary-label');
        const help = el.shadowRoot.querySelector('lightning-helptext');
        expect(label.textContent).toBe('FICO_MIN');
        expect(help.content).toBe('Credit score too low.');
    });

    it('is case-insensitive on lookup', () => {
        const el = render({ code: 'fico_min' });
        const help = el.shadowRoot.querySelector('lightning-helptext');
        expect(help.content).toBe('Credit score too low.');
    });

    it('renders the label but NO tooltip for an unknown token', () => {
        const el = render({ code: 'MYSTERY_RULE' });
        const label = el.shadowRoot.querySelector('.glossary-label');
        const help = el.shadowRoot.querySelector('lightning-helptext');
        expect(label.textContent).toBe('MYSTERY_RULE');
        expect(help).toBeNull();
    });

    it('covers every dictionary key with non-empty 6th-grade copy', () => {
        const keys = [
            'DTI',
            'LTV',
            'FICO',
            'REPLAY',
            'EXCEPTION',
            'VIOLATION',
            'DTI_MAX',
            'DTI_WARN',
            'FICO_MIN',
            'LTV_MAX',
            'INCOME_MIN',
            'EMPLOY_MIN',
            'ASSET_MIN',
            'DEBT_MAX',
            'FICO_PREF',
            'LTV_PREF'
        ];
        keys.forEach((key) => {
            const el = render({ code: key });
            const help = el.shadowRoot.querySelector('lightning-helptext');
            expect(help).not.toBeNull();
            expect(help.content.length).toBeGreaterThan(0);
        });
    });
});
