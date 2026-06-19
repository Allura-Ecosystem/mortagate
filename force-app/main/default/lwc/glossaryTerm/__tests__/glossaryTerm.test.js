import { createElement } from 'lwc';
import GlossaryTerm from 'c/glossaryTerm';

/**
 * glossaryTerm — the "Leo rule" plain-language helper. Presentational only.
 *
 * THE LEO FLIP: for a known token the PRIMARY label is now the plain name and
 * the raw code is demoted to a small `.code-badge`. The longer jargon sentence
 * stays in the help tooltip. An unknown token shows the raw token, no badge,
 * no tooltip.
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

    it('renders a bare term word (no plain name) as the on-screen label', () => {
        // A term word like "DTI" has no entry in PLAIN_NAME, so it stays raw
        // as the primary label and gets no code badge.
        const el = render({ term: 'DTI' });
        const label = el.shadowRoot.querySelector('.glossary-label');
        const badge = el.shadowRoot.querySelector('.code-badge');
        expect(label.textContent).toBe('DTI');
        expect(badge).toBeNull();
    });

    it('shows a help tooltip with the longer jargon explanation for a term', () => {
        const el = render({ term: 'DTI' });
        const help = el.shadowRoot.querySelector('lightning-helptext');
        expect(help).not.toBeNull();
        expect(help.content).toBe(
            'Debt-to-income: how much of monthly pay goes to debt.'
        );
    });

    it('THE LEO FLIP: a rule code shows the PLAIN NAME primary, the code as a badge', () => {
        const el = render({ code: 'DTI_MAX' });
        const label = el.shadowRoot.querySelector('.glossary-label');
        const badge = el.shadowRoot.querySelector('.code-badge');
        const help = el.shadowRoot.querySelector('lightning-helptext');
        // Primary label = plain name, NOT the code.
        expect(label.textContent).toBe('Debt vs. income too high');
        // Raw code demoted to a small secondary mono badge.
        expect(badge).not.toBeNull();
        expect(badge.textContent).toBe('DTI_MAX');
        // The "?" tooltip still carries the longer jargon sentence.
        expect(help.content).toBe('Debt vs. income too high.');
    });

    it('prefers code over term when both are supplied (and flips the code)', () => {
        const el = render({ term: 'DTI', code: 'FICO_MIN' });
        const label = el.shadowRoot.querySelector('.glossary-label');
        const badge = el.shadowRoot.querySelector('.code-badge');
        const help = el.shadowRoot.querySelector('lightning-helptext');
        expect(label.textContent).toBe('Credit score too low');
        expect(badge.textContent).toBe('FICO_MIN');
        expect(help.content).toBe('Credit score too low.');
    });

    it('is case-insensitive on lookup (lowercase code still flips)', () => {
        const el = render({ code: 'fico_min' });
        const label = el.shadowRoot.querySelector('.glossary-label');
        const badge = el.shadowRoot.querySelector('.code-badge');
        const help = el.shadowRoot.querySelector('lightning-helptext');
        expect(label.textContent).toBe('Credit score too low');
        // Badge preserves whatever raw token was passed in.
        expect(badge.textContent).toBe('fico_min');
        expect(help.content).toBe('Credit score too low.');
    });

    it('renders the raw token, NO badge and NO tooltip for an unknown token', () => {
        const el = render({ code: 'MYSTERY_RULE' });
        const label = el.shadowRoot.querySelector('.glossary-label');
        const badge = el.shadowRoot.querySelector('.code-badge');
        const help = el.shadowRoot.querySelector('lightning-helptext');
        expect(label.textContent).toBe('MYSTERY_RULE');
        expect(badge).toBeNull();
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

    it('every RULE CODE flips: plain-name primary label + code badge', () => {
        const ruleCodes = [
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
        ruleCodes.forEach((code) => {
            const el = render({ code });
            const label = el.shadowRoot.querySelector('.glossary-label');
            const badge = el.shadowRoot.querySelector('.code-badge');
            // Primary label is a plain name, never the raw code.
            expect(label.textContent.length).toBeGreaterThan(0);
            expect(label.textContent).not.toBe(code);
            // The raw code lives on as the secondary badge.
            expect(badge).not.toBeNull();
            expect(badge.textContent).toBe(code);
        });
    });
});
