import { LightningElement, api } from 'lwc';

/**
 * slaBadge — presentational badge for the SLA column in the audit queue.
 *
 * Renders the SLA label with a coloured chip fill. The text is the primary
 * signal; the chip fill is decorative reinforcement (WCAG 1.4.1).
 *
 * Tone bands:
 *   overdue → red fill   (SLA window blown)
 *   soon    → amber fill (due today or within 3 days)
 *   ok      → muted      (plenty of runway)
 *   met     → green tint (closed case)
 *   none    → transparent (no due date)
 */
export default class SlaBadge extends LightningElement {
    @api label;
    @api tone;

    get badgeClass() {
        const base = 'sla-badge';
        switch (this.tone) {
            case 'overdue':
                return `${base} sla-badge--overdue`;
            case 'soon':
                return `${base} sla-badge--soon`;
            case 'met':
                return `${base} sla-badge--met`;
            case 'ok':
                return `${base} sla-badge--ok`;
            default:
                return `${base} sla-badge--none`;
        }
    }
}
