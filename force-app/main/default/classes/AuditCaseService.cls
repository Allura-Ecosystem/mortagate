/**
 * AuditCaseService — Manages audit case lifecycle.
 *
 * Handles case creation from approved loans, auditor assignment
 * (with self-audit prevention), and queue retrieval.
 *
 * @group Audit Case Management
 * @see DESIGN.md — Audit Case State Machine
 */
public with sharing class AuditCaseService {

    public class SelfAuditException extends Exception {}

    /**
     * Create an audit case from an approved loan.
     *
     * @param loanApplicationId   The original Loan_Application__c Id (stored as Text(18))
     * @param samplingReason      Why this loan was selected (Random, Risk_Based, Targeted, Ad_Hoc)
     * @param originalApproverId  The User Id who approved the original loan
     * @param approvalTimestamp   When the original loan was approved
     * @return The created Audit_Case__c with Id populated
     */
    public static Audit_Case__c createFromLoan(
        String loanApplicationId,
        String samplingReason,
        Id originalApproverId,
        Datetime approvalTimestamp
    ) {
        // Auto-select historical policy version BEFORE insert
        String policyId = PolicyVersionSelector.selectByApprovalDate(approvalTimestamp);

        Audit_Case__c auditCase = new Audit_Case__c(
            Loan_Application__c   = loanApplicationId,
            Sampling_Reason__c    = samplingReason,
            Original_Approver__c  = originalApproverId,
            Approval_Timestamp__c = approvalTimestamp,
            Status__c             = 'Created'
        );
        if (policyId != null) {
            auditCase.Policy_Version__c = policyId;
        }
        insert auditCase;

        AuditEventService.logEvent(
            auditCase.Id,
            'Case_Created',
            UserInfo.getUserId(),
            JSON.serialize(new Map<String, Object>{
                'loanApplicationId' => loanApplicationId,
                'samplingReason' => samplingReason
            }),
            null
        );

        // Auto-populate evidence shell (needs the case Id)
        FactAssembler.createEvidenceShell(auditCase.Id);

        return auditCase;
    }

    /**
     * Bulk create audit cases from approved loans.
     * Single DML for cases, single DML for events.
     *
     * @param cases List of Audit_Case__c records to insert (Status__c will be set to Created)
     * @return The inserted cases with Ids populated
     */
    public static List<Audit_Case__c> createFromLoans(List<Audit_Case__c> cases) {
        for (Audit_Case__c c : cases) {
            c.Status__c = 'Created';
        }
        insert cases;

        List<Audit_Event__c> events = new List<Audit_Event__c>();
        String actor = UserInfo.getUserId();
        Datetime now = Datetime.now();
        for (Audit_Case__c c : cases) {
            events.add(new Audit_Event__c(
                Audit_Case__c = c.Id,
                Event_Type__c = 'Case_Created',
                Actor__c = actor,
                Timestamp__c = now,
                Payload__c = JSON.serialize(new Map<String, Object>{
                    'samplingReason' => c.Sampling_Reason__c
                })
            ));
        }
        AuditEventService.logEvents(events);

        // Bulk auto-select historical policy versions (no SOQL in loop)
        // Collect distinct approval dates, query matching policies once, then map
        Set<Date> approvalDates = new Set<Date>();
        for (Audit_Case__c c : cases) {
            if (c.Approval_Timestamp__c != null) {
                approvalDates.add(c.Approval_Timestamp__c.date());
            }
        }

        // Query all candidate policy versions in one go
        List<Policy_Rule_Version__c> allVersions = [
            SELECT Id, Effective_Date__c
            FROM Policy_Rule_Version__c
            WHERE Status__c IN ('Active', 'Superseded')
            WITH USER_MODE
            ORDER BY Effective_Date__c DESC
        ];

        // Fallback: current active
        String fallbackPolicyId = PolicyVersionSelector.selectCurrentActive();

        // Build date-to-policy map: for each approval date, find the best match
        Map<Date, String> dateToPolicyId = new Map<Date, String>();
        for (Date approvalDate : approvalDates) {
            String bestMatch = null;
            for (Policy_Rule_Version__c pv : allVersions) {
                if (pv.Effective_Date__c <= approvalDate) {
                    bestMatch = String.valueOf(pv.Id);
                    break; // Already ordered DESC, first match is the best
                }
            }
            dateToPolicyId.put(approvalDate, bestMatch != null ? bestMatch : fallbackPolicyId);
        }

        // Apply policy versions and collect cases to update
        List<Audit_Case__c> casesToUpdate = new List<Audit_Case__c>();
        for (Audit_Case__c c : cases) {
            String policyId;
            if (c.Approval_Timestamp__c != null) {
                policyId = dateToPolicyId.get(c.Approval_Timestamp__c.date());
            } else {
                policyId = fallbackPolicyId;
            }
            if (policyId != null) {
                casesToUpdate.add(new Audit_Case__c(
                    Id = c.Id,
                    Policy_Version__c = policyId
                ));
                c.Policy_Version__c = policyId;
            }
        }
        if (!casesToUpdate.isEmpty()) {
            update casesToUpdate;
        }

        // Bulk auto-populate evidence shells (single DML)
        List<String> requiredTypes = new List<String>{
            'W2', 'Credit_Report', 'Bank_Statement', 'Appraisal', 'Pay_Stub'
        };
        List<Evidence_Item__c> allShells = new List<Evidence_Item__c>();
        for (Audit_Case__c c : cases) {
            for (String docType : requiredTypes) {
                allShells.add(new Evidence_Item__c(
                    Audit_Case__c = c.Id,
                    Document_Type__c = docType,
                    Status__c = 'Missing'
                ));
            }
        }
        if (!allShells.isEmpty()) {
            insert allShells;
        }

        return cases;
    }

    /**
     * Assign a case to an auditor.
     * Validates self-audit prevention: the auditor must not be the original approver.
     *
     * @param auditCaseId The Audit_Case__c to assign
     * @param auditorId   The User Id of the assigned auditor
     * @return The updated Audit_Case__c
     * @throws SelfAuditException if auditor is the original approver
     */
    public static Audit_Case__c assignCase(Id auditCaseId, Id auditorId) {
        List<Audit_Case__c> cases = [
            SELECT Id, Original_Approver__c, Auditor__c, Status__c
            FROM Audit_Case__c
            WHERE Id = :auditCaseId
            WITH USER_MODE
            LIMIT 1
        ];

        if (cases.isEmpty()) {
            throw new SelfAuditException('Audit case not found: ' + auditCaseId);
        }

        Audit_Case__c auditCase = cases[0];

        if (auditCase.Original_Approver__c != null && auditCase.Original_Approver__c == auditorId) {
            throw new SelfAuditException(
                'Auditor cannot audit a loan they originally approved.'
            );
        }

        auditCase.Auditor__c     = auditorId;
        auditCase.Assigned_At__c = Datetime.now();
        auditCase.Status__c      = 'Assigned';
        update auditCase;

        AuditEventService.logEvent(
            auditCase.Id,
            'Case_Assigned',
            UserInfo.getUserId(),
            JSON.serialize(new Map<String, Object>{
                'auditorId' => auditorId
            }),
            null
        );

        return auditCase;
    }

    /**
     * Get the audit queue filtered by the queue's filter controls.
     * Returns cases ordered by risk tier (Critical first) then created date.
     *
     * SECURITY: every WHERE clause uses a hardcoded field name (compile-time
     * literal) paired with a bind variable for the value — no client-supplied
     * string is ever concatenated into the query, so there is no SOQL-injection
     * surface. Field names act as an implicit allow-list.
     *
     * @param filterStatus         Optional status (e.g. 'In_Review')
     * @param filterRiskTier       Optional risk tier (e.g. 'High')
     * @param filterApproverId     Optional original-approver User Id
     * @param filterSamplingReason Optional sampling reason (e.g. 'Risk_Based')
     * @param filterApprovalDays   Optional approval-recency window in days ('7','30','90')
     * @param filterAuditorId      Optional assigned-auditor User Id
     * @param filterDueBefore      Optional due-date upper bound (inclusive, end-of-day)
     * @return Filtered list of Audit_Case__c records
     *
     * NOTE: Product and Branch filter controls exist in the LWC but have no
     * backing field on Audit_Case__c yet, so they are intentionally NOT accepted
     * here — wiring them is blocked on a data-model decision (add Loan_Product__c
     * / Branch__c + backfill). Accepting-and-ignoring them would be a silent no-op.
     */
    public static List<Audit_Case__c> getQueue(
        String filterStatus,
        String filterRiskTier,
        String filterApproverId,
        String filterSamplingReason,
        String filterApprovalDays,
        String filterAuditorId,
        Date filterDueBefore
    ) {
        String query = 'SELECT Id, Name, Loan_Application__c, Borrower_Name_Snapshot__c, Status__c, '
            + 'Auditor__c, Auditor__r.Name, Original_Approver__c, Original_Approver__r.Name, '
            + 'Sampling_Reason__c, Risk_Tier__c, Approval_Timestamp__c, '
            + 'Assigned_At__c, Due_At__c, Sampled_At__c, CreatedDate '
            + 'FROM Audit_Case__c';

        List<String> conditions = new List<String>();

        // Resolve typed bind values from raw inputs (kept in-scope for Database.query binding).
        Id approverId = String.isNotBlank(filterApproverId) ? Id.valueOf(filterApproverId) : null;
        Id auditorId  = String.isNotBlank(filterAuditorId)  ? Id.valueOf(filterAuditorId)  : null;

        Datetime approvalCutoff = null;
        if (String.isNotBlank(filterApprovalDays) && filterApprovalDays.isNumeric()) {
            approvalCutoff = Datetime.now().addDays(-Integer.valueOf(filterApprovalDays));
        }

        Datetime dueCutoff = (filterDueBefore != null)
            ? Datetime.newInstance(filterDueBefore, Time.newInstance(23, 59, 59, 0))
            : null;

        if (String.isNotBlank(filterStatus)) {
            conditions.add('Status__c = :filterStatus');
        }
        if (String.isNotBlank(filterRiskTier)) {
            conditions.add('Risk_Tier__c = :filterRiskTier');
        }
        if (approverId != null) {
            conditions.add('Original_Approver__c = :approverId');
        }
        if (String.isNotBlank(filterSamplingReason)) {
            conditions.add('Sampling_Reason__c = :filterSamplingReason');
        }
        if (approvalCutoff != null) {
            conditions.add('Approval_Timestamp__c >= :approvalCutoff');
        }
        if (auditorId != null) {
            conditions.add('Auditor__c = :auditorId');
        }
        if (dueCutoff != null) {
            conditions.add('Due_At__c <= :dueCutoff');
        }
        if (filterStatus != 'Closed') {
            conditions.add('Status__c != \'Closed\'');
        }

        if (!conditions.isEmpty()) {
            query += ' WHERE ' + String.join(conditions, ' AND ');
        }

        // Enforce FLS/CRUD on the dynamic query (restored — goal C2).
        query += ' WITH USER_MODE';

        // SOQL does not support CASE in ORDER BY. Risk_Tier__c is a picklist, so SOQL sorts
        // by picklist DEFINITION order (Low, Medium, High, Critical). DESC therefore surfaces
        // Critical → High → Medium → Low first, putting the highest-risk loans at the top of
        // the LIMIT 200 queue. (ASC buried Critical/High past the cap — invisible until the
        // queue exceeded 200 rows; caught with the 614-row Kaggle dataset.)
        query += ' ORDER BY Risk_Tier__c DESC, CreatedDate DESC LIMIT 200';

        return Database.query(query);
    }

    /**
     * Distinct original approvers across open audit cases — backs the queue's
     * Approver filter so it can actually narrow by approver (F-01 / audit
     * finding F1). Returns {id, name} maps ordered by name; an empty list when
     * no open case carries an approver (the LWC still shows "All approvers").
     *
     * Two queries, no SOQL in a loop: an aggregate DISTINCT on the lookup, then
     * one User name lookup. FLS/CRUD enforced via USER_MODE on both.
     *
     * @return List of maps with keys 'id' (User Id) and 'name' (User.Name)
     */
    public static List<Map<String, String>> getApprovers() {
        Set<Id> approverIds = new Set<Id>();
        for (AggregateResult ar : [
            SELECT Original_Approver__c approverId
            FROM Audit_Case__c
            WHERE Original_Approver__c != null
              AND Status__c != 'Closed'
            WITH USER_MODE
            GROUP BY Original_Approver__c
        ]) {
            approverIds.add((Id) ar.get('approverId'));
        }

        List<Map<String, String>> approvers = new List<Map<String, String>>();
        if (approverIds.isEmpty()) {
            return approvers;
        }

        for (User u : [
            SELECT Id, Name
            FROM User
            WHERE Id IN :approverIds
            WITH USER_MODE
            ORDER BY Name
        ]) {
            approvers.add(new Map<String, String>{
                'id'   => String.valueOf(u.Id),
                'name' => u.Name
            });
        }
        return approvers;
    }
}