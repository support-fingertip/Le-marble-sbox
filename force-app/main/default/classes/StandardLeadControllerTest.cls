@IsTest
private class StandardLeadControllerTest {
    private class MockHttpCallout implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"success":true}');
            res.setStatusCode(200);
            return res;
        }
    }

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

    @IsTest
    static void testCreateLeadWithValidPinCode() {
        Test.setMock(HttpCalloutMock.class, new MockHttpCallout());

        Map<String, Object> leadData = new Map<String, Object>{
            'firstName' => 'Pin',
            'lastName' => 'Valid',
            'company' => 'Test Company',
            'primaryPhone' => '919876540001',
            'pinCode' => '673001'
        };

        Test.startTest();
        Id leadId = StandardLeadController.createLead(leadData);
        Test.stopTest();

        Lead createdLead = [SELECT Id, Pin_Code__c FROM Lead WHERE Id = :leadId LIMIT 1];
        System.assertEquals(Decimal.valueOf('673001'), createdLead.Pin_Code__c);
    }

    @IsTest
    static void testCreateLeadWithInvalidPinCode() {
        Map<String, Object> leadData = new Map<String, Object>{
            'firstName' => 'Pin',
            'lastName' => 'Invalid',
            'company' => 'Test Company',
            'primaryPhone' => '919876540002',
            'pinCode' => '67A001'
        };

        Boolean exceptionThrown = false;

        try {
            Test.startTest();
            StandardLeadController.createLead(leadData);
            Test.stopTest();
        } catch (AuraHandledException ex) {
            exceptionThrown = true;
        }

        System.assertEquals(true, exceptionThrown, 'Expected pin code validation exception.');
    }

}