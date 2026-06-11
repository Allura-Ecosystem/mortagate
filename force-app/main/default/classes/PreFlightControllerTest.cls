@IsTest
private class PreFlightControllerTest {

    @IsTest
    static void getBand_returnsPopulatedMap() {
        PolicyEngineTestFactory.standardRules();
        Test.startTest();
        Map<String, Object> band = PreFlightController.getBand(150000, 400000, 'CONVENTIONAL');
        Test.stopTest();

        System.assertEquals('LIKELY_ELIGIBLE', band.get('eligibility'));
        System.assert((Decimal) band.get('highEstimate') > (Decimal) band.get('lowEstimate'));
        System.assert(String.isNotBlank((String) band.get('guidance')));
    }

    @IsTest
    static void getBand_defaultsLoanType() {
        Map<String, Object> band = PreFlightController.getBand(120000, 350000, null);
        System.assertNotEquals(null, band.get('eligibility'));
    }
}
