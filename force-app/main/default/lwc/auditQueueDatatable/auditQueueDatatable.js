import LightningDatatable from 'lightning/datatable';
import riskBadgeCell from './riskBadgeCell.html';

/**
 * auditQueueDatatable — lightning-datatable extended with a custom `riskBadge`
 * cell type. The base datatable renders cells in its own shadow DOM, so a
 * standard `text` column with a cellAttributes class can never pick up the
 * auditQueue stylesheet (that was the AUDIT_CHECK_FAIL drift: risk colours and
 * shape sigils were defined but never rendered). The custom type delegates to
 * the <c-risk-badge> component, which carries its own markup + CSS, so the
 * colour + sigil render reliably inside the table.
 *
 * Public API is unchanged from lightning-datatable (data, columns, sortable,
 * onsort, onrowaction, etc.) — auditQueue uses it as a drop-in replacement.
 */
export default class AuditQueueDatatable extends LightningDatatable {
    static customTypes = {
        riskBadge: {
            template: riskBadgeCell,
            standardCellLayout: true
        }
    };
}
