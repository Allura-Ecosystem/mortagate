/**
 * FactAssembler — Reads evidence for an audit case and reconstructs facts.
 *
 * Stage 2 of the 3-layer audit replay kernel.
 * Reads Evidence_Item__c records, builds Reconstructed_Fact__c records
 * with provenance chain. Does NOT persist — returns unsaved records
 * for review before commit.
 *
 * @group Audit Replay Kernel
 * @see DESIGN.md — Fact Reconstruction
 */
public with sharing class FactAssembler {

    private static final String PENDING = 'PENDING_EXTRACTION';

    /**
     * Reconstruct facts for an audit case from its evidence items.
     * Reads the original loan data via the Audit_Case__c and builds
     * Reconstructed_Fact__c records with source provenance.
     *
     * Returns unsaved records — caller decides when to persist.
     *
     * @param auditCaseId The Audit_Case__c to reconstruct facts for
     * @return List of Reconstructed_Fact__c (NOT yet inserted)
     */
    public static List<Reconstructed_Fact__c> reconstructFacts(Id auditCaseId) {
        // Query the audit case to get loan reference
        List<Audit_Case__c> cases = [
            SELECT Id, Loan_Application__c
            FROM Audit_Case__c
            WHERE Id = :auditCaseId
            WITH USER_MODE
            LIMIT 1
        ];

        if (cases.isEmpty()) {
            return new List<Reconstructed_Fact__c>();
        }

        String loanAppId = cases[0].Loan_Application__c;

        // Attempt to read real financial data from Loan_Application__c
        Map<String, String> loanValues = queryLoanValues(new Set<String>{ loanAppId });
        Map<String, String> valuesForLoan = extractValuesForLoan(loanValues, loanAppId);

        // Query evidence items for this audit case
        List<Evidence_Item__c> evidenceItems = [
            SELECT Id, Document_Type__c, Status__c
            FROM Evidence_Item__c
            WHERE Audit_Case__c = :auditCaseId
            WITH USER_MODE
        ];

        // Build a map of evidence by document type for provenance linking
        Map<String, Evidence_Item__c> evidenceByType = new Map<String, Evidence_Item__c>();
        for (Evidence_Item__c ei : evidenceItems) {
            evidenceByType.put(ei.Document_Type__c, ei);
        }

        List<Reconstructed_Fact__c> facts = new List<Reconstructed_Fact__c>();

        // DTI — sourced from bank statements or tax return
        facts.add(buildFact(auditCaseId, 'DTI', valuesForLoan.get('DTI'), evidenceByType,
            new List<String>{'Bank_Statement', 'Tax_Return'}));

        // Credit Score — sourced from credit report
        facts.add(buildFact(auditCaseId, 'Credit_Score', valuesForLoan.get('Credit_Score'), evidenceByType,
            new List<String>{'Credit_Report'}));

        // Annual Income — sourced from W2 or pay stub
        facts.add(buildFact(auditCaseId, 'Annual_Income', valuesForLoan.get('Annual_Income'), evidenceByType,
            new List<String>{'W2', 'Pay_Stub'}));

        // LTV — sourced from appraisal (no field on Loan_Application__c)
        facts.add(buildFact(auditCaseId, 'LTV', null, evidenceByType,
            new List<String>{'Appraisal'}));

        // Employment Duration — sourced from W2 or pay stub
        facts.add(buildFact(auditCaseId, 'Employment_Duration', valuesForLoan.get('Employment_Duration'), evidenceByType,
            new List<String>{'W2', 'Pay_Stub'}));

        // Loan Amount — sourced from loan docs
        facts.add(buildFact(auditCaseId, 'Loan_Amount', valuesForLoan.get('Loan_Amount'), evidenceByType,
            new List<String>{'Bank_Statement'}));

        return facts;
    }

    /**
     * Bulk reconstruct facts for multiple audit cases.
     * Single SOQL for cases, single SOQL for evidence, single SOQL for loans,
     * then in-memory assembly. No SOQL in loops.
     *
     * @param auditCaseIds Set of Audit_Case__c Ids
     * @return Map of Audit_Case__c Id to list of unsaved Reconstructed_Fact__c
     */
    public static Map<Id, List<Reconstructed_Fact__c>> reconstructFactsBulk(Set<Id> auditCaseIds) {
        // 1. Query all audit cases to get loan references
        Map<Id, String> loanIdByCaseId = new Map<Id, String>();
        Set<String> allLoanIds = new Set<String>();
        for (Audit_Case__c ac : [
            SELECT Id, Loan_Application__c
            FROM Audit_Case__c
            WHERE Id IN :auditCaseIds
            WITH USER_MODE
        ]) {
            loanIdByCaseId.put(ac.Id, ac.Loan_Application__c);
            if (String.isNotBlank(ac.Loan_Application__c)) {
                allLoanIds.add(ac.Loan_Application__c);
            }
        }

        // 2. Bulk query loan financial data (single SOQL, no loop)
        Map<String, String> loanValues = queryLoanValues(allLoanIds);

        // 3. Query all evidence in one SOQL
        Map<Id, List<Evidence_Item__c>> evidenceByCaseId = new Map<Id, List<Evidence_Item__c>>();
        for (Id caseId : auditCaseIds) {
            evidenceByCaseId.put(caseId, new List<Evidence_Item__c>());
        }

        for (Evidence_Item__c ei : [
            SELECT Id, Audit_Case__c, Document_Type__c, Status__c
            FROM Evidence_Item__c
            WHERE Audit_Case__c IN :auditCaseIds
            WITH USER_MODE
        ]) {
            evidenceByCaseId.get(ei.Audit_Case__c).add(ei);
        }

        // 4. Assemble facts in memory
        Map<Id, List<Reconstructed_Fact__c>> result = new Map<Id, List<Reconstructed_Fact__c>>();
        for (Id caseId : auditCaseIds) {
            Map<String, Evidence_Item__c> evidenceByType = new Map<String, Evidence_Item__c>();
            for (Evidence_Item__c ei : evidenceByCaseId.get(caseId)) {
                evidenceByType.put(ei.Document_Type__c, ei);
            }

            String loanId = loanIdByCaseId.get(caseId);
            Map<String, String> valuesForLoan = extractValuesForLoan(loanValues, loanId);

            List<Reconstructed_Fact__c> facts = new List<Reconstructed_Fact__c>();
            facts.add(buildFact(caseId, 'DTI', valuesForLoan.get('DTI'), evidenceByType,
                new List<String>{'Bank_Statement', 'Tax_Return'}));
            facts.add(buildFact(caseId, 'Credit_Score', valuesForLoan.get('Credit_Score'), evidenceByType,
                new List<String>{'Credit_Report'}));
            facts.add(buildFact(caseId, 'Annual_Income', valuesForLoan.get('Annual_Income'), evidenceByType,
                new List<String>{'W2', 'Pay_Stub'}));
            facts.add(buildFact(caseId, 'LTV', null, evidenceByType,
                new List<String>{'Appraisal'}));
            facts.add(buildFact(caseId, 'Employment_Duration', valuesForLoan.get('Employment_Duration'), evidenceByType,
                new List<String>{'W2', 'Pay_Stub'}));
            facts.add(buildFact(caseId, 'Loan_Amount', valuesForLoan.get('Loan_Amount'), evidenceByType,
                new List<String>{'Bank_Statement'}));
            result.put(caseId, facts);
        }

        return result;
    }

    /**
     * Create placeholder Evidence_Item__c records for required document types.
     * All start with Status='Missing'. Gives auditors a checklist.
     *
     * @param auditCaseId The Audit_Case__c to create evidence shell for
     * @return The inserted Evidence_Item__c records
     */
    public static List<Evidence_Item__c> createEvidenceShell(Id auditCaseId) {
        List<String> requiredTypes = new List<String>{
            'W2', 'Credit_Report', 'Bank_Statement', 'Appraisal', 'Pay_Stub'
        };
        List<Evidence_Item__c> shell = new List<Evidence_Item__c>();
        for (String docType : requiredTypes) {
            shell.add(new Evidence_Item__c(
                Audit_Case__c = auditCaseId,
                Document_Type__c = docType,
                Status__c = 'Missing'
            ));
        }
        insert shell;
        return shell;
    }

    // ---------------------------------------------------------------
    // Private helpers
    // ---------------------------------------------------------------

    /**
     * Query Loan_Application__c records for financial data.
     * Returns a flat map keyed as "loanId:FieldName" -> stringValue.
     * Uses dynamic SOQL so the class compiles even if Loan_Application__c
     * is not deployed to the target org.
     */
    private static Map<String, String> queryLoanValues(Set<String> loanIds) {
        Map<String, String> valueMap = new Map<String, String>();
        if (loanIds == null || loanIds.isEmpty()) {
            return valueMap;
        }

        try {
            // Dynamic SOQL — compiles without Loan_Application__c on the org.
            // FLS enforced via AccessLevel.USER_MODE (inline WITH USER_MODE is
            // not available on Database.query string form).
            String soql = 'SELECT Id, DTI__c, Credit_Score__c, Annual_Income__c, '
                + 'Employment_Duration_Years__c, Loan_Amount__c '
                + 'FROM Loan_Application__c '
                + 'WHERE Id IN :loanIds';
            List<SObject> loans = Database.query(soql, AccessLevel.USER_MODE);

            for (SObject loan : loans) {
                String lid = (String) loan.get('Id');
                Object dti = loan.get('DTI__c');
                Object credit = loan.get('Credit_Score__c');
                Object income = loan.get('Annual_Income__c');
                Object empDur = loan.get('Employment_Duration_Years__c');
                Object amount = loan.get('Loan_Amount__c');

                if (dti != null) { valueMap.put(lid + ':DTI', String.valueOf(dti)); }
                if (credit != null) { valueMap.put(lid + ':Credit_Score', String.valueOf(credit)); }
                if (income != null) { valueMap.put(lid + ':Annual_Income', String.valueOf(income)); }
                if (empDur != null) { valueMap.put(lid + ':Employment_Duration', String.valueOf(empDur)); }
                if (amount != null) { valueMap.put(lid + ':Loan_Amount', String.valueOf(amount)); }
            }
        } catch (Exception e) {
            // Loan_Application__c not deployed or Ids are invalid text —
            // all values remain PENDING_EXTRACTION via fallback
        }

        return valueMap;
    }

    /**
     * Extract per-fact values for a specific loan from the bulk map.
     */
    private static Map<String, String> extractValuesForLoan(Map<String, String> loanValues, String loanId) {
        Map<String, String> vals = new Map<String, String>();
        if (String.isBlank(loanId)) {
            return vals;
        }
        vals.put('DTI', loanValues.get(loanId + ':DTI'));
        vals.put('Credit_Score', loanValues.get(loanId + ':Credit_Score'));
        vals.put('Annual_Income', loanValues.get(loanId + ':Annual_Income'));
        vals.put('Employment_Duration', loanValues.get(loanId + ':Employment_Duration'));
        vals.put('Loan_Amount', loanValues.get(loanId + ':Loan_Amount'));
        return vals;
    }

    /**
     * Build a single Reconstructed_Fact__c with provenance.
     * Finds the best evidence source from the preferred document types.
     * If no evidence is available, marks the fact as unverifiable.
     * Sets Source_Evidence__c lookup for provenance chain (B2).
     */
    private static Reconstructed_Fact__c buildFact(
        Id auditCaseId,
        String factType,
        String value,
        Map<String, Evidence_Item__c> evidenceByType,
        List<String> preferredDocTypes
    ) {
        Reconstructed_Fact__c fact = new Reconstructed_Fact__c(
            Audit_Case__c = auditCaseId,
            Fact_Type__c  = factType,
            Value__c      = value != null ? value : PENDING
        );

        // Find the best available evidence source
        Evidence_Item__c source = null;
        for (String docType : preferredDocTypes) {
            if (evidenceByType.containsKey(docType)) {
                Evidence_Item__c candidate = evidenceByType.get(docType);
                if (candidate.Status__c == 'Available') {
                    source = candidate;
                    break;
                } else if (source == null) {
                    source = candidate; // Keep first match even if not Available
                }
            }
        }

        if (source == null || source.Status__c == 'Missing') {
            // No evidence available — fact is unverifiable
            fact.Value__c = 'UNVERIFIABLE';
        } else if (source.Status__c == 'Available') {
            // B2: Set Source_Evidence__c provenance lookup
            fact.Source_Evidence__c = source.Id;
        }

        return fact;
    }
}