/**
 * Controller for AdverseActionNotice.page (renderAs="pdf") — the ECOA / Reg B adverse
 * action notice. Like DecisionReceiptController it is a PURE READ: no DML, no apex:form,
 * no input, so it cannot mutate the append-only Decision_Event__c. It does the I/O the
 * pure AdverseActionService cannot — load the event and its failing rules, the borrower's
 * name, any credit score on file, and the Adverse_Action_Config__mdt — then hands plain
 * values to the service and exposes the assembled Notice to the page.
 *
 * Security is non-negotiable: this letter leaves the org. FLS/CRUD is enforced on every
 * surfaced field; the record is fetched with a bind variable under USER_MODE.
 */
public with sharing class AdverseActionNoticeController {

    private static final List<String> EVENT_FIELDS = new List<String>{
        'Outcome__c', 'Decision_Timestamp__c', 'Decline_Reason__c', 'Rule_Results_JSON__c', 'Application__c'
    };

    public AdverseActionService.Notice notice { get; private set; }
    public Boolean accessDenied { get; private set; }
    public String accessMessage { get; private set; }

    public AdverseActionNoticeController() {
        this.accessDenied = false;
        load();
    }

    private void load() {
        if (!Schema.sObjectType.Decision_Event__c.isAccessible()) {
            deny('You do not have access to decision records.');
            return;
        }
        Map<String, Schema.SObjectField> fmap = Decision_Event__c.SObjectType.getDescribe().fields.getMap();
        for (String f : EVENT_FIELDS) {
            Schema.SObjectField token = fmap.get(f.toLowerCase());
            if (token == null || !token.getDescribe().isAccessible()) {
                deny('You do not have permission to view all fields on this notice.');
                return;
            }
        }
        String raw = ApexPages.currentPage() == null
            ? null : ApexPages.currentPage().getParameters().get('id');
        Id eventId = safeId(raw);
        if (eventId == null) {
            deny('No valid decision identifier was supplied.');
            return;
        }
        List<Decision_Event__c> found = [
            SELECT Id, Outcome__c, Decision_Timestamp__c, Decline_Reason__c,
                   Rule_Results_JSON__c, Application__c,
                   Application__r.Borrower__r.Name
            FROM Decision_Event__c
            WHERE Id = :eventId
            WITH USER_MODE
            LIMIT 1
        ];
        if (found.isEmpty()) {
            deny('This notice could not be found.');
            return;
        }
        Decision_Event__c e = found[0];

        String applicantName = (e.Application__r != null && e.Application__r.Borrower__r != null)
            ? e.Application__r.Borrower__r.Name : null;

        Date noticeDate = e.Decision_Timestamp__c == null
            ? Date.today() : e.Decision_Timestamp__c.date();

        this.notice = AdverseActionService.build(
            e.Outcome__c,
            parseFailingRules(e.Rule_Results_JSON__c),
            lookupCreditScore(e.Application__c),
            loadConfig(),
            applicantName,
            noticeDate
        );
    }

    /** Parse the receipt JSON into the service's FailingRule inputs (FAIL rows only). */
    private static List<AdverseActionService.FailingRule> parseFailingRules(String json) {
        List<AdverseActionService.FailingRule> failing = new List<AdverseActionService.FailingRule>();
        if (String.isBlank(json)) { return failing; }
        try {
            for (Object o : (List<Object>) System.JSON.deserializeUntyped(json)) {
                Map<String, Object> m = (Map<String, Object>) o;
                if (!'FAIL'.equals(str(m.get('outcome')))) { continue; }
                AdverseActionService.FailingRule fr = new AdverseActionService.FailingRule(
                    str(m.get('explanation')), str(m.get('ruleCode')), str(m.get('severity')));
                fr.factValue = str(m.get('factValue'));
                fr.threshold = str(m.get('threshold'));
                failing.add(fr);
            }
        } catch (Exception ex) {
            // Malformed JSON must not break the notice — degrade to no itemized reasons.
        }
        return failing;
    }

    /** Most recent verified credit score on file, if any (null until P3 bureau pull). */
    private static Integer lookupCreditScore(Id applicationId) {
        if (applicationId == null) { return null; }
        if (!Schema.sObjectType.Extracted_Facts__c.isAccessible()
            || !Extracted_Facts__c.FICO_Score__c.getDescribe().isAccessible()) {
            return null;
        }
        List<Extracted_Facts__c> facts = [
            SELECT FICO_Score__c
            FROM Extracted_Facts__c
            WHERE Application__c = :applicationId AND FICO_Score__c != null
            WITH USER_MODE
            ORDER BY Extracted_Date__c DESC NULLS LAST
            LIMIT 1
        ];
        if (facts.isEmpty() || facts[0].FICO_Score__c == null) { return null; }
        return facts[0].FICO_Score__c.intValue();
    }

    /**
     * Test seam: a Default Adverse_Action_Config__mdt record cannot be created by a
     * test (custom metadata is not DML-able) and this DE org cannot deploy CMDT
     * records, so tests inject the Config here to exercise the wiring. Null in prod.
     */
    @TestVisible private static AdverseActionService.Config configOverride;

    /** Map the Default Adverse_Action_Config__mdt record into the service Config. */
    private static AdverseActionService.Config loadConfig() {
        if (configOverride != null) { return configOverride; }
        AdverseActionService.Config c = new AdverseActionService.Config();
        List<Adverse_Action_Config__mdt> rows = [
            SELECT Creditor_Name__c, Creditor_Address__c, Oversight_Agency_Name__c,
                   Oversight_Agency_Address__c, ECOA_Notice__c, Reason_Limit__c, Notice_Window_Days__c
            FROM Adverse_Action_Config__mdt
            WHERE DeveloperName = 'Default'
            LIMIT 1
        ];
        if (rows.isEmpty()) { return c; }
        Adverse_Action_Config__mdt r = rows[0];
        c.creditorName = r.Creditor_Name__c;
        c.creditorAddress = r.Creditor_Address__c;
        c.agencyName = r.Oversight_Agency_Name__c;
        c.agencyAddress = r.Oversight_Agency_Address__c;
        c.ecoaNoticeTemplate = r.ECOA_Notice__c;
        c.reasonLimit = r.Reason_Limit__c == null ? null : r.Reason_Limit__c.intValue();
        c.noticeWindowDays = r.Notice_Window_Days__c == null ? null : r.Notice_Window_Days__c.intValue();
        return c;
    }

    private static Id safeId(String raw) {
        if (String.isBlank(raw)) { return null; }
        try {
            Id candidate = Id.valueOf(raw);
            return candidate.getSObjectType() == Decision_Event__c.SObjectType ? candidate : null;
        } catch (Exception e) {
            return null;
        }
    }

    private void deny(String message) {
        this.accessDenied = true;
        this.accessMessage = message;
    }

    private static String str(Object o) { return o == null ? '' : String.valueOf(o); }
}
