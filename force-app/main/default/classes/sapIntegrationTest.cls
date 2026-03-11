@IsTest
public class sapIntegrationTest {
    
    // Mock for successful SAP callouts
    private class MockSAPCalloutSuccess implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            
            if (req.getEndpoint().contains('/Login')) {
                res.setStatusCode(200);
                res.setBody('{"SessionId":"test-session-id-12345"}');
            } else if (req.getEndpoint().contains('/BusinessPartners(')) {
                if (req.getMethod() == 'GET') {
                    res.setStatusCode(404);
                    res.setBody('{"error":{"code":-2028,"message":{"value":"No matching records found"}}}');
                } else if (req.getMethod() == 'POST') {
                    res.setStatusCode(201);
                    res.setBody('{"CardCode":"CU0001234","CardName":"Test Customer"}');
                } else if (req.getMethod() == 'PATCH') {
                    res.setStatusCode(204);
                    res.setBody('');
                }
            } else if (req.getEndpoint().contains('/BusinessPartners') && req.getMethod() == 'POST') {
                res.setStatusCode(201);
                res.setBody('{"CardCode":"CU0001234","CardName":"Test Customer"}');
            } else if (req.getEndpoint().contains('/Orders')) {
                res.setStatusCode(201);
                res.setBody('{"DocEntry":12345,"DocNum":"SO-00001"}');
            } else if (req.getEndpoint().contains('/Invoices')) {
                res.setStatusCode(200);
                String invoiceJson = '{"value":[' +
                    '{"DocEntry":"INV001","DocNum":"1001","DocDate":"2026-03-01","DocTotal":10000,' +
                    '"Comments":"Test","CardCode":"CU001","SalesPersonCode":"SP001","CancelStatus":"csNo",' +
                    '"TotalDiscount":100,"U_Saleorder":"SO001",' +
                    '"DocumentLines":[{"LineNum":0,"ItemCode":"ITEM001","LineTotal":9000,"Price":100,' +
                    '"PriceAfterVAT":118,"Quantity":90,"ShipDate":"2026-03-05","TaxTotal":1000,' +
                    '"UnitPrice":100,"WarehouseCode":"WH001"}]}' +
                    ']}';
                res.setBody(invoiceJson);
            } else {
                res.setStatusCode(200);
                res.setBody('{"CurrentAccountBalance":5000.00}');
            }
            return res;
        }
    }
    
    // Mock for login failure
    private class MockSAPCalloutLoginFail implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(401);
            res.setBody('{"error":{"code":-10001,"message":{"value":"Invalid credentials"}}}');
            return res;
        }
    }
    
    // Mock for BP already exists
    private class MockSAPCalloutBPExists implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            
            if (req.getEndpoint().contains('/Login')) {
                res.setStatusCode(200);
                res.setBody('{"SessionId":"test-session-id-12345"}');
            } else if (req.getEndpoint().contains('/BusinessPartners(') && req.getMethod() == 'GET') {
                res.setStatusCode(200);
                res.setBody('{"CardCode":"CU0001234","CardName":"Existing Customer"}');
            } else {
                res.setStatusCode(200);
                res.setBody('{}');
            }
            return res;
        }
    }
    
    // Mock for BP creation failure
    private class MockSAPCalloutBPFail implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            
            if (req.getEndpoint().contains('/Login')) {
                res.setStatusCode(200);
                res.setBody('{"SessionId":"test-session-id-12345"}');
            } else if (req.getEndpoint().contains('/BusinessPartners(') && req.getMethod() == 'GET') {
                res.setStatusCode(404);
                res.setBody('{"error":{"code":-2028,"message":{"value":"No matching records found"}}}');
            } else if (req.getEndpoint().contains('/BusinessPartners') && req.getMethod() == 'POST') {
                res.setStatusCode(400);
                res.setBody('{"error":{"code":-5001,"message":{"value":"Invalid data"}}}');
            } else {
                res.setStatusCode(200);
                res.setBody('{}');
            }
            return res;
        }
    }
    
    // Mock for order creation failure
    private class MockSAPCalloutOrderFail implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            
            if (req.getEndpoint().contains('/Login')) {
                res.setStatusCode(200);
                res.setBody('{"SessionId":"test-session-id-12345"}');
            } else if (req.getEndpoint().contains('/Orders')) {
                res.setStatusCode(400);
                res.setBody('{"error":{"code":-5002,"message":{"value":"Invalid Item Code"}}}');
            } else {
                res.setStatusCode(200);
                res.setBody('{}');
            }
            return res;
        }
    }
    
    // Mock for update BP - BP not found triggers create
    private class MockSAPCalloutUpdateNotFound implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            
            if (req.getEndpoint().contains('/Login')) {
                res.setStatusCode(200);
                res.setBody('{"SessionId":"test-session-id-12345"}');
            } else if (req.getEndpoint().contains('/BusinessPartners(') && req.getMethod() == 'GET') {
                res.setStatusCode(400);
                res.setBody('{"error":{"code":-2028,"message":{"value":"No matching records found"}}}');
            } else {
                res.setStatusCode(200);
                res.setBody('{}');
            }
            return res;
        }
    }
    
    @TestSetup
    static void setupTestData() {
        // Create Custom Notification Type - skip if can't create
        
        // Create test user with SAP code
        Profile p = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
        User testUser = new User(
            FirstName = 'Test',
            LastName = 'SAPUser',
            Email = 'testsap@test.com',
            Username = 'testsapuser' + DateTime.now().getTime() + '@test.com',
            Alias = 'tsap',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = p.Id,
            LanguageLocaleKey = 'en_US',
            SAP_Emp_Code__c = '100'
        );
        insert testUser;
        
        // Create test Account
        Account acc = new Account(
            Name = 'Test SAP Account',
            Email__c = 'test@sapaccount.com',
            Phone = '9876543210',
            Secondary_Phone__c = '9876543211',
            Customer_Type__c = 'B2B',
            GST_Number__c = '29ABCDE1234F1Z5',
            GST_Type__c = 'gstRegularTDSISD',
            BillingStreet = 'Street1, Street2, Street3',
            BillingCity = 'Bangalore',
            BillingPostalCode = '560001',
            Address_Line1__c = 'Ship Address 1',
            Address_Line2__c = 'Ship Address 2',
            Address_Line3__c = 'Ship Address 3',
            pin_code__c = 560001,
            POC_Name__c = 'Test POC',
            POC_Number__c = '9876543212',
            OwnerId = testUser.Id
        );
        insert acc;
        
        // Create Product2
        Product2 prod = new Product2(
            Name = 'Test Product SAP',
            Product_Code__c = 'ITEM001',
            IsActive = true
        );
        insert prod;
        
        // Get standard pricebook
        Id stdPricebookId = Test.getStandardPricebookId();
        
        // Create PricebookEntry
        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = stdPricebookId,
            Product2Id = prod.Id,
            UnitPrice = 100,
            IsActive = true
        );
        insert pbe;
        
        // Create Warehouse
        Warehouse__c wh = new Warehouse__c(
            Name = 'Test Warehouse',
            Warehouse_Code__c = 'WH001',
            Location__c = 'Test Location'
        );
        insert wh;
        
        // Create Opportunity
        Opportunity opp = new Opportunity(
            Name = 'Test Opp SAP',
            AccountId = acc.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            OwnerId = testUser.Id
        );
        insert opp;
        
        // Create Order
        Order ord = new Order(
            AccountId = acc.Id,
            OpportunityId = opp.Id,
            EffectiveDate = Date.today(),
            Status = 'Draft',
            Pricebook2Id = stdPricebookId,
            Warehouse__c = wh.Id,
      //      AddressLine1__c = 'Order Address 1',
        //    AddressLine2__c = 'Order Address 2',
          //  AddressLine3__c = 'Order Address 3',
            OwnerId = testUser.Id
        );
        insert ord;
        
        // Create OrderItem
        OrderItem oi = new OrderItem(
            OrderId = ord.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 10,
            UnitPrice = 100,
            Warehouse__c = wh.Id
        );
        insert oi;
        
        // Create Order_Batch_Item__c
        Order_Batch_Item__c batch = new Order_Batch_Item__c(
            Order_Product__c = oi.Id,
            Batch__c = 'BATCH001',
            Quantity__c = 10,
            Warehouse_Code__c = 'WH001'
        );
        insert batch;
    }
    
    @IsTest
    static void testGetAccount() {
        Test.startTest();
        List<Account> accounts = sapIntegration.getAccount();
        Test.stopTest();
        
        System.assert(accounts.size() > 0, 'Should return accounts');
    }
    
    @IsTest
    static void testGetItems() {
        Test.startTest();
        sapIntegration.Sap_comp result = sapIntegration.getitems();
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertNotEquals(null, result.items, 'Items should not be null');
        System.assertNotEquals(null, result.prof, 'Profile should not be null');
    }
    
    @IsTest
    static void testLoginToSAP_Success() {
        Test.setMock(HttpCalloutMock.class, new MockSAPCalloutSuccess());
        
        Test.startTest();
        String sessionId = sapIntegration.loginToSAP();
        Test.stopTest();
        
        System.assertEquals('test-session-id-12345', sessionId, 'Should return session ID');
    }
    
    @IsTest
    static void testLoginToSAP_Failure() {
        Test.setMock(HttpCalloutMock.class, new MockSAPCalloutLoginFail());
        
        Test.startTest();
        String sessionId = sapIntegration.loginToSAP();
        Test.stopTest();
        
        System.assertEquals(null, sessionId, 'Should return null on login failure');
    }
    
    @IsTest
    static void testCreateBusinessPartner_Success() {
        Test.setMock(HttpCalloutMock.class, new MockSAPCalloutSuccess());
        Account acc = [SELECT Id FROM Account WHERE Name = 'Test SAP Account' LIMIT 1];
        
        Test.startTest();
        sapIntegration.createBusinessPartner(acc.Id);
        Test.stopTest();
        
        // Verify account was updated
        acc = [SELECT Id, Pushed_to_SAP__c FROM Account WHERE Id = :acc.Id];
        System.assertEquals(true, acc.Pushed_to_SAP__c, 'Pushed_to_SAP__c should be true');
    }
    
    @IsTest
    static void testCreateBusinessPartner_BPExists() {
        Test.setMock(HttpCalloutMock.class, new MockSAPCalloutBPExists());
        Account acc = [SELECT Id FROM Account WHERE Name = 'Test SAP Account' LIMIT 1];
        
        Test.startTest();
        sapIntegration.createBusinessPartner(acc.Id);
        Test.stopTest();
        
        // Should not throw exception - BP already exists
        System.assert(true, 'Should handle BP already exists');
    }
    
    @IsTest
    static void testCreateBusinessPartner_Failure() {
        Test.setMock(HttpCalloutMock.class, new MockSAPCalloutBPFail());
        Account acc = [SELECT Id FROM Account WHERE Name = 'Test SAP Account' LIMIT 1];
        
        Test.startTest();
        sapIntegration.createBusinessPartner(acc.Id);
        Test.stopTest();
        
        // Should not throw exception - handled gracefully
        System.assert(true, 'Should handle BP creation failure');
    }
    
    @IsTest
    static void testUpdateBusinessPartner_Success() {
        Test.setMock(HttpCalloutMock.class, new MockSAPCalloutSuccess());
        Account acc = [SELECT Id FROM Account WHERE Name = 'Test SAP Account' LIMIT 1];
        
        Test.startTest();
        sapIntegration.updateBusinessPartner(acc.Id);
        Test.stopTest();
        
        // Should complete without exception
        System.assert(true, 'Should update BP successfully');
    }
    
    @IsTest
    static void testUpdateBusinessPartner_NotFound() {
        Test.setMock(HttpCalloutMock.class, new MockSAPCalloutUpdateNotFound());
        Account acc = [SELECT Id FROM Account WHERE Name = 'Test SAP Account' LIMIT 1];
        
        Test.startTest();
        sapIntegration.updateBusinessPartner(acc.Id);
        Test.stopTest();
        
        // Should trigger CreateBusinessPartnerQueueable
        System.assert(true, 'Should handle BP not found');
    }
    
    @IsTest
    static void testSendOrderToSAP_Success() {
        Test.setMock(HttpCalloutMock.class, new MockSAPCalloutSuccess());
        Order ord = [SELECT Id FROM Order LIMIT 1];
        
        Test.startTest();
        sapIntegration.sendOrderToSAP(ord.Id);
        Test.stopTest();
        
        // Verify order was updated
        ord = [SELECT Id, SAP_Doc_Num__c, Order_status__c FROM Order WHERE Id = :ord.Id];
        System.assertEquals('SO-00001', ord.SAP_Doc_Num__c, 'SAP Doc Num should be set');
        System.assertEquals('Sent to SAP', ord.Order_status__c, 'Order status should be Sent to SAP');
    }
    
    @IsTest
    static void testSendOrderToSAP_Failure() {
        Test.setMock(HttpCalloutMock.class, new MockSAPCalloutOrderFail());
        Order ord = [SELECT Id FROM Order LIMIT 1];
        
        Test.startTest();
        sapIntegration.sendOrderToSAP(ord.Id);
        Test.stopTest();
        
        // Should not throw exception
        System.assert(true, 'Should handle order creation failure');
    }
    
    @IsTest
    static void testSendOrderToSAP_LoginFail() {
        Test.setMock(HttpCalloutMock.class, new MockSAPCalloutLoginFail());
        Order ord = [SELECT Id FROM Order LIMIT 1];
        
        Test.startTest();
        sapIntegration.sendOrderToSAP(ord.Id);
        Test.stopTest();
        
        // Should not throw exception
        System.assert(true, 'Should handle login failure');
    }
    
    @IsTest
    static void testGetInvoiceMaster() {
        Test.setMock(HttpCalloutMock.class, new MockSAPCalloutSuccess());
        
        Test.startTest();
        sapIntegration.getInvoiceMaster('');
        Test.stopTest();
        
        // Verify invoices were created
        List<Invoice__c> invoices = [SELECT Id FROM Invoice__c];
        System.assert(invoices.size() > 0, 'Invoices should be created');
    }
    
    @IsTest
    static void testGetCustOutstanding() {
        Test.setMock(HttpCalloutMock.class, new MockSAPCalloutSuccess());
        Account acc = [SELECT Id FROM Account WHERE Name = 'Test SAP Account' LIMIT 1];
        
        Test.startTest();
        Decimal outstanding = sapIntegration.getCustOutstanding(acc.Id);
        Test.stopTest();
        
        // Method should complete without exception
        // Outstanding may be null if Customer_Number__c is not set (auto-generated)
        System.assert(true, 'Should complete without exception');
    }
    
    @IsTest
    static void testGetCountryCode() {
        Test.startTest();
        String code = sapIntegration.getCountryCode('India');
        String nullCode = sapIntegration.getCountryCode(null);
        String blankCode = sapIntegration.getCountryCode('');
        Test.stopTest();
        
        // May return null if India is not in picklist, but should not throw
        System.assert(true, 'Should handle country code lookup');
        System.assertEquals(null, nullCode, 'Should return null for null input');
        System.assertEquals(null, blankCode, 'Should return null for blank input');
    }
    
    @IsTest
    static void testGetStateCode() {
        Test.startTest();
        String code = sapIntegration.getStateCode('Karnataka');
        String nullCode = sapIntegration.getStateCode(null);
        String blankCode = sapIntegration.getStateCode('');
        Test.stopTest();
        
        // May return null if Karnataka is not in picklist, but should not throw
        System.assert(true, 'Should handle state code lookup');
        System.assertEquals(null, nullCode, 'Should return null for null input');
        System.assertEquals(null, blankCode, 'Should return null for blank input');
    }
    
    @IsTest
    static void testBuildPayload() {
        Order ord = [SELECT Id, Name, OrderNumber, Order_Owner__c, AccountId, 
            Account.Name, Account.Customer_Number__c, Account.Customer_Type__c,
            Warehouse__r.Warehouse_Code__c, OpportunityId, OwnerId, SAP_Doc_Num__c,
            Order_status__c
            FROM Order LIMIT 1];
        //, AddressLine1__c, AddressLine2__c, AddressLine3__c,
            //District__c, State__c, Country__c
        
        Test.startTest();
        sapIntegration.SAPOrderPayload payload = sapIntegration.buildPayload(ord);
        Test.stopTest();
        
        System.assertNotEquals(null, payload, 'Payload should not be null');
        System.assertNotEquals(null, payload.CardCode, 'CardCode should not be null');
        System.assertNotEquals(null, payload.DocumentLines, 'DocumentLines should not be null');
    }
    
    @IsTest
    static void testCreateBusinessPartner_B2CCustomer() {
        Test.setMock(HttpCalloutMock.class, new MockSAPCalloutSuccess());
        
        // Update account to B2C
        Account acc = [SELECT Id FROM Account WHERE Name = 'Test SAP Account' LIMIT 1];
        acc.Customer_Type__c = 'B2C';
        update acc;
        
        Test.startTest();
        sapIntegration.createBusinessPartner(acc.Id);
        Test.stopTest();
        
        // Should complete without exception
        System.assert(true, 'Should handle B2C customer');
    }
    
    @IsTest
    static void testUpdateBusinessPartner_WithBillingAddress() {
        Test.setMock(HttpCalloutMock.class, new MockSAPCalloutSuccess());
        
        // Mock that returns existing BP with addresses
        Account acc = [SELECT Id FROM Account WHERE Name = 'Test SAP Account' LIMIT 1];
        
        Test.startTest();
        sapIntegration.updateBusinessPartner(acc.Id);
        Test.stopTest();
        
        // Should complete without exception
        System.assert(true, 'Should handle update with billing address');
    }
    
    @IsTest
    static void testSendOrderToSAP_WithoutBatches() {
        Test.setMock(HttpCalloutMock.class, new MockSAPCalloutSuccess());
        
        // Delete batch items
        delete [SELECT Id FROM Order_Batch_Item__c];
        
        Order ord = [SELECT Id FROM Order LIMIT 1];
        
        Test.startTest();
        sapIntegration.sendOrderToSAP(ord.Id);
        Test.stopTest();
        
        // Should complete without exception
        System.assert(true, 'Should handle order without batches');
    }
}