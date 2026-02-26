@IsTest
private class StandardLeadControllerTest {
    @IsTest
    static void testPicklistFetchers() {
        Test.startTest();
        List<String> leadTypes = StandardLeadController.getLeadTypes();
        List<String> salutations = StandardLeadController.getSalutations();
        List<String> leadSources = StandardLeadController.getLeadSources();
        List<String> leadCategories = StandardLeadController.getLeadCategories();
        List<String> states = StandardLeadController.getStates();
        List<String> districts = StandardLeadController.getDistricts();
        List<String> panchayaths = StandardLeadController.getPanchayaths();
        List<String> countries = StandardLeadController.getCountries();
        List<String> unqualifiedReasons = StandardLeadController.getUnqualifiedReasons();
        Test.stopTest();

        System.assertNotEquals(null, leadTypes);
        System.assertNotEquals(null, salutations);
        System.assertNotEquals(null, leadSources);
        System.assertNotEquals(null, leadCategories);
        System.assertNotEquals(null, states);
        System.assertNotEquals(null, districts);
        System.assertNotEquals(null, panchayaths);
        System.assertNotEquals(null, countries);
        System.assertNotEquals(null, unqualifiedReasons);
    }

}