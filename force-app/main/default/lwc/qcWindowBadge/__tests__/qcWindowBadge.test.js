import { createElement } from 'lwc';
import QcWindowBadge from 'c/qcWindowBadge';

/**
 * qcWindowBadge — renders days-remaining in the Fannie Mae 90-day QC window as
 * a WORD (never colour alone, WCAG 1.4.1) and applies the tone class that
 * drives the chip background (ADR-9: semantic colour on the chip, not bare
 * text). This is the single source of truth for the daysLeft → label/tone map
 * that the audit queue datatable's `qcWindow` custom cell type depends on.
 */
describe('c-qc-window-badge', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
    });

    function render(daysLeft) {
        const el = createElement('c-qc-window-badge', { is: QcWindowBadge });
        el.daysLeft = daysLeft;
        document.body.appendChild(el);
        return el;
    }

    function span(daysLeft) {
        return render(daysLeft).shadowRoot.querySelector('span');
    }

    it.each([
        [45, '45 days left', 'qc-badge--ok'],
        [15, '15 days left', 'qc-badge--ok'],
        [14, '14 days left', 'qc-badge--warn'],
        [1, '1 day left', 'qc-badge--warn'],
        [0, '0 days left', 'qc-badge--warn'],
        [-10, 'Window exceeded', 'qc-badge--exceeded']
    ])('daysLeft=%s renders "%s" with class %s', (daysLeft, label, cls) => {
        const el = span(daysLeft);
        expect(el.textContent).toBe(label);
        expect(el.className).toContain('qc-badge');
        expect(el.className).toContain(cls);
    });

    it('renders an em dash placeholder when there is no window (null)', () => {
        const el = span(null);
        expect(el.textContent).toBe('—');
        expect(el.className).toContain('qc-badge--none');
    });

    it('renders an em dash placeholder when daysLeft is undefined', () => {
        const el = span(undefined);
        expect(el.textContent).toBe('—');
        expect(el.className).toContain('qc-badge--none');
    });

    it('conveys the QC window without relying on colour (WCAG 1.4.1)', async () => {
        // The days-remaining word is always present as text, so the chip is
        // accessible even though jsdom cannot resolve the token colours.
        const el = render(14);
        await expect(el).toBeAccessible();
        expect(el.shadowRoot.querySelector('span').textContent).toBe('14 days left');
    });
});
