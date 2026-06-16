import { createElement } from 'lwc';
import SignoffReceipt from 'c/signoffReceipt';
import getReceipt from '@salesforce/apex/SignoffController.getReceipt';
import signOff from '@salesforce/apex/SignoffController.signOff';

jest.mock(
    '@salesforce/apex/SignoffController.getReceipt',
    () => {
        const { createApexTestWireAdapter } = require('@salesforce/sfdx-lwc-jest');
        return { default: createApexTestWireAdapter(jest.fn()) };
    },
    { virtual: true }
);
jest.mock(
    '@salesforce/apex/SignoffController.signOff',
    () => ({ default: jest.fn() }),
    { virtual: true }
);

const READY_VIEW = {
    recordId: 'a0Sabir',
    caseNumber: 'AC-0001',
    borrowerName: 'Sabir Asheed Sr.',
    loanNumber: 'LA-558823',
    riskTier: 'High',
    status: 'Ready for Signoff',
    isReadyForSignoff: true,
    hasReplay: true,
    passCount: 8,
    violationCount: 2,
    unverifiableCount: 0,
    totalFindings: 2,
    receipt: null
};

const SIGNED_VIEW = {
    ...READY_VIEW,
    status: 'Closed',
    isReadyForSignoff: false,
    receipt: {
        recordId: 'aRcpt1',
        passCount: 8,
        violationCount: 2,
        exceptionCount: 0,
        totalFindings: 2,
        signedOffAt: '2026-06-16T12:00:00.000Z',
        receiptHash: 'a'.repeat(64),
        reviewerName: 'Auditor One'
    }
};

describe('c-signoff-receipt', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
    });

    function setup() {
        const el = createElement('c-signoff-receipt', { is: SignoffReceipt });
        el.recordId = 'a0Sabir';
        document.body.appendChild(el);
        return el;
    }

    const flush = () => Promise.resolve();

    it('renders preview counts and a Sign off button when ready', async () => {
        const el = setup();
        getReceipt.emit(READY_VIEW);
        await flush();

        const borrower = el.shadowRoot.querySelector('.borrower-name');
        expect(borrower.textContent).toBe('Sabir Asheed Sr.');

        const values = el.shadowRoot.querySelectorAll('.count-value');
        expect(values[1].textContent).toBe('2'); // violations

        const btn = el.shadowRoot.querySelector('.signoff-btn');
        expect(btn).not.toBeNull();

        // Not signed yet => no receipt card / hash.
        expect(el.shadowRoot.querySelector('.receipt-card')).toBeNull();

        // Demo badge present, restrained tone: never the word "denied".
        expect(el.shadowRoot.querySelector('.demo-badge')).not.toBeNull();
        expect(el.shadowRoot.textContent.toLowerCase()).not.toContain('denied');
    });

    it('hides the Sign off button when the case is not ready', async () => {
        const el = setup();
        getReceipt.emit({ ...READY_VIEW, isReadyForSignoff: false, status: 'In Review' });
        await flush();

        expect(el.shadowRoot.querySelector('.signoff-btn')).toBeNull();
        expect(el.shadowRoot.querySelector('.empty-state')).not.toBeNull();
    });

    it('fires signOff when the button is clicked', async () => {
        signOff.mockResolvedValue(SIGNED_VIEW);

        const el = setup();
        getReceipt.emit(READY_VIEW);
        await flush();

        el.shadowRoot.querySelector('.signoff-btn').click();
        await flush();

        expect(signOff).toHaveBeenCalledWith({ auditCaseId: 'a0Sabir' });
    });

    it('shows the immutable receipt and the hash disclosure once signed', async () => {
        const el = setup();
        getReceipt.emit(SIGNED_VIEW);
        await flush();

        // No Sign off button once signed.
        expect(el.shadowRoot.querySelector('.signoff-btn')).toBeNull();

        const receiptCard = el.shadowRoot.querySelector('.receipt-card');
        expect(receiptCard).not.toBeNull();

        const hash = el.shadowRoot.querySelector('.hash-value');
        expect(hash.textContent).toBe('a'.repeat(64));

        const disclosure = el.shadowRoot.querySelector('.hash-disclosure');
        expect(disclosure.textContent.toLowerCase()).toContain(
            'illustrative hash, not a cryptographic seal'
        );
    });
});
