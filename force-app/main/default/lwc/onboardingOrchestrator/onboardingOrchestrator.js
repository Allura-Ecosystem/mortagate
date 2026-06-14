import { LightningElement, track } from 'lwc';
import createLoanApplication from '@salesforce/apex/OnboardingController.createLoanApplication';
import runDecision from '@salesforce/apex/OnboardingController.runDecision';

/**
 * c-onboarding-orchestrator — US-1.1
 *
 * Six-screen state machine for borrower onboarding (BLUEPRINT B3).
 * Manages navigation, data flow, and Apex calls between child components.
 *
 * Screens: Welcome(0) -> Intent(1) -> PreCheck(2) -> Evidence(3) -> DecisionRoom(4) -> Outcome(5)
 *
 * Invariants:
 * - ADR-7: pre-check uses the same kernel, no record created
 * - ADR-8: no pre-filled defaults from previous sessions or URL params
 * - No back navigation past Evidence (documents uploaded = irreversible)
 */
const SCREENS = Object.freeze({
    WELCOME: 0,
    INTENT: 1,
    PRECHECK: 2,
    EVIDENCE: 3,
    DECISION_ROOM: 4,
    OUTCOME: 5
});

export default class OnboardingOrchestrator extends LightningElement {
    @track currentScreen = SCREENS.WELCOME;
    @track error = '';
    @track loading = false;

    // Intent data (captured at Screen 2)
    loanPurpose;
    propertyValue;
    annualIncome;

    // Application record (created at PreCheck -> Evidence boundary)
    applicationId;

    // Decision result (populated after evidence complete)
    decisionOutcome;
    decisionEventId;
    declineReason;

    // Decision Room events (populated during review)
    @track decisionEvents = [];

    // --- Screen visibility getters ---
    get isWelcome() { return this.currentScreen === SCREENS.WELCOME; }
    get isIntent() { return this.currentScreen === SCREENS.INTENT; }
    get isPreCheck() { return this.currentScreen === SCREENS.PRECHECK; }
    get isEvidence() { return this.currentScreen === SCREENS.EVIDENCE; }
    get isDecisionRoom() { return this.currentScreen === SCREENS.DECISION_ROOM; }
    get isOutcome() { return this.currentScreen === SCREENS.OUTCOME; }

    // --- Back navigation (blocked once evidence starts) ---
    get canGoBack() {
        return this.currentScreen === SCREENS.INTENT ||
               this.currentScreen === SCREENS.PRECHECK;
    }

    get hasError() { return Boolean(this.error); }

    // --- Event handlers from child components ---

    handleStart() {
        this.currentScreen = SCREENS.INTENT;
    }

    handleIntentCaptured(event) {
        const { loanPurpose, propertyValue, annualIncome } = event.detail;
        this.loanPurpose = loanPurpose;
        this.propertyValue = propertyValue;
        this.annualIncome = annualIncome;
        this.currentScreen = SCREENS.PRECHECK;
    }

    async handleEmailCaptured(event) {
        const { email } = event.detail;
        this.error = '';
        this.loading = true;
        try {
            this.applicationId = await createLoanApplication({
                purpose: this.loanPurpose,
                propertyValue: this.propertyValue,
                annualIncome: this.annualIncome
            });
            this.currentScreen = SCREENS.EVIDENCE;
        } catch (e) {
            this.error = e.body ? e.body.message : 'Unable to start your application. Please try again.';
        } finally {
            this.loading = false;
        }
    }

    async handleQueueComplete() {
        this.error = '';
        this.loading = true;
        this.currentScreen = SCREENS.DECISION_ROOM;
        this.decisionEvents = [
            { id: 'evt-1', label: 'Application received', timestamp: new Date().toISOString() },
            { id: 'evt-2', label: 'Documents uploaded', timestamp: new Date().toISOString() },
            { id: 'evt-3', label: 'Underwriting review started', timestamp: new Date().toISOString() }
        ];

        try {
            const result = await runDecision({ applicationId: this.applicationId });
            this.decisionOutcome = result.outcome;
            this.decisionEventId = result.decisionEventId;
            this.declineReason = result.declineReason;

            this.decisionEvents = [
                ...this.decisionEvents,
                { id: 'evt-4', label: 'Decision rendered', timestamp: new Date().toISOString() }
            ];
            this.currentScreen = SCREENS.OUTCOME;
        } catch (e) {
            this.error = e.body ? e.body.message : 'Unable to process your application. Our team has been notified.';
        } finally {
            this.loading = false;
        }
    }

    handleBack() {
        if (this.canGoBack) {
            this.currentScreen -= 1;
            this.error = '';
        }
    }

    handleScheduleCall() {
        // Future: integrate scheduling
    }

    handleNextSteps() {
        // Future: route to next-steps content
    }

    handleViewReceipt(event) {
        const { decisionEventId } = event.detail;
        window.open(`/apex/DecisionReceipt?id=${decisionEventId}`, '_blank');
    }

    handleViewNotice(event) {
        const { decisionEventId } = event.detail;
        window.open(`/apex/AdverseActionNotice?id=${decisionEventId}`, '_blank');
    }

    handleDismissError() {
        this.error = '';
    }
}
