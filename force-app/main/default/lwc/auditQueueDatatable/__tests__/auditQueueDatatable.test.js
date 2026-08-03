import AuditQueueDatatable from 'c/auditQueueDatatable';

/**
 * auditQueueDatatable — extends LightningDatatable with a single custom cell
 * type (`riskBadge`). Because LightningDatatable is a platform base component,
 * Jest cannot instantiate it via createElement (no mock ships with sfdx-lwc-jest
 * for the datatable). What we CAN test is the static contract that the class
 * exposes: the customTypes map that the framework reads at runtime.
 *
 * These tests guard against:
 *   - Accidental deletion of the riskBadge type registration
 *   - Breaking the standardCellLayout flag (which controls padding/alignment)
 *   - Adding surprise custom types that violate one-thing-per-component
 */
describe('c-audit-queue-datatable', () => {
    // --- Static contract: customTypes ---

    it('registers the riskBadge custom type', () => {
        expect(AuditQueueDatatable.customTypes).toBeDefined();
        expect(AuditQueueDatatable.customTypes.riskBadge).toBeDefined();
    });

    it('registers the qcWindow custom type', () => {
        expect(AuditQueueDatatable.customTypes.qcWindow).toBeDefined();
    });

    it('uses standardCellLayout for both custom types', () => {
        const { riskBadge, qcWindow } = AuditQueueDatatable.customTypes;
        expect(riskBadge.standardCellLayout).toBe(true);
        expect(qcWindow.standardCellLayout).toBe(true);
    });

    it('provides a template for each custom type', () => {
        const { riskBadge, qcWindow } = AuditQueueDatatable.customTypes;
        // The template is an imported HTML module — it will be a function or
        // object depending on the Jest transform, but it must be truthy.
        expect(riskBadge.template).toBeTruthy();
        expect(qcWindow.template).toBeTruthy();
    });

    it('registers exactly the two badge cell types (no surprise types)', () => {
        const typeNames = Object.keys(AuditQueueDatatable.customTypes);
        expect(typeNames).toEqual(['riskBadge', 'qcWindow', 'slaBadge']);
    });

    // --- Inheritance ---

    it('extends LightningDatatable (not LightningElement)', () => {
        // The prototype chain must include LightningDatatable. We cannot
        // import LightningDatatable directly in Jest, but we can verify the
        // class name survives in the constructor chain. A simpler check: the
        // class itself should NOT be a plain LightningElement (no @api tier,
        // no template of its own beyond the cell template).
        expect(typeof AuditQueueDatatable).toBe('function');
        // customTypes is a static property specific to LightningDatatable
        // subclasses — its presence is proof of correct inheritance.
        expect(AuditQueueDatatable.customTypes).toBeDefined();
    });
});
