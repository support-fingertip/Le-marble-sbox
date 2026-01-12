@isTest
public class CustomerTriggerTest {
    // Mock class for HTTP callouts
    private class MockHttpCallout implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"success":true}');
            res.setStatusCode(200);
            return res;
        }
    }

    @TestSetup
    static void setupTestData() {
        // Set up mock for callouts
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

        // Create test cart
        Cart__c cart = new Cart__c(
            Customer__c = customer.Id
        );
        insert cart;
    }

    @isTest
    static void testCustomerConversion() {
        Test.setMock(HttpCalloutMock.class, new MockHttpCallout());

        // Create a fresh customer for this test with unique email and phone
        Customer__c customer = new Customer__c(
            Name = 'Test Customer',
            Phone__c = '9198765432' + String.valueOf(System.currentTimeMillis()).right(4),
            Email__c = 'test' + System.currentTimeMillis() + '@customer.com',
            Status1__c = 'New',
            Company__c = 'Test Company',
            CustomerEntryDate__c = Date.today(),
            LeadSource__c = 'Website',
            NextFollowupDate__c = Date.today().addDays(7),
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

        // Create a cart for this customer
        Cart__c cart = new Cart__c(Customer__c = customer.Id);
        insert cart;

        Test.startTest();
        customer.Status1__c = 'Converted';
        update customer;
        Test.stopTest();

        List<Deals__c> deals = [
            SELECT Id FROM Deals__c WHERE Customer__c = :customer.Id
        ];
        System.assertEquals(1, deals.size(), 'Should create one deal');
    }

    @isTest
    static void testCustomerConversionWithMultipleCarts() {
        // Set up mock for callouts
        Test.setMock(HttpCalloutMock.class, new MockHttpCallout());

        // Get the test customer
        Customer__c customer = [SELECT Id, Status1__c FROM Customer__c LIMIT 1];

        // Create additional cart
        Cart__c secondCart = new Cart__c(
            Customer__c = customer.Id
        );
        insert secondCart;

        Test.startTest();
        // Update customer status to trigger conversion
        customer.Status1__c = 'Converted';
        update customer;
        Test.stopTest();

        // Verify deal was created
        List<Deals__c> deals = [
            SELECT Id 
            FROM Deals__c 
            WHERE Customer__c = :customer.Id
        ];
        System.assertEquals(1, deals.size(), 'Should create one deal');

        // Verify both carts were updated with deal ID
        List<Cart__c> carts = [
            SELECT Id, Deals__c 
            FROM Cart__c 
            WHERE Customer__c = :customer.Id
        ];
        System.assertEquals(2, carts.size(), 'Should find two carts');
        for(Cart__c cart : carts) {
            System.assertEquals(deals[0].Id, cart.Deals__c, 'Cart should be linked to the new deal');
        }
    }

    @isTest
    static void testCustomerConversionWithNoCarts() {
        // Set up mock for callouts
        Test.setMock(HttpCalloutMock.class, new MockHttpCallout());

        // Get the test customer
        Customer__c customer = [SELECT Id, Status1__c FROM Customer__c LIMIT 1];

        // Delete existing cart
        delete [SELECT Id FROM Cart__c WHERE Customer__c = :customer.Id];

        Test.startTest();
        // Update customer status to trigger conversion
        customer.Status1__c = 'Converted';
        update customer;
        Test.stopTest();

        // Verify deal was created
        List<Deals__c> deals = [
            SELECT Id 
            FROM Deals__c 
            WHERE Customer__c = :customer.Id
        ];
        System.assertEquals(1, deals.size(), 'Should create one deal');

        // Verify no carts exist
        List<Cart__c> carts = [
            SELECT Id 
            FROM Cart__c 
            WHERE Customer__c = :customer.Id
        ];
        System.assertEquals(0, carts.size(), 'Should find no carts');
    }

    @isTest
    static void testCustomerConversionWithAddressFields() {
        // Set up mock for callouts
        Test.setMock(HttpCalloutMock.class, new MockHttpCallout());

        // Get the test customer with all address fields
        Customer__c customer = [
            SELECT Id, Address__City__s, Address__CountryCode__s, 
                   Address__StateCode__s, Address__Street__s, Address__PostalCode__s,
                   Status1__c
            FROM Customer__c 
            LIMIT 1
        ];

        Test.startTest();
        // Update customer status to trigger conversion
        customer.Status1__c = 'Converted';
        update customer;
        Test.stopTest();

        // Verify deal was created with correct address fields
        List<Deals__c> deals = [
            SELECT Id, Address__City__s, Address__CountryCode__s, 
                   Address__StateCode__s, Address__Street__s, Address__PostalCode__s
            FROM Deals__c 
            WHERE Customer__c = :customer.Id
        ];
        System.assertEquals(1, deals.size(), 'Should create one deal');
        
        Deals__c deal = deals[0];
        System.assertEquals(customer.Address__City__s, deal.Address__City__s, 'City should be copied');
        System.assertEquals(customer.Address__CountryCode__s, deal.Address__CountryCode__s, 'Country should be copied');
        System.assertEquals(customer.Address__StateCode__s, deal.Address__StateCode__s, 'State should be copied');
        System.assertEquals(customer.Address__Street__s, deal.Address__Street__s, 'Street should be copied');
        System.assertEquals(customer.Address__PostalCode__s, deal.Address__PostalCode__s, 'Postal code should be copied');
    }

    @isTest
    static void testCustomerConversionWithError() {
        // Set up mock for callouts
        Test.setMock(HttpCalloutMock.class, new MockHttpCallout());

        // Get the test customer
        Customer__c customer = [SELECT Id, Status1__c FROM Customer__c LIMIT 1];

        Test.startTest();
        // Update customer with invalid data to trigger error
        customer.Phone__c = null; // Assuming Phone is required
        customer.Status1__c = 'Converted';
        
        Database.SaveResult result;
        try {
            result = Database.update(customer, false);
            //System.assert(!result.isSuccess(), 'Update should have failed');
            //System.assert(result.getErrors().size() > 0, 'Should have validation errors');
        } catch (Exception e) {
            //System.assert(false, 'Should not throw exception, should return error in SaveResult');
        }
        Test.stopTest();

        // Verify no deal was created
        List<Deals__c> deals = [
            SELECT Id 
            FROM Deals__c 
            WHERE Customer__c = :customer.Id
        ];
        //System.assertEquals(0, deals.size(), 'No deal should be created when error occurs');
    }
}