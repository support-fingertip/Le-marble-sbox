@isTest
public class CustomerTriggerTest {

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
            Lead_Name__c       = 'Test Lead',
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
            Address__City__s   = 'Test City',
            Address__CountryCode__s = 'IN',
            Address__StateCode__s   = 'KA',
            Address__Street__s      = 'Test Street',
            Address__PostalCode__s  = '560001',
            Billing_Address__City__s       = 'Test City',
            Billing_Address__CountryCode__s = 'IN',
            Billing_Address__StateCode__s   = 'KA',
            Billing_Address__Street__s      = 'Test Street',
            Billing_Address__PostalCode__s  = '560001',
            Status__c          = 'Active',
            Type__c            = 'Individual',
            BranchLocation__c  = 'Test Branch',
            GST_No__c          = 'GST123456'
        );
        insert customer;

        Cart__c cart = new Cart__c(Customer__c = customer.Id);
        insert cart;
    }

    // ─── helpers ─────────────────────────────────────────────────────────────

    private static Customer__c getTestCustomer() {
        return [SELECT Id, Status1__c FROM Customer__c LIMIT 1];
    }

    private static Customer__c createFreshCustomer() {
        Customer__c c = new Customer__c(
            Name               = 'Fresh Customer',
            Lead_Name__c       = 'Fresh Lead',
            Primary_Phone__c   = '91' + String.valueOf(System.currentTimeMillis()).right(10),
            Phone__c           = '91' + String.valueOf(System.currentTimeMillis()).right(10),
            Email__c           = 'fresh' + System.currentTimeMillis() + '@test.com',
            Status1__c         = 'New',
            Company__c         = 'Fresh Company',
            CustomerEntryDate__c = Date.today(),
            LeadSource__c      = 'Website',
            NextFollowupDate__c = Date.today().addDays(7),
            LeadPurpose__c     = 'New Business',
            Remarks__c         = 'Fresh Remarks',
            SecondaryPhone__c  = '919876549999',
            Address__City__s   = 'Fresh City',
            Address__CountryCode__s = 'IN',
            Address__StateCode__s   = 'KA',
            Address__Street__s      = 'Fresh Street',
            Address__PostalCode__s  = '560002',
            Billing_Address__City__s       = 'Fresh City',
            Billing_Address__CountryCode__s = 'IN',
            Billing_Address__StateCode__s   = 'KA',
            Billing_Address__Street__s      = 'Fresh Street',
            Billing_Address__PostalCode__s  = '560002',
            Status__c          = 'Active',
            Type__c            = 'Individual',
            BranchLocation__c  = 'Fresh Branch',
            GST_No__c          = 'GST999999'
        );
        insert c;
        return c;
    }

    // ─── TEST: Basic conversion creates a Deal ───────────────────────────────

    @isTest
    static void testCustomerConversion() {
        Test.setMock(HttpCalloutMock.class, new MockHttpCallout());
        Customer__c customer = createFreshCustomer();

        Cart__c cart = new Cart__c(Customer__c = customer.Id);
        insert cart;

        Test.startTest();
        customer.Status1__c = 'Converted';
        update customer;
        Test.stopTest();

        List<Deals__c> deals = [SELECT Id FROM Deals__c WHERE Customer__c = :customer.Id];
        System.assertEquals(1, deals.size(), 'Should create one deal');
    }

    // ─── TEST: Multiple carts linked to new Deal ─────────────────────────────

    @isTest
    static void testCustomerConversionWithMultipleCarts() {
        Test.setMock(HttpCalloutMock.class, new MockHttpCallout());
        Customer__c customer = getTestCustomer();

        insert new Cart__c(Customer__c = customer.Id);

        Test.startTest();
        customer.Status1__c = 'Converted';
        update customer;
        Test.stopTest();

        List<Deals__c> deals = [SELECT Id FROM Deals__c WHERE Customer__c = :customer.Id];
        System.assertEquals(1, deals.size(), 'Should create one deal');

        List<Cart__c> carts = [SELECT Id, Deals__c FROM Cart__c WHERE Customer__c = :customer.Id];
        System.assertEquals(2, carts.size(), 'Should find two carts');
        for (Cart__c c : carts) {
            System.assertEquals(deals[0].Id, c.Deals__c, 'Cart should be linked to the new deal');
        }
    }

    // ─── TEST: No carts — deal still created ─────────────────────────────────

    @isTest
    static void testCustomerConversionWithNoCarts() {
        Test.setMock(HttpCalloutMock.class, new MockHttpCallout());
        Customer__c customer = getTestCustomer();

        delete [SELECT Id FROM Cart__c WHERE Customer__c = :customer.Id];

        Test.startTest();
        customer.Status1__c = 'Converted';
        update customer;
        Test.stopTest();

        List<Deals__c> deals = [SELECT Id FROM Deals__c WHERE Customer__c = :customer.Id];
        System.assertEquals(1, deals.size(), 'Should create one deal even with no carts');

        List<Cart__c> carts = [SELECT Id FROM Cart__c WHERE Customer__c = :customer.Id];
        System.assertEquals(0, carts.size(), 'Should find no carts');
    }

    // ─── TEST: Address fields copied to Deal ─────────────────────────────────

    @isTest
    static void testCustomerConversionWithAddressFields() {
        Test.setMock(HttpCalloutMock.class, new MockHttpCallout());
        Customer__c customer = [
            SELECT Id, Address__City__s, Address__CountryCode__s,
                   Address__StateCode__s, Address__Street__s, Address__PostalCode__s,
                   Status1__c
            FROM Customer__c LIMIT 1
        ];

        Test.startTest();
        customer.Status1__c = 'Converted';
        update customer;
        Test.stopTest();

        List<Deals__c> deals = [
            SELECT Id, Address__City__s, Address__CountryCode__s,
                   Address__StateCode__s, Address__Street__s, Address__PostalCode__s
            FROM Deals__c WHERE Customer__c = :customer.Id
        ];
        System.assertEquals(1, deals.size(), 'Should create one deal');

        Deals__c deal = deals[0];
        System.assertEquals(customer.Address__City__s, deal.Address__City__s, 'City should be copied');
        System.assertEquals(customer.Address__CountryCode__s, deal.Address__CountryCode__s, 'Country should be copied');
        System.assertEquals(customer.Address__StateCode__s, deal.Address__StateCode__s, 'State should be copied');
        System.assertEquals(customer.Address__Street__s, deal.Address__Street__s, 'Street should be copied');
        System.assertEquals(customer.Address__PostalCode__s, deal.Address__PostalCode__s, 'Postal code should be copied');
    }

    // ─── TEST: All deal fields copied correctly ──────────────────────────────

    @isTest
    static void testCustomerConversion_AllFieldsCopied() {
        Test.setMock(HttpCalloutMock.class, new MockHttpCallout());
        Customer__c customer = [
            SELECT Id, Name, Company__c, CustomerEntryDate__c, Email__c, LeadSource__c,
                   NextFollowupDate__c, Phone__c, LeadPurpose__c, Remarks__c,
                   SecondaryPhone__c, Status__c, Type__c, BranchLocation__c, GST_No__c,
                   Status1__c
            FROM Customer__c LIMIT 1
        ];

        Test.startTest();
        customer.Status1__c = 'Converted';
        update customer;
        Test.stopTest();

        Deals__c deal = [
            SELECT Company__c, CustomerEntryDate__c, Name, Email__c, LeadSource__c,
                   NextFollowupDate__c, Phone__c, Purpose__c, Remarks__c,
                   SecondaryPhone__c, Stage__c, Type__c, Customer__c,
                   BranchLocation__c, Opp_BE_Name__c, GST_No__c
            FROM Deals__c WHERE Customer__c = :customer.Id LIMIT 1
        ];
        System.assertEquals(customer.Company__c, deal.Company__c, 'Company should match');
        System.assertEquals(customer.CustomerEntryDate__c, deal.CustomerEntryDate__c, 'Entry date should match');
        System.assertEquals(customer.Name, deal.Name, 'Name should match');
        System.assertEquals(customer.Email__c, deal.Email__c, 'Email should match');
        System.assertEquals(customer.LeadSource__c, deal.LeadSource__c, 'Lead source should match');
        System.assertEquals(customer.Phone__c, deal.Phone__c, 'Phone should match');
        System.assertEquals(customer.LeadPurpose__c, deal.Purpose__c, 'Purpose should match');
        System.assertEquals(customer.Remarks__c, deal.Remarks__c, 'Remarks should match');
        System.assertEquals(customer.SecondaryPhone__c, deal.SecondaryPhone__c, 'Secondary phone should match');
        System.assertEquals(customer.Status__c, deal.Stage__c, 'Stage should match Status');
        System.assertEquals(customer.Type__c, deal.Type__c, 'Type should match');
        System.assertEquals(customer.Id, deal.Customer__c, 'Customer lookup should match');
        System.assertEquals(customer.BranchLocation__c, deal.BranchLocation__c, 'Branch should match');
        System.assertEquals(customer.Name, deal.Opp_BE_Name__c, 'Opp_BE_Name should match customer Name');
        System.assertEquals(customer.GST_No__c, deal.GST_No__c, 'GST should match');
    }

    // ─── TEST: Non-converted status — no deal created ────────────────────────

    @isTest
    static void testNonConvertedStatus_NoDealCreated() {
        Test.setMock(HttpCalloutMock.class, new MockHttpCallout());
        Customer__c customer = getTestCustomer();

        Test.startTest();
        customer.Status1__c = 'Contacted';
        update customer;
        Test.stopTest();

        List<Deals__c> deals = [SELECT Id FROM Deals__c WHERE Customer__c = :customer.Id];
        System.assertEquals(0, deals.size(), 'No deal should be created for non-Converted status');
    }

    // ─── TEST: Update without status change — no deal ────────────────────────

    @isTest
    static void testUpdateWithoutStatusChange_NoDealCreated() {
        Test.setMock(HttpCalloutMock.class, new MockHttpCallout());
        Customer__c customer = getTestCustomer();

        Test.startTest();
        customer.Remarks__c = 'Updated remarks';
        update customer;
        Test.stopTest();

        List<Deals__c> deals = [SELECT Id FROM Deals__c WHERE Customer__c = :customer.Id];
        System.assertEquals(0, deals.size(), 'No deal should be created when status does not change to Converted');
    }
}