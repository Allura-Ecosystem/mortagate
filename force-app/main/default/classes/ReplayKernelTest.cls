/**
 * ReplayKernelTest — Coverage + behavior for the audit replay kernel.
 *
 * The replay kernel (FactAssembler → PolicyRuleEvaluator → AuditCommitService,
 * orchestrated by CaseReviewController.runReplay) is the centerpiece of the
 * audit-queue but was only exercised indirectly. This suite gives the PURE
 * kernel classes dedicated, deterministic coverage so the audit-queue can clear
 * the ≥75% per-class production bar as an independently-deployable unit.
 *
 * SCOPE NOTE (org schema reality): in the current target org a batch of fields
 * referenced by the source classes under `WITH USER_MODE` are not FLS-readable
 * (Policy_Rule_Version__c.HITL_Credit_Threshold__c / Max_Loan_No_Escalation__c,
 *  Finding__c.Rationale__c / Remediation_Due_At__c, Rule_Check__c.Exception_*).
 * Paths that USER_MODE-query those fields (CaseReviewController.runReplay /
 * getCaseReview, PolicyVersionSelector.loadPolicyVersion, FindingService
 * exception workflow) therefore cannot execute green until the FLS/schema drift
 * is resolved. This suite deliberately covers everything that does NOT depend on
 * those fields — including the entire PolicyRuleEvaluator via in-memory facts —
 * and leaves the FLS-gated paths to the schema remediation.
 *
 * @group Audit Replay Kernel
 */
@IsTest
private class ReplayKernelTest {

    private static final String LOAN_REF = 'a0000000000REPLAY1';

    // ─── Fixtures ──────────────────────────────────────────────────────────

    private static Policy_Rule_Version__c buildPolicy(
        String name, String status, Date effective, Decimal version
    ) {
        // HITL / Max are set in-memory only (system-mode insert ignores FLS);
        // they drive the in-memory PolicyRuleEvaluator branches below.
        return new Policy_Rule_Version__c(
            Name = name,
            Version_Number__c = version,
            Status__c = status,
            Effective_Date__c = effective,
            DTI_Threshold__c = 43,
            Min_Credit_Score__c = 620,
            HITL_Credit_Threshold__c = 680,
            Max_Loan_No_Escalation__c = 400000,
            Rule_Code__c = 'REPLAY_TEST_' + version,
            Rule_Label__c = name,
            Fact_Field__c = 'DTI'
        );
    }

    private static Reconstructed_Fact__c fact(String type, String value) {
        return new Reconstructed_Fact__c(Fact_Type__c = type, Value__c = value);
    }

    // A fully-populated, in-memory policy for pure-evaluator tests (no SOQL,
    // so no FLS dependency on HITL / Max).
    private static Policy_Rule_Version__c inMemoryPolicy() {
        return new Policy_Rule_Version__c(
            DTI_Threshold__c = 43,
            Min_Credit_Score__c = 620,
            HITL_Credit_Threshold__c = 680,
            Max_Loan_No_Escalation__c = 400000
        );
    }

    @TestSetup
    static void setup() {
        insert new List<Policy_Rule_Version__c>{
            buildPolicy('Replay Superseded v1', 'Superseded', Date.today().addYears(-3), 1),
            buildPolicy('Replay Active v2',     'Active',     Date.today().addYears(-1), 2)
        };

        Audit_Case__c c = new Audit_Case__c(
            Loan_Application__c   = LOAN_REF,
            Sampling_Reason__c    = 'Risk_Based',
            Approval_Timestamp__c = Datetime.now().addMonths(-6),
            Status__c             = 'Created',
            Risk_Tier__c          = 'Critical'
        );
        insert c;

        insert new List<Evidence_Item__c>{
            new Evidence_Item__c(Audit_Case__c = c.Id, Document_Type__c = 'W2',            Status__c = 'Available'),
            new Evidence_Item__c(Audit_Case__c = c.Id, Document_Type__c = 'Credit_Report', Status__c = 'Available'),
            new Evidence_Item__c(Audit_Case__c = c.Id, Document_Type__c = 'Bank_Statement',Status__c = 'Available'),
            new Evidence_Item__c(Audit_Case__c = c.Id, Document_Type__c = 'Pay_Stub',      Status__c = 'Missing'),
            new Evidence_Item__c(Audit_Case__c = c.Id, Document_Type__c = 'Appraisal',     Status__c = 'Missing')
        };
    }

    private static Id theCaseId() {
        return [SELECT Id FROM Audit_Case__c WHERE Loan_Application__c = :LOAN_REF LIMIT 1].Id;
    }

    // ─── PolicyRuleEvaluator — every rule + outcome (in-memory) ────────────

    @IsTest
    static void test_replayRules_highRiskOutcomes() {
        Id caseId = theCaseId();
        Policy_Rule_Version__c policy = inMemoryPolicy();

        // DTI 47 > 43 → Violation; Credit 712 ≥620 and ≥680 → Pass+Pass;
        // Loan 410000 > 400000 → Exception.
        List<Reconstructed_Fact__c> facts = new List<Reconstructed_Fact__c>{
            fact('DTI', '47'), fact('Credit_Score', '712'),
            fact('Loan_Amount', '410000'), fact('LTV', 'UNVERIFIABLE')
        };

        Test.startTest();
        List<Rule_Check__c> checks = PolicyRuleEvaluator.replayRules(facts, policy, caseId);
        Test.stopTest();

        Map<String, String> byRule = new Map<String, String>();
        for (Rule_Check__c rc : checks) { byRule.put(rc.Rule_Name__c, rc.Outcome__c); }

        System.assertEquals(4, checks.size(), 'DTI + Credit + HITL + Escalation.');
        System.assertEquals('Violation', byRule.get('DTI Threshold'));
        System.assertEquals('Pass', byRule.get('Min Credit Score'));
        System.assertEquals('Pass', byRule.get('HITL Credit Threshold'));
        System.assertEquals('Exception', byRule.get('Loan Escalation Threshold'));
    }

    @IsTest
    static void test_replayRules_lowRiskAndUnverifiable() {
        Id caseId = theCaseId();
        Policy_Rule_Version__c policy = inMemoryPolicy();

        // DTI 30 ≤43 → Pass; Credit 600 <620 → Violation, <680 → Exception;
        // Loan 200000 ≤400000 → Pass.
        List<Reconstructed_Fact__c> low = new List<Reconstructed_Fact__c>{
            fact('DTI', '30'), fact('Credit_Score', '600'), fact('Loan_Amount', '200000')
        };
        Map<String, String> byRule = new Map<String, String>();
        for (Rule_Check__c rc : PolicyRuleEvaluator.replayRules(low, policy, caseId)) {
            byRule.put(rc.Rule_Name__c, rc.Outcome__c);
        }
        System.assertEquals('Pass', byRule.get('DTI Threshold'));
        System.assertEquals('Violation', byRule.get('Min Credit Score'));
        System.assertEquals('Exception', byRule.get('HITL Credit Threshold'));
        System.assertEquals('Pass', byRule.get('Loan Escalation Threshold'));

        // Unverifiable across the board.
        Map<String, String> blind = new Map<String, String>();
        for (Rule_Check__c rc : PolicyRuleEvaluator.replayRules(
                new List<Reconstructed_Fact__c>{ fact('DTI', 'UNVERIFIABLE') }, policy, caseId)) {
            blind.put(rc.Rule_Name__c, rc.Outcome__c);
        }
        System.assertEquals('Unverifiable', blind.get('DTI Threshold'));
        System.assertEquals('Unverifiable', blind.get('Min Credit Score'));
        System.assertEquals('Unverifiable', blind.get('Loan Escalation Threshold'));
    }

    @IsTest
    static void test_replayRules_noOptionalRules_andDtoOverload() {
        Id caseId = theCaseId();
        // Policy with only the mandatory thresholds → HITL & Escalation skipped.
        Policy_Rule_Version__c minimal = new Policy_Rule_Version__c(
            DTI_Threshold__c = 36, Min_Credit_Score__c = 660);

        List<Rule_Check__c> checks = PolicyRuleEvaluator.replayRules(
            new List<Reconstructed_Fact__c>{ fact('DTI', '20'), fact('Credit_Score', '700') },
            minimal, caseId);
        System.assertEquals(2, checks.size(),
            'Without HITL / Max thresholds only DTI + Credit are evaluated.');

        List<PolicyRuleEvaluator.RuleCheckResult> results =
            PolicyRuleEvaluator.replayRulesAsResults(
                new List<Reconstructed_Fact__c>{
                    fact('DTI', '50'), fact('Credit_Score', 'PENDING_EXTRACTION') },
                minimal);
        System.assertEquals(2, results.size());
        Map<String, String> dto = new Map<String, String>();
        for (PolicyRuleEvaluator.RuleCheckResult r : results) { dto.put(r.ruleName, r.outcome); }
        System.assertEquals('Violation', dto.get('DTI Threshold'),
            'DTI 50 over 36 is a Violation in the DTO overload.');
        System.assertEquals('Unverifiable', dto.get('Min Credit Score'),
            'PENDING credit is Unverifiable in the DTO overload.');
    }

    // ─── FactAssembler — single, bulk, shell ───────────────────────────────

    @IsTest
    static void test_factAssembler_reconstruct_bulk_and_shell() {
        Id caseId = theCaseId();

        Test.startTest();
        List<Reconstructed_Fact__c> single = FactAssembler.reconstructFacts(caseId);
        Map<Id, List<Reconstructed_Fact__c>> bulkFacts =
            FactAssembler.reconstructFactsBulk(new Set<Id>{ caseId });
        List<Evidence_Item__c> shell = FactAssembler.createEvidenceShell(caseId);
        Test.stopTest();

        System.assertEquals(6, single.size(), 'Six canonical facts per case.');
        System.assertEquals(6, bulkFacts.get(caseId).size(), 'Bulk mirrors single reconstruction.');
        System.assertEquals(5, shell.size(), 'Evidence shell seeds five required document types.');

        Boolean anyProvenance = false;
        for (Reconstructed_Fact__c f : single) {
            if (f.Source_Evidence__c != null) { anyProvenance = true; }
        }
        System.assert(anyProvenance, 'At least one fact links to Available evidence (provenance chain).');

        System.assert(FactAssembler.reconstructFactsBulk(new Set<Id>()).isEmpty(),
            'Empty bulk input returns an empty map.');
    }

    @IsTest
    static void test_factAssembler_missingCase_returnsEmpty() {
        // A syntactically-valid but non-existent Audit_Case__c Id.
        Id ghost = Audit_Case__c.SObjectType.getDescribe().getKeyPrefix() + '000000000001AAA';
        System.assert(FactAssembler.reconstructFacts(ghost).isEmpty(),
            'No case → no facts.');
    }

    // ─── AuditCommitService — replay results + findings ────────────────────

    @IsTest
    static void test_commit_replayResults_and_findings() {
        Id caseId = theCaseId();
        String pvKey = 'PRV-TEST-001';

        List<Reconstructed_Fact__c> facts = new List<Reconstructed_Fact__c>{
            new Reconstructed_Fact__c(Audit_Case__c = caseId, Fact_Type__c = 'DTI', Value__c = '47')
        };
        // Rule_Check__c.Policy_Rule_Version__c is REQUIRED on this org.
        List<Rule_Check__c> checks = new List<Rule_Check__c>{
            new Rule_Check__c(Audit_Case__c = caseId, Policy_Rule_Version__c = pvKey, Rule_Name__c = 'DTI Threshold', Outcome__c = 'Violation'),
            new Rule_Check__c(Audit_Case__c = caseId, Policy_Rule_Version__c = pvKey, Rule_Name__c = 'Doc Check', Outcome__c = 'Unverifiable'),
            new Rule_Check__c(Audit_Case__c = caseId, Policy_Rule_Version__c = pvKey, Rule_Name__c = 'Escalation', Outcome__c = 'Exception'),
            new Rule_Check__c(Audit_Case__c = caseId, Policy_Rule_Version__c = pvKey, Rule_Name__c = 'Credit', Outcome__c = 'Pass')
        };

        Test.startTest();
        AuditCommitService.CommitResult commitRes =
            AuditCommitService.commitReplayResults(caseId, facts, checks);

        // Violation→Eligibility, Unverifiable→Documentation, Exception→Process,
        // Pass→(none) = 3 findings.
        List<Finding__c> findings = FindingService.createFromRuleChecks(caseId, checks);
        AuditCommitService.CommitResult findingCommit =
            AuditCommitService.commitFindings(caseId, findings);
        Test.stopTest();

        System.assertEquals(1, commitRes.factIds.size(), 'One fact committed.');
        System.assertEquals(4, commitRes.ruleCheckIds.size(), 'Four checks committed.');
        System.assert(commitRes.totalRecords > 0, 'Commit reports a record total.');
        System.assertEquals('In_Review',
            [SELECT Status__c FROM Audit_Case__c WHERE Id = :caseId].Status__c,
            'commitReplayResults advances the case to In_Review.');

        System.assertEquals(3, findings.size(), 'Pass yields no finding; the other three do.');
        Set<String> categories = new Set<String>();
        for (Finding__c f : findings) { categories.add(f.Category__c); }
        System.assert(categories.containsAll(new Set<String>{'Eligibility','Documentation','Process'}),
            'Finding categories map from rule-check outcomes.');
        System.assert(findingCommit.eventIds.size() >= 3, 'Each finding logs an audit event.');

        // Empty inputs are safe no-ops.
        AuditCommitService.CommitResult empties = AuditCommitService.commitReplayResults(
            caseId, new List<Reconstructed_Fact__c>(), new List<Rule_Check__c>());
        System.assertEquals(0, empties.factIds.size());
        AuditCommitService.CommitResult noFindings =
            AuditCommitService.commitFindings(caseId, new List<Finding__c>());
        System.assertEquals(0, noFindings.eventIds.size());
    }

    @IsTest
    static void test_findingService_passOnly_yieldsNoFindings() {
        Id caseId = theCaseId();
        List<Rule_Check__c> allPass = new List<Rule_Check__c>{
            new Rule_Check__c(Audit_Case__c = caseId, Rule_Name__c = 'A', Outcome__c = 'Pass'),
            new Rule_Check__c(Audit_Case__c = caseId, Rule_Name__c = 'B', Outcome__c = 'Pass')
        };
        System.assert(FindingService.createFromRuleChecks(caseId, allPass).isEmpty(),
            'An all-Pass case produces no findings.');
    }

    // ─── PolicyVersionSelector — temporal selection (Id-only USER_MODE) ────

    @IsTest
    static void test_policyVersionSelector_selection() {
        Test.startTest();
        String historical = PolicyVersionSelector.selectByApprovalDate(Datetime.now().addMonths(-6));
        String current    = PolicyVersionSelector.selectByApprovalDate(null);
        String active     = PolicyVersionSelector.selectCurrentActive();
        Test.stopTest();

        System.assertNotEquals(null, historical, 'A historical version resolves for a past approval.');
        System.assertNotEquals(null, current, 'Null approval falls back to current Active.');
        System.assertNotEquals(null, active, 'An Active version exists.');
        System.assertEquals(null, PolicyVersionSelector.loadPolicyVersion(null),
            'A blank id loads nothing (early return).');
        System.assertEquals(null, PolicyVersionSelector.loadPolicyVersion(''),
            'An empty id loads nothing (early return).');
    }

    // ─── CaseReviewController — FLS-safe surface (evidence + timeline) ─────

    @IsTest
    static void test_caseReview_evidence_and_timeline() {
        Id caseId = theCaseId();
        Evidence_Item__c ev = [SELECT Id FROM Evidence_Item__c
                               WHERE Audit_Case__c = :caseId AND Status__c = 'Missing' LIMIT 1];

        Test.startTest();
        CaseReviewController.updateEvidenceStatus(ev.Id, 'Available');
        List<Audit_Event__c> timeline = CaseReviewController.getTimeline(caseId);
        Test.stopTest();

        System.assertEquals('Available',
            [SELECT Status__c FROM Evidence_Item__c WHERE Id = :ev.Id].Status__c,
            'Evidence status update persisted.');
        System.assert(!timeline.isEmpty(),
            'Updating evidence logs an Evidence_Linked event onto the timeline.');
    }
}
