@isTest
private class TestSAPUpdateBusinessPartner {

    class MockUpdateBPCallout implements HttpCalloutMock {
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
                res.setStatusCode(204); // Success
            } else {
                res.setStatusCode(400);
                res.setBody('{"error":"Invalid request"}');
            }

            return res;
        }
    }

    @isTest
    static void testUpdateBusinessPartner() {
        Test.setMock(HttpCalloutMock.class, new MockUpdateBPCallout());

        Customer__c customer = new Customer__c(Name='Test Customer', Customer_ID__c='CUST123');
        insert customer;

        Deals__c deal = new Deals__c(
            Name = 'Deal Vishwa',
            Customer__c = customer.Id,
            Email__c = 'vishwa@example.com',
            Phone__c = '9999999999',
            SecondaryPhone__c = '8888888888',
            Company__c = 'Vishwa Corp',
            Remarks__c = 'VIP Client',
            Address__Street__s = '123 Gandhi Road',
            Address__City__s = 'Chennai',
            Address__PostalCode__s = '600001',
            Address__StateCode__s = 'TN',
            Address__CountryCode__s = 'IN'
        );
        insert deal;

        Test.startTest();
        SAPBPCreation.updateBusinessPartner(deal.Id);
        Test.stopTest();

        System.debug('✅ Direct updateBusinessPartner() method call tested.');
    }

    @isTest
    static void testOppSAPTriggerInsert() {
        Test.setMock(HttpCalloutMock.class, new MockUpdateBPCallout());

        Customer__c customer = new Customer__c(Name='Test Customer', Customer_ID__c='CUST123');
        insert customer;

        Test.startTest();
        Deals__c deal = new Deals__c(
            Name = 'Test Deal Insert',
            Customer__c = customer.Id,
            Email__c = 'test@example.com',
            Phone__c = '9999999999',
            Company__c = 'Test Company',
            Remarks__c = 'Test remarks',
            Address__Street__s = '123 Road',
            Address__City__s = 'Chennai',
            Address__PostalCode__s = '600001',
            Address__StateCode__s = 'TN',
            Address__CountryCode__s = 'IN'
        );
        insert deal;
        Test.stopTest();

        System.debug('✅ OppSAPTrigger insert test completed.');
    }

    @isTest
    static void testOppSAPTriggerUpdateName() {
        Test.setMock(HttpCalloutMock.class, new MockUpdateBPCallout());

        Customer__c customer = new Customer__c(Name='Test Customer', Customer_ID__c='CUST123');
        insert customer;

        Deals__c deal = new Deals__c(
            Name = 'Original Name',
            Customer__c = customer.Id,
            Email__c = 'test@example.com',
            Phone__c = '9999999999',
            Company__c = 'Test Company',
            Remarks__c = 'Test remarks',
            Address__Street__s = '123 Road',
            Address__City__s = 'Chennai',
            Address__PostalCode__s = '600001',
            Address__StateCode__s = 'TN',
            Address__CountryCode__s = 'IN'
        );
        insert deal;

        Test.startTest();
        deal.Name = 'Updated Name';
        update deal;
        Test.stopTest();

        System.debug('✅ OppSAPTrigger update name test completed.');
    }

    @isTest
    static void testOppSAPTriggerUpdateEmail() {
        Test.setMock(HttpCalloutMock.class, new MockUpdateBPCallout());

        Customer__c customer = new Customer__c(Name='Test Customer', Customer_ID__c='CUST123');
        insert customer;

        Deals__c deal = new Deals__c(
            Name = 'Test Deal',
            Customer__c = customer.Id,
            Email__c = 'original@example.com',
            Phone__c = '9999999999',
            Company__c = 'Test Company',
            Remarks__c = 'Test remarks',
            Address__Street__s = '123 Road',
            Address__City__s = 'Chennai',
            Address__PostalCode__s = '600001',
            Address__StateCode__s = 'TN',
            Address__CountryCode__s = 'IN'
        );
        insert deal;

        Test.startTest();
        deal.Email__c = 'updated@example.com';
        update deal;
        Test.stopTest();

        System.debug('✅ OppSAPTrigger update email test completed.');
    }

    @isTest
    static void testOppSAPTriggerUpdatePhone() {
        Test.setMock(HttpCalloutMock.class, new MockUpdateBPCallout());

        Customer__c customer = new Customer__c(Name='Test Customer', Customer_ID__c='CUST123');
        insert customer;

        Deals__c deal = new Deals__c(
            Name = 'Test Deal',
            Customer__c = customer.Id,
            Email__c = 'test@example.com',
            Phone__c = '9999999999',
            Company__c = 'Test Company',
            Remarks__c = 'Test remarks',
            Address__Street__s = '123 Road',
            Address__City__s = 'Chennai',
            Address__PostalCode__s = '600001',
            Address__StateCode__s = 'TN',
            Address__CountryCode__s = 'IN'
        );
        insert deal;

        Test.startTest();
        deal.Phone__c = '8888888888';
        update deal;
        Test.stopTest();

        System.debug('✅ OppSAPTrigger update phone test completed.');
    }

    @isTest
    static void testOppSAPTriggerUpdateAddress() {
        Test.setMock(HttpCalloutMock.class, new MockUpdateBPCallout());

        Customer__c customer = new Customer__c(Name='Test Customer', Customer_ID__c='CUST123');
        insert customer;

        Deals__c deal = new Deals__c(
            Name = 'Test Deal',
            Customer__c = customer.Id,
            Email__c = 'test@example.com',
            Phone__c = '9999999999',
            Company__c = 'Test Company',
            Remarks__c = 'Test remarks',
            Address__Street__s = '123 Road',
            Address__City__s = 'Chennai',
            Address__PostalCode__s = '600001',
            Address__StateCode__s = 'TN',
            Address__CountryCode__s = 'IN'
        );
        insert deal;

        Test.startTest();
        deal.Address__Street__s = '456 New Street';
        deal.Address__City__s = 'Mumbai';
        update deal;
        Test.stopTest();

        System.debug('✅ OppSAPTrigger update address test completed.');
    }

    @isTest
    static void testOppSAPTriggerUpdateBillingAddress() {
        Test.setMock(HttpCalloutMock.class, new MockUpdateBPCallout());

        Customer__c customer = new Customer__c(Name='Test Customer', Customer_ID__c='CUST123');
        insert customer;

        Deals__c deal = new Deals__c(
            Name = 'Test Deal',
            Customer__c = customer.Id,
            Email__c = 'test@example.com',
            Phone__c = '9999999999',
            Company__c = 'Test Company',
            Remarks__c = 'Test remarks',
            Address__Street__s = '123 Road',
            Address__City__s = 'Chennai',
            Address__PostalCode__s = '600001',
            Address__StateCode__s = 'TN',
            Address__CountryCode__s = 'IN',
            Billing_Address__Street__s = '789 Billing Street',
            Billing_Address__City__s = 'Delhi',
            Billing_Address__PostalCode__s = '110001',
            Billing_Address__StateCode__s = 'DL',
            Billing_Address__CountryCode__s = 'IN'
        );
        insert deal;

        Test.startTest();
        deal.Billing_Address__Street__s = '999 New Billing Street';
        deal.Billing_Address__City__s = 'Bangalore';
        update deal;
        Test.stopTest();

        System.debug('✅ OppSAPTrigger update billing address test completed.');
    }

    @isTest
    static void testOppSAPTriggerUpdateAddressNames() {
        Test.setMock(HttpCalloutMock.class, new MockUpdateBPCallout());

        Customer__c customer = new Customer__c(Name='Test Customer', Customer_ID__c='CUST123');
        insert customer;

        Deals__c deal = new Deals__c(
            Name = 'Test Deal',
            Customer__c = customer.Id,
            Email__c = 'test@example.com',
            Phone__c = '9999999999',
            Company__c = 'Test Company',
            Remarks__c = 'Test remarks',
            Address__Street__s = '123 Road',
            Address__City__s = 'Chennai',
            Address__PostalCode__s = '600001',
            Address__StateCode__s = 'TN',
            Address__CountryCode__s = 'IN',
            Shipping_Address_Name__c = 'Original Ship To',
            Billing_Address_Name__c = 'Original Bill To'
        );
        insert deal;

        Test.startTest();
        deal.Shipping_Address_Name__c = 'Updated Ship To';
        deal.Billing_Address_Name__c = 'Updated Bill To';
        update deal;
        Test.stopTest();

        System.debug('✅ OppSAPTrigger update address names test completed.');
    }

    @isTest
    static void testOppSAPTriggerNoChanges() {
        Test.setMock(HttpCalloutMock.class, new MockUpdateBPCallout());

        Customer__c customer = new Customer__c(Name='Test Customer', Customer_ID__c='CUST123');
        insert customer;

        Deals__c deal = new Deals__c(
            Name = 'Test Deal',
            Customer__c = customer.Id,
            Email__c = 'test@example.com',
            Phone__c = '9999999999',
            Company__c = 'Test Company',
            Remarks__c = 'Test remarks',
            Address__Street__s = '123 Road',
            Address__City__s = 'Chennai',
            Address__PostalCode__s = '600001',
            Address__StateCode__s = 'TN',
            Address__CountryCode__s = 'IN'
        );
        insert deal;

        Test.startTest();
        // Update a field that doesn't trigger the SAP update
        deal.Remarks__c = 'Updated remarks but no address changes';
        update deal;
        Test.stopTest();

        System.debug('✅ OppSAPTrigger no changes test completed.');
    }
    
}