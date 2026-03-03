@isTest
private class OppSAPTriggerTest {

    // Mock HTTP callout for SAP integration
    private class MockSAPCallout implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            String endpoint = req.getEndpoint();

            if (endpoint.contains('/Login')) {
                res.setStatusCode(200);
                res.setBody('{"SessionId":"mockedSessionId"}');
            } else if (req.getMethod() == 'GET' && endpoint.contains('/BusinessPartners')) {
                res.setStatusCode(200);
                res.setBody('{' +
                    '"CardCode": "CUST123",' +
                    '"BPAddresses": [' +
                    '   {"AddressType": "bo_BillTo"},' +
                    '   {"AddressType": "bo_ShipTo"}' +
                    ' ]' +
                    '}');
            } else if (req.getMethod() == 'PATCH' && endpoint.contains('/BusinessPartners')) {
                res.setStatusCode(204);
            } else if (req.getMethod() == 'POST') {
                res.setStatusCode(201);
                res.setBody('{"CardCode":"BP123"}');
            } else {
                res.setStatusCode(200);
                res.setBody('{}');
            }

            return res;
        }
    }

    // Helper method to create test Customer
    private static Customer__c createTestCustomer() {
        Customer__c customer = new Customer__c(
            Name = 'Test Customer',
            Customer_ID__c = 'CUST123',
            Lead_Name__c = 'Test Lead',
            Primary_Phone__c = '9999999999'
        );
        insert customer;
        return customer;
    }

    // Helper method to create test Deal
    private static Deals__c createTestDeal(Id customerId) {
        Deals__c deal = new Deals__c(
            Name = 'Test Deal',
            Customer__c = customerId,
            Email__c = 'test@example.com',
            Phone__c = '9999999999',
            SecondaryPhone__c = '8888888888',
            Company__c = 'Test Company',
            Remarks__c = 'Test remarks',
            Address__Street__s = '123 Test Road',
            Address__City__s = 'Chennai',
            Address__PostalCode__s = '600001',
            Address__StateCode__s = 'TN',
            Address__CountryCode__s = 'IN'
        );
        insert deal;
        return deal;
    }

    // =====================
    // TEST: After Insert
    // =====================
    @isTest
    static void testTrigger_AfterInsert() {
        Test.setMock(HttpCalloutMock.class, new MockSAPCallout());
        Customer__c customer = createTestCustomer();

        Test.startTest();
        Deals__c deal = new Deals__c(
            Name = 'New Deal Insert',
            Customer__c = customer.Id,
            Email__c = 'newdeal@example.com',
            Phone__c = '9876543210',
            Company__c = 'New Company'
        );
        insert deal;
        Test.stopTest();

        Deals__c inserted = [SELECT Id, Name FROM Deals__c WHERE Id = :deal.Id];
        System.assertNotEquals(null, inserted, 'Deal should be inserted');
    }

    // =====================
    // TEST: Update Email
    // =====================
    @isTest
    static void testTrigger_UpdateEmail() {
        Test.setMock(HttpCalloutMock.class, new MockSAPCallout());
        Customer__c customer = createTestCustomer();
        Deals__c deal = createTestDeal(customer.Id);

        Test.startTest();
        deal.Email__c = 'updated@example.com';
        update deal;
        Test.stopTest();

        Deals__c updated = [SELECT Email__c FROM Deals__c WHERE Id = :deal.Id];
        System.assertEquals('updated@example.com', updated.Email__c, 'Email should be updated');
    }

    // =====================
    // TEST: Update Phone
    // =====================
    @isTest
    static void testTrigger_UpdatePhone() {
        Test.setMock(HttpCalloutMock.class, new MockSAPCallout());
        Customer__c customer = createTestCustomer();
        Deals__c deal = createTestDeal(customer.Id);

        Test.startTest();
        deal.Phone__c = '1111111111';
        update deal;
        Test.stopTest();

        Deals__c updated = [SELECT Phone__c FROM Deals__c WHERE Id = :deal.Id];
        System.assertEquals('1111111111', updated.Phone__c, 'Phone should be updated');
    }

    // =====================
    // TEST: Update SecondaryPhone
    // =====================
    @isTest
    static void testTrigger_UpdateSecondaryPhone() {
        Test.setMock(HttpCalloutMock.class, new MockSAPCallout());
        Customer__c customer = createTestCustomer();
        Deals__c deal = createTestDeal(customer.Id);

        Test.startTest();
        deal.SecondaryPhone__c = '2222222222';
        update deal;
        Test.stopTest();

        Deals__c updated = [SELECT SecondaryPhone__c FROM Deals__c WHERE Id = :deal.Id];
        System.assertEquals('2222222222', updated.SecondaryPhone__c, 'SecondaryPhone should be updated');
    }

    // =====================
    // TEST: Update Company
    // =====================
    @isTest
    static void testTrigger_UpdateCompany() {
        Test.setMock(HttpCalloutMock.class, new MockSAPCallout());
        Customer__c customer = createTestCustomer();
        Deals__c deal = createTestDeal(customer.Id);

        Test.startTest();
        deal.Company__c = 'Updated Company';
        update deal;
        Test.stopTest();

        Deals__c updated = [SELECT Company__c FROM Deals__c WHERE Id = :deal.Id];
        System.assertEquals('Updated Company', updated.Company__c, 'Company should be updated');
    }

    // =====================
    // TEST: Update Remarks
    // =====================
    @isTest
    static void testTrigger_UpdateRemarks() {
        Test.setMock(HttpCalloutMock.class, new MockSAPCallout());
        Customer__c customer = createTestCustomer();
        Deals__c deal = createTestDeal(customer.Id);

        Test.startTest();
        deal.Remarks__c = 'Updated remarks';
        update deal;
        Test.stopTest();

        Deals__c updated = [SELECT Remarks__c FROM Deals__c WHERE Id = :deal.Id];
        System.assertEquals('Updated remarks', updated.Remarks__c, 'Remarks should be updated');
    }

    // =====================
    // TEST: Update Address Fields
    // =====================
    @isTest
    static void testTrigger_UpdateAddressFields() {
        Test.setMock(HttpCalloutMock.class, new MockSAPCallout());
        Customer__c customer = createTestCustomer();
        Deals__c deal = createTestDeal(customer.Id);

        Test.startTest();
        deal.Address__Street__s = '456 New Street';
        deal.Address__City__s = 'Mumbai';
        deal.Address__PostalCode__s = '400001';
        deal.Address__StateCode__s = 'MH';
        deal.Address__CountryCode__s = 'IN';
        update deal;
        Test.stopTest();

        Deals__c updated = [SELECT Address__City__s FROM Deals__c WHERE Id = :deal.Id];
        System.assertEquals('Mumbai', updated.Address__City__s, 'Address City should be updated');
    }

    // =====================
    // TEST: Update Billing Address
    // =====================
    @isTest
    static void testTrigger_UpdateBillingAddress() {
        Test.setMock(HttpCalloutMock.class, new MockSAPCallout());
        Customer__c customer = createTestCustomer();
        Deals__c deal = createTestDeal(customer.Id);

        Test.startTest();
        deal.Billing_Address__Street__s = '789 Billing Street';
        deal.Billing_Address__City__s = 'Delhi';
        deal.Billing_Address__PostalCode__s = '110001';
        deal.Billing_Address__StateCode__s = 'DL';
        deal.Billing_Address__CountryCode__s = 'IN';
        update deal;
        Test.stopTest();

        Deals__c updated = [SELECT Billing_Address__City__s FROM Deals__c WHERE Id = :deal.Id];
        System.assertEquals('Delhi', updated.Billing_Address__City__s, 'Billing City should be updated');
    }

    // =====================
    // TEST: Update Address Names
    // =====================
    @isTest
    static void testTrigger_UpdateAddressNames() {
        Test.setMock(HttpCalloutMock.class, new MockSAPCallout());
        Customer__c customer = createTestCustomer();
        Deals__c deal = createTestDeal(customer.Id);

        Test.startTest();
        deal.Billing_Address_Name__c = 'Billing Name 1';
        deal.Billing_Address_Name_2__c = 'Billing Name 2';
        deal.Billing_Address_Name_3__c = 'Billing Name 3';
        deal.Shipping_Address_Name__c = 'Shipping Name 1';
        deal.Shipping_Address_Name_2__c = 'Shipping Name 2';
        deal.Shipping_Address_Name_3__c = 'Shipping Name 3';
        update deal;
        Test.stopTest();

        Deals__c updated = [SELECT Billing_Address_Name__c, Shipping_Address_Name__c FROM Deals__c WHERE Id = :deal.Id];
        System.assertEquals('Billing Name 1', updated.Billing_Address_Name__c, 'Billing Address Name should be updated');
        System.assertEquals('Shipping Name 1', updated.Shipping_Address_Name__c, 'Shipping Address Name should be updated');
    }

    // =====================
    // TEST: No Field Changes (Should NOT trigger update)
    // =====================
    @isTest
    static void testTrigger_NoFieldChanges() {
        Test.setMock(HttpCalloutMock.class, new MockSAPCallout());
        Customer__c customer = createTestCustomer();
        Deals__c deal = createTestDeal(customer.Id);

        Test.startTest();
        // Update a field that is NOT in the trigger condition
        deal.Name = 'Updated Deal Name';
        update deal;
        Test.stopTest();

        Deals__c updated = [SELECT Name FROM Deals__c WHERE Id = :deal.Id];
        System.assertEquals('Updated Deal Name', updated.Name, 'Name should be updated');
    }

    // =====================
    // TEST: Bulk Insert
    // =====================
    @isTest
    static void testTrigger_BulkInsert() {
        Test.setMock(HttpCalloutMock.class, new MockSAPCallout());
        Customer__c customer = createTestCustomer();

        Test.startTest();
        List<Deals__c> deals = new List<Deals__c>();
        for (Integer i = 0; i < 10; i++) {
            deals.add(new Deals__c(
                Name = 'Bulk Deal ' + i,
                Customer__c = customer.Id,
                Email__c = 'bulk' + i + '@example.com',
                Phone__c = '999000000' + i
            ));
        }
        insert deals;
        Test.stopTest();

        Integer count = [SELECT COUNT() FROM Deals__c WHERE Name LIKE 'Bulk Deal%'];
        System.assertEquals(10, count, 'Should have inserted 10 deals');
    }

    // =====================
    // TEST: Bulk Update
    // =====================
    @isTest
    static void testTrigger_BulkUpdate() {
        Test.setMock(HttpCalloutMock.class, new MockSAPCallout());
        Customer__c customer = createTestCustomer();

        List<Deals__c> deals = new List<Deals__c>();
        for (Integer i = 0; i < 10; i++) {
            deals.add(new Deals__c(
                Name = 'Bulk Update Deal ' + i,
                Customer__c = customer.Id,
                Email__c = 'bulkupdate' + i + '@example.com',
                Phone__c = '888000000' + i
            ));
        }
        insert deals;

        Test.startTest();
        for (Deals__c deal : deals) {
            deal.Email__c = 'updated' + deal.Email__c;
        }
        update deals;
        Test.stopTest();

        List<Deals__c> updated = [SELECT Email__c FROM Deals__c WHERE Name LIKE 'Bulk Update Deal%'];
        System.assertEquals(10, updated.size(), 'Should have updated 10 deals');
    }
}