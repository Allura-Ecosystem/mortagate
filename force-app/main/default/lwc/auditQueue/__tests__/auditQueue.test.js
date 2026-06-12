import { createElement } from 'lwc';
import AuditQueue from 'c/auditQueue';
import getQueue from '@salesforce/apex/AuditQueueController.getQueue';
import USER_ID from '@salesforce/user/Id';

// Register the @wire(getQueue) Apex method as an emittable test wire adapter.
jest.mock(
    '@salesforce/apex/AuditQueueController.getQueue',
    () => {
        const {
            createApexTestWireAdapter
        } = require('@salesforce/sfdx-lwc-jest');
        return { default: createApexTestWireAdapter(jest.fn()) };
    },
    { virtual: true }
);

/**
 * CONTRACT GUARD (Ralph loop T3 — Knuth's rule).
 *
 * The blank-datatable bug was an unverified equality between two lists:
 * the columns the LWC declares vs. the keys the queueData getter produces
 * from the raw Audit_Case__c SObject. This test asserts that equality.
 *
 * APEX_ROW is shaped EXACTLY as AuditCaseService.getQueue serializes an
 * Audit_Case__c (API field names, nested relationship object). If the getter
 * or the SOQL field list drifts apart from the columns again, this goes red
 * here — not on the auditor's screen.
 */
const APEX_ROW = {
    Id: 'a0X000000000001AAA',
    Name: 'AC-0001',
    Loan_Application__c: 'LA-558823',
    Borrower_Name_Snapshot__c: 'Dolores Vance',
    Status__c: 'Evidence_Needed',
    Risk_Tier__c: 'Critical',
    Original_Approver__r: { Name: 'Dana Whitfield' },
    Due_At__c: '2026-06-20T17:00:00.000Z'
};

function flush() {
    return Promise.resolve();
}

describe('c-audit-queue — column/key contract', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
    });

    it('produces a row key for every declared field column', async () => {
        const element = createElement('c-audit-queue', { is: AuditQueue });
        document.body.appendChild(element);

        getQueue.emit([APEX_ROW]);
        await flush();

        const table = element.shadowRoot.querySelector('lightning-datatable');
        expect(table).not.toBeNull();

        const row = table.data[0];
        // The equality assertion: every declared column.fieldName must exist on the mapped row.
        const fieldColumns = table.columns.filter((c) => c.fieldName);
        fieldColumns.forEach((c) => {
            expect(row[c.fieldName]).toBeDefined();
        });
        // Cell-attribute-backed field (risk badge class) must be produced too.
        expect(row.riskClass).toBeDefined();
    });

    it('maps SObject API fields to the correct column property names', async () => {
        const element = createElement('c-audit-queue', { is: AuditQueue });
        document.body.appendChild(element);

        getQueue.emit([APEX_ROW]);
        await flush();

        const row = element.shadowRoot.querySelector('lightning-datatable').data[0];
        expect(row.id).toBe(APEX_ROW.Id); // key-field fix: SObject 'Id' -> 'id'
        expect(row.loanNumber).toBe('LA-558823');
        expect(row.borrowerName).toBe('Dolores Vance'); // ADR-001: write-once snapshot field
        expect(row.riskTier).toBe('Critical');
        expect(row.riskClass).toContain('risk-badge--critical');
        expect(row.status).toBe('Evidence Needed'); // underscore humanized
        expect(row.approverName).toBe('Dana Whitfield'); // nested __r.Name flattened
        expect(typeof row.slaRemaining).toBe('string'); // computed from Due_At__c
    });

    it('backs borrowerName with the write-once snapshot field, not a fabricated value (ADR-001)', async () => {
        const element = createElement('c-audit-queue', { is: AuditQueue });
        document.body.appendChild(element);

        getQueue.emit([APEX_ROW]);
        await flush();

        const table = element.shadowRoot.querySelector('lightning-datatable');
        // The column exists again now that Borrower_Name_Snapshot__c backs it.
        const hasBorrowerColumn = table.columns.some((c) => c.fieldName === 'borrowerName');
        expect(hasBorrowerColumn).toBe(true);
        // And it is sourced from the snapshot field — never invented.
        expect(table.data[0].borrowerName).toBe(APEX_ROW.Borrower_Name_Snapshot__c);
    });

    it('renders an empty borrowerName (not undefined) when the snapshot is missing', async () => {
        const element = createElement('c-audit-queue', { is: AuditQueue });
        document.body.appendChild(element);

        const noSnapshot = { ...APEX_ROW, Borrower_Name_Snapshot__c: undefined };
        getQueue.emit([noSnapshot]);
        await flush();

        const row = element.shadowRoot.querySelector('lightning-datatable').data[0];
        expect(row.borrowerName).toBe('');
    });

    /**
     * FILTER-WIRE CONTRACT (F-01).
     *
     * Every filter control that has a backing Audit_Case__c field must reach
     * the getQueue wire adapter as a reactive param. If a future edit drops one
     * from the @wire config (the original "dead filter" bug), this goes red in
     * CI rather than silently failing on the auditor's screen.
     */
    it('wires every backing filter param to the getQueue adapter', async () => {
        const element = createElement('c-audit-queue', { is: AuditQueue });
        document.body.appendChild(element);
        await flush();

        const config = getQueue.getLastConfig();
        [
            'filterStatus',
            'filterRiskTier',
            'filterApproverId',
            'filterSamplingReason',
            'filterApprovalDays',
            'filterAuditorId',
            'filterDueBefore'
        ].forEach((param) => {
            expect(config).toHaveProperty(param);
        });

        // Product/Branch have no backing field yet — they must NOT be wired
        // (wiring an unsupported param would be a silent no-op). Guard the gap.
        expect(config).not.toHaveProperty('filterProduct');
        expect(config).not.toHaveProperty('filterBranch');
    });

    it("resolves the 'mine' auditor selection to the current user Id", async () => {
        const element = createElement('c-audit-queue', { is: AuditQueue });
        document.body.appendChild(element);
        await flush();

        const auditor = element.shadowRoot.querySelector(
            'lightning-combobox[data-field="auditor"]'
        );
        auditor.dispatchEvent(new CustomEvent('change', { detail: { value: 'mine' } }));
        await flush();

        const config = getQueue.getLastConfig();
        expect(config.filterAuditorId).toBe(USER_ID);
    });

    it('passes null (not an empty string) for an unset due-before date', async () => {
        const element = createElement('c-audit-queue', { is: AuditQueue });
        document.body.appendChild(element);
        await flush();

        // Empty date must resolve to null so it never hits the Apex Date param.
        expect(getQueue.getLastConfig().filterDueBefore).toBeNull();
    });

    /**
     * COLUMN SORT (F-04). Columns declare sortable:true; the datatable must
     * actually reorder on `onsort`, flip on direction, stay stable for ties,
     * and reject any field outside the allow-list.
     */
    function rowWith(overrides) {
        return { ...APEX_ROW, ...overrides };
    }

    function fireSort(table, fieldName, sortDirection) {
        table.dispatchEvent(
            new CustomEvent('sort', { detail: { fieldName, sortDirection } })
        );
    }

    it('reorders rows on sort and flips with direction (F-04)', async () => {
        const element = createElement('c-audit-queue', { is: AuditQueue });
        document.body.appendChild(element);

        getQueue.emit([
            rowWith({ Id: 'c', Borrower_Name_Snapshot__c: 'Charlie' }),
            rowWith({ Id: 'a', Borrower_Name_Snapshot__c: 'Alice' }),
            rowWith({ Id: 'b', Borrower_Name_Snapshot__c: 'Bob' })
        ]);
        await flush();

        const table = element.shadowRoot.querySelector('lightning-datatable');

        fireSort(table, 'borrowerName', 'asc');
        await flush();
        expect(table.sortedBy).toBe('borrowerName');
        expect(table.sortedDirection).toBe('asc');
        expect(table.data.map((r) => r.borrowerName)).toEqual([
            'Alice',
            'Bob',
            'Charlie'
        ]);

        fireSort(table, 'borrowerName', 'desc');
        await flush();
        expect(table.sortedDirection).toBe('desc');
        expect(table.data.map((r) => r.borrowerName)).toEqual([
            'Charlie',
            'Bob',
            'Alice'
        ]);
    });

    it('keeps server order for tied sort values (stable)', async () => {
        const element = createElement('c-audit-queue', { is: AuditQueue });
        document.body.appendChild(element);

        // Both rows share Risk_Tier__c 'High' — sorting by riskTier is a tie.
        getQueue.emit([
            rowWith({ Id: 'first', Risk_Tier__c: 'High' }),
            rowWith({ Id: 'second', Risk_Tier__c: 'High' })
        ]);
        await flush();

        const table = element.shadowRoot.querySelector('lightning-datatable');
        fireSort(table, 'riskTier', 'asc');
        await flush();

        expect(table.data.map((r) => r.id)).toEqual(['first', 'second']);
    });

    it('ignores a sort on a field outside the allow-list', async () => {
        const element = createElement('c-audit-queue', { is: AuditQueue });
        document.body.appendChild(element);

        getQueue.emit([
            rowWith({ Id: 'x', Borrower_Name_Snapshot__c: 'Zara' }),
            rowWith({ Id: 'y', Borrower_Name_Snapshot__c: 'Aaron' })
        ]);
        await flush();

        const table = element.shadowRoot.querySelector('lightning-datatable');
        const before = table.data.map((r) => r.id);

        fireSort(table, 'riskClass', 'asc'); // cellAttributes field, not sortable
        await flush();

        expect(table.sortedBy).toBe(''); // never accepted
        expect(table.data.map((r) => r.id)).toEqual(before); // order untouched
    });

    /**
     * ACCESSIBILITY (WCAG). Two deterministic guards:
     *  - 1.4.1 (use of color): risk must be conveyed by a TEXT value, never by
     *    color alone. The Risk column is type 'text' and the row carries the
     *    tier word, independent of the riskClass color hook. (The 1.4.3 contrast
     *    of those colors is verified separately and recorded in the release note;
     *    jsdom cannot compute rendered contrast, so it is checked numerically.)
     *  - 4.1.x / error semantics: the load-error state must expose role="alert"
     *    so assistive tech announces it, not just render colored text.
     */
    it('conveys risk by a text value, not color alone (WCAG 1.4.1)', async () => {
        const element = createElement('c-audit-queue', { is: AuditQueue });
        document.body.appendChild(element);

        getQueue.emit([rowWith({ Risk_Tier__c: 'Medium' })]);
        await flush();

        const table = element.shadowRoot.querySelector('lightning-datatable');
        const riskCol = table.columns.find((c) => c.fieldName === 'riskTier');
        expect(riskCol.type).toBe('text'); // the word is rendered, not a swatch
        // The tier word is present independent of the color class.
        expect(table.data[0].riskTier).toBe('Medium');
        expect(table.data[0].riskClass).toContain('risk-badge--medium');
    });

    it('exposes the load-error state with role="alert" for assistive tech', async () => {
        const element = createElement('c-audit-queue', { is: AuditQueue });
        document.body.appendChild(element);

        getQueue.error({ body: { message: 'boom' }, ok: false, status: 500 });
        await flush();

        const alert = element.shadowRoot.querySelector('[role="alert"]');
        expect(alert).not.toBeNull();
    });
});
