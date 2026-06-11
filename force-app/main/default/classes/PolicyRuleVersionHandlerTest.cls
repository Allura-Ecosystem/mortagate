/**
 * Proves the FR-17 analyst rule-versioning invariants — the feature that lets
 * non-developers version policy without a deployment, safely:
 *
 *  - Auto-versioning: Version_Number__c is assigned, not typed (monotonic per code).
 *  - Supersession: vN+1 expires the prior active version and links Supersedes__c.
 *  - Immutability after reference: LOGIC fields lock once a version has governed a
 *    decision; lifecycle fields stay settable so supersession can still expire it.
 *  - No deletes: a version the audit trail may point to is never removed.
 *
 * Each invariant is enforced by the trigger, not asserted in prose.
 */
@IsTest
private class PolicyRuleVersionHandlerTest {

    private static Policy_Rule_Version__c newRule(String code, Decimal threshold) {
        return new Policy_Rule_Version__c(
            Rule_Code__c = code,
            Rule_Label__c = code,
            Rule_Category__c = 'INCOME',
            Fact_Field__c = 'DTI_Ratio__c',
            Operator__c = 'LTE',
            Threshold_Value__c = threshold,
            Severity__c = 'HARD_DECLINE',
            Rule_Explanation__c = code + ' explanation',
            Effective_Date__c = Date.today(),
            Is_Active__c = true
            // Version_Number__c intentionally omitted — the trigger assigns it.
        );
    }

    // ---- Auto-versioning ----------------------------------------------------
    @IsTest
    static void firstVersion_isOne() {
        Policy_Rule_Version__c r = newRule('DTI_MAX', 0.43);
        insert r;
        r = [SELECT Version_Number__c, Supersedes__c FROM Policy_Rule_Version__c WHERE Id = :r.Id];
        System.assertEquals(1, r.Version_Number__c.intValue(), 'First version must be 1');
        System.assertEquals(null, r.Supersedes__c, 'First version supersedes nothing');
    }

    @IsTest
    static void bulkInsert_sameCode_versionsAreMonotonic() {
        List<Policy_Rule_Version__c> batch = new List<Policy_Rule_Version__c>{
            newRule('FICO_MIN', 620), newRule('FICO_MIN', 640), newRule('FICO_MIN', 660)
        };
        insert batch;
        Set<Integer> seen = new Set<Integer>();
        for (Policy_Rule_Version__c r : [
                SELECT Version_Number__c FROM Policy_Rule_Version__c WHERE Rule_Code__c = 'FICO_MIN']) {
            seen.add(r.Version_Number__c.intValue());
        }
        System.assertEquals(new Set<Integer>{ 1, 2, 3 }, seen,
            'Three same-code inserts must take versions 1,2,3 with no collisions');
    }

    // ---- Supersession -------------------------------------------------------
    @IsTest
    static void secondVersion_supersedesAndExpiresPrior() {
        Policy_Rule_Version__c v1 = newRule('LTV_MAX', 0.97);
        insert v1;

        Test.startTest();
        Policy_Rule_Version__c v2 = newRule('LTV_MAX', 0.95);
        v2.Effective_Date__c = Date.today().addDays(1);
        insert v2;
        Test.stopTest();

        v2 = [SELECT Version_Number__c, Supersedes__c, Effective_Date__c FROM Policy_Rule_Version__c WHERE Id = :v2.Id];
        System.assertEquals(2, v2.Version_Number__c.intValue(), 'Second version must be 2');
        System.assertEquals(v1.Id, v2.Supersedes__c, 'v2 must link the prior governing version');

        v1 = [SELECT Is_Active__c, Expiration_Date__c FROM Policy_Rule_Version__c WHERE Id = :v1.Id];
        System.assertEquals(false, v1.Is_Active__c, 'Prior version must be deactivated');
        System.assertEquals(v2.Effective_Date__c, v1.Expiration_Date__c,
            'Prior version must expire as the new one takes effect');
    }

    // ---- Immutability after reference --------------------------------------
    @IsTest
    static void logicChange_onReferencedVersion_isBlocked() {
        Policy_Rule_Version__c r = newRule('DTI_REF', 0.43);
        insert r;
        referenceWithDecision(r.Id);

        r.Threshold_Value__c = 0.50; // a LOGIC field
        Test.startTest();
        Database.SaveResult sr = Database.update(r, false);
        Test.stopTest();

        System.assert(!sr.isSuccess(), 'Logic edit on a cited version must be rejected');
        System.assert(sr.getErrors()[0].getMessage().contains('locked'),
            'Error should explain the version is locked');
    }

    @IsTest
    static void lifecycleChange_onReferencedVersion_isAllowed() {
        Policy_Rule_Version__c r = newRule('DTI_LIFE', 0.43);
        insert r;
        referenceWithDecision(r.Id);

        r.Expiration_Date__c = Date.today().addDays(10);
        r.Is_Active__c = false; // lifecycle fields — supersession must still work
        Test.startTest();
        Database.SaveResult sr = Database.update(r, false);
        Test.stopTest();

        System.assert(sr.isSuccess(),
            'Lifecycle edit on a cited version must be allowed so supersession can expire it');
    }

    @IsTest
    static void logicChange_onUnreferencedVersion_isAllowed() {
        Policy_Rule_Version__c r = newRule('DTI_FREE', 0.43);
        insert r;

        r.Threshold_Value__c = 0.50;
        Test.startTest();
        Database.SaveResult sr = Database.update(r, false);
        Test.stopTest();

        System.assert(sr.isSuccess(),
            'A version never cited by a decision is still freely editable');
    }

    // ---- No deletes ---------------------------------------------------------
    @IsTest
    static void delete_isBlocked() {
        Policy_Rule_Version__c r = newRule('DTI_DEL', 0.43);
        insert r;

        Test.startTest();
        Database.DeleteResult dr = Database.delete(r, false);
        Test.stopTest();

        System.assert(!dr.isSuccess(), 'Rule versions must never be deletable');
        System.assert(dr.getErrors()[0].getMessage().contains('cannot be deleted'));
        System.assertEquals(1, [SELECT COUNT() FROM Policy_Rule_Version__c WHERE Id = :r.Id]);
    }

    /** Cite a rule version from a committed decision so the immutability lock engages. */
    private static void referenceWithDecision(Id ruleVersionId) {
        Loan_Application__c app = PolicyEngineTestFactory.application();
        insert app;
        insert new Decision_Event__c(
            Application__c = app.Id,
            Rule_Version__c = ruleVersionId,
            Outcome__c = 'HARD_DECLINED',
            Rule_Results_JSON__c = '[]',
            Evaluated_Rule_Count__c = 1,
            Hard_Decline_Count__c = 1,
            Decision_Timestamp__c = Datetime.now(),
            Triggered_By__c = 'SYSTEM'
        );
    }
}
