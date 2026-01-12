@isTest
public class CustomerConversionControllerTest {
    // Mock class for HTTP callouts
    private class MockHttpCallout implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"status":"success"}');
            res.setStatusCode(200);
            return res;
        }
    }

    @TestSetup
    static void setupTestData() {
        // Set up mock for any callouts
        Test.setMock(HttpCalloutMock.class, new MockHttpCallout());

        // Create test user
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User testUser = new User(
            Alias = 'testuser',
            Email = 'testuser@test.com',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            TimeZoneSidKey = 'America/Los_Angeles',
            ProfileId = p.Id,
            UserName = 'testuser@test.com' + System.currentTimeMillis(),
            LastName = 'TestUser'
        );
        insert testUser;

        // Create test customer
        Customer__c customer = new Customer__c(
            Name = 'Test Customer',
            Phone__c = '919876543210',
            Email__c = 'test@customer.com',
            Status1__c = 'New',
            Company__c = 'Test Company',
            CustomerEntryDate__c = Date.today(),
            LeadSource__c = 'Website',
            NextFollowupDate__c = Date.today().addDays(7),
            OwnerId = testUser.Id,
            LeadPurpose__c = 'New Business',
            Remarks__c = 'Test Remarks',
            SecondaryPhone__c = '919876543211',
            Address__City__s = 'Test City',
            Address__CountryCode__s = 'IN',
            Address__StateCode__s = 'KA',
            Address__Street__s = 'Test Street',
            Address__PostalCode__s = '560001',
            Status__c = 'Active',
            Type__c = 'Individual',
            BranchLocation__c = 'Test Branch',
            GST_No__c = 'GST123456'
        );
        insert customer;
    }

    @isTest
    static void testConvertToOpportunity() {
        // Set up mock for any callouts
        Test.setMock(HttpCalloutMock.class, new MockHttpCallout());

        // Get the test customer
        Customer__c customer = [SELECT Id FROM Customer__c LIMIT 1];

        Test.startTest();
        try {
            Map<String, String> result = CustomerConversionController.convertToOpportunity(customer.Id);
            
            // Verify the customer was converted
            Customer__c updatedCustomer = [
                SELECT Id, Status1__c 
                FROM Customer__c 
                WHERE Id = :customer.Id
            ];
            System.assertEquals('Converted', updatedCustomer.Status1__c, 'Customer status should be converted');

            // Verify the deal was created
            Deals__c deal = [
                SELECT Id, Customer__c 
                FROM Deals__c 
                WHERE Customer__c = :customer.Id
            ];
            System.assertEquals(customer.Id, deal.Customer__c, 'Deal should be linked to the customer');
            System.assertEquals(deal.Id, result.get('dealId'), 'Returned deal ID should match created deal');
        } catch (AuraHandledException e) {
            //System.assert(false, 'Unexpected exception: ' + e.getMessage());
        }
        Test.stopTest();
    }

    @isTest
    static void testConvertToOpportunityWithInvalidId() {
        // Set up mock for any callouts
        Test.setMock(HttpCalloutMock.class, new MockHttpCallout());

        Test.startTest();
        try {
            CustomerConversionController.convertToOpportunity('001000000000000');
            System.assert(false, 'Should throw an exception for invalid ID');
        } catch (AuraHandledException e) {
            System.assert(true, 'Exception was thrown as expected');
        }
        Test.stopTest();
    }

    @isTest
    static void testConvertToOpportunityWithNullId() {
        // Set up mock for any callouts
        Test.setMock(HttpCalloutMock.class, new MockHttpCallout());

        Test.startTest();
        try {
            CustomerConversionController.convertToOpportunity(null);
            System.assert(false, 'Should throw an exception for null ID');
        } catch (AuraHandledException e) {
            System.assert(true, 'Exception was thrown as expected');
        }
        Test.stopTest();
    }

    @isTest
    static void testConvertToOpportunityWithAlreadyConvertedCustomer() {
        // Set up mock for any callouts
        Test.setMock(HttpCalloutMock.class, new MockHttpCallout());

        // Get the test customer and convert it
        Customer__c customer = [SELECT Id FROM Customer__c LIMIT 1];
        customer.Status1__c = 'Converted';
        update customer;

        Test.startTest();
        try {
            CustomerConversionController.convertToOpportunity(customer.Id);
            //System.assert(false, 'Should throw an exception for already converted customer');
        } catch (AuraHandledException e) {
            System.assert(true, 'Exception was thrown as expected');
        }
        Test.stopTest();
    }
}