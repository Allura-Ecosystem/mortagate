import { createElement } from 'lwc';
import PolicyVersions from 'c/policyVersions';
import getVersions from '@salesforce/apex/PolicyVersionsController.getVersions';
import getRules from '@salesforce/apex/PolicyVersionsController.getRules';

jest.mock(
    '@salesforce/apex/PolicyVersionsController.getVersions',
    () => {
        const { createApexTestWireAdapter } = require('@salesforce/sfdx-lwc-jest');
        return { default: createApexTestWireAdapter(jest.fn()) };
    },
    { virtual: true }
);
jest.mock(
    '@salesforce/apex/PolicyVersionsController.getRules',
    () => {
        const { createApexTestWireAdapter } = require('@salesforce/sfdx-lwc-jest');
        return { default: createApexTestWireAdapter(jest.fn()) };
    },
    { virtual: true }
);

const VERSIONS = [
    {
        recordId: 'pv2',
        name: 'PV-0002',
        versionLabel: 'Q2 2025 Conventional',
        versionNumber: 2,
        policyType: 'Conventional',
        isActive: false,
        ruleCount: 0
    },
    {
        recordId: 'pv1',
        name: 'PV-0001',
        versionLabel: 'Q1 2025 Conventional',
        versionNumber: 1,
        policyType: 'Conventional',
        isActive: true,
        ruleCount: 3
    }
];

const RULES = [
    {
        recordId: 'r1',
        ruleCode: 'DTI_MAX',
        ruleLabel: 'Max DTI Ratio',
        category: 'Income',
        operator: 'LTE',
        threshold: 43,
        severity: 'Hard Decline',
        severityApi: 'Hard_Decline'
    },
    {
        recordId: 'r2',
        ruleCode: 'FICO_MIN',
        ruleLabel: 'Min FICO Score',
        category: 'Credit',
        operator: 'GTE',
        threshold: 620,
        severity: 'Warning',
        severityApi: 'Warning'
    }
];

describe('c-policy-versions', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
    });

    function setup() {
        const el = createElement('c-policy-versions', { is: PolicyVersions });
        document.body.appendChild(el);
        return el;
    }

    const flush = () => Promise.resolve();

    it('renders the version list newest-first from getVersions', async () => {
        const el = setup();
        getVersions.emit(VERSIONS);
        await flush();

        const rows = el.shadowRoot.querySelectorAll('.version-row');
        expect(rows.length).toBe(2);

        const labels = el.shadowRoot.querySelectorAll('.version-row__label');
        expect(labels[0].textContent).toBe('Q2 2025 Conventional');
        expect(labels[1].textContent).toBe('Q1 2025 Conventional');
    });

    it('shows the active chip in plain words', async () => {
        const el = setup();
        getVersions.emit(VERSIONS);
        await flush();

        const activeChip = el.shadowRoot.querySelector('.status-chip--active');
        expect(activeChip).not.toBeNull();
        expect(activeChip.textContent).toBe('In use now');
    });

    it('auto-selects the newest version and renders its rules', async () => {
        const el = setup();
        getVersions.emit(VERSIONS);
        await flush();
        getRules.emit(RULES);
        await flush();

        const ruleRows = el.shadowRoot.querySelectorAll('.rule-row');
        expect(ruleRows.length).toBe(2);

        const hardPill = el.shadowRoot.querySelector('.severity-pill--hard');
        expect(hardPill.textContent).toBe('Hard Decline');
    });

    it('selects a different version when clicked', async () => {
        const el = setup();
        getVersions.emit(VERSIONS);
        await flush();

        const rows = el.shadowRoot.querySelectorAll('.version-row');
        rows[1].click();
        await flush();

        const selected = el.shadowRoot.querySelector('.version-row--selected');
        expect(selected).not.toBeNull();
        expect(selected.dataset.id).toBe('pv1');
    });

    it('shows an empty state when there are no versions', async () => {
        const el = setup();
        getVersions.emit([]);
        await flush();

        const empty = el.shadowRoot.querySelector('.empty-state');
        expect(empty).not.toBeNull();
    });
});
