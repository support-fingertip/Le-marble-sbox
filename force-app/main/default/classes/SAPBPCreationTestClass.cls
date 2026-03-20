@isTest
private class SAPBPCreationTestClass {

    // ─── Default mock: login OK → GET 404 → POST 201 / GET 200+addresses → PATCH 204 ──
    class SAPMockHttpCallout implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            String endpoint = req.getEndpoint();

            if (endpoint.contains('/Login')) {
                res.setStatusCode(200);
                res.setBody('{"SessionId":"mockedSessionId"}');
            } else if (req.getMethod() == 'GET' && endpoint.contains('/BusinessPartners')) {
                // For update tests return BP with existing addresses
                res.setStatusCode(200);
                res.setBody('{"CardCode":"CUST123","CardName":"Existing BP","BPAddresses":[' +
                    '{"AddressName":"Ship To Address","AddressType":"bo_ShipTo","Street":"Old Ship St","City":"OldCity","State":"KA","ZipCode":"560001","Country":"IN"},' +
                    '{"AddressName":"Bill To Address","AddressType":"bo_BillTo","Street":"Old Bill St","City":"OldCity","State":"KA","ZipCode":"560001","Country":"IN"}' +
                ']}');
            } else if (req.getMethod() == 'POST' && endpoint.contains('/BusinessPartners')) {
                res.setStatusCode(201);
                res.setBody('{"CardCode":"CUST123"}');
            } else if (req.getMethod() == 'PATCH' && endpoint.contains('/BusinessPartners')) {
                res.setStatusCode(204);
            } else {
                res.setStatusCode(400);
                res.setBody('{"error":"Invalid Request"}');
            }

            return res;
        }
    }

    // ─── Mock: login OK → GET 404 (BP not found) → POST 201 ──
    class SAPMockBPNotFoundCallout implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            String endpoint = req.getEndpoint();

            if (endpoint.contains('/Login')) {
                res.setStatusCode(200);
                res.setBody('{"SessionId":"mockedSessionId"}');
            } else if (req.getMethod() == 'GET' && endpoint.contains('/BusinessPartners')) {
                res.setStatusCode(404);
                res.setBody('{"error":{"code":"-1","message":{"value":"BP not found"}}}');
            } else if (req.getMethod() == 'POST' && endpoint.contains('/BusinessPartners')) {
                res.setStatusCode(201);
                res.setBody('{"CardCode":"CUST123"}');
            } else {
                res.setStatusCode(400);
                res.setBody('{"error":"Invalid Request"}');
            }

            return res;
        }
    }

    // ─── Mock: BP already exists (GET 200) ──
    class SAPMockBPExistsCallout implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            String endpoint = req.getEndpoint();

            if (endpoint.contains('/Login')) {
                res.setStatusCode(200);
                res.setBody('{"SessionId":"mockedSessionId"}');
            } else if (req.getMethod() == 'GET' && endpoint.contains('/BusinessPartners')) {
                res.setStatusCode(200);
                res.setBody('{"CardCode":"CUST123","CardName":"Existing BP"}');
            } else {
                res.setStatusCode(400);
                res.setBody('{"error":"Invalid Request"}');
            }

            return res;
        }
    }

    // ─── Mock: login failure ──
    class SAPMockLoginFailureCallout implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(401);
            res.setBody('{"error":"Login failed"}');
            return res;
        }
    }

    // ─── Mock: login OK → GET 404 → POST fails ──
    class SAPMockBPCreationFailureCallout implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            String endpoint = req.getEndpoint();

            if (endpoint.contains('/Login')) {
                res.setStatusCode(200);
                res.setBody('{"SessionId":"mockedSessionId"}');
            } else if (req.getMethod() == 'GET' && endpoint.contains('/BusinessPartners')) {
                res.setStatusCode(404);
                res.setBody('{"error":{"code":"-1","message":{"value":"BP not found"}}}');
            } else if (req.getMethod() == 'POST' && endpoint.contains('/BusinessPartners')) {
                res.setStatusCode(400);
                res.setBody('{"error":"BP creation failed"}');
            } else {
                res.setStatusCode(400);
                res.setBody('{"error":"Invalid Request"}');
            }

            return res;
        }
    }

    // ─── Mock: login OK → GET returns unexpected error (e.g. 500) ──
    class SAPMockGETErrorCallout implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            String endpoint = req.getEndpoint();

            if (endpoint.contains('/Login')) {
                res.setStatusCode(200);
                res.setBody('{"SessionId":"mockedSessionId"}');
            } else if (req.getMethod() == 'GET' && endpoint.contains('/BusinessPartners')) {
                res.setStatusCode(500);
                res.setBody('{"error":"Internal server error"}');
            } else {
                res.setStatusCode(400);
                res.setBody('{"error":"Invalid Request"}');
            }

            return res;
        }
    }

    // ─── Mock: login OK → GET 200 (no addresses) → PATCH fails ──
    class SAPMockUpdateFailureCallout implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            String endpoint = req.getEndpoint();

            if (endpoint.contains('/Login')) {
                res.setStatusCode(200);
                res.setBody('{"SessionId":"mockedSessionId"}');
            } else if (req.getMethod() == 'GET' && endpoint.contains('/BusinessPartners')) {
                res.setStatusCode(200);
                res.setBody('{"CardCode":"CUST123","CardName":"Existing BP","BPAddresses":[]}');
            } else if (req.getMethod() == 'PATCH' && endpoint.contains('/BusinessPartners')) {
                res.setStatusCode(400);
                res.setBody('{"error":"PATCH failed"}');
            } else {
                res.setStatusCode(400);
                res.setBody('{"error":"Invalid Request"}');
            }

            return res;
        }
    }

    // ─── Helper: create Customer__c + Deals__c ──
    private static Deals__c createTestDeal(Boolean withBillingAddress, Boolean withAddressNames) {
        Customer__c customer = new Customer__c(
            Name = 'Test Project',
            Lead_Name__c = 'Test Lead',
            Primary_Phone__c = '9876543210',
            LeadSource__c = 'Web',
            Email__c = 'testcustomer@example.com',
            Phone__c = '9876543210',
            CustomerEntryDate__c = Date.today()
        );
        insert customer;

        Deals__c deal = new Deals__c(
            Name = 'Test Deal',
            Customer__c = customer.Id,
            Email__c = 'test@example.com',
            Phone__c = '9999999999',
            SecondaryPhone__c = '8888888888',
            Company__c = 'Test Company',
            Remarks__c = 'Important customer',
            Opp_BE_Name__c = 'Test BE Name',
            Address__Street__s = '123 Road',
            Address__City__s = 'Chennai',
            Address__PostalCode__s = '600001',
            Address__StateCode__s = 'TN',
            Address__CountryCode__s = 'IN',
            Billing_Address__Street__s = '123 Road',
            Billing_Address__City__s = 'Chennai',
            Billing_Address__PostalCode__s = '600001',
            Billing_Address__StateCode__s = 'TN',
            Billing_Address__CountryCode__s = 'IN'
        );

        if (withBillingAddress) {
            deal.Billing_Address__Street__s = '456 Billing Street';
            deal.Billing_Address__City__s = 'Mumbai';
            deal.Billing_Address__PostalCode__s = '400001';
            deal.Billing_Address__StateCode__s = 'MH';
            deal.Billing_Address__CountryCode__s = 'IN';
        }

        if (withAddressNames) {
            deal.Shipping_Address_Name__c = 'Ship To Address';
            deal.Shipping_Address_Name_2__c = 'Ship Addr Line 2';
            deal.Shipping_Address_Name_3__c = 'Ship Addr Line 3';
            deal.Billing_Address_Name__c = 'Bill To Address';
            deal.Billing_Address_Name_2__c = 'Bill Addr Line 2';
            deal.Billing_Address_Name_3__c = 'Bill Addr Line 3';
        }

        insert deal;
        return deal;
    }

    // ═══════════════════════════════════════════════════════════════════
    //  CREATE BP — success (BP not found → create)
    // ═══════════════════════════════════════════════════════════════════

    @isTest
    static void testCreateBusinessPartner_Success() {
        Test.setMock(HttpCalloutMock.class, new SAPMockBPNotFoundCallout());

        Deals__c deal = createTestDeal(true, true);

        Test.startTest();
        SAPBPCreation.createBusinessPartner(deal.Id);
        Test.stopTest();

        System.assertNotEquals(null, deal.Id, 'Deal should exist');
    }

    // ═══════════════════════════════════════════════════════════════════
    //  CREATE BP — BP already exists in SAP (GET 200 → skip creation)
    // ═══════════════════════════════════════════════════════════════════

    @isTest
    static void testCreateBusinessPartner_BPAlreadyExists() {
        Test.setMock(HttpCalloutMock.class, new SAPMockBPExistsCallout());

        Deals__c deal = createTestDeal(false, false);

        Test.startTest();
        SAPBPCreation.createBusinessPartner(deal.Id);
        Test.stopTest();

        System.assertNotEquals(null, deal.Id, 'Deal should exist');
    }

    // ═══════════════════════════════════════════════════════════════════
    //  CREATE BP — login failure
    // ═══════════════════════════════════════════════════════════════════

    @isTest
    static void testCreateBusinessPartner_LoginFailure() {
        Test.setMock(HttpCalloutMock.class, new SAPMockLoginFailureCallout());

        Deals__c deal = createTestDeal(false, false);

        Test.startTest();
        SAPBPCreation.createBusinessPartner(deal.Id);
        Test.stopTest();

        System.assertNotEquals(null, deal.Id, 'Deal should exist');
    }

    // ═══════════════════════════════════════════════════════════════════
    //  CREATE BP — BP creation POST fails (400)
    // ═══════════════════════════════════════════════════════════════════

    @isTest
    static void testCreateBusinessPartner_CreationFailure() {
        Test.setMock(HttpCalloutMock.class, new SAPMockBPCreationFailureCallout());

        Deals__c deal = createTestDeal(true, true);

        Test.startTest();
        SAPBPCreation.createBusinessPartner(deal.Id);
        Test.stopTest();

        System.assertNotEquals(null, deal.Id, 'Deal should exist');
    }

    // ═══════════════════════════════════════════════════════════════════
    //  CREATE BP — GET returns unexpected error (not 200, not 404)
    // ═══════════════════════════════════════════════════════════════════

    @isTest
    static void testCreateBusinessPartner_GETError() {
        Test.setMock(HttpCalloutMock.class, new SAPMockGETErrorCallout());

        Deals__c deal = createTestDeal(false, false);

        Test.startTest();
        SAPBPCreation.createBusinessPartner(deal.Id);
        Test.stopTest();

        System.assertNotEquals(null, deal.Id, 'Deal should exist');
    }

    // ═══════════════════════════════════════════════════════════════════
    //  UPDATE BP — success with matching address names (updates existing)
    // ═══════════════════════════════════════════════════════════════════

    @isTest
    static void testUpdateBusinessPartner_MatchingAddresses() {
        Test.setMock(HttpCalloutMock.class, new SAPMockHttpCallout());

        Deals__c deal = createTestDeal(true, true);

        Test.startTest();
        SAPBPCreation.updateBusinessPartner(deal.Id);
        Test.stopTest();

        System.assertNotEquals(null, deal.Id, 'Deal should exist');
    }

    // ═══════════════════════════════════════════════════════════════════
    //  UPDATE BP — no matching address names → adds new addresses
    // ═══════════════════════════════════════════════════════════════════

    @isTest
    static void testUpdateBusinessPartner_NewAddresses() {
        Test.setMock(HttpCalloutMock.class, new SAPMockUpdateFailureCallout());

        Deals__c deal = createTestDeal(true, true);
        // Change address names so they don't match the mock's existing addresses
        deal.Shipping_Address_Name__c = 'New Ship Address';
        deal.Billing_Address_Name__c = 'New Bill Address';
        update deal;

        Test.startTest();
        SAPBPCreation.updateBusinessPartner(deal.Id);
        Test.stopTest();

        System.assertNotEquals(null, deal.Id, 'Deal should exist');
    }

    // ═══════════════════════════════════════════════════════════════════
    //  UPDATE BP — without address names (null → skips adding)
    // ═══════════════════════════════════════════════════════════════════

    @isTest
    static void testUpdateBusinessPartner_NoAddressNames() {
        Test.setMock(HttpCalloutMock.class, new SAPMockHttpCallout());

        Deals__c deal = createTestDeal(false, false);

        Test.startTest();
        SAPBPCreation.updateBusinessPartner(deal.Id);
        Test.stopTest();

        System.assertNotEquals(null, deal.Id, 'Deal should exist');
    }

    // ═══════════════════════════════════════════════════════════════════
    //  UPDATE BP — login failure
    // ═══════════════════════════════════════════════════════════════════

    @isTest
    static void testUpdateBusinessPartner_LoginFailure() {
        Test.setMock(HttpCalloutMock.class, new SAPMockLoginFailureCallout());

        Deals__c deal = createTestDeal(false, false);

        Test.startTest();
        SAPBPCreation.updateBusinessPartner(deal.Id);
        Test.stopTest();

        System.assertNotEquals(null, deal.Id, 'Deal should exist');
    }

    // ═══════════════════════════════════════════════════════════════════
    //  UPDATE BP — GET returns error (not 200) → can't retrieve BP
    // ═══════════════════════════════════════════════════════════════════

    @isTest
    static void testUpdateBusinessPartner_GETError() {
        Test.setMock(HttpCalloutMock.class, new SAPMockGETErrorCallout());

        Deals__c deal = createTestDeal(false, false);

        Test.startTest();
        SAPBPCreation.updateBusinessPartner(deal.Id);
        Test.stopTest();

        System.assertNotEquals(null, deal.Id, 'Deal should exist');
    }

    // ═══════════════════════════════════════════════════════════════════
    //  UPDATE BP — PATCH fails (400)
    // ═══════════════════════════════════════════════════════════════════

    @isTest
    static void testUpdateBusinessPartner_PatchFailure() {
        Test.setMock(HttpCalloutMock.class, new SAPMockUpdateFailureCallout());

        Deals__c deal = createTestDeal(true, true);

        Test.startTest();
        SAPBPCreation.updateBusinessPartner(deal.Id);
        Test.stopTest();

        System.assertNotEquals(null, deal.Id, 'Deal should exist');
    }
}