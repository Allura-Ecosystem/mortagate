/**
 * SignoffController — data source + sole write path for the Sign-off Receipt
 * screen (the c-signoff-receipt LWC), the final step of the auditor 5-screen
 * flow.
 *
 * What it does:
 *   • getReceipt(caseId)  — read-only. Returns the existing immutable
 *                           Audit_Receipt__c for the case (or null) PLUS a
 *                           live preview summary (latest-batch pass / violation /
 *                           unverifiable counts + total findings) so the UI can
 *                           show "what will be signed" before the auditor commits.
 *   • signOff(caseId)     — the ONLY write. Computes counts from the LATEST
 *                           replay batch (R-11) + findings, INSERTS exactly one
 *                           immutable Audit_Receipt__c, closes the case, and logs
 *                           a governed Audit_Event__c. Refuses a second receipt
 *                           (immutable — never two) and refuses unless the case
 *                           is Ready_for_Signoff.
 *
 * FLS/sharing: `with sharing`; every read runs USER_MODE via AuditSoql (or
 * WITH USER_MODE). The Receipt_Hash__c is an ILLUSTRATIVE demo hash, not a
 * cryptographic seal.
 *
 * @group Sign-off
 * @see AuditSoql, ReplayService, AuditEventService
 */
public with sharing class SignoffController {

    @TestVisible private static final String STATUS_READY  = 'Ready_for_Signoff';
    @TestVisible private static final String STATUS_CLOSED = 'Closed';

    // ── Read ─────────────────────────────────────────────────────────────

    /**
     * Assemble the sign-off DTO for one case: the existing receipt (if any) and
     * a live preview of what a sign-off would record. Cacheable, never writes.
     *
     * @param auditCaseId the Audit_Case__c being reviewed for sign-off
     * @return a SignoffView, or null if the case is not visible / not found
     */
    @AuraEnabled(cacheable=true)
    public static SignoffView getReceipt(Id auditCaseId) {
        if (auditCaseId == null) {
            return null;
        }

        List<Audit_Case__c> cases = (List<Audit_Case__c>) AuditSoql.query(
            'SELECT Id, Name, Status__c, Risk_Tier__c, Borrower_Name_Snapshot__c, ' +
            'Loan__r.LOS_Loan_Id__c, Loan__r.Approver_Name__c ' +
            'FROM Audit_Case__c WHERE Id = :auditCaseId LIMIT 1',
            new Map<String, Object>{ 'auditCaseId' => auditCaseId });
        if (cases.isEmpty()) {
            return null;
        }
        Audit_Case__c ac = cases[0];

        SignoffView v = new SignoffView();
        v.recordId     = ac.Id;
        v.caseNumber   = ac.Name;
        v.borrowerName = ac.Borrower_Name_Snapshot__c;
        v.loanNumber   = (ac.Loan__r != null) ? ac.Loan__r.LOS_Loan_Id__c : null;
        v.riskTier     = ac.Risk_Tier__c;
        v.statusApi    = ac.Status__c;
        v.status       = (ac.Status__c == null) ? null : ac.Status__c.replace('_', ' ');
        v.isReadyForSignoff = (ac.Status__c == STATUS_READY);

        // Live preview from the latest replay batch + findings (R-11).
        Counts c = computeCounts(auditCaseId);
        v.passCount         = c.passes;
        v.violationCount    = c.violations;
        v.unverifiableCount = c.unverifiable;
        v.totalFindings     = c.totalFindings;
        v.hasReplay         = (c.passes + c.violations + c.unverifiable) > 0;

        // Existing immutable receipt (if already signed).
        List<Audit_Receipt__c> receipts = (List<Audit_Receipt__c>) AuditSoql.query(
            'SELECT Id, Pass_Count__c, Violation_Count__c, Exception_Count__c, ' +
            'Total_Findings__c, Signed_Off_At__c, Receipt_Hash__c, Reviewer__r.Name ' +
            'FROM Audit_Receipt__c WHERE Audit_Case__c = :auditCaseId ' +
            'ORDER BY CreatedDate ASC LIMIT 1',
            new Map<String, Object>{ 'auditCaseId' => auditCaseId });
        if (!receipts.isEmpty()) {
            v.receipt = toReceiptDto(receipts[0]);
        }

        return v;
    }

    // ── Write (the ONLY one) ─────────────────────────────────────────────

    /**
     * Sign off the case: insert one immutable Audit_Receipt__c from the latest
     * replay batch + findings, close the case, and log the event. Strictly
     * user-triggered.
     *
     * Guards:
     *   - refuses if a receipt already exists (the receipt is immutable — there
     *     is never a second one);
     *   - refuses unless the case is Ready_for_Signoff.
     *
     * @param auditCaseId the Audit_Case__c to sign off
     * @return the refreshed SignoffView (so the UI repaints in one round trip)
     */
    @AuraEnabled
    public static SignoffView signOff(Id auditCaseId) {
        if (auditCaseId == null) {
            throw new AuraHandledException('An audit case id is required to sign off.');
        }

        try {
            List<Audit_Case__c> cases = [
                SELECT Id, Status__c, Risk_Tier__c
                FROM Audit_Case__c
                WHERE Id = :auditCaseId
                WITH USER_MODE
                LIMIT 1
            ];
            if (cases.isEmpty()) {
                throw new AuraHandledException('This audit case is not available for sign-off.');
            }
            Audit_Case__c ac = cases[0];

            // Guard 1: the receipt is immutable — never sign a second one.
            Integer existing = [
                SELECT COUNT()
                FROM Audit_Receipt__c
                WHERE Audit_Case__c = :auditCaseId
                WITH USER_MODE
            ];
            if (existing > 0) {
                throw new AuraHandledException(
                    'This case has already been signed off. The receipt is immutable ' +
                    'and cannot be re-issued.');
            }

            // Guard 2: only a Ready-for-Sign-off case can be signed.
            if (ac.Status__c != STATUS_READY) {
                throw new AuraHandledException(
                    'This case is not ready for sign-off yet. Complete the review and ' +
                    'mark it Ready for Signoff first.');
            }

            // Counts from the latest replay batch + findings (R-11).
            Counts c = computeCounts(auditCaseId);
            Datetime now = Datetime.now();
            String hash = demoHash(auditCaseId, c, now);

            Audit_Receipt__c receipt = new Audit_Receipt__c(
                Audit_Case__c      = auditCaseId,
                Pass_Count__c      = c.passes,
                Violation_Count__c = c.violations,
                Exception_Count__c = c.unverifiable,
                Total_Findings__c  = c.totalFindings,
                Signed_Off_At__c   = now,
                Reviewer__c        = UserInfo.getUserId(),
                Receipt_Hash__c    = hash,
                Replay_Snapshot__c = c.replaySnapshotJson,
                Findings_Snapshot__c = c.findingsSnapshotJson
            );
            insert receipt;  // 1 DML — the immutable receipt

            // Close the case + stamp sign-off audit fields.
            ac.Status__c       = STATUS_CLOSED;
            ac.Signed_Off_At__c = now;
            ac.Signed_Off_By__c = UserInfo.getUserId();
            update ac;  // 1 DML

            // Governed append-only audit event.
            AuditEventService.logEvent(
                auditCaseId,
                'Case_Signed_Off',
                UserInfo.getName(),
                '{"violationCount":' + c.violations +
                    ',"passCount":' + c.passes +
                    ',"exceptionCount":' + c.unverifiable +
                    ',"totalFindings":' + c.totalFindings + '}',
                receipt.Id
            );  // 1 DML

            return getReceipt(auditCaseId);
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    // ── Helpers ──────────────────────────────────────────────────────────

    /**
     * Count results from the LATEST replay batch (Pass / Violation / Unverifiable)
     * plus the total Finding__c count for the case. Single definition of "current"
     * via AuditSoql.latestChecksFor so the receipt agrees with Case Review.
     */
    private static Counts computeCounts(Id auditCaseId) {
        Counts c = new Counts();

        List<Replay_Check__c> checks = AuditSoql.latestChecksFor(auditCaseId);
        List<Map<String, Object>> snapRows = new List<Map<String, Object>>();
        for (Replay_Check__c rc : checks) {
            if (rc.Result__c == 'Fail') {
                c.violations++;
            } else if (rc.Result__c == 'Pass') {
                c.passes++;
            } else {
                c.unverifiable++;  // Unverifiable / anything else
            }
            snapRows.add(new Map<String, Object>{
                'rule'     => rc.Rule_Name__c,
                'result'   => rc.Result__c,
                'expected' => rc.Expected_Value__c,
                'actual'   => rc.Actual_Value__c
            });
        }
        c.replaySnapshotJson = JSON.serialize(snapRows);

        // Total findings on the case (auditor-recorded outcomes).
        c.totalFindings = [
            SELECT COUNT()
            FROM Finding__c
            WHERE Audit_Case__c = :auditCaseId
            WITH USER_MODE
        ];

        List<Finding__c> findings = [
            SELECT Severity__c, Category__c, Description__c
            FROM Finding__c
            WHERE Audit_Case__c = :auditCaseId
            WITH USER_MODE
        ];
        List<Map<String, Object>> fRows = new List<Map<String, Object>>();
        for (Finding__c f : findings) {
            fRows.add(new Map<String, Object>{
                'severity'    => f.Severity__c,
                'category'    => f.Category__c,
                'description' => f.Description__c
            });
        }
        c.findingsSnapshotJson = JSON.serialize(fRows);

        return c;
    }

    /**
     * Build an ILLUSTRATIVE receipt hash for the demo — a SHA-256 over the
     * snapshot material. This is NOT a cryptographic seal / chain-of-custody
     * proof; the UI discloses that explicitly.
     */
    private static String demoHash(Id auditCaseId, Counts c, Datetime signedAt) {
        String material = auditCaseId + '|' + signedAt.getTime()
            + '|P' + c.passes + '|V' + c.violations + '|U' + c.unverifiable
            + '|F' + c.totalFindings + '|' + c.replaySnapshotJson;
        Blob digest = Crypto.generateDigest('SHA-256', Blob.valueOf(material));
        return EncodingUtil.convertToHex(digest);  // 64 hex chars (fits Text(64))
    }

    private static ReceiptDto toReceiptDto(Audit_Receipt__c r) {
        ReceiptDto dto = new ReceiptDto();
        dto.recordId        = r.Id;
        dto.passCount       = intOf(r.Pass_Count__c);
        dto.violationCount  = intOf(r.Violation_Count__c);
        dto.exceptionCount  = intOf(r.Exception_Count__c);
        dto.totalFindings   = intOf(r.Total_Findings__c);
        dto.signedOffAt     = r.Signed_Off_At__c;
        dto.receiptHash     = r.Receipt_Hash__c;
        dto.reviewerName    = (r.Reviewer__r != null) ? r.Reviewer__r.Name : null;
        return dto;
    }

    private static Integer intOf(Decimal d) {
        return (d == null) ? 0 : d.intValue();
    }

    // ── Inner types ──────────────────────────────────────────────────────

    private class Counts {
        Integer passes = 0;
        Integer violations = 0;
        Integer unverifiable = 0;
        Integer totalFindings = 0;
        String replaySnapshotJson;
        String findingsSnapshotJson;
    }

    // ── DTOs ─────────────────────────────────────────────────────────────

    public class SignoffView {
        @AuraEnabled public Id recordId;
        @AuraEnabled public String caseNumber;
        @AuraEnabled public String borrowerName;
        @AuraEnabled public String loanNumber;
        @AuraEnabled public String riskTier;
        @AuraEnabled public String status;     // display label
        @AuraEnabled public String statusApi;  // raw picklist value
        @AuraEnabled public Boolean isReadyForSignoff = false;
        @AuraEnabled public Boolean hasReplay = false;
        // Live preview counts (what a sign-off would record).
        @AuraEnabled public Integer passCount = 0;
        @AuraEnabled public Integer violationCount = 0;
        @AuraEnabled public Integer unverifiableCount = 0;
        @AuraEnabled public Integer totalFindings = 0;
        // The signed receipt, present only once the case is signed off.
        @AuraEnabled public ReceiptDto receipt;
    }

    public class ReceiptDto {
        @AuraEnabled public Id recordId;
        @AuraEnabled public Integer passCount;
        @AuraEnabled public Integer violationCount;
        @AuraEnabled public Integer exceptionCount;
        @AuraEnabled public Integer totalFindings;
        @AuraEnabled public Datetime signedOffAt;
        @AuraEnabled public String receiptHash;
        @AuraEnabled public String reviewerName;
    }
}
