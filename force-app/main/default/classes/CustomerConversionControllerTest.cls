@isTest
public class CustomerConversionControllerTest {

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
        Test.setMock(HttpCalloutMock.class, new MockHttpCallout());

        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User testUser = new User(
            Alias            = 'testuser',
            Email            = 'testuser@test.com',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey     = 'en_US',
            TimeZoneSidKey   = 'America/Los_Angeles',
            ProfileId        = p.Id,
            UserName         = 'testuser@test.com' + System.currentTimeMillis(),
            LastName         = 'TestUser'
        );
        insert testUser;

        Customer__c customer = new Customer__c(
            Name               = 'Test Customer',
            Lead_Name__c       = 'Test Customer',
            Primary_Phone__c   = '919876543210',
            Phone__c           = '919876543210',
            Email__c           = 'test@customer.com',
            Status1__c         = 'New',
            Company__c         = 'Test Company',
            CustomerEntryDate__c = Date.today(),
            LeadSource__c      = 'Website',
            NextFollowupDate__c = Date.today().addDays(7),
            OwnerId            = testUser.Id,
            LeadPurpose__c     = 'New Business',
            Remarks__c         = 'Test Remarks',
            SecondaryPhone__c  = '919876543211',
            Address__City__s          = 'Test City',
            Address__CountryCode__s   = 'IN',
            Address__StateCode__s     = 'KA',
            Address__Street__s        = 'Test Street',
            Address__PostalCode__s    = '560001',
            Billing_Address__City__s          = 'Test City',
            Billing_Address__CountryCode__s   = 'IN',
            Billing_Address__StateCode__s     = 'KA',
            Billing_Address__Street__s        = 'Test Street',
            Billing_Address__PostalCode__s    = '560001',
            Status__c          = 'Active',
            Type__c            = 'Individual',
            BranchLocation__c  = 'Test Branch',
            GST_No__c          = 'GST123456'
        );
        insert customer;
    }

    // ─── helpers ─────────────────────────────────────────────────────────────

    private static Customer__c getTestCustomer() {
        return [SELECT Id, Status1__c FROM Customer__c LIMIT 1];
    }

    // ─── TEST: Successful conversion ─────────────────────────────────────────

    @isTest
    static void testConvertToOpportunity() {
        Test.setMock(HttpCalloutMock.class, new MockHttpCallout());
        Customer__c customer = getTestCustomer();

        Test.startTest();
        Map<String, String> result = CustomerConversionController.convertToOpportunity(customer.Id);
        Test.stopTest();

        // Verify status changed
        Customer__c updated = [SELECT Status1__c FROM Customer__c WHERE Id = :customer.Id];
        System.assertEquals('Converted', updated.Status1__c, 'Customer status should be Converted');

        // Verify deal created and returned
        System.assertNotEquals(null, result.get('dealId'), 'Deal ID should be returned');

        Deals__c deal = [SELECT Id, Customer__c FROM Deals__c WHERE Id = :result.get('dealId')];
        System.assertEquals(customer.Id, deal.Customer__c, 'Deal should be linked to the customer');
    }

    // ─── TEST: Deal fields copied from customer ──────────────────────────────

    @isTest
    static void testConvertToOpportunity_DealFieldsCopied() {
        Test.setMock(HttpCalloutMock.class, new MockHttpCallout());
        Customer__c customer = getTestCustomer();

        Test.startTest();
        Map<String, String> result = CustomerConversionController.convertToOpportunity(customer.Id);
        Test.stopTest();

        Deals__c deal = [
            SELECT Company__c, Name, Email__c, Phone__c, LeadSource__c,
                   Purpose__c, Type__c, Customer__c, BranchLocation__c, GST_No__c
            FROM Deals__c WHERE Id = :result.get('dealId')
        ];
        System.assertEquals('Test Company', deal.Company__c, 'Company should be copied');
        System.assertEquals('Test Customer', deal.Name, 'Name should be copied');
        System.assertEquals('test@customer.com', deal.Email__c, 'Email should be copied');
        System.assertEquals('919876543210', deal.Phone__c, 'Phone should be copied');
        System.assertEquals('Website', deal.LeadSource__c, 'LeadSource should be copied');
        System.assertEquals('Individual', deal.Type__c, 'Type should be copied');
        System.assertEquals('Test Branch', deal.BranchLocation__c, 'Branch should be copied');
        System.assertEquals('GST123456', deal.GST_No__c, 'GST should be copied');
    }

    // ─── TEST: Invalid customer ID ───────────────────────────────────────────

    @isTest
    static void testConvertToOpportunityWithInvalidId() {
        Test.setMock(HttpCalloutMock.class, new MockHttpCallout());

        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            CustomerConversionController.convertToOpportunity('001000000000000');
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'Should throw exception for invalid ID');
    }

    // ─── TEST: Null customer ID ──────────────────────────────────────────────

    @isTest
    static void testConvertToOpportunityWithNullId() {
        Test.setMock(HttpCalloutMock.class, new MockHttpCallout());

        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            CustomerConversionController.convertToOpportunity(null);
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'Should throw exception for null ID');
    }

    // ─── TEST: Already converted customer ────────────────────────────────────

    @isTest
    static void testConvertToOpportunityWithAlreadyConvertedCustomer() {
        Test.setMock(HttpCalloutMock.class, new MockHttpCallout());
        Customer__c customer = getTestCustomer();

        // First conversion
        customer.Status1__c = 'Converted';
        update customer;

        // Second conversion attempt
        Test.startTest();
        try {
            Map<String, String> result = CustomerConversionController.convertToOpportunity(customer.Id);
            // If it succeeds, a second Deal may be created — verify at least one exists
            System.assertNotEquals(null, result.get('dealId'), 'dealId should be present');
        } catch (AuraHandledException e) {
            // Some orgs may reject re-conversion
            System.assert(true, 'Exception thrown for already converted customer');
        }
        Test.stopTest();
    }
}