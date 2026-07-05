/**
 * AuditQueueController — read-only data source for the Audit Queue screen
 * (the c-audit-queue LWC). Surfaces the auditor work queue and the five
 * dashboard metric counts from Audit_Case__c (five workload counts plus the
 * Fannie Mae 90-day QC-window at-risk count).
 *
 * FLS/sharing: `with sharing` + AccessLevel.USER_MODE on every query (via the
 * shared AuditSoql helper), so the queue can never show an auditor a case (or
 * field) they cannot see.
 *
 * SOQL safety: bound bind variables only (no string-concatenated values),
 * a sort allowlist, and a hard row cap (MAX_LIMIT) — all enforced through
 * AuditSoql so the posture matches every other audit-UI controller.
 *
 * @group Audit Queue
 */
public with sharing class AuditQueueController {

    @TestVisible private static final Integer DEFAULT_LIMIT = 100;

    // ── QC compliance window ────────────────────────────────────────────
    // Fannie Mae Selling Guide (D1-3-06) requires post-closing QC review to be
    // COMPLETED within 90 days of loan closing. Loan__c carries no
    // Closing_Date__c (see DATA-DICTIONARY), so the 90-day clock anchors on
    // Loan__r.Approval_Date__c — the only durable origination date on the audit
    // loan snapshot. No new field is introduced; the anchor is a documented
    // proxy. "At risk" is the last two weeks of that window.
    @TestVisible private static final Integer QC_WINDOW_DAYS = 90;
    @TestVisible private static final Integer QC_AT_RISK_DAYS = 14;

    // Allowlist: external sort key -> SObject field. Anything else is rejected.
    private static final Map<String, String> SORT_ALLOWLIST = new Map<String, String>{
        'risk'     => 'Risk_Tier__c',
        'due'      => 'Due_At__c',
        'status'   => 'Status__c',
        'amount'   => 'Loan_Amount__c'
    };

    // ── Public API ──────────────────────────────────────────────────────

    /**
     * Return the filtered, sorted queue rows.
     * @param filters serialized AuditQueueFilters (all members optional)
     */
    @AuraEnabled(cacheable=true)
    public static List<AuditCaseRow> getQueue(AuditQueueFilters filters) {
        AuditQueueFilters f = (filters == null) ? new AuditQueueFilters() : filters;
        Id currentUserId = UserInfo.getUserId();

        List<String> wheres = new List<String>();
        Map<String, Object> binds = new Map<String, Object>();

        if (String.isNotBlank(f.status)) {
            wheres.add('Status__c = :status');
            binds.put('status', f.status);
        }
        if (String.isNotBlank(f.productType)) {
            wheres.add('Product_Type__c = :productType');
            binds.put('productType', f.productType);
        }
        if (String.isNotBlank(f.branch)) {
            wheres.add('Branch__c = :branch');
            binds.put('branch', f.branch);
        }
        if (String.isNotBlank(f.approver)) {
            wheres.add('Original_Approver__c = :approver');
            binds.put('approver', f.approver);
        }
        if (String.isNotBlank(f.riskTier)) {
            wheres.add('Risk_Tier__c = :riskTier');
            binds.put('riskTier', f.riskTier);
        }
        if (String.isNotBlank(f.samplingReason)) {
            wheres.add('Sampling_Reason__c = :samplingReason');
            binds.put('samplingReason', f.samplingReason);
        }
        if (f.myCasesOnly == true) {
            wheres.add('Auditor__c = :currentUserId');
            binds.put('currentUserId', currentUserId);
        }

        String orderField = AuditSoql.resolveSortField(SORT_ALLOWLIST, f.sortBy, 'Due_At__c');
        String direction = AuditSoql.resolveDirection(f.sortDirection);

        // Sanitized Integer — safe to inline (no injection surface).
        Integer rowLimit = AuditSoql.resolveLimit(f.pageSize, DEFAULT_LIMIT);

        String soql =
            'SELECT Id, Name, Status__c, Risk_Tier__c, Product_Type__c, Branch__c, ' +
            'Loan_Amount__c, Borrower_Name_Snapshot__c, ' +
            'Original_Approver__c, Original_Approver__r.Name, ' +
            'Due_At__c, Auditor__c, ' +
            'Loan__r.LOS_Loan_Id__c, Loan__r.Borrower_Name__c, ' +
            'Loan__r.Approver_Name__c, Loan__r.Originating_Branch__c, ' +
            'Loan__r.Approval_Date__c ' +
            'FROM Audit_Case__c ';
        if (!wheres.isEmpty()) {
            soql += 'WHERE ' + String.join(wheres, ' AND ') + ' ';
        }
        soql += 'ORDER BY ' + orderField + ' ' + direction + ' NULLS LAST LIMIT ' + rowLimit;

        List<Audit_Case__c> cases = (List<Audit_Case__c>) AuditSoql.query(soql, binds);

        List<AuditCaseRow> rows = new List<AuditCaseRow>();
        for (Audit_Case__c ac : cases) {
            rows.add(toRow(ac, currentUserId));
        }
        return rows;
    }

    /**
     * Return the six dashboard metric counts.
     */
    @AuraEnabled(cacheable=true)
    public static AuditMetrics getMetrics() {
        Id currentUserId = UserInfo.getUserId();
        Datetime slaHorizon = Datetime.now().addDays(3);

        AuditMetrics m = new AuditMetrics();
        m.assignedToMe = countOf(
            'SELECT COUNT() FROM Audit_Case__c WHERE Auditor__c = :uid AND Status__c != :closed',
            new Map<String, Object>{ 'uid' => currentUserId, 'closed' => 'Closed' });
        m.highRisk = countOf(
            'SELECT COUNT() FROM Audit_Case__c WHERE Risk_Tier__c = :tier AND Status__c != :closed',
            new Map<String, Object>{ 'tier' => 'High', 'closed' => 'Closed' });
        m.evidenceNeeded = countOf(
            'SELECT COUNT() FROM Audit_Case__c WHERE Status__c = :st',
            new Map<String, Object>{ 'st' => 'Evidence_Needed' });
        m.readyForSignoff = countOf(
            'SELECT COUNT() FROM Audit_Case__c WHERE Status__c = :st',
            new Map<String, Object>{ 'st' => 'Ready_for_Signoff' });
        m.slaAtRisk = countOf(
            'SELECT COUNT() FROM Audit_Case__c WHERE Status__c != :closed ' +
            'AND Due_At__c != null AND Due_At__c <= :horizon',
            new Map<String, Object>{ 'closed' => 'Closed', 'horizon' => slaHorizon });

        // QC window at risk: open cases with 0 < daysLeft <= QC_AT_RISK_DAYS.
        //   daysLeft = QC_WINDOW_DAYS - (today - anchor)
        //   daysLeft > 0                 ⇢ anchor  >  today - 90  (window not blown)
        //   daysLeft <= QC_AT_RISK_DAYS  ⇢ anchor  <= today - 76  (final two weeks)
        // Expressed as parent-field date bounds so the count stays a single
        // aggregate query (no per-row math, USER_MODE via AuditSoql.count).
        Date qcFloor = Date.today().addDays(-QC_WINDOW_DAYS);
        Date qcCeil = Date.today().addDays(-(QC_WINDOW_DAYS - QC_AT_RISK_DAYS));
        m.qcWindowAtRisk = countOf(
            'SELECT COUNT() FROM Audit_Case__c WHERE Status__c != :closed ' +
            'AND Loan__r.Approval_Date__c != null ' +
            'AND Loan__r.Approval_Date__c > :qcFloor ' +
            'AND Loan__r.Approval_Date__c <= :qcCeil',
            new Map<String, Object>{ 'closed' => 'Closed', 'qcFloor' => qcFloor, 'qcCeil' => qcCeil });
        return m;
    }

    // ── Helpers ─────────────────────────────────────────────────────────

    private static Integer countOf(String soql, Map<String, Object> binds) {
        return AuditSoql.count(soql, binds);
    }

    private static AuditCaseRow toRow(Audit_Case__c ac, Id currentUserId) {
        AuditCaseRow r = new AuditCaseRow();
        r.recordId = ac.Id;
        r.caseNumber = ac.Name;
        r.loanNumber = (ac.Loan__r != null) ? ac.Loan__r.LOS_Loan_Id__c : null;
        r.productType = ac.Product_Type__c;
        r.borrowerName = String.isNotBlank(ac.Borrower_Name_Snapshot__c)
            ? ac.Borrower_Name_Snapshot__c
            : (ac.Loan__r != null ? ac.Loan__r.Borrower_Name__c : null);
        r.loanAmount = ac.Loan_Amount__c;
        r.branch = String.isNotBlank(ac.Branch__c)
            ? ac.Branch__c
            : (ac.Loan__r != null ? ac.Loan__r.Originating_Branch__c : null);
        r.riskTier = ac.Risk_Tier__c;
        r.statusApi = ac.Status__c;
        r.status = (ac.Status__c == null) ? null : ac.Status__c.replace('_', ' ');
        r.approverName = (ac.Original_Approver__r != null)
            ? ac.Original_Approver__r.Name
            : (ac.Loan__r != null ? ac.Loan__r.Approver_Name__c : null);
        r.slaDueAt = ac.Due_At__c;
        r.assignedToCurrentUser = (ac.Auditor__c == currentUserId);
        applySla(r, ac);
        applyQcWindow(r, ac);
        return r;
    }

    /**
     * Derive days remaining in the 90-day Fannie Mae QC window from the anchor
     * date (Loan__r.Approval_Date__c). Negative = window already blown. Closed
     * cases and cases with no anchor date carry null (window not applicable /
     * unknown) so the UI renders a neutral placeholder rather than a false clock.
     */
    private static void applyQcWindow(AuditCaseRow r, Audit_Case__c ac) {
        if (ac.Status__c == 'Closed') {
            r.qcWindowDaysLeft = null; // QC review complete — clock retired
            return;
        }
        Date anchor = (ac.Loan__r == null) ? null : ac.Loan__r.Approval_Date__c;
        if (anchor == null) {
            r.qcWindowDaysLeft = null;
            return;
        }
        Integer daysSince = anchor.daysBetween(Date.today());
        r.qcWindowDaysLeft = QC_WINDOW_DAYS - daysSince;
    }

    /**
     * Derive the SLA chip label + tone. Closed cases read "Met"; open cases
     * read Overdue / Due today / Nd relative to Due_At__c.
     */
    private static void applySla(AuditCaseRow r, Audit_Case__c ac) {
        if (ac.Status__c == 'Closed') {
            r.slaLabel = 'Met';
            r.slaTone = 'met';
            return;
        }
        if (ac.Due_At__c == null) {
            r.slaLabel = '';
            r.slaTone = 'none';
            return;
        }
        Integer days = Date.today().daysBetween(ac.Due_At__c.date());
        if (days < 0) {
            r.slaLabel = 'Overdue ' + Math.abs(days) + 'd';
            r.slaTone = 'overdue';
        } else if (days == 0) {
            r.slaLabel = 'Due today';
            r.slaTone = 'soon';
        } else {
            r.slaLabel = days + 'd';
            r.slaTone = (days <= 3) ? 'soon' : 'ok';
        }
    }

    // ── DTOs ────────────────────────────────────────────────────────────

    public class AuditQueueFilters {
        @AuraEnabled public String status;
        @AuraEnabled public String productType;
        @AuraEnabled public String branch;
        @AuraEnabled public String approver;
        @AuraEnabled public String riskTier;
        @AuraEnabled public String samplingReason;
        @AuraEnabled public Boolean myCasesOnly;
        @AuraEnabled public String sortBy;        // allowlisted key: risk|due|status|amount
        @AuraEnabled public String sortDirection; // asc|desc
        @AuraEnabled public Integer pageSize;
    }

    public class AuditCaseRow {
        @AuraEnabled public Id recordId;
        @AuraEnabled public String caseNumber;
        @AuraEnabled public String loanNumber;
        @AuraEnabled public String productType;
        @AuraEnabled public String borrowerName;
        @AuraEnabled public Decimal loanAmount;
        @AuraEnabled public String branch;
        @AuraEnabled public String riskTier;
        @AuraEnabled public String status;     // display label
        @AuraEnabled public String statusApi;  // raw picklist value
        @AuraEnabled public String approverName;
        @AuraEnabled public Datetime slaDueAt;
        @AuraEnabled public String slaLabel;
        @AuraEnabled public String slaTone;    // overdue|soon|ok|met|none
        @AuraEnabled public Boolean assignedToCurrentUser;
        // Days remaining in the 90-day Fannie Mae QC window (anchor =
        // Loan__r.Approval_Date__c). Negative = window exceeded; null = n/a
        // (Closed or no anchor date). UI tone is derived client-side.
        @AuraEnabled public Integer qcWindowDaysLeft;
    }

    public class AuditMetrics {
        @AuraEnabled public Integer assignedToMe = 0;
        @AuraEnabled public Integer highRisk = 0;
        @AuraEnabled public Integer evidenceNeeded = 0;
        @AuraEnabled public Integer readyForSignoff = 0;
        @AuraEnabled public Integer slaAtRisk = 0;
        @AuraEnabled public Integer qcWindowAtRisk = 0;
    }
}
