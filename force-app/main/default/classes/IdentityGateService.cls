/**
 * IdentityGateService — the KYC/OFAC GATING PRECONDITION, OUTSIDE the pure kernel.
 *
 * ADR-24 (ratified) + DESIGN-kyc-ofac.md §5.2: identity verification (KYC/CIP) and
 * OFAC sanctions screening are preconditions evaluated BEFORE any policy verdict —
 * NEVER modeled as Policy_Rule__c rows and NEVER entering PolicyRuleEvaluator. This
 * service GATES; it does not decide creditworthiness and it never writes.
 *
 * Orthogonal axes: an uncleared sanctions screen (or an absent one) BLOCKS a loan
 * regardless of the policy verdict — a 760 FICO / 20% DTI borrower with a
 * Confirmed_Match is still blocked; and conversely a clean screen never *improves*
 * a policy decline. The two axes do not mix (this is exactly why sanctions are not
 * kernel rules: worst-wins must never collapse a sanctions hit into an ECOA-wrong
 * creditworthiness HARD_DECLINE — ADR-24 rejected alternative).
 *
 * The ADR-3 asymmetry is deliberately inverted here: a missing borrower *fact* is
 * INDETERMINATE (never a decline) for progressive onboarding, but a missing sanctions
 * *screen* is a HARD BLOCK — absence of proof of clearance is not clearance
 * (OQ-R8-2, Knuth's recommendation; compliance sign-off still outstanding, R-8).
 *
 * Gate logic per loan (first match wins, precedence per §5.2):
 *   1. Identity_Verification_Status__c != 'Verified'      → KYC_INCOMPLETE
 *   2. no Sanctions_Screening__c on file                  → SCREEN_MISSING (hard block)
 *   3. newest Sanctions_Screening__c.Result__c != 'Clear' → SANCTIONS_HOLD
 *   else                                                  → not blocked
 * "Newest" = greatest Screened_At__c (the current disposition; the chain is history).
 *
 * Purity / bulk-safety: hoisted reads only, ZERO DML. evaluate(Set<Id>) spends
 * exactly 2 SOQL for N loans (one loan-status read, one screening read); the
 * pre-hoisted overload spends 1 SOQL (screening only) for callers that already hold
 * the identity status (e.g. CaseSummaryService reads it off its existing case join).
 *
 * BOUNDARY (do not cross): this is a PRESENT-STATE precondition. It is intentionally
 * NOT wired into PolicyRuleEvaluator (must stay pure, ADR-5), ReplayService, or
 * SecondPassSweepBatch (the sweep re-runs decision *history*; gating is about the
 * loan's state right now — a screen recorded after a historical decision must not
 * retroactively rewrite that decision's replay). Wire it only where a present-tense
 * verdict is surfaced to a human (e.g. CaseSummaryService Phase-2, LoanDecisionService).
 *
 * @group KYC-OFAC
 */
public with sharing class IdentityGateService {

    @TestVisible private static final String KYC_INCOMPLETE = 'KYC_INCOMPLETE';
    @TestVisible private static final String SANCTIONS_HOLD = 'SANCTIONS_HOLD';
    @TestVisible private static final String SCREEN_MISSING = 'SCREEN_MISSING';

    private static final String VERIFIED = 'Verified';
    private static final String CLEAR    = 'Clear';

    /** Outcome of gating a single loan. Present-state precondition, not a policy verdict. */
    public class GateResult {
        public Boolean blocked;
        public String  blockCode;   // KYC_INCOMPLETE | SANCTIONS_HOLD | SCREEN_MISSING | null
        public String  reason;      // plain-words narration (RuleNarration style)
    }

    /**
     * Full gate: reads identity status AND screenings for the given loans.
     * Contract: 2 SOQL for N loans, 0 DML.
     */
    public static Map<Id, GateResult> evaluate(Set<Id> loanIds) {
        if (loanIds == null || loanIds.isEmpty()) {
            return new Map<Id, GateResult>();
        }
        Map<Id, String> identityStatusByLoan = new Map<Id, String>();
        for (Loan__c ln : [
            SELECT Id, Identity_Verification_Status__c
            FROM Loan__c
            WHERE Id IN :loanIds
            WITH USER_MODE
        ]) {                                                         // SOQL 1
            identityStatusByLoan.put(ln.Id, ln.Identity_Verification_Status__c);
        }
        return evaluate(loanIds, identityStatusByLoan);              // SOQL 2 (inside)
    }

    /**
     * Pre-hoisted gate for callers that already hold the identity status per loan
     * (avoids a redundant Loan__c read). Contract: 1 SOQL for N loans, 0 DML.
     * A loanId absent from identityStatusByLoan is treated as unverified (blocked),
     * fail-closed — an unknown identity is never a pass.
     */
    public static Map<Id, GateResult> evaluate(
        Set<Id> loanIds, Map<Id, String> identityStatusByLoan) {

        Map<Id, GateResult> results = new Map<Id, GateResult>();
        if (loanIds == null || loanIds.isEmpty()) {
            return results;
        }
        Map<Id, String> statuses = (identityStatusByLoan == null)
            ? new Map<Id, String>() : identityStatusByLoan;

        // Newest screening result per loan (ASC => last write wins => greatest Screened_At__c).
        //
        // Deliberate system-mode read (NO WITH USER_MODE): Sanctions_Screening__c is under
        // need-to-know isolation per ADR-24 (KYC-Officer permset only, kept OFF the auditor/
        // engine permset). The gate is privileged precondition INFRASTRUCTURE — it must be
        // able to check the screen on the caller's behalf even when the caller (e.g. an
        // auditor) lacks object access, and it returns ONLY the verdict + disposition label
        // (never SSN, never Match_Details__c). Sharing is still honoured (with sharing class).
        // Only the required Result__c/Screened_At__c/Loan__c fields are selected.
        Map<Id, String> newestResultByLoan = new Map<Id, String>();
        for (Sanctions_Screening__c s : [
            SELECT Loan__c, Result__c, Screened_At__c
            FROM Sanctions_Screening__c
            WHERE Loan__c IN :loanIds
            ORDER BY Screened_At__c ASC
        ]) {                                                         // SOQL (screening)
            newestResultByLoan.put(s.Loan__c, s.Result__c);
        }

        for (Id loanId : loanIds) {
            results.put(loanId,
                gateOne(statuses.get(loanId), newestResultByLoan, loanId));
        }
        return results;
    }

    // ── Pure decision for one loan (no SOQL, no DML) ─────────────────────────
    private static GateResult gateOne(
        String identityStatus, Map<Id, String> newestResultByLoan, Id loanId) {

        GateResult g = new GateResult();

        if (identityStatus != VERIFIED) {
            g.blocked   = true;
            g.blockCode = KYC_INCOMPLETE;
            g.reason    = 'Identity verification is not complete for this loan (status: '
                + (String.isBlank(identityStatus) ? 'none on file' : RuleNarration.label(identityStatus))
                + '). Origination is blocked until the borrower\'s identity is verified.';
            return g;
        }

        if (!newestResultByLoan.containsKey(loanId)) {
            g.blocked   = true;
            g.blockCode = SCREEN_MISSING;
            g.reason    = 'No sanctions screening is on file for this loan. Absence of a '
                + 'screen is not clearance — origination is blocked until a screening is recorded.';
            return g;
        }

        String newest = newestResultByLoan.get(loanId);
        if (newest != CLEAR) {
            g.blocked   = true;
            g.blockCode = SANCTIONS_HOLD;
            g.reason    = 'The most recent sanctions screening returned "'
                + RuleNarration.label(newest) + '" (not Clear). Origination is on a sanctions '
                + 'hold and cannot proceed regardless of the policy decision.';
            return g;
        }

        g.blocked   = false;
        g.blockCode = null;
        g.reason    = 'Identity is verified and the latest sanctions screening is clear.';
        return g;
    }
}
