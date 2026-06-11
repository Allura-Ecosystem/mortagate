/**
 * Unit tests for AdverseActionService — pure, no DML/SOQL, runs without the org.
 * They pin the regulated behavior: adverse-action determination, specific principal
 * reasons (1002.9(b)(2)), HARD_DECLINE prioritization, the four-reason cap and dedupe,
 * the 701(a) agency-token resolution, the FCRA score block, and graceful degradation.
 */
@isTest
private class AdverseActionServiceTest {

    private static AdverseActionService.Config cfg() {
        AdverseActionService.Config c = new AdverseActionService.Config();
        c.creditorName = 'Veridact Lending';
        c.creditorAddress = '1 Market Street, San Francisco, CA 94105';
        c.agencyName = 'Consumer Financial Protection Bureau';
        c.agencyAddress = '1700 G Street NW, Washington, DC 20006';
        c.ecoaNoticeTemplate = 'The Federal Equal Credit Opportunity Act prohibits creditors '
            + 'from discriminating... The Federal agency that administers compliance with this '
            + 'law concerning this creditor is [AGENCY].';
        c.reasonLimit = 4;
        c.noticeWindowDays = 30;
        return c;
    }

    private static AdverseActionService.FailingRule fr(String expl, String code, String sev) {
        return new AdverseActionService.FailingRule(expl, code, sev);
    }

    @isTest
    static void hardDeclined_isAdverseAction() {
        AdverseActionService.Notice n = AdverseActionService.build(
            'HARD_DECLINED', new List<AdverseActionService.FailingRule>(), null, cfg(), 'Dana Lee', Date.today());
        System.assertEquals(true, n.isAdverseAction, 'HARD_DECLINED is adverse action');
        System.assert(n.actionStatement.toLowerCase().contains('unable to approve'),
            'Adverse statement should state the action taken');
    }

    @isTest
    static void approved_isNotAdverseAction() {
        AdverseActionService.Notice n = AdverseActionService.build(
            'APPROVED', new List<AdverseActionService.FailingRule>(), null, cfg(), 'Dana Lee', Date.today());
        System.assertEquals(false, n.isAdverseAction, 'APPROVED is not adverse action');
    }

    @isTest
    static void reasons_areSpecificFromExplanations() {
        List<AdverseActionService.FailingRule> failing = new List<AdverseActionService.FailingRule>{
            fr('Your debt-to-income ratio exceeds our threshold of 43%.', 'DTI_MAX', 'HARD_DECLINE')
        };
        AdverseActionService.Notice n = AdverseActionService.build(
            'HARD_DECLINED', failing, null, cfg(), 'Dana Lee', Date.today());
        System.assertEquals(1, n.reasons.size());
        System.assert(n.reasons[0].text.contains('43%'), 'Reason carries the specific explanation');
    }

    @isTest
    static void reasons_hardDeclineComesFirst() {
        List<AdverseActionService.FailingRule> failing = new List<AdverseActionService.FailingRule>{
            fr('Soft warning about employment length.', 'EMP_MONTHS', 'SOFT_DECLINE'),
            fr('Loan-to-value ratio is too high for this program.', 'LTV_MAX', 'HARD_DECLINE')
        };
        AdverseActionService.Notice n = AdverseActionService.build(
            'HARD_DECLINED', failing, null, cfg(), 'Dana Lee', Date.today());
        System.assertEquals('LTV_MAX', n.reasons[0].ruleCode, 'HARD_DECLINE reason is ranked first');
    }

    @isTest
    static void reasons_cappedAtLimit() {
        List<AdverseActionService.FailingRule> failing = new List<AdverseActionService.FailingRule>();
        for (Integer i = 0; i < 7; i++) {
            failing.add(fr('Specific reason number ' + i + '.', 'RULE_' + i, 'HARD_DECLINE'));
        }
        AdverseActionService.Config c = cfg();
        c.reasonLimit = 4;
        AdverseActionService.Notice n = AdverseActionService.build(
            'HARD_DECLINED', failing, null, c, 'Dana Lee', Date.today());
        System.assertEquals(4, n.reasons.size(), 'No more than the configured cap of reasons');
    }

    @isTest
    static void reasons_areDeduped() {
        List<AdverseActionService.FailingRule> failing = new List<AdverseActionService.FailingRule>{
            fr('Your debt-to-income ratio exceeds our threshold of 43%.', 'DTI_MAX', 'HARD_DECLINE'),
            fr('Your debt-to-income ratio exceeds our threshold of 43%.', 'DTI_DUP', 'HARD_DECLINE')
        };
        AdverseActionService.Notice n = AdverseActionService.build(
            'HARD_DECLINED', failing, null, cfg(), 'Dana Lee', Date.today());
        System.assertEquals(1, n.reasons.size(), 'Identical explanations collapse to one reason');
    }

    @isTest
    static void blankExplanations_areSkipped() {
        List<AdverseActionService.FailingRule> failing = new List<AdverseActionService.FailingRule>{
            fr('', 'EMPTY', 'HARD_DECLINE'),
            fr(null, 'NULLX', 'HARD_DECLINE'),
            fr('A real, specific reason.', 'REAL', 'HARD_DECLINE')
        };
        AdverseActionService.Notice n = AdverseActionService.build(
            'HARD_DECLINED', failing, null, cfg(), 'Dana Lee', Date.today());
        System.assertEquals(1, n.reasons.size(), 'Blank/null explanations are not disclosed');
        System.assertEquals('REAL', n.reasons[0].ruleCode);
    }

    @isTest
    static void ecoaNotice_resolvesAgencyToken() {
        AdverseActionService.Notice n = AdverseActionService.build(
            'HARD_DECLINED', new List<AdverseActionService.FailingRule>(), null, cfg(), 'Dana Lee', Date.today());
        System.assert(!n.ecoaNotice.contains('[AGENCY]'), 'The [AGENCY] token must be replaced');
        System.assert(n.ecoaNotice.contains('Consumer Financial Protection Bureau'),
            'Agency name folded into the notice');
        System.assert(n.ecoaNotice.contains('1700 G Street'), 'Agency address folded into the notice');
    }

    @isTest
    static void creditScore_producesDisclosure() {
        AdverseActionService.Notice n = AdverseActionService.build(
            'HARD_DECLINED', new List<AdverseActionService.FailingRule>(), 612, cfg(), 'Dana Lee', Date.today());
        System.assertEquals(true, n.creditScoreDisclosed);
        System.assertEquals(612, n.creditScore);
        System.assert(n.scoreDisclosure.contains('612'), 'Score is disclosed');
        System.assert(n.scoreDisclosure.contains('60 days'), 'FCRA free-report window disclosed');
        System.assert(n.scoreDisclosure.toLowerCase().contains('dispute'), 'Right to dispute disclosed');
    }

    @isTest
    static void noCreditScore_noDisclosure() {
        AdverseActionService.Notice n = AdverseActionService.build(
            'HARD_DECLINED', new List<AdverseActionService.FailingRule>(), null, cfg(), 'Dana Lee', Date.today());
        System.assertEquals(false, n.creditScoreDisclosed);
        System.assertEquals(null, n.scoreDisclosure);
    }

    @isTest
    static void respondByDate_usesConfiguredWindow() {
        Date today = Date.newInstance(2026, 1, 1);
        AdverseActionService.Notice n = AdverseActionService.build(
            'HARD_DECLINED', new List<AdverseActionService.FailingRule>(), null, cfg(), 'Dana Lee', today);
        System.assertEquals(today.addDays(30), n.respondByDate, 'Window is noticeDate + 30');
    }

    @isTest
    static void nullConfig_degradesGracefully() {
        AdverseActionService.Notice n = AdverseActionService.build(
            'HARD_DECLINED', new List<AdverseActionService.FailingRule>(), null, null, null, null);
        System.assertEquals(true, n.isAdverseAction);
        System.assertEquals('Applicant', n.applicantName, 'Blank name defaults safely');
        System.assertEquals('', n.ecoaNotice, 'No template yields empty, not an exception');
        System.assertNotEquals(null, n.respondByDate, 'Defaults to a 30-day window');
    }

    @isTest
    static void doesNotEmitForbiddenScoreOnlyPhrasing() {
        // 1002.9(b)(2): "failed to achieve a qualifying score" is INSUFFICIENT as a reason.
        // Our reasons come from rule explanations, never that boilerplate.
        List<AdverseActionService.FailingRule> failing = new List<AdverseActionService.FailingRule>{
            fr('Your verified income does not support the requested loan amount.', 'INC_MIN', 'HARD_DECLINE')
        };
        AdverseActionService.Notice n = AdverseActionService.build(
            'HARD_DECLINED', failing, 612, cfg(), 'Dana Lee', Date.today());
        for (AdverseActionService.PrincipalReason r : n.reasons) {
            System.assert(!r.text.toLowerCase().contains('qualifying score'),
                'Reasons must be specific, not score-boilerplate');
            System.assert(!r.text.toLowerCase().contains('internal standards'),
                'Reasons must be specific, not "internal standards"');
        }
    }
}
