import { createElement } from 'lwc';
import CaseReview from 'c/caseReview';
import getCaseDetail from '@salesforce/apex/CaseReviewController.getCaseDetail';
import rerunReplay from '@salesforce/apex/CaseReviewController.rerunReplay';

jest.mock(
    '@salesforce/apex/CaseReviewController.getCaseDetail',
    () => {
        const { createApexTestWireAdapter } = require('@salesforce/sfdx-lwc-jest');
        return { default: createApexTestWireAdapter(jest.fn()) };
    },
    { virtual: true }
);
jest.mock(
    '@salesforce/apex/CaseReviewController.rerunReplay',
    () => ({ default: jest.fn() }),
    { virtual: true }
);

const DETAIL = {
    header: {
        recordId: 'a0Sabir',
        caseNumber: 'AC-0001',
        loanNumber: 'LA-558823',
        borrowerName: 'Sabir Asheed Sr.',
        riskTier: 'High',
        status: 'In Review',
        approverName: 'Janet Chen'
    },
    evidence: [
        { recordId: 'e1', documentType: 'Pay_Stub', status: 'Linked' },
        { recordId: 'e2', documentType: 'Appraisal', status: 'Missing' }
    ],
    checks: [
        {
            recordId: 'c1',
            ruleName: 'DTI_MAX',
            result: 'Fail',
            expectedValue: '43',
            actualValue: '44.8',
            rationale: 'DTI exceeds the maximum.',
            sortOrder: 0,
            isFail: true
        },
        {
            recordId: 'c2',
            ruleName: 'FICO_MIN',
            result: 'Pass',
            expectedValue: '620',
            actualValue: '710',
            rationale: null,
            sortOrder: 1,
            isFail: false
        }
    ],
    replayStale: true,
    hasReplay: true,
    failCount: 1
};

describe('c-case-review', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
    });

    function setup() {
        const el = createElement('c-case-review', { is: CaseReview });
        el.recordId = 'a0Sabir';
        document.body.appendChild(el);
        return el;
    }

    const flush = () => Promise.resolve();

    it('renders both panes from a mocked getCaseDetail', async () => {
        const el = setup();
        getCaseDetail.emit(DETAIL);
        await flush();

        const evidenceItems = el.shadowRoot.querySelectorAll('.evidence-item');
        expect(evidenceItems.length).toBe(2);

        const checkRows = el.shadowRoot.querySelectorAll('.check-row');
        expect(checkRows.length).toBe(2);

        // FAIL row visually surfaced via modifier class
        const failRow = el.shadowRoot.querySelector('.check-row--fail');
        expect(failRow).not.toBeNull();

        const failPill = el.shadowRoot.querySelector('.status-pill--fail');
        expect(failPill.textContent).toBe('Fail');

        const borrower = el.shadowRoot.querySelector('.borrower-name');
        expect(borrower.textContent).toBe('Sabir Asheed Sr.');
    });

    it('wraps each rule name in a c-glossary-term with the rule code', async () => {
        const el = setup();
        getCaseDetail.emit(DETAIL);
        await flush();

        const terms = el.shadowRoot.querySelectorAll('c-glossary-term');
        expect(terms.length).toBe(2);
        const codes = Array.from(terms).map((t) => t.code);
        expect(codes).toEqual(['DTI_MAX', 'FICO_MIN']);
    });

    it('shows the staleness banner when replayStale is true', async () => {
        const el = setup();
        getCaseDetail.emit(DETAIL);
        await flush();

        const banner = el.shadowRoot.querySelector('.stale-banner');
        expect(banner).not.toBeNull();
        expect(banner.textContent).toContain('stale');
    });

    it('hides the staleness banner when not stale', async () => {
        const el = setup();
        getCaseDetail.emit({ ...DETAIL, replayStale: false });
        await flush();

        expect(el.shadowRoot.querySelector('.stale-banner')).toBeNull();
    });

    it('fires rerunReplay when the button is clicked', async () => {
        rerunReplay.mockResolvedValue({ ...DETAIL, replayStale: false, failCount: 2 });

        const el = setup();
        getCaseDetail.emit(DETAIL);
        await flush();

        const btn = el.shadowRoot.querySelector('.rerun-btn');
        btn.click();
        await flush();

        expect(rerunReplay).toHaveBeenCalledWith({ auditCaseId: 'a0Sabir' });
    });
});
