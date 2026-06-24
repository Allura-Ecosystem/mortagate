import { createElement } from 'lwc';
import FindingDetail from 'c/findingDetail';
import getFindings from '@salesforce/apex/FindingController.getFindings';
import saveFinding from '@salesforce/apex/FindingController.saveFinding';

jest.mock(
    '@salesforce/apex/FindingController.getFindings',
    () => {
        const { createApexTestWireAdapter } = require('@salesforce/sfdx-lwc-jest');
        return { default: createApexTestWireAdapter(jest.fn()) };
    },
    { virtual: true }
);
jest.mock(
    '@salesforce/apex/FindingController.saveFinding',
    () => ({ default: jest.fn() }),
    { virtual: true }
);

const FINDINGS = [
    {
        recordId: 'f1',
        name: 'F-0001',
        severity: 'Violation',
        category: 'Income',
        disposition: 'Open',
        description: 'DTI 44.8 over the 43 ceiling.',
        aiDrafted: true,
        aiDraftAccepted: false,
        isViolation: true,
        isException: false
    },
    {
        recordId: 'f2',
        name: 'F-0002',
        severity: 'Exception',
        category: 'Documentation',
        disposition: 'Acknowledged',
        description: 'Compensating reserves documented.',
        aiDrafted: false,
        aiDraftAccepted: false,
        isViolation: false,
        isException: true
    }
];

function flush() {
    return Promise.resolve();
}

describe('c-finding-detail', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
    });

    function build() {
        const el = createElement('c-finding-detail', { is: FindingDetail });
        el.recordId = 'a0Case01';
        document.body.appendChild(el);
        return el;
    }

    it('renders the case findings from the wire', async () => {
        const el = build();
        getFindings.emit(FINDINGS);
        await flush();

        const items = el.shadowRoot.querySelectorAll('.finding-item');
        expect(items.length).toBe(2);
        const pills = el.shadowRoot.querySelectorAll('.sev-pill');
        // Plain-language read-back (the "Leo rule"): the saved value shows in
        // plain words while still keeping the canonical token in parentheses.
        expect(pills[0].textContent).toBe('Rule broken (Violation)');
    });

    it('shows the empty state when there are no findings', async () => {
        const el = build();
        getFindings.emit([]);
        await flush();

        const empty = el.shadowRoot.querySelector('.empty-state');
        expect(empty).not.toBeNull();
    });

    it('defaults the editor to a new Violation draft', async () => {
        const el = build();
        getFindings.emit([]);
        await flush();

        const severity = el.shadowRoot.querySelector('lightning-combobox[data-field="severity"]');
        expect(severity.value).toBe('Violation');
        const title = el.shadowRoot.querySelector('.editor-title');
        expect(title.textContent).toBe('Document a finding');
    });

    it('saves a finding through the saveFinding Apex write', async () => {
        saveFinding.mockResolvedValue({
            recordId: 'f9',
            severity: 'Violation',
            category: 'Income',
            disposition: 'Open',
            aiDrafted: false,
            aiDraftAccepted: false
        });
        const el = build();
        getFindings.emit([]);
        await flush();

        el.shadowRoot.querySelector('.save-btn').click();
        await flush();

        expect(saveFinding).toHaveBeenCalledTimes(1);
        const arg = saveFinding.mock.calls[0][0].input;
        expect(arg.auditCaseId).toBe('a0Case01');
        expect(arg.severity).toBe('Violation');
    });

    it('surfaces a save error without throwing', async () => {
        saveFinding.mockRejectedValue({ body: { message: 'boom' } });
        const el = build();
        getFindings.emit([]);
        await flush();

        el.shadowRoot.querySelector('.save-btn').click();
        await flush();
        await flush();

        // Still rendered; no unhandled rejection.
        expect(el.shadowRoot.querySelector('.editor')).not.toBeNull();
    });
});
