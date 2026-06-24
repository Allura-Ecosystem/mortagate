import { createElement } from 'lwc';
import AuditMetricCards from 'c/auditMetricCards';

describe('c-audit-metric-cards', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
    });

    function setup(props = {}) {
        const el = createElement('c-audit-metric-cards', { is: AuditMetricCards });
        Object.assign(el, props);
        document.body.appendChild(el);
        return el;
    }

    it('renders all five cards with values and labels', () => {
        const el = setup({
            metrics: {
                assignedToMe: 14,
                highRisk: 23,
                evidenceNeeded: 9,
                readyForSignoff: 6,
                slaAtRisk: 4
            }
        });
        const values = [...el.shadowRoot.querySelectorAll('.metric-value')].map(
            (n) => n.textContent.trim()
        );
        const labels = [...el.shadowRoot.querySelectorAll('.metric-label')].map(
            (n) => n.textContent.trim()
        );
        expect(values).toEqual(['14', '23', '9', '6', '4']);
        expect(labels).toEqual([
            'Assigned to me',
            'High risk',
            'Evidence needed',
            'Ready for signoff',
            'SLA at risk'
        ]);
    });

    it('defaults missing metrics to zero', () => {
        const el = setup({ metrics: {} });
        const values = [...el.shadowRoot.querySelectorAll('.metric-value')].map(
            (n) => n.textContent.trim()
        );
        expect(values).toEqual(['0', '0', '0', '0', '0']);
    });

    it('applies the colour rail tone classes', () => {
        const el = setup({ metrics: {} });
        const cards = el.shadowRoot.querySelectorAll('.metric-card');
        expect(cards[0].className).toContain('rail-blue');
        expect(cards[4].className).toContain('rail-red');
    });
});
