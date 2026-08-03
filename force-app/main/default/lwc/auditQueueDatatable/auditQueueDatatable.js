import LightningDatatable from 'lightning/datatable';
import riskBadgeCell from './riskBadgeCell.html';
import qcWindowCell from './qcWindowCell.html';
import slaBadgeCell from './slaBadgeCell.html';

/**
 * auditQueueDatatable — lightning-datatable extended with custom cell types
 * (`riskBadge`, `qcWindow`). The base datatable renders cells in its own shadow
 * DOM, so a standard `text` column with a cellAttributes class can never pick
 * up the auditQueue stylesheet (that was the AUDIT_CHECK_FAIL drift: risk
 * colours and shape sigils were defined but never rendered). Each custom type
 * delegates to a leaf component (<c-risk-badge>, <c-qc-window-badge>) that
 * carries its own markup + CSS, so the colour renders reliably inside the table.
 *
 * Public API is unchanged from lightning-datatable (data, columns, sortable,
 * onsort, onrowaction, etc.) — auditQueue uses it as a drop-in replacement.
 */
export default class AuditQueueDatatable extends LightningDatatable {
    static customTypes = {
        riskBadge: {
            template: riskBadgeCell,
            standardCellLayout: true
        },
        qcWindow: {
            template: qcWindowCell,
            standardCellLayout: true
        },
        slaBadge: {
            template: slaBadgeCell,
            standardCellLayout: true,
            typeAttributes: ['tone']
        }
    };
}
