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

    // ═══════════════════════════════════════════════════════════════════
    //  Picklist fetchers
    // ═══════════════════════════════════════════════════════════════════

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

    // ═══════════════════════════════════════════════════════════════════
    //  createLead — valid pin code
    // ═══════════════════════════════════════════════════════════════════

    @IsTest
    static void testCreateLeadWithValidPinCode() {
        Test.setMock(HttpCalloutMock.class, new MockHttpCallout());

        Map<String, Object> leadData = new Map<String, Object>{
            'firstName' => 'Pin',
            'lastName' => 'Valid',
            'company' => 'Test Company',
            'primaryPhone' => '9876540001',
            'pinCode' => '673001',
            'country' => 'IN'
        };

        Test.startTest();
        Id leadId = StandardLeadController.createLead(leadData);
        Test.stopTest();

        Lead createdLead = [SELECT Id, Pin_Code__c FROM Lead WHERE Id = :leadId LIMIT 1];
        System.assertEquals(Decimal.valueOf('673001'), createdLead.Pin_Code__c);
    }

    // ═══════════════════════════════════════════════════════════════════
    //  createLead — invalid pin code (non-numeric)
    // ═══════════════════════════════════════════════════════════════════

    @IsTest
    static void testCreateLeadWithInvalidPinCode() {
        Map<String, Object> leadData = new Map<String, Object>{
            'firstName' => 'Pin',
            'lastName' => 'Invalid',
            'company' => 'Test Company',
            'primaryPhone' => '9876540002',
            'pinCode' => '67A001',
            'country' => 'IN'
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

    // ═══════════════════════════════════════════════════════════════════
    //  createLead — pin code too short (not 6 digits)
    // ═══════════════════════════════════════════════════════════════════

    @IsTest
    static void testCreateLeadWithShortPinCode() {
        Map<String, Object> leadData = new Map<String, Object>{
            'firstName' => 'Pin',
            'lastName' => 'Short',
            'company' => 'Test Company',
            'primaryPhone' => '9876540003',
            'pinCode' => '12345',
            'country' => 'IN'
        };

        Boolean exceptionThrown = false;

        try {
            Test.startTest();
            StandardLeadController.createLead(leadData);
            Test.stopTest();
        } catch (AuraHandledException ex) {
            exceptionThrown = true;
        }

        System.assertEquals(true, exceptionThrown, 'Expected pin code validation exception for short pin.');
    }

    // ═══════════════════════════════════════════════════════════════════
    //  createLead — null pin code (should skip validation)
    // ═══════════════════════════════════════════════════════════════════

    @IsTest
    static void testCreateLeadWithNullPinCode() {
        Test.setMock(HttpCalloutMock.class, new MockHttpCallout());

        Map<String, Object> leadData = new Map<String, Object>{
            'firstName' => 'Pin',
            'lastName' => 'Null',
            'company' => 'Test Company',
            'primaryPhone' => '9876540004',
            'pinCode' => null,
            'country' => 'IN'
        };

        Test.startTest();
        Id leadId = StandardLeadController.createLead(leadData);
        Test.stopTest();

        System.assertNotEquals(null, leadId, 'Lead should be created with null pin code');
    }

    // ═══════════════════════════════════════════════════════════════════
    //  createLead — blank pin code (should skip validation)
    // ═══════════════════════════════════════════════════════════════════

    @IsTest
    static void testCreateLeadWithBlankPinCode() {
        Test.setMock(HttpCalloutMock.class, new MockHttpCallout());

        Map<String, Object> leadData = new Map<String, Object>{
            'firstName' => 'Pin',
            'lastName' => 'Blank',
            'company' => 'Test Company',
            'primaryPhone' => '9876540005',
            'pinCode' => '   ',
            'country' => 'IN'
        };

        Test.startTest();
        Id leadId = StandardLeadController.createLead(leadData);
        Test.stopTest();

        System.assertNotEquals(null, leadId, 'Lead should be created with blank pin code');
    }

    // ═══════════════════════════════════════════════════════════════════
    //  createLead — no pin code key at all
    // ═══════════════════════════════════════════════════════════════════

    @IsTest
    static void testCreateLeadWithoutPinCodeKey() {
        Test.setMock(HttpCalloutMock.class, new MockHttpCallout());

        Map<String, Object> leadData = new Map<String, Object>{
            'firstName' => 'No',
            'lastName' => 'PinKey',
            'company' => 'Test Company',
            'primaryPhone' => '9876540006',
            'country' => 'IN'
        };

        Test.startTest();
        Id leadId = StandardLeadController.createLead(leadData);
        Test.stopTest();

        System.assertNotEquals(null, leadId, 'Lead should be created without pinCode key');
    }

    // ═══════════════════════════════════════════════════════════════════
    //  createLead — all fields populated
    // ═══════════════════════════════════════════════════════════════════

    @IsTest
    static void testCreateLeadAllFields() {
        Test.setMock(HttpCalloutMock.class, new MockHttpCallout());

        Map<String, Object> leadData = new Map<String, Object>{
            'firstName' => 'All',
            'lastName' => 'Fields',
            'company' => 'Full Corp',
            'primaryPhone' => '9876540007',
            'secondaryPhone' => '9876540008',
            'email' => 'allfields@test.com',
            'country' => 'IN',
            'pinCode' => '600001',
            'remarks' => 'Test remarks for full coverage'
        };

        Test.startTest();
        Id leadId = StandardLeadController.createLead(leadData);
        Test.stopTest();

        Lead created = [SELECT FirstName, LastName, Company, Phone, Secondary_Phone__c,
                                Email, Country__c, Pin_Code__c, Remarks__c
                         FROM Lead WHERE Id = :leadId];
        System.assertEquals('All', created.FirstName);
        System.assertEquals('Fields', created.LastName);
        System.assertNotEquals(null, created.Company, 'Company should be set');
        System.assertEquals('9876540007', created.Phone);
        System.assertEquals('9876540008', created.Secondary_Phone__c);
        System.assertEquals('allfields@test.com', created.Email);
        System.assertEquals('IN', created.Country__c);
        System.assertEquals(Decimal.valueOf('600001'), created.Pin_Code__c);
        System.assertEquals('Test remarks for full coverage', created.Remarks__c);
    }

    // ═══════════════════════════════════════════════════════════════════
    //  createLead — minimal fields (only required)
    // ═══════════════════════════════════════════════════════════════════

    @IsTest
    static void testCreateLeadMinimalFields() {
        Test.setMock(HttpCalloutMock.class, new MockHttpCallout());

        Map<String, Object> leadData = new Map<String, Object>{
            'lastName' => 'MinimalLead',
            'company' => 'Min Co',
            'primaryPhone' => '9876540009',
            'country' => 'IN'
        };

        Test.startTest();
        Id leadId = StandardLeadController.createLead(leadData);
        Test.stopTest();

        Lead created = [SELECT LastName, Company FROM Lead WHERE Id = :leadId];
        System.assertEquals('MinimalLead', created.LastName);
        System.assertNotEquals(null, created.Company, 'Company should be set');
    }

    // ═══════════════════════════════════════════════════════════════════
    //  createLead — with owner assignment
    // ═══════════════════════════════════════════════════════════════════

    @IsTest
    static void testCreateLeadWithOwnerAssignment() {
        Test.setMock(HttpCalloutMock.class, new MockHttpCallout());

        Id currentUserId = UserInfo.getUserId();

        Map<String, Object> leadData = new Map<String, Object>{
            'firstName' => 'Owner',
            'lastName' => 'Assigned',
            'company' => 'Owner Corp',
            'primaryPhone' => '9876540010',
            'assignedExecutive' => currentUserId,
            'country' => 'IN'
        };

        Test.startTest();
        Id leadId = StandardLeadController.createLead(leadData);
        Test.stopTest();

        Lead created = [SELECT OwnerId FROM Lead WHERE Id = :leadId];
        System.assertEquals(currentUserId, created.OwnerId, 'Owner should be the assigned executive');
    }
}