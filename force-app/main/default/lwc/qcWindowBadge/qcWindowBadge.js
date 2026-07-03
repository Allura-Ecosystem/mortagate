import { LightningElement, api } from 'lwc';

/**
 * qcWindowBadge — presentational badge for the Fannie Mae 90-day QC window.
 *
 * Renders days-remaining as a WORD ("X days left" / "Window exceeded"); the
 * chip fill is decorative reinforcement, never the sole signal (WCAG 1.4.1).
 * Like c-risk-badge, this component owns BOTH its markup and its stylesheet so
 * the colour renders inside a lightning-datatable's own shadow root (a plain
 * text column's cellAttributes class can never reach that far).
 *
 * Tone bands (ADR-9 — semantic status colour lives on the chip BACKGROUND):
 *   daysLeft < 0                 → declined/red   "Window exceeded"
 *   0 <= daysLeft <= AT_RISK_DAYS → warn/amber     final two weeks
 *   daysLeft > AT_RISK_DAYS      → muted (neutral) plenty of runway
 *   null/undefined               → muted em dash   n/a (Closed or no anchor)
 */
const AT_RISK_DAYS = 14;

export default class QcWindowBadge extends LightningElement {
    @api daysLeft;

    get hasWindow() {
        return this.daysLeft !== null && this.daysLeft !== undefined;
    }

    get label() {
        if (!this.hasWindow) {
            return '—';
        }
        if (this.daysLeft < 0) {
            return 'Window exceeded';
        }
        return this.daysLeft === 1 ? '1 day left' : `${this.daysLeft} days left`;
    }

    get badgeClass() {
        if (!this.hasWindow) {
            return 'qc-badge qc-badge--none';
        }
        if (this.daysLeft < 0) {
            return 'qc-badge qc-badge--exceeded';
        }
        if (this.daysLeft <= AT_RISK_DAYS) {
            return 'qc-badge qc-badge--warn';
        }
        return 'qc-badge qc-badge--ok';
    }
}
