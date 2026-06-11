/**
 * Controller for the Decision Receipt PDF (DecisionReceipt.page, renderAs="pdf").
 *
 * Makes the Veridact promise literal: "Every decision has a receipt." It renders
 * one immutable Decision_Event__c into a human-readable, printable, emailable
 * audit document. It is a PURE READ — there is no DML, no apex:form, no input —
 * so it cannot mutate the append-only event (Allura immutability holds by
 * construction). Security is non-negotiable here because this artifact may be
 * emailed outside the org: FLS/CRUD is enforced before any field is surfaced,
 * and the record is fetched with a bind variable (no SOQL injection surface).
 */
public with sharing class DecisionReceiptController {

    private static final List<String> RECEIPT_FIELDS = new List<String>{
        'Outcome__c', 'Decision_Timestamp__c', 'Triggered_By__c', 'Decline_Reason__c',
        'Evaluated_Rule_Count__c', 'Hard_Decline_Count__c', 'Rule_Results_JSON__c'
    };

    public Decision_Event__c event { get; private set; }
    public Boolean accessDenied { get; private set; }
    public String accessMessage { get; private set; }
    public List<ReceiptLine> ruleLines { get; private set; }

    public DecisionReceiptController() {
        this.accessDenied = false;
        this.ruleLines = new List<ReceiptLine>();
        load();
    }

    private void load() {
        // 1. Object-level CRUD.
        if (!Schema.sObjectType.Decision_Event__c.isAccessible()) {
            deny('You do not have access to decision records.');
            return;
        }
        // 2. Field-level security — every field we intend to surface.
        Map<String, Schema.SObjectField> fmap = Decision_Event__c.SObjectType.getDescribe().fields.getMap();
        for (String f : RECEIPT_FIELDS) {
            Schema.SObjectField token = fmap.get(f.toLowerCase());
            if (token == null || !token.getDescribe().isAccessible()) {
                deny('You do not have permission to view all fields on this receipt.');
                return;
            }
        }
        // 3. Validate the supplied Id before touching the database.
        String raw = ApexPages.currentPage() == null
            ? null : ApexPages.currentPage().getParameters().get('id');
        Id eventId = safeId(raw);
        if (eventId == null) {
            deny('No valid decision identifier was supplied.');
            return;
        }
        // 4. Bind-variable query — never string concatenation.
        List<Decision_Event__c> found = [
            SELECT Id, Name, Outcome__c, Decision_Timestamp__c, Triggered_By__c,
                   Decline_Reason__c, Evaluated_Rule_Count__c, Hard_Decline_Count__c,
                   Rule_Results_JSON__c
            FROM Decision_Event__c
            WHERE Id = :eventId
            WITH USER_MODE
            LIMIT 1
        ];
        if (found.isEmpty()) {
            deny('This receipt could not be found.');
            return;
        }
        this.event = found[0];
        this.ruleLines = parseReceipt(this.event.Rule_Results_JSON__c);
    }

    /** Coerce/validate the URL param into a Decision_Event__c Id; null if invalid. */
    private static Id safeId(String raw) {
        if (String.isBlank(raw)) { return null; }
        try {
            Id candidate = Id.valueOf(raw);
            return candidate.getSObjectType() == Decision_Event__c.SObjectType ? candidate : null;
        } catch (Exception e) {
            return null;
        }
    }

    /**
     * Deserialize the receipt body (a serialized List<RuleOutcome>) into typed
     * display rows. Parsing for human display is a controller job — the page never
     * renders raw JSON. Untyped parse avoids depending on RuleOutcome's
     * non-default constructor.
     */
    private static List<ReceiptLine> parseReceipt(String json) {
        List<ReceiptLine> lines = new List<ReceiptLine>();
        if (String.isBlank(json)) { return lines; }
        try {
            for (Object o : (List<Object>) System.JSON.deserializeUntyped(json)) {
                Map<String, Object> m = (Map<String, Object>) o;
                lines.add(new ReceiptLine(m));
            }
        } catch (Exception e) {
            // Malformed JSON should never break the receipt — show the header only.
        }
        return lines;
    }

    private void deny(String message) {
        this.accessDenied = true;
        this.accessMessage = message;
    }

    /** A single rule's result, every field a display-ready String. */
    public class ReceiptLine {
        public String ruleCode { get; private set; }
        public String version { get; private set; }
        public String outcome { get; private set; }
        public String severity { get; private set; }
        public String category { get; private set; }
        public String explanation { get; private set; }
        public String factValue { get; private set; }
        public String threshold { get; private set; }
        public Boolean isFail { get; private set; }

        public ReceiptLine(Map<String, Object> m) {
            this.ruleCode = str(m.get('ruleCode'));
            this.version = m.get('versionNumber') == null ? '' : 'v' + str(m.get('versionNumber'));
            this.outcome = str(m.get('outcome'));
            this.severity = str(m.get('severity'));
            this.category = str(m.get('category'));
            this.explanation = str(m.get('explanation'));
            this.factValue = str(m.get('factValue'));
            this.threshold = str(m.get('threshold'));
            this.isFail = this.outcome == 'FAIL';
        }

        private String str(Object o) { return o == null ? '' : String.valueOf(o); }
    }
}
