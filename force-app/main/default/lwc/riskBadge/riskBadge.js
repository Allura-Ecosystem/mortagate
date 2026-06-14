import { LightningElement, api } from 'lwc';

/**
 * riskBadge — presentational risk-tier badge.
 *
 * Renders the tier WORD plus a colour + shape sigil. This component exists so
 * the badge markup AND its stylesheet live in the SAME shadow root: a
 * lightning-datatable renders its cells inside its own shadow DOM, so the
 * parent auditQueue stylesheet could never reach the cells (the original
 * AUDIT_CHECK_FAIL drift — colours/sigils defined but never rendered). Used
 * via the custom `riskBadge` datatable cell type in auditQueueDatatable.
 *
 * Single source of truth for the tier→class map (previously duplicated in
 * auditQueue.js). The tier word is always rendered as text, so risk is never
 * conveyed by colour alone (WCAG 1.4.1); the sigil is an additional non-colour
 * discriminator (Critical ● / High ▲ / Medium ◆ / Low ■).
 */
const TIER_CLASS = {
    Critical: 'risk-badge risk-badge--critical',
    High: 'risk-badge risk-badge--high',
    Medium: 'risk-badge risk-badge--medium',
    Low: 'risk-badge risk-badge--low'
};

export default class RiskBadge extends LightningElement {
    @api tier;

    get badgeClass() {
        return TIER_CLASS[this.tier] || 'risk-badge';
    }
}
