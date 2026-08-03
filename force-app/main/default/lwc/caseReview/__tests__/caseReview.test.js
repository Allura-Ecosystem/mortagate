import { createElement } from 'lwc';
import CaseReview from 'c/caseReview';
import getCaseDetail from '@salesforce/apex/CaseReviewController.getCaseDetail';
import rerunReplay from '@salesforce/apex/CaseReviewController.rerunReplay';
import signOff from '@salesforce/apex/SignoffController.signOff';

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
jest.mock(
    '@salesforce/apex/SignoffController.signOff',
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

const ALL_PASS_DETAIL = {
    ...DETAIL,
    checks: [
        {
            recordId: 'c1',
            ruleName: 'DTI_MAX',
            result: 'Pass',
            expectedValue: '43',
            actualValue: '38',
            rationale: null,
            sortOrder: 0,
            isFail: false
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
    failCount: 0
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

    // ── Enhancement 1: Progress spinner ──────────────────────────────────

    it('shows the progress spinner during replay execution', async () => {
        // Keep the promise pending so isLoading stays true.
        rerunReplay.mockReturnValue(new Promise(() => {}));

        const el = setup();
        getCaseDetail.emit(DETAIL);
        await flush();

        const btn = el.shadowRoot.querySelector('.rerun-btn');
        btn.click();
        await flush();

        const spinner = el.shadowRoot.querySelector('.spinner-wrap');
        expect(spinner).not.toBeNull();

        const spinnerText = el.shadowRoot.querySelector('.spinner-text');
        expect(spinnerText).not.toBeNull();
        expect(spinnerText.textContent).toMatch(/Running audit replay|Evaluating rule/i);
    });

    it('hides the spinner after replay completes', async () => {
        rerunReplay.mockResolvedValue({ ...DETAIL, replayStale: false, failCount: 2 });

        const el = setup();
        getCaseDetail.emit(DETAIL);
        await flush();

        const btn = el.shadowRoot.querySelector('.rerun-btn');
        btn.click();

        // Wait for the full async chain: handleRerun → rerunReplay → finally → re-render.
        await flush();
        await flush();
        await flush();

        // After the promise resolves, isLoading should be false.
        expect(el.shadowRoot.querySelector('.spinner-wrap')).toBeNull();
    });

    // ── Enhancement 2: Inline decision summary ──────────────────────────

    it('shows the decision summary with pass/fail counts', async () => {
        const el = setup();
        getCaseDetail.emit(DETAIL);
        await flush();

        const summary = el.shadowRoot.querySelector('.decision-summary');
        expect(summary).not.toBeNull();

        expect(summary.textContent).toContain('1 passed');
        expect(summary.textContent).toContain('1 failed');
    });

    it('lists failing rules by name in the decision summary', async () => {
        const el = setup();
        getCaseDetail.emit(DETAIL);
        await flush();

        const failItems = el.shadowRoot.querySelectorAll('.summary-fail-item');
        expect(failItems.length).toBe(1);

        const ruleName = el.shadowRoot.querySelector('.summary-fail-rule');
        expect(ruleName.textContent).toBe('DTI_MAX');

        const detail = el.shadowRoot.querySelector('.summary-fail-detail');
        expect(detail.textContent).toContain('DTI exceeds the maximum.');
    });

    it('shows all-pass variant when no rules fail', async () => {
        const el = setup();
        getCaseDetail.emit(ALL_PASS_DETAIL);
        await flush();

        const summary = el.shadowRoot.querySelector('.decision-summary');
        expect(summary).not.toBeNull();
        expect(summary.getAttribute('data-passed')).toBe('true');

        expect(summary.textContent).toContain('2 passed');
        expect(summary.textContent).toContain('0 failed');

        // No failing rule items when all pass.
        expect(el.shadowRoot.querySelectorAll('.summary-fail-item').length).toBe(0);
    });

    // ── Enhancement 3: Post-sign-off confirmation modal ──────────────────

    it('shows the confirmation modal after successful sign-off', async () => {
        signOff.mockResolvedValue({ ...DETAIL, status: 'Closed' });

        const el = setup();
        getCaseDetail.emit(DETAIL);
        await flush();

        // Call handleSignOff directly (it's exposed for parent/child use).
        await el.handleSignOff();
        await flush();

        const modal = el.shadowRoot.querySelector('.modal-dialog');
        expect(modal).not.toBeNull();

        const title = el.shadowRoot.querySelector('.modal-title');
        expect(title.textContent).toBe('Signed off');

        const message = el.shadowRoot.querySelector('.modal-message');
        expect(message.textContent).toContain('Janet Chen');
        expect(message.textContent).toContain('Compliance');
    });

    it('dismisses the modal when Done is clicked', async () => {
        signOff.mockResolvedValue({ ...DETAIL, status: 'Closed' });

        const el = setup();
        getCaseDetail.emit(DETAIL);
        await flush();

        await el.handleSignOff();
        await flush();

        const doneBtn = el.shadowRoot.querySelector('.modal-done-btn');
        doneBtn.click();
        await flush();

        expect(el.shadowRoot.querySelector('.modal-dialog')).toBeNull();
    });

    it('dismisses the modal when backdrop is clicked', async () => {
        signOff.mockResolvedValue({ ...DETAIL, status: 'Closed' });

        const el = setup();
        getCaseDetail.emit(DETAIL);
        await flush();

        await el.handleSignOff();
        await flush();

        const backdrop = el.shadowRoot.querySelector('.modal-backdrop');
        backdrop.click();
        await flush();

        expect(el.shadowRoot.querySelector('.modal-dialog')).toBeNull();
    });

    it('shows a toast on sign-off failure', async () => {
        const err = new Error();
        err.body = { message: 'Not ready for sign-off' };
        signOff.mockRejectedValue(err);

        const el = setup();
        getCaseDetail.emit(DETAIL);
        await flush();

        const dispatchSpy = jest.spyOn(el, 'dispatchEvent');

        await el.handleSignOff();
        await flush();

        // Should have dispatched an error toast, not shown the modal.
        expect(el.shadowRoot.querySelector('.modal-dialog')).toBeNull();

        // Check that dispatchEvent was called at least once (the error toast).
        expect(dispatchSpy.mock.calls.length).toBeGreaterThanOrEqual(1);
    });
});
