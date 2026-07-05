/**
 * IdentityGateServiceTest — proves the KYC/OFAC gating precondition (ADR-24):
 *   • Verified identity + Clear screen           → NOT blocked
 *   • Confirmed_Match (identity Verified)         → SANCTIONS_HOLD (orthogonal to policy)
 *   • Potential_Match / Pending_Review            → SANCTIONS_HOLD
 *   • NO screening on file                        → SCREEN_MISSING (absence ≠ clearance)
 *   • Pending / Failed / Not_Started identity     → KYC_INCOMPLETE (precedence over screen)
 *   • newest Screened_At__c wins                  → a later Clear clears an earlier hit
 *   • bulk-200                                    → ≤2 SOQL, 0 DML
 *   • pre-hoisted overload                        → 1 SOQL, 0 DML
 *
 * The gate reads present state only — it never runs replay and writes nothing.
 */
@IsTest
private class IdentityGateServiceTest {

    private static Loan__c makeLoan(String status) {
        Loan__c ln = new Loan__c(
            Borrower_Name__c = 'Party', Loan_Amount__c = 250000, Property_Value__c = 400000,
            Loan_Type__c = 'Conventional', Purpose__c = 'Purchase', Approval_Date__c = Date.today(),
            Identity_Verification_Status__c = status);
        insert ln;
        return ln;
    }

    private static void screen(Id loanId, String result, Datetime at) {
        insert new Sanctions_Screening__c(
            Loan__c = loanId, Result__c = result, List_Source__c = 'OFAC_SDN',
            List_Version__c = 'OFAC-SDN-2026-06-18', Screened_At__c = at);
    }

    @IsTest
    static void verifiedAndClear_isNotBlocked() {
        Loan__c ln = makeLoan('Verified');
        screen(ln.Id, 'Clear', Datetime.now());

        Map<Id, IdentityGateService.GateResult> out =
            IdentityGateService.evaluate(new Set<Id>{ ln.Id });

        IdentityGateService.GateResult g = out.get(ln.Id);
        System.assertEquals(false, g.blocked, 'Verified + Clear passes the gate');
        System.assertEquals(null, g.blockCode, 'No block code on a clean gate');
        System.assert(g.reason.contains('clear'), 'Clean reason narrated');
    }

    @IsTest
    static void confirmedMatch_isSanctionsHold_evenWithVerifiedIdentity() {
        // Orthogonality: identity is Verified (KYC passes) — a Confirmed_Match still
        // BLOCKS. The gate never consults any policy/replay verdict; a sanctions hit is
        // categorically separate from creditworthiness.
        Loan__c ln = makeLoan('Verified');
        screen(ln.Id, 'Confirmed_Match', Datetime.now());

        IdentityGateService.GateResult g =
            IdentityGateService.evaluate(new Set<Id>{ ln.Id }).get(ln.Id);

        System.assertEquals(true, g.blocked, 'Confirmed_Match blocks regardless of policy');
        System.assertEquals('SANCTIONS_HOLD', g.blockCode, 'Sanctions hold, not a KYC block');
        System.assert(g.reason.contains('Confirmed Match'), 'Names the disposition plainly');
    }

    @IsTest
    static void potentialMatch_isSanctionsHold() {
        Loan__c ln = makeLoan('Verified');
        screen(ln.Id, 'Potential_Match', Datetime.now());
        IdentityGateService.GateResult g =
            IdentityGateService.evaluate(new Set<Id>{ ln.Id }).get(ln.Id);
        System.assertEquals(true, g.blocked, 'Uncleared potential match blocks');
        System.assertEquals('SANCTIONS_HOLD', g.blockCode, 'Sanctions hold');
    }

    @IsTest
    static void pendingReview_isSanctionsHold() {
        Loan__c ln = makeLoan('Verified');
        screen(ln.Id, 'Pending_Review', Datetime.now());
        IdentityGateService.GateResult g =
            IdentityGateService.evaluate(new Set<Id>{ ln.Id }).get(ln.Id);
        System.assertEquals(true, g.blocked, 'Pending review is not clearance');
        System.assertEquals('SANCTIONS_HOLD', g.blockCode, 'Sanctions hold');
    }

    @IsTest
    static void noScreeningOnFile_isScreenMissing() {
        // The absence≠clearance pin: identity Verified, but no screen recorded => hard BLOCK.
        Loan__c ln = makeLoan('Verified');
        IdentityGateService.GateResult g =
            IdentityGateService.evaluate(new Set<Id>{ ln.Id }).get(ln.Id);
        System.assertEquals(true, g.blocked, 'A missing screen is a hard block');
        System.assertEquals('SCREEN_MISSING', g.blockCode, 'Absence of a screen is not clearance');
        System.assert(g.reason.contains('not clearance'), 'Reason states absence ≠ clearance');
    }

    @IsTest
    static void unverifiedIdentity_isKycIncomplete_regardlessOfScreen() {
        // KYC precedence: even with a Clear screen on file, an unverified identity blocks.
        for (String status : new List<String>{ 'Pending', 'Failed', 'Not_Started', 'Manual_Review' }) {
            Loan__c ln = makeLoan(status);
            screen(ln.Id, 'Clear', Datetime.now());
            IdentityGateService.GateResult g =
                IdentityGateService.evaluate(new Set<Id>{ ln.Id }).get(ln.Id);
            System.assertEquals(true, g.blocked, status + ' identity blocks');
            System.assertEquals('KYC_INCOMPLETE', g.blockCode,
                status + ' => KYC_INCOMPLETE, ahead of the screen check');
        }
    }

    @IsTest
    static void newestScreeningWins_laterClearClearsEarlierHit() {
        Loan__c ln = makeLoan('Verified');
        screen(ln.Id, 'Confirmed_Match', Datetime.now().addDays(-5)); // older hit
        screen(ln.Id, 'Clear',           Datetime.now());             // newer clear

        IdentityGateService.GateResult g =
            IdentityGateService.evaluate(new Set<Id>{ ln.Id }).get(ln.Id);
        System.assertEquals(false, g.blocked, 'Newest Screened_At__c (Clear) governs');

        // And the reverse ordering => the newer hit governs and blocks.
        Loan__c ln2 = makeLoan('Verified');
        screen(ln2.Id, 'Clear',           Datetime.now().addDays(-5));
        screen(ln2.Id, 'Confirmed_Match', Datetime.now());
        IdentityGateService.GateResult g2 =
            IdentityGateService.evaluate(new Set<Id>{ ln2.Id }).get(ln2.Id);
        System.assertEquals(true, g2.blocked, 'Newer hit governs over an older clear');
        System.assertEquals('SANCTIONS_HOLD', g2.blockCode, 'Sanctions hold on the newest screen');
    }

    @IsTest
    static void bulk200_isWithin2Soql_and0Dml() {
        List<Loan__c> loans = new List<Loan__c>();
        for (Integer i = 0; i < 200; i++) {
            loans.add(new Loan__c(Borrower_Name__c = 'Bulk ' + i, Loan_Amount__c = 250000,
                Property_Value__c = 400000, Loan_Type__c = 'Conventional', Purpose__c = 'Purchase',
                Approval_Date__c = Date.today(), Identity_Verification_Status__c = 'Verified'));
        }
        insert loans;
        List<Sanctions_Screening__c> screens = new List<Sanctions_Screening__c>();
        for (Integer i = 0; i < 200; i++) {
            // Mix outcomes so the fold is exercised across all rows.
            String res = (Math.mod(i, 2) == 0) ? 'Clear' : 'Confirmed_Match';
            screens.add(new Sanctions_Screening__c(Loan__c = loans[i].Id, Result__c = res,
                List_Source__c = 'OFAC_SDN', List_Version__c = 'v', Screened_At__c = Datetime.now()));
        }
        insert screens;

        Set<Id> loanIds = new Map<Id, Loan__c>(loans).keySet();

        Test.startTest();
        Integer soqlBefore = Limits.getQueries();
        Integer dmlBefore  = Limits.getDmlStatements();
        Map<Id, IdentityGateService.GateResult> out = IdentityGateService.evaluate(loanIds);
        Integer soqlUsed = Limits.getQueries() - soqlBefore;
        Integer dmlUsed  = Limits.getDmlStatements() - dmlBefore;
        Test.stopTest();

        System.assertEquals(200, out.size(), 'One result per loan');
        System.assert(soqlUsed <= 2, 'At most 2 SOQL for N loans, got ' + soqlUsed);
        System.assertEquals(0, dmlUsed, 'The gate writes nothing');

        Integer blocked = 0;
        for (IdentityGateService.GateResult g : out.values()) {
            if (g.blocked) { blocked++; }
        }
        System.assertEquals(100, blocked, 'Half (the Confirmed_Match loans) are gated');
    }

    @IsTest
    static void preHoistedOverload_spendsOnly1Soql() {
        Loan__c ln = makeLoan('Verified');
        screen(ln.Id, 'Clear', Datetime.now());
        Map<Id, String> statusByLoan = new Map<Id, String>{ ln.Id => 'Verified' };

        Test.startTest();
        Integer soqlBefore = Limits.getQueries();
        Map<Id, IdentityGateService.GateResult> out =
            IdentityGateService.evaluate(new Set<Id>{ ln.Id }, statusByLoan);
        Integer soqlUsed = Limits.getQueries() - soqlBefore;
        Test.stopTest();

        System.assert(soqlUsed <= 1, 'Pre-hoisted overload reads only screenings, got ' + soqlUsed);
        System.assertEquals(false, out.get(ln.Id).blocked, 'Verified + Clear passes');
    }

    @IsTest
    static void emptyInput_isEmptyMap_noSoql() {
        Test.startTest();
        Integer soqlBefore = Limits.getQueries();
        Map<Id, IdentityGateService.GateResult> out =
            IdentityGateService.evaluate(new Set<Id>());
        Integer soqlUsed = Limits.getQueries() - soqlBefore;
        Test.stopTest();
        System.assertEquals(0, out.size(), 'Empty in, empty out');
        System.assertEquals(0, soqlUsed, 'No query on an empty set');
    }
}
