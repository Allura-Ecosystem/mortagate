/**
 * Assembles an ECOA / Regulation B (12 CFR 1002.9) adverse action notice from a
 * decision verdict and its failing rules. PURE LOGIC — zero SOQL, zero DML — so it
 * is unit-testable without an org (NFR-6), exactly like PolicyRuleEvaluator. The
 * controller does the I/O (load the event, the borrower, the config) and hands this
 * class plain values; this class owns only the regulated composition.
 *
 * What the regulation requires of the notice (and what this builds):
 *   1002.9(a)(2)(i)  statement of the action taken                    -> actionStatement
 *   1002.9(a)(2)(i)  name and address of the creditor                 -> creditorName/Address
 *   1002.9(a)(2)(i)  the ECOA 701(a) anti-discrimination notice       -> ecoaNotice
 *   1002.9(b)(1)     name/address of the federal oversight agency     -> folded into ecoaNotice [AGENCY]
 *   1002.9(b)(2)     SPECIFIC principal reasons for the action        -> reasons (from Rule_Explanation__c)
 *
 * 1002.9(b)(2) is the trap most engines fall into: a notice that says only
 * "internal standards" or "failed to achieve a qualifying score" is NON-compliant.
 * We never emit that phrasing. Reasons come from the rules' own human explanations,
 * which are written to be specific, and we surface the actual value vs. threshold.
 *
 * FCRA (15 U.S.C. 1681m) is a SEPARATE obligation that also attaches to a mortgage
 * decline when a consumer report was used: disclose the score, key factors, the CRA,
 * and the consumer's rights. We model that block here but flag it honestly — the CRA
 * identity arrives with the P3 credit-bureau integration; today the score is a
 * supplied fact, so the disclosure renders what we hold and names what is pending.
 */
public with sharing class AdverseActionService {

    /** Verdicts that constitute adverse action for notice purposes. */
    private static final Set<String> ADVERSE_VERDICTS = new Set<String>{ 'HARD_DECLINED' };

    /** Severity ranked first when choosing principal reasons. */
    private static final String HARD = 'HARD_DECLINE';

    /**
     * Config holder — a plain object, not the CMDT, so the core logic needs no org.
     * The controller maps Adverse_Action_Config__mdt into this.
     */
    public class Config {
        public String creditorName;
        public String creditorAddress;
        public String agencyName;
        public String agencyAddress;
        public String ecoaNoticeTemplate;   // contains the literal token [AGENCY]
        public Integer reasonLimit;
        public Integer noticeWindowDays;
    }

    /** One failing rule, decoupled from RuleOutcome's parameterized-only constructor. */
    public class FailingRule {
        public String explanation;
        public String ruleCode;
        public String severity;     // HARD_DECLINE, SOFT_DECLINE, WARNING, ADVISORY
        public String factValue;
        public String threshold;

        public FailingRule(String explanation, String ruleCode, String severity) {
            this.explanation = explanation;
            this.ruleCode = ruleCode;
            this.severity = severity;
        }
    }

    /** A specific principal reason, as required by 1002.9(b)(2). */
    public class PrincipalReason {
        public String text { get; private set; }
        public String ruleCode { get; private set; }
        public String severity { get; private set; }

        public PrincipalReason(String text, String ruleCode, String severity) {
            this.text = text;
            this.ruleCode = ruleCode;
            this.severity = severity;
        }
    }

    /** The assembled notice — pure data, rendered by AdverseActionNotice.page. */
    public class Notice {
        public Boolean isAdverseAction { get; private set; }
        public String actionStatement { get; private set; }
        public String applicantName { get; private set; }
        public Date noticeDate { get; private set; }
        public Date respondByDate { get; private set; }
        public String creditorName { get; private set; }
        public String creditorAddress { get; private set; }
        public List<PrincipalReason> reasons { get; private set; }
        public String ecoaNotice { get; private set; }
        public Boolean creditScoreDisclosed { get; private set; }
        public Integer creditScore { get; private set; }
        public String scoreDisclosure { get; private set; }

        public Notice() {
            this.reasons = new List<PrincipalReason>();
            this.isAdverseAction = false;
            this.creditScoreDisclosed = false;
        }
    }

    /**
     * Build the notice. A null/empty config is tolerated (renders blanks rather than
     * throwing) so a missing CMDT record degrades gracefully instead of breaking the
     * decline path — but compliance review must ensure the config is present in prod.
     */
    public static Notice build(String verdict, List<FailingRule> failingRules,
                               Integer creditScore, Config cfg, String applicantName, Date noticeDate) {
        Config c = cfg == null ? new Config() : cfg;
        Notice n = new Notice();
        n.isAdverseAction = verdict != null && ADVERSE_VERDICTS.contains(verdict);
        n.applicantName = String.isBlank(applicantName) ? 'Applicant' : applicantName;
        n.noticeDate = noticeDate == null ? Date.today() : noticeDate;
        Integer window = c.noticeWindowDays == null ? 30 : c.noticeWindowDays;
        n.respondByDate = n.noticeDate.addDays(window);
        n.creditorName = c.creditorName;
        n.creditorAddress = c.creditorAddress;
        n.actionStatement = n.isAdverseAction
            ? 'After carefully reviewing the application for the credit you requested, '
              + 'we are unable to approve it at this time.'
            : 'This notice accompanies the decision on your credit application.';
        n.reasons = selectReasons(failingRules, c.reasonLimit);
        n.ecoaNotice = resolveEcoaNotice(c);
        if (creditScore != null) {
            n.creditScoreDisclosed = true;
            n.creditScore = creditScore;
            n.scoreDisclosure = buildScoreDisclosure(creditScore);
        }
        return n;
    }

    /**
     * Choose the specific principal reasons. HARD_DECLINE rules come first (they are
     * what actually drove the denial), then any other failing rules, deduped by text,
     * capped at the configured limit (default 4 — more than four is treated as
     * unhelpful by the Official Interpretation of 1002.9(b)(2)).
     */
    private static List<PrincipalReason> selectReasons(List<FailingRule> failing, Integer limitCount) {
        List<PrincipalReason> out = new List<PrincipalReason>();
        if (failing == null || failing.isEmpty()) { return out; }
        Integer cap = (limitCount == null || limitCount <= 0) ? 4 : limitCount;

        // NOTE: local names must NOT case-insensitively collide with the HARD
        // constant — Apex identifiers are case-insensitive, so a local named
        // `hard` would shadow `HARD` and silently break severity classification.
        List<FailingRule> hardRules = new List<FailingRule>();
        List<FailingRule> otherRules = new List<FailingRule>();
        for (FailingRule fr : failing) {
            if (fr == null || String.isBlank(fr.explanation)) { continue; }
            if (fr.severity != null && HARD.equalsIgnoreCase(fr.severity.trim())) {
                hardRules.add(fr);
            } else {
                otherRules.add(fr);
            }
        }
        Set<String> seen = new Set<String>();
        for (FailingRule fr : ordered(hardRules, otherRules)) {
            String text = fr.explanation.trim();
            String key = text.toLowerCase();
            if (seen.contains(key)) { continue; }
            seen.add(key);
            out.add(new PrincipalReason(text, fr.ruleCode, fr.severity));
            if (out.size() >= cap) { break; }
        }
        return out;
    }

    // HARD_DECLINE rules precede all others (1002.9(b)(2) principal-reason ordering).
    private static List<FailingRule> ordered(List<FailingRule> first, List<FailingRule> second) {
        List<FailingRule> all = new List<FailingRule>();
        all.addAll(first);
        all.addAll(second);
        return all;
    }

    /** Fold the agency name + address into the configured 701(a) notice template. */
    private static String resolveEcoaNotice(Config c) {
        if (String.isBlank(c.ecoaNoticeTemplate)) { return ''; }
        String agency = String.isBlank(c.agencyName) ? '' : c.agencyName;
        if (String.isNotBlank(c.agencyAddress)) {
            agency = String.isBlank(agency) ? c.agencyAddress : agency + ', ' + c.agencyAddress;
        }
        return c.ecoaNoticeTemplate.replace('[AGENCY]', agency);
    }

    /**
     * FCRA-style credit score disclosure block. Honest about scope: until the P3
     * bureau integration lands, the consumer reporting agency identity is not yet
     * captured, so the block discloses the score and the consumer's rights and names
     * the CRA detail as pending rather than inventing a source.
     */
    private static String buildScoreDisclosure(Integer score) {
        return 'Our credit decision was based in whole or in part on information obtained '
            + 'in a consumer report. Your credit score at the time of this decision was '
            + score + '. You have the right to obtain a free copy of your consumer report '
            + 'from the consumer reporting agency that furnished it, if you request it within '
            + '60 days of receiving this notice, and to dispute with that agency the accuracy '
            + 'or completeness of any information in your report. The consumer reporting agency '
            + 'did not make the credit decision and cannot provide the specific reasons for it. '
            + '(Consumer reporting agency contact details are provided with the report source '
            + 'and will be itemized here once the credit-bureau integration is enabled.)';
    }
}
