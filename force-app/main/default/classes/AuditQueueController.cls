/**
 * AuditQueueController — read-only data source for the Audit Queue screen
 * (the c-audit-queue LWC). Surfaces the auditor work queue and the five
 * dashboard metric counts from Audit_Case__c.
 *
 * FLS/sharing: `with sharing` + AccessLevel.USER_MODE on every query, so the
 * queue can never show an auditor a case (or field) they cannot see.
 *
 * SOQL safety: bound bind variables only (no string-concatenated values),
 * a sort allowlist, and a hard row cap (MAX_LIMIT).
 *
 * @group Audit Queue
 */
public with sharing class AuditQueueController {

    @TestVisible private static final Integer DEFAULT_LIMIT = 100;
    @TestVisible private static final Integer MAX_LIMIT = 200;

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

        String orderField = SORT_ALLOWLIST.containsKey(f.sortBy)
            ? SORT_ALLOWLIST.get(f.sortBy)
            : 'Due_At__c';
        String direction = (f.sortDirection == 'desc') ? 'DESC' : 'ASC';

        // Sanitized Integer — safe to inline (no injection surface).
        Integer rowLimit = (f.pageSize != null && f.pageSize > 0)
            ? Math.min(f.pageSize, MAX_LIMIT)
            : DEFAULT_LIMIT;

        String soql =
            'SELECT Id, Name, Status__c, Risk_Tier__c, Product_Type__c, Branch__c, ' +
            'Loan_Amount__c, Borrower_Name_Snapshot__c, ' +
            'Original_Approver__c, Original_Approver__r.Name, ' +
            'Due_At__c, Auditor__c, ' +
            'Loan__r.LOS_Loan_Id__c, Loan__r.Borrower_Name__c, ' +
            'Loan__r.Approver_Name__c, Loan__r.Originating_Branch__c ' +
            'FROM Audit_Case__c ';
        if (!wheres.isEmpty()) {
            soql += 'WHERE ' + String.join(wheres, ' AND ') + ' ';
        }
        soql += 'ORDER BY ' + orderField + ' ' + direction + ' NULLS LAST LIMIT ' + rowLimit;

        List<Audit_Case__c> cases = Database.queryWithBinds(soql, binds, AccessLevel.USER_MODE);

        List<AuditCaseRow> rows = new List<AuditCaseRow>();
        for (Audit_Case__c ac : cases) {
            rows.add(toRow(ac, currentUserId));
        }
        return rows;
    }

    /**
     * Return the five dashboard metric counts.
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
        return m;
    }

    // ── Helpers ─────────────────────────────────────────────────────────

    private static Integer countOf(String soql, Map<String, Object> binds) {
        return Database.countQueryWithBinds(soql, binds, AccessLevel.USER_MODE);
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
        return r;
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
    }

    public class AuditMetrics {
        @AuraEnabled public Integer assignedToMe = 0;
        @AuraEnabled public Integer highRisk = 0;
        @AuraEnabled public Integer evidenceNeeded = 0;
        @AuraEnabled public Integer readyForSignoff = 0;
        @AuraEnabled public Integer slaAtRisk = 0;
    }
}
