import { createElement } from 'lwc';
import OnboardingOrchestrator from 'c/onboardingOrchestrator';
import createLoanApplication from '@salesforce/apex/OnboardingController.createLoanApplication';
import runDecision from '@salesforce/apex/OnboardingController.runDecision';

jest.mock(
    '@salesforce/apex/OnboardingController.createLoanApplication',
    () => ({ default: jest.fn() }),
    { virtual: true }
);

jest.mock(
    '@salesforce/apex/OnboardingController.runDecision',
    () => ({ default: jest.fn() }),
    { virtual: true }
);

describe('c-onboarding-orchestrator', () => {
    let element;

    beforeEach(() => {
        element = createElement('c-onboarding-orchestrator', { is: OnboardingOrchestrator });
    });

    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
    });

    // --- Screen transitions ---

    it('renders welcome screen by default', () => {
        document.body.appendChild(element);
        const welcome = element.shadowRoot.querySelector('c-welcome-gate');
        expect(welcome).not.toBeNull();
    });

    it('advances to intent on start event', async () => {
        document.body.appendChild(element);
        const welcome = element.shadowRoot.querySelector('c-welcome-gate');
        welcome.dispatchEvent(new CustomEvent('start', { bubbles: true, composed: true }));

        await Promise.resolve();
        const intent = element.shadowRoot.querySelector('c-intent-capture');
        expect(intent).not.toBeNull();
    });

    it('advances to precheck on intentcaptured event', async () => {
        document.body.appendChild(element);
        // Go to intent
        element.shadowRoot.querySelector('c-welcome-gate')
            .dispatchEvent(new CustomEvent('start', { bubbles: true, composed: true }));
        await Promise.resolve();

        // Fire intent captured
        element.shadowRoot.querySelector('c-intent-capture')
            .dispatchEvent(new CustomEvent('intentcaptured', {
                bubbles: true,
                composed: true,
                detail: { loanPurpose: 'buying', propertyValue: 400000, annualIncome: 90000 }
            }));
        await Promise.resolve();

        const preCheck = element.shadowRoot.querySelector('c-pre-check-result');
        expect(preCheck).not.toBeNull();
        expect(preCheck.loanPurpose).toBe('buying');
        expect(preCheck.propertyValue).toBe(400000);
        expect(preCheck.annualIncome).toBe(90000);
    });

    it('stores intent payload in component state', async () => {
        document.body.appendChild(element);
        element.shadowRoot.querySelector('c-welcome-gate')
            .dispatchEvent(new CustomEvent('start', { bubbles: true, composed: true }));
        await Promise.resolve();

        element.shadowRoot.querySelector('c-intent-capture')
            .dispatchEvent(new CustomEvent('intentcaptured', {
                bubbles: true,
                composed: true,
                detail: { loanPurpose: 'refinancing', propertyValue: 600000, annualIncome: 120000 }
            }));
        await Promise.resolve();

        // Verify by checking precheck component receives the values
        const preCheck = element.shadowRoot.querySelector('c-pre-check-result');
        expect(preCheck.loanPurpose).toBe('refinancing');
        expect(preCheck.propertyValue).toBe(600000);
        expect(preCheck.annualIncome).toBe(120000);
    });

    it('creates loan application and advances to evidence on emailcaptured', async () => {
        createLoanApplication.mockResolvedValue('001MOCK000000001');
        document.body.appendChild(element);

        // Navigate to precheck
        element.shadowRoot.querySelector('c-welcome-gate')
            .dispatchEvent(new CustomEvent('start', { bubbles: true, composed: true }));
        await Promise.resolve();
        element.shadowRoot.querySelector('c-intent-capture')
            .dispatchEvent(new CustomEvent('intentcaptured', {
                bubbles: true, composed: true,
                detail: { loanPurpose: 'buying', propertyValue: 400000, annualIncome: 90000 }
            }));
        await Promise.resolve();

        // Email captured
        element.shadowRoot.querySelector('c-pre-check-result')
            .dispatchEvent(new CustomEvent('emailcaptured', {
                bubbles: true, composed: true,
                detail: { email: 'test@example.com' }
            }));
        await Promise.resolve();
        await Promise.resolve(); // allow async to settle

        expect(createLoanApplication).toHaveBeenCalledWith({
            purpose: 'buying',
            propertyValue: 400000,
            annualIncome: 90000
        });

        const evidence = element.shadowRoot.querySelector('c-evidence-queue');
        expect(evidence).not.toBeNull();
        expect(evidence.recordId).toBe('001MOCK000000001');
    });

    it('shows error on Apex failure without advancing screen', async () => {
        createLoanApplication.mockRejectedValue({ body: { message: 'Server error' } });
        document.body.appendChild(element);

        // Navigate to precheck
        element.shadowRoot.querySelector('c-welcome-gate')
            .dispatchEvent(new CustomEvent('start', { bubbles: true, composed: true }));
        await Promise.resolve();
        element.shadowRoot.querySelector('c-intent-capture')
            .dispatchEvent(new CustomEvent('intentcaptured', {
                bubbles: true, composed: true,
                detail: { loanPurpose: 'buying', propertyValue: 400000, annualIncome: 90000 }
            }));
        await Promise.resolve();

        // Email captured (will fail)
        element.shadowRoot.querySelector('c-pre-check-result')
            .dispatchEvent(new CustomEvent('emailcaptured', {
                bubbles: true, composed: true,
                detail: { email: 'test@example.com' }
            }));
        await Promise.resolve();
        await Promise.resolve();

        const errorBanner = element.shadowRoot.querySelector('.error-banner');
        expect(errorBanner).not.toBeNull();
        expect(errorBanner.textContent).toContain('Server error');

        // Should still be on precheck
        const preCheck = element.shadowRoot.querySelector('c-pre-check-result');
        expect(preCheck).not.toBeNull();
    });

    // --- Back navigation ---

    it('allows back navigation from intent to welcome', async () => {
        document.body.appendChild(element);
        element.shadowRoot.querySelector('c-welcome-gate')
            .dispatchEvent(new CustomEvent('start', { bubbles: true, composed: true }));
        await Promise.resolve();

        const backBtn = element.shadowRoot.querySelector('.back-btn');
        expect(backBtn).not.toBeNull();
        backBtn.click();
        await Promise.resolve();

        const welcome = element.shadowRoot.querySelector('c-welcome-gate');
        expect(welcome).not.toBeNull();
    });

    it('allows back navigation from precheck to intent', async () => {
        document.body.appendChild(element);
        element.shadowRoot.querySelector('c-welcome-gate')
            .dispatchEvent(new CustomEvent('start', { bubbles: true, composed: true }));
        await Promise.resolve();
        element.shadowRoot.querySelector('c-intent-capture')
            .dispatchEvent(new CustomEvent('intentcaptured', {
                bubbles: true, composed: true,
                detail: { loanPurpose: 'buying', propertyValue: 400000, annualIncome: 90000 }
            }));
        await Promise.resolve();

        const backBtn = element.shadowRoot.querySelector('.back-btn');
        backBtn.click();
        await Promise.resolve();

        const intent = element.shadowRoot.querySelector('c-intent-capture');
        expect(intent).not.toBeNull();
    });

    it('blocks back navigation from evidence screen', async () => {
        createLoanApplication.mockResolvedValue('001MOCK000000001');
        document.body.appendChild(element);

        // Navigate to evidence
        element.shadowRoot.querySelector('c-welcome-gate')
            .dispatchEvent(new CustomEvent('start', { bubbles: true, composed: true }));
        await Promise.resolve();
        element.shadowRoot.querySelector('c-intent-capture')
            .dispatchEvent(new CustomEvent('intentcaptured', {
                bubbles: true, composed: true,
                detail: { loanPurpose: 'buying', propertyValue: 400000, annualIncome: 90000 }
            }));
        await Promise.resolve();
        element.shadowRoot.querySelector('c-pre-check-result')
            .dispatchEvent(new CustomEvent('emailcaptured', {
                bubbles: true, composed: true,
                detail: { email: 'test@example.com' }
            }));
        await Promise.resolve();
        await Promise.resolve();

        const backBtn = element.shadowRoot.querySelector('.back-btn');
        expect(backBtn).toBeNull();
    });

    // --- Decision flow ---

    it('runs decision and shows outcome after queuecomplete', async () => {
        createLoanApplication.mockResolvedValue('001MOCK000000001');
        runDecision.mockResolvedValue({
            outcome: 'APPROVED',
            decisionEventId: 'a0BMOCK000000001',
            declineReason: null
        });
        document.body.appendChild(element);

        // Navigate to evidence
        element.shadowRoot.querySelector('c-welcome-gate')
            .dispatchEvent(new CustomEvent('start', { bubbles: true, composed: true }));
        await Promise.resolve();
        element.shadowRoot.querySelector('c-intent-capture')
            .dispatchEvent(new CustomEvent('intentcaptured', {
                bubbles: true, composed: true,
                detail: { loanPurpose: 'buying', propertyValue: 400000, annualIncome: 90000 }
            }));
        await Promise.resolve();
        element.shadowRoot.querySelector('c-pre-check-result')
            .dispatchEvent(new CustomEvent('emailcaptured', {
                bubbles: true, composed: true,
                detail: { email: 'test@example.com' }
            }));
        await Promise.resolve();
        await Promise.resolve();

        // Queue complete
        element.shadowRoot.querySelector('c-evidence-queue')
            .dispatchEvent(new CustomEvent('queuecomplete', { bubbles: true, composed: true }));
        await Promise.resolve();
        await Promise.resolve();
        await Promise.resolve();

        expect(runDecision).toHaveBeenCalledWith({ applicationId: '001MOCK000000001' });

        const outcome = element.shadowRoot.querySelector('c-outcome-view');
        expect(outcome).not.toBeNull();
        expect(outcome.outcome).toBe('APPROVED');
        expect(outcome.decisionEventId).toBe('a0BMOCK000000001');
    });
});
