/**
 * SeedDataLoader — Seeds the Sabir Sr. demo case and 4 queue-variety personas.
 *
 * Run via: sf apex run --target-org mortagate-de -f scripts/seed-data.apex
 *
 * Idempotent: deletes existing seed data (matched by Borrower_Name__c) before re-inserting.
 * All DML is bulkified — no DML inside loops.
 *
 * Picklist values verified against field-meta.xml as of 2026-06-14.
 *
 * NOTE on story-vs-schema mapping:
 *   - Story "Violation" -> Severity__c 'Hard_Decline' (schema picklist)
 *   - Story "Warning"   -> Severity__c 'Warning'
 *   - Story "Advisory"  -> Severity__c 'Info'
 *   - Story "Open"      -> Status__c 'In_Review' (no 'Open' in picklist)
 *   - Story "Jumbo"     -> Loan_Type__c 'Conventional' (Jumbo is conforming-plus Conventional)
 *   - Fact_Category 'Collateral' in story -> 'Asset' on Borrower_Snapshot__c (schema uses 'Asset')
 */
public with sharing class SeedDataLoader {

    private static final List<String> SEED_BORROWER_NAMES = new List<String>{
        'Sabir Asheed Sr.',
        'Maria Rodriguez',
        'James Chen',
        'Priya Patel',
        'Robert Williams'
    };

    /**
     * Entry point. Call from anonymous Apex: SeedDataLoader.loadAll();
     */
    public static void loadAll() {
        cleanExisting();

        // 1. Policy Version (needed before rules and audit cases)
        Policy_Version__c pv = buildPolicyVersion();
        insert pv;
        System.debug('Inserted Policy_Version__c: ' + pv.Id);

        // 2. Policy Rules (master-detail on Policy_Version__c)
        List<Policy_Rule__c> rules = buildPolicyRules(pv.Id);
        insert rules;
        System.debug('Inserted ' + rules.size() + ' Policy_Rule__c records');

        // 3. Loans (all 5 personas)
        List<Loan__c> loans = buildLoans();
        insert loans;
        System.debug('Inserted ' + loans.size() + ' Loan__c records');

        // Build a map by borrower name for linking
        Map<String, Loan__c> loanByBorrower = new Map<String, Loan__c>();
        for (Loan__c l : loans) {
            loanByBorrower.put(l.Borrower_Name__c, l);
        }

        // 4. Audit Cases (all 5)
        List<Audit_Case__c> cases = buildAuditCases(loanByBorrower, pv.Id);
        insert cases;
        System.debug('Inserted ' + cases.size() + ' Audit_Case__c records');

        // Find the Sabir Sr. case for child records
        Audit_Case__c sabirCase = null;
        for (Audit_Case__c ac : cases) {
            if (ac.Borrower_Name_Snapshot__c == 'Sabir Asheed Sr.') {
                sabirCase = ac;
                break;
            }
        }

        // 5. Borrower Snapshots (Sabir Sr. only)
        List<Borrower_Snapshot__c> snapshots = buildBorrowerSnapshots(sabirCase.Id);
        insert snapshots;
        System.debug('Inserted ' + snapshots.size() + ' Borrower_Snapshot__c records');

        // 6. Evidence Items (Sabir Sr. only)
        List<Evidence_Item__c> evidence = buildEvidenceItems(sabirCase.Id);
        insert evidence;
        System.debug('Inserted ' + evidence.size() + ' Evidence_Item__c records');

        System.debug('SeedDataLoader.loadAll() complete.');
    }

    /**
     * Removes previously seeded data to allow re-runs.
     * Deletes in reverse dependency order.
     */
    private static void cleanExisting() {
        // Find existing loans by borrower name
        List<Loan__c> existingLoans = [
            SELECT Id FROM Loan__c
            WHERE Borrower_Name__c IN :SEED_BORROWER_NAMES
        ];
        Set<Id> loanIds = new Set<Id>();
        for (Loan__c l : existingLoans) {
            loanIds.add(l.Id);
        }

        if (loanIds.isEmpty()) {
            System.debug('No existing seed data to clean.');
            return;
        }

        // Find audit cases linked to those loans
        List<Audit_Case__c> existingCases = [
            SELECT Id FROM Audit_Case__c
            WHERE Loan__c IN :loanIds
        ];
        Set<Id> caseIds = new Set<Id>();
        for (Audit_Case__c ac : existingCases) {
            caseIds.add(ac.Id);
        }

        // Delete children first (order matters for lookup integrity)
        if (!caseIds.isEmpty()) {
            delete [SELECT Id FROM Evidence_Item__c WHERE Audit_Case__c IN :caseIds];
            delete [SELECT Id FROM Borrower_Snapshot__c WHERE Audit_Case__c IN :caseIds];
            delete existingCases;
        }

        delete existingLoans;

        // Clean policy version by label
        List<Policy_Version__c> existingPV = [
            SELECT Id FROM Policy_Version__c
            WHERE Version_Label__c = 'Q1 2025 Conventional'
        ];
        if (!existingPV.isEmpty()) {
            // Policy_Rule__c is master-detail, so cascade-deletes with parent
            delete existingPV;
        }

        System.debug('Cleaned existing seed data.');
    }

    // ─── Builders ────────────────────────────────────────────────────────

    private static Policy_Version__c buildPolicyVersion() {
        return new Policy_Version__c(
            Version_Label__c     = 'Q1 2025 Conventional',
            Policy_Type__c       = 'Conventional',
            Effective_Date__c    = Date.newInstance(2025, 1, 1),
            Is_Active__c         = true,
            Version_Number__c    = 1
        );
    }

    private static List<Policy_Rule__c> buildPolicyRules(Id pvId) {
        List<Policy_Rule__c> rules = new List<Policy_Rule__c>();

        // Story spec: 10 rules with (Rule_Code, Threshold, Operator, Rule_Category, Severity)
        // Mapping story severity: Violation->Hard_Decline, Warning->Warning, Advisory->Info

        rules.add(makeRule(pvId, 'DTI_MAX',    'Maximum DTI Ratio',       43,    'LTE', 'Income',      'Hard_Decline', 'DTI_Ratio__c',    1));
        rules.add(makeRule(pvId, 'FICO_MIN',   'Minimum FICO Score',      620,   'GTE', 'Credit',      'Hard_Decline', 'FICO_Score__c',   2));
        rules.add(makeRule(pvId, 'LTV_MAX',    'Maximum LTV Ratio',       80,    'LTE', 'Collateral',  'Hard_Decline', 'LTV_Ratio__c',    3));
        rules.add(makeRule(pvId, 'INCOME_MIN', 'Minimum Annual Income',   30000, 'GTE', 'Income',      'Warning',      'Annual_Income__c',4));
        rules.add(makeRule(pvId, 'EMPLOY_MIN', 'Minimum Employment',      12,    'GTE', 'Employment',  'Warning',      'Employment_Months__c', 5));
        rules.add(makeRule(pvId, 'ASSET_MIN',  'Minimum Asset Value',     100000,'GTE', 'Collateral',  'Info',         'Asset_Value__c',  6));
        rules.add(makeRule(pvId, 'DTI_WARN',   'DTI Warning Threshold',   40,    'LTE', 'Income',      'Info',         'DTI_Ratio__c',    7));
        rules.add(makeRule(pvId, 'FICO_PREF',  'Preferred FICO Score',    680,   'GTE', 'Credit',      'Info',         'FICO_Score__c',   8));
        rules.add(makeRule(pvId, 'LTV_PREF',   'Preferred LTV Ratio',     90,    'LTE', 'Collateral',  'Info',         'LTV_Ratio__c',    9));
        rules.add(makeRule(pvId, 'DEBT_MAX',   'Maximum Monthly Debt',    5000,  'LTE', 'Debt',        'Warning',      'Monthly_Debt__c', 10));

        return rules;
    }

    private static Policy_Rule__c makeRule(
        Id pvId, String code, String label, Decimal threshold,
        String op, String category, String severity, String factField, Integer sortOrder
    ) {
        return new Policy_Rule__c(
            Policy_Version__c    = pvId,
            Rule_Code__c         = code,
            Rule_Label__c        = label,
            Threshold_Value__c   = threshold,
            Operator__c          = op,
            Rule_Category__c     = category,
            Severity__c          = severity,
            Fact_Field__c        = factField
        );
    }

    private static List<Loan__c> buildLoans() {
        List<Loan__c> loans = new List<Loan__c>();

        // Sabir Asheed Sr. — primary demo case
        loans.add(new Loan__c(
            Borrower_Name__c       = 'Sabir Asheed Sr.',
            Loan_Amount__c         = 380000,
            Loan_Type__c           = 'Conventional',
            Purpose__c             = 'Purchase',
            DTI_At_Approval__c = 44.8,
            FICO_At_Approval__c    = 710,
            LTV_At_Approval__c     = 80,
            Annual_Income__c       = 95000,
            Property_Value__c      = 475000,
            Approval_Date__c       = Date.newInstance(2025, 3, 15),
            Originating_Branch__c  = 'Durham Main',
            Approver_Name__c       = 'Janet Chen'
        ));

        // Maria Rodriguez — FHA
        loans.add(new Loan__c(
            Borrower_Name__c       = 'Maria Rodriguez',
            Loan_Amount__c         = 275000,
            Loan_Type__c           = 'FHA',
            Purpose__c             = 'Purchase',
            DTI_At_Approval__c = 38,
            FICO_At_Approval__c    = 680,
            LTV_At_Approval__c     = 96.5,
            Annual_Income__c       = 72000,
            Property_Value__c      = 285000,
            Approval_Date__c       = Date.newInstance(2025, 2, 20),
            Originating_Branch__c  = 'Raleigh South',
            Approver_Name__c       = 'Tom Park'
        ));

        // James Chen — Jumbo (stored as Conventional; Jumbo is not a picklist value)
        loans.add(new Loan__c(
            Borrower_Name__c       = 'James Chen',
            Loan_Amount__c         = 520000,
            Loan_Type__c           = 'Conventional',
            Purpose__c             = 'Purchase',
            DTI_At_Approval__c = 32,
            FICO_At_Approval__c    = 780,
            LTV_At_Approval__c     = 70,
            Annual_Income__c       = 185000,
            Property_Value__c      = 743000,
            Approval_Date__c       = Date.newInstance(2025, 3, 1),
            Originating_Branch__c  = 'Chapel Hill',
            Approver_Name__c       = 'Lisa Huang'
        ));

        // Priya Patel — Conventional
        loans.add(new Loan__c(
            Borrower_Name__c       = 'Priya Patel',
            Loan_Amount__c         = 190000,
            Loan_Type__c           = 'Conventional',
            Purpose__c             = 'Refinance',
            DTI_At_Approval__c = 41,
            FICO_At_Approval__c    = 640,
            LTV_At_Approval__c     = 85,
            Annual_Income__c       = 58000,
            Property_Value__c      = 224000,
            Approval_Date__c       = Date.newInstance(2025, 1, 28),
            Originating_Branch__c  = 'Durham Main',
            Approver_Name__c       = 'Janet Chen'
        ));

        // Robert Williams — VA
        loans.add(new Loan__c(
            Borrower_Name__c       = 'Robert Williams',
            Loan_Amount__c         = 310000,
            Loan_Type__c           = 'VA',
            Purpose__c             = 'Purchase',
            DTI_At_Approval__c = 35,
            FICO_At_Approval__c    = 720,
            LTV_At_Approval__c     = 100,
            Annual_Income__c       = 88000,
            Property_Value__c      = 310000,
            Approval_Date__c       = Date.newInstance(2025, 3, 10),
            Originating_Branch__c  = 'Fayetteville',
            Approver_Name__c       = 'Mark Davis'
        ));

        return loans;
    }

    private static List<Audit_Case__c> buildAuditCases(Map<String, Loan__c> loanByBorrower, Id pvId) {
        List<Audit_Case__c> cases = new List<Audit_Case__c>();

        // Sabir Sr. — In_Review, High, Full
        Loan__c sabirLoan = loanByBorrower.get('Sabir Asheed Sr.');
        cases.add(new Audit_Case__c(
            Loan__c                  = sabirLoan.Id,
            Status__c                = 'In_Review',
            Risk_Tier__c             = 'High',
            Scope__c                 = 'Full',
            Borrower_Name_Snapshot__c = 'Sabir Asheed Sr.',
            Loan_Amount__c           = 380000,
            Branch__c                = 'Durham Main',
            Original_Approver__c     = 'Janet Chen',
            Product_Type__c          = 'Conventional',
            Sampling_Reason__c       = 'DTI exceeds 43% threshold',
            Policy_Version__c        = pvId,
            Sampled_At__c            = Datetime.now()
        ));

        // Maria Rodriguez — In_Review (closest to "Open"), Medium
        Loan__c mariaLoan = loanByBorrower.get('Maria Rodriguez');
        cases.add(new Audit_Case__c(
            Loan__c                  = mariaLoan.Id,
            Status__c                = 'In_Review',
            Risk_Tier__c             = 'Medium',
            Scope__c                 = 'Full',
            Borrower_Name_Snapshot__c = 'Maria Rodriguez',
            Loan_Amount__c           = 275000,
            Branch__c                = 'Raleigh South',
            Original_Approver__c     = 'Tom Park',
            Product_Type__c          = 'FHA',
            Sampling_Reason__c       = 'Random FHA sample',
            Sampled_At__c            = Datetime.now()
        ));

        // James Chen — In_Review, Low
        Loan__c jamesLoan = loanByBorrower.get('James Chen');
        cases.add(new Audit_Case__c(
            Loan__c                  = jamesLoan.Id,
            Status__c                = 'In_Review',
            Risk_Tier__c             = 'Low',
            Scope__c                 = 'Targeted',
            Borrower_Name_Snapshot__c = 'James Chen',
            Loan_Amount__c           = 520000,
            Branch__c                = 'Chapel Hill',
            Original_Approver__c     = 'Lisa Huang',
            Product_Type__c          = 'Conventional',
            Sampling_Reason__c       = 'Jumbo threshold exceeded',
            Sampled_At__c            = Datetime.now()
        ));

        // Priya Patel — In_Review, High
        Loan__c priyaLoan = loanByBorrower.get('Priya Patel');
        cases.add(new Audit_Case__c(
            Loan__c                  = priyaLoan.Id,
            Status__c                = 'In_Review',
            Risk_Tier__c             = 'High',
            Scope__c                 = 'Full',
            Borrower_Name_Snapshot__c = 'Priya Patel',
            Loan_Amount__c           = 190000,
            Branch__c                = 'Durham Main',
            Original_Approver__c     = 'Janet Chen',
            Product_Type__c          = 'Conventional',
            Sampling_Reason__c       = 'Low FICO with elevated DTI',
            Sampled_At__c            = Datetime.now()
        ));

        // Robert Williams — Ready_for_Signoff, Medium
        Loan__c robertLoan = loanByBorrower.get('Robert Williams');
        cases.add(new Audit_Case__c(
            Loan__c                  = robertLoan.Id,
            Status__c                = 'Ready_for_Signoff',
            Risk_Tier__c             = 'Medium',
            Scope__c                 = 'Full',
            Borrower_Name_Snapshot__c = 'Robert Williams',
            Loan_Amount__c           = 310000,
            Branch__c                = 'Fayetteville',
            Original_Approver__c     = 'Mark Davis',
            Product_Type__c          = 'VA',
            Sampling_Reason__c       = 'VA 100% LTV review',
            Sampled_At__c            = Datetime.now()
        ));

        return cases;
    }

    private static List<Borrower_Snapshot__c> buildBorrowerSnapshots(Id caseId) {
        List<Borrower_Snapshot__c> snaps = new List<Borrower_Snapshot__c>();

        // Income snapshot
        snaps.add(new Borrower_Snapshot__c(
            Audit_Case__c        = caseId,
            Fact_Category__c     = 'Income',
            DTI_Ratio__c         = 44.8,
            Annual_Income__c     = 95000,
            Monthly_Income__c    = 7916.67,
            Monthly_Debt__c      = 3546.67,
            Employment_Months__c = 36,
            Confidence__c        = 95.0
        ));

        // Credit snapshot
        snaps.add(new Borrower_Snapshot__c(
            Audit_Case__c        = caseId,
            Fact_Category__c     = 'Credit',
            FICO_Score__c        = 710,
            Confidence__c        = 98.0
        ));

        // Collateral snapshot (Fact_Category = 'Asset' per schema)
        snaps.add(new Borrower_Snapshot__c(
            Audit_Case__c        = caseId,
            Fact_Category__c     = 'Asset',
            LTV_Ratio__c         = 80,
            Asset_Value__c       = 475000,
            Confidence__c        = 92.0
        ));

        return snaps;
    }

    private static List<Evidence_Item__c> buildEvidenceItems(Id caseId) {
        List<Evidence_Item__c> items = new List<Evidence_Item__c>();

        items.add(new Evidence_Item__c(
            Audit_Case__c   = caseId,
            Document_Type__c = 'Pay_Stub',
            Status__c        = 'Linked',
            Required__c      = true
        ));

        items.add(new Evidence_Item__c(
            Audit_Case__c   = caseId,
            Document_Type__c = 'W2',
            Status__c        = 'Linked',
            Required__c      = true
        ));

        items.add(new Evidence_Item__c(
            Audit_Case__c   = caseId,
            Document_Type__c = 'Credit_Report',
            Status__c        = 'Linked',
            Required__c      = true
        ));

        items.add(new Evidence_Item__c(
            Audit_Case__c   = caseId,
            Document_Type__c = 'Appraisal',
            Status__c        = 'Missing',
            Required__c      = true
        ));

        items.add(new Evidence_Item__c(
            Audit_Case__c   = caseId,
            Document_Type__c = 'Bank_Statement',
            Status__c        = 'Linked',
            Required__c      = true
        ));

        return items;
    }
}
