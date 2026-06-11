import { LightningElement } from 'lwc';

/**
 * c-welcome-gate — Screen 1. One sentence, one button, no login wall.
 * The headline is borrower-addressed and functional (Inter Medium). The brand
 * tagline appears as a quiet footer signature in Source Serif 4 — it is the
 * signature, not the call to action.
 */
export default class WelcomeGate extends LightningElement {
    handleStart() {
        this.dispatchEvent(new CustomEvent('start', { bubbles: true, composed: true }));
    }
}
