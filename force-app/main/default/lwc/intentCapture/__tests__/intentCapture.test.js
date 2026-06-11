import { createElement } from 'lwc';
import IntentCapture from 'c/intentCapture';

function flush() {
    return Promise.resolve();
}

describe('c-intent-capture', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
    });

    function setup() {
        const el = createElement('c-intent-capture', { is: IntentCapture });
        document.body.appendChild(el);
        return el;
    }

    it('renders the first question with two purpose choices', () => {
        const el = setup();
        const choices = el.shadowRoot.querySelectorAll('.choice');
        expect(choices.length).toBe(2);
        const headline = el.shadowRoot.querySelector('.headline');
        expect(headline.textContent).toContain('buying or refinancing');
    });

    it('shows a prompt, not a fake number, before the borrower answers', async () => {
        const el = setup();
        // Advance to property step by selecting a purpose.
        el.shadowRoot.querySelector('[data-value="buying"]').click();
        await flush();
        const display = el.shadowRoot.querySelector('.value-display');
        expect(display.textContent).toContain('Set your estimate');
        // The Continue CTA is disabled until the field is touched.
        const cta = el.shadowRoot.querySelector('.cta');
        expect(cta.disabled).toBe(true);
    });

    it('fires intentcaptured only after all three real answers', async () => {
        const el = setup();
        const handler = jest.fn();
        el.addEventListener('intentcaptured', handler);

        // All panels render simultaneously (slide animation), so target by index:
        // sliders[0] = property, sliders[1] = income; ctas[0] = property, ctas[1] = income.
        // Q1
        el.shadowRoot.querySelector('[data-value="buying"]').click();
        await flush();
        // Q2 — touch the property slider, then its Continue
        const propertySlider = el.shadowRoot.querySelectorAll('.slider')[0];
        propertySlider.value = 450000;
        propertySlider.dispatchEvent(new CustomEvent('input'));
        await flush();
        el.shadowRoot.querySelectorAll('.cta')[0].click();
        await flush();
        // Q3 — touch the income slider, then "See my range"
        const incomeSlider = el.shadowRoot.querySelectorAll('.slider')[1];
        incomeSlider.value = 120000;
        incomeSlider.dispatchEvent(new CustomEvent('input'));
        await flush();
        el.shadowRoot.querySelectorAll('.cta')[1].click();
        await flush();

        expect(handler).toHaveBeenCalledTimes(1);
        const detail = handler.mock.calls[0][0].detail;
        expect(detail.loanPurpose).toBe('buying');
        expect(detail.propertyValue).toBe(450000);
        expect(detail.annualIncome).toBe(120000);
    });
});
