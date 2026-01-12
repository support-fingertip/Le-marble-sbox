@isTest
private class SAPBPCreationTestClass {

    class SAPMockHttpCallout implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            String endpoint = req.getEndpoint();

            if (endpoint.contains('/Login')) {
                res.setStatusCode(200);
                res.setBody('{"SessionId":"mockedSessionId"}');
            } else if (req.getMethod() == 'GET' && endpoint.contains('/BusinessPartners')) {
                res.setStatusCode(404); // simulate BP not found
                res.setBody('{"error":{"code":"-1","message":{"value":"BP not found"}}}');
            } else if (req.getMethod() == 'POST' && endpoint.contains('/BusinessPartners')) {
                res.setStatusCode(201); // simulate successful creation
                res.setBody('{"CardCode":"CUST123"}');
            } else if (req.getMethod() == 'PATCH' && endpoint.contains('/BusinessPartners')) {
                res.setStatusCode(204); // simulate successful update
            } else {
                res.setStatusCode(400);
                res.setBody('{"error":"Invalid Request"}');
            }

            return res;
        }
    }

    // Mock for BP already exists scenario
    class SAPMockBPExistsCallout implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            String endpoint = req.getEndpoint();

            if (endpoint.contains('/Login')) {
                res.setStatusCode(200);
                res.setBody('{"SessionId":"mockedSessionId"}');
            } else if (req.getMethod() == 'GET' && endpoint.contains('/BusinessPartners')) {
                res.setStatusCode(200); // BP already exists
                res.setBody('{"CardCode":"CUST123","CardName":"Existing BP"}');
            } else {
                res.setStatusCode(400);
                res.setBody('{"error":"Invalid Request"}');
            }

            return res;
        }
    }

    // Mock for login failure scenario
    class SAPMockLoginFailureCallout implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(401);
            res.setBody('{"error":"Login failed"}');
            return res;
        }
    }

    // Mock for BP creation failure scenario
    class SAPMockBPCreationFailureCallout implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            String endpoint = req.getEndpoint();

            if (endpoint.contains('/Login')) {
                res.setStatusCode(200);
                res.setBody('{"SessionId":"mockedSessionId"}');
            } else if (req.getMethod() == 'GET' && endpoint.contains('/BusinessPartners')) {
                res.setStatusCode(404); // BP not found
                res.setBody('{"error":{"code":"-1","message":{"value":"BP not found"}}}');
            } else if (req.getMethod() == 'POST' && endpoint.contains('/BusinessPartners')) {
                res.setStatusCode(400); // BP creation failed
                res.setBody('{"error":"BP creation failed"}');
            } else {
                res.setStatusCode(400);
                res.setBody('{"error":"Invalid Request"}');
            }

            return res;
        }
    }

    @isTest
    static void testCreateBusinessPartnerOnInsert() {
        Test.setMock(HttpCalloutMock.class, new SAPMockHttpCallout());

        Customer__c customer = new Customer__c(
            Name = 'Test Project - Vishwa',
            LeadSource__c = 'Web',
            Email__c = 'testcustomer@example.com',
            Status__c = 'Tamil Nadu',
            Phone__c = '9876543210',
            CustomerEntryDate__c = Date.newInstance(2025, 6, 11)
        );
        insert customer;

        Test.startTest();

        Deals__c deal = new Deals__c(
            Name = 'Test Deal',
            Customer__c = customer.Id,
            Email__c = 'test@example.com',
            Phone__c = '9999999999',
            SecondaryPhone__c = '8888888888',
            Company__c = 'Test Company',
            Remarks__c = 'Important customer',
            Address__Street__s = '123 Road',
            Address__City__s = 'Chennai',
            Address__PostalCode__s = '600001',
            Address__StateCode__s = 'TN',
            Address__CountryCode__s = 'IN'
        );
        insert deal;
        
        

        Test.stopTest();

        System.debug('✅ Created Business Partner successfully on insert.');
    }

    @isTest
    static void testUpdateBusinessPartnerOnFieldChange() {
        Test.setMock(HttpCalloutMock.class, new SAPMockHttpCallout());

        Customer__c customer = new Customer__c(
            Name = 'Test Project - Vishwa',
            LeadSource__c = 'Web',
            Email__c = 'testcustomer@example.com',
            Status__c = 'Tamil Nadu',
            Phone__c = '9876543210',
            CustomerEntryDate__c = Date.newInstance(2025, 6, 11)
        );
        insert customer;

        Deals__c deal = new Deals__c(
            Name = 'Test Deal',
            Customer__c = customer.Id,
            Email__c = 'test@example.com',
            Phone__c = '9999999999',
            SecondaryPhone__c = '8888888888',
            Company__c = 'Test Company',
            Remarks__c = 'Initial Remarks',
            Address__Street__s = '123 Road',
            Address__City__s = 'Chennai',
            Address__PostalCode__s = '600001',
            Address__StateCode__s = 'TN',
            Address__CountryCode__s = 'IN'
        );
        insert deal;

        Test.startTest();

        deal.Remarks__c = 'Updated Remarks'; // triggers update logic
        update deal;

        Test.stopTest();

        System.debug('✅ Updated Business Partner successfully on field change.');
    }

    @isTest
    static void testCreateBusinessPartnerBPAlreadyExists() {
        Test.setMock(HttpCalloutMock.class, new SAPMockBPExistsCallout());

        Customer__c customer = new Customer__c(
            Name = 'Test Customer',
            LeadSource__c = 'Web',
            Email__c = 'test@example.com',
            Status__c = 'Active',
            Phone__c = '9876543210',
            CustomerEntryDate__c = Date.today()
        );
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
        SAPBPCreation.createBusinessPartner(deal.Id);
        Test.stopTest();

        System.debug('✅ Tested BP already exists scenario.');
    }

    @isTest
    static void testCreateBusinessPartnerLoginFailure() {
        Test.setMock(HttpCalloutMock.class, new SAPMockLoginFailureCallout());

        Customer__c customer = new Customer__c(
            Name = 'Test Customer',
            LeadSource__c = 'Web',
            Email__c = 'test@example.com',
            Status__c = 'Active',
            Phone__c = '9876543210',
            CustomerEntryDate__c = Date.today()
        );
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
        SAPBPCreation.createBusinessPartner(deal.Id);
        Test.stopTest();

        System.debug('✅ Tested login failure scenario.');
    }

    @isTest
    static void testCreateBusinessPartnerCreationFailure() {
        Test.setMock(HttpCalloutMock.class, new SAPMockBPCreationFailureCallout());

        Customer__c customer = new Customer__c(
            Name = 'Test Customer',
            LeadSource__c = 'Web',
            Email__c = 'test@example.com',
            Status__c = 'Active',
            Phone__c = '9876543210',
            CustomerEntryDate__c = Date.today()
        );
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
        SAPBPCreation.createBusinessPartner(deal.Id);
        Test.stopTest();

        System.debug('✅ Tested BP creation failure scenario.');
    }

    @isTest
    static void testUpdateBusinessPartnerWithAddresses() {
        Test.setMock(HttpCalloutMock.class, new SAPMockHttpCallout());

        Customer__c customer = new Customer__c(
            Name = 'Test Customer',
            LeadSource__c = 'Web',
            Email__c = 'test@example.com',
            Status__c = 'Active',
            Phone__c = '9876543210',
            CustomerEntryDate__c = Date.today()
        );
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
            Billing_Address__Street__s = '456 Billing Street',
            Billing_Address__City__s = 'Mumbai',
            Billing_Address__PostalCode__s = '400001',
            Billing_Address__StateCode__s = 'MH',
            Billing_Address__CountryCode__s = 'IN',
            Shipping_Address_Name__c = 'Ship To Address',
            Billing_Address_Name__c = 'Bill To Address'
        );
        insert deal;

        Test.startTest();
        SAPBPCreation.updateBusinessPartner(deal.Id);
        Test.stopTest();

        System.debug('✅ Tested update BP with addresses scenario.');
    }

    @isTest
    static void testUpdateBusinessPartnerLoginFailure() {
        Test.setMock(HttpCalloutMock.class, new SAPMockLoginFailureCallout());

        Customer__c customer = new Customer__c(
            Name = 'Test Customer',
            LeadSource__c = 'Web',
            Email__c = 'test@example.com',
            Status__c = 'Active',
            Phone__c = '9876543210',
            CustomerEntryDate__c = Date.today()
        );
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
        SAPBPCreation.updateBusinessPartner(deal.Id);
        Test.stopTest();

        System.debug('✅ Tested update BP login failure scenario.');
    }
}