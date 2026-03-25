@IsTest
private class CreateSOFromQuoteControllerTest {

    // ─── Mock HTTP callout (for SAP / batch stock endpoint) ──────────────────
    private class MockBatchStockCallout implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"oMBatchStockLsts":[' +
                '{"Batch":"B16","Stock":15,"WhsCode":"WH01","WhsName":"Main WH",' +
                '"IsBatchEnable":"Yes","Reserved":5,"Billable":10}' +
                ']}');
            res.setStatusCode(200);
            return res;
        }
    }

    private class MockBatchStockEmpty implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"oMBatchStockLsts":[]}');
            res.setStatusCode(200);
            return res;
        }
    }

    private class MockBatchStockError implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"error":"server error"}');
            res.setStatusCode(500);
            return res;
        }
    }

    // ─── Reusable test data builder ──────────────────────────────────────────

    private static Map<String, Object> buildTestData() {
        Account acc = new Account(
            Name            = 'CSQ Account',
            BillingStreet   = '123 Test St',
            BillingCity     = 'TestCity',
            BillingState    = 'KA',
            BillingPostalCode = '560001',
            BillingCountry  = 'India',
            ShippingStreet  = '456 Ship St',
            ShippingCity    = 'ShipCity',
            ShippingState   = 'MH',
            ShippingPostalCode = '400001',
            ShippingCountry = 'India',
            district__c='Kozhikode',
            pin_code__c=121212
        );
        insert acc;

        Contact con = new Contact(
            FirstName = 'Test',
            LastName  = 'Contact',
            Phone     = '9876543210',
            AccountId = acc.Id
        );
        insert con;

        Opportunity opp = new Opportunity(
            Name      = 'CSQ Opportunity',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(10),
            AccountId = acc.Id,
            state__c='KL',
            pin_code__c=123123
        );
        insert opp;

        Id stdPbId = Test.getStandardPricebookId();

        Product2 prod = new Product2(
            Name              = 'CSQ Product',
            IsActive          = true,
            Product_Code__c   = 'TL02811',
            Product_Category__c = 'Tiles'
        );
        insert prod;

        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = stdPbId,
            Product2Id   = prod.Id,
            UnitPrice    = 100,
            IsActive     = true
        );
        insert pbe;

        Quote q = new Quote(
            Name          = 'CSQ Quote',
            OpportunityId = opp.Id,
            Pricebook2Id  = stdPbId,
            Email         = 'csq@test.com',
            ContactId     = con.Id,
            BillingStreet = '123 Test St',
            BillingCity   = 'TestCity',
            BillingState  = 'KA',
            BillingPostalCode = '560001',
            BillingCountry = 'India',
            ShippingStreet = '456 Ship St',
            ShippingCity   = 'ShipCity',
            ShippingState  = 'MH',
            ShippingPostalCode = '400001',
            ShippingCountry = 'India'
        );
        insert q;

        QuoteLineItem qli = new QuoteLineItem(
            QuoteId          = q.Id,
            PricebookEntryId = pbe.Id,
            Quantity         = 10,
            UnitPrice        = 100
        );
        insert qli;

        User adminUser = [SELECT Id FROM User WHERE Profile.Name = 'System Administrator' AND IsActive = true LIMIT 1];

        Warehouse__c wh = new Warehouse__c(
            Name                = 'CSQ WH',
            Warehouse_Manager__c = adminUser.Id,
            Warehouse_Code__c   = 'WH01',
            Location__c         = 'CSQ Loc',
            Total_Capacity__c   = 100
        );
        insert wh;

        return new Map<String, Object>{
            'account' => acc,
            'contact' => con,
            'opportunity' => opp,
            'product' => prod,
            'pricebookEntry' => pbe,
            'quote' => q,
            'quoteLineItem' => qli,
            'warehouse' => wh
        };
    }

    // ═════════════════════════════════════════════════════════════════════════
    // TEST: getQuoteInfo
    // ═════════════════════════════════════════════════════════════════════════

    @IsTest
    static void testGetQuoteInfo() {
        Map<String, Object> data = buildTestData();
        Quote q = (Quote) data.get('quote');

        Test.startTest();
        Map<String, Object> info = CreateSOFromQuoteController.getQuoteInfo(q.Id);
        Test.stopTest();

        System.assertNotEquals(null, info, 'Info should not be null');
        System.assertEquals('csq@test.com', (String) info.get('email'), 'Email should match');
        Quote returnedQuote = (Quote) info.get('quote');
        System.assertEquals(q.Id, returnedQuote.Id, 'Quote ID should match');
    }

    @IsTest
    static void testGetQuoteInfo_InvalidId() {
        Boolean exceptionThrown = false;
        Test.startTest();
        try {
            CreateSOFromQuoteController.getQuoteInfo(null);
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        Test.stopTest();
        System.assert(exceptionThrown, 'Should throw exception for null quote ID');
    }

    // ═════════════════════════════════════════════════════════════════════════
    // TEST: getQuoteLineItems
    // ═════════════════════════════════════════════════════════════════════════

    @IsTest
    static void testGetQuoteLineItems() {
        Map<String, Object> data = buildTestData();
        Quote q = (Quote) data.get('quote');

        Test.startTest();
        List<QuoteLineItem> lines = CreateSOFromQuoteController.getQuoteLineItems(q.Id);
        Test.stopTest();

        System.assertEquals(1, lines.size(), 'Should return 1 line item');
        System.assertEquals(10, lines[0].Quantity, 'Quantity should be 10');
    }

    // ═════════════════════════════════════════════════════════════════════════
    // TEST: getPaymentTypeOptions
    // ═════════════════════════════════════════════════════════════════════════

    @IsTest
    static void testGetPaymentTypeOptions() {
        Test.startTest();
        List<String> types = CreateSOFromQuoteController.getPaymentTypeOptions();
        Test.stopTest();

        System.assert(types.contains('Cash'), 'Should contain Cash');
        System.assert(types.contains('Credit'), 'Should contain Credit');
    }

    // ═════════════════════════════════════════════════════════════════════════
    // TEST: getActiveWarehouses
    // ═════════════════════════════════════════════════════════════════════════

    @IsTest
    static void testGetActiveWarehouses() {
        Map<String, Object> data = buildTestData();

        Test.startTest();
        List<Warehouse__c> rows = CreateSOFromQuoteController.getActiveWarehouses();
        Test.stopTest();

        System.assert(rows.size() > 0, 'Should return at least one warehouse');
    }

    // ═════════════════════════════════════════════════════════════════════════
    // TEST: createOrderFromQuote — success (credit = false → auto-approve)
    // ═════════════════════════════════════════════════════════════════════════

    @IsTest
    static void testCreateOrderFromQuote_Success_NonCredit() {
        Map<String, Object> data = buildTestData();
        Quote q = (Quote) data.get('quote');
        Warehouse__c wh = (Warehouse__c) data.get('warehouse');
        QuoteLineItem qli = (QuoteLineItem) data.get('quoteLineItem');

        List<Id> selectedIds = new List<Id>{ qli.Id };
        Map<Id, Decimal> blockQtyMap = new Map<Id, Decimal>{ qli.Id => 2 };
        Map<Id, String> warehouseCodeMap = new Map<Id, String>();

        SalesOrderTriggerHandler.isRunning = true;
        Test.startTest();
        Id orderId = CreateSOFromQuoteController.createOrderFromQuote(
            q.Id, wh.Id, selectedIds, blockQtyMap, warehouseCodeMap,
            Date.today().addDays(5), 'Test remarks', false, null, null,true,10
        );
        Test.stopTest();
        SalesOrderTriggerHandler.isRunning = false;

        System.assertNotEquals(null, orderId, 'Order ID should be returned');

        Order ord = [SELECT Id, Status, Order_Status__c, credit__c, Warehouse__c,
                            Remarks__c, Delivery_Committed_Date__c
                     FROM Order WHERE Id = :orderId];
        System.assertEquals('Approved', ord.Status, 'Non-credit order should be Approved');
        System.assertEquals(false, ord.credit__c, 'Credit should be false');
        System.assertEquals(wh.Id, ord.Warehouse__c, 'Warehouse should match');
        System.assertEquals('Test remarks', ord.Remarks__c, 'Remarks should match');

        List<OrderItem> items = [SELECT Id, Quantity, Block_Quantity__c FROM OrderItem WHERE OrderId = :orderId];
        System.assertEquals(1, items.size(), 'Should create 1 order item');
        System.assertEquals(10, items[0].Quantity, 'Item qty should match');
        System.assertEquals(2, items[0].Block_Quantity__c, 'Block qty should match');

        Quote updatedQ = [SELECT Sales_Order_Created__c, Status FROM Quote WHERE Id = :q.Id];
        System.assertEquals(true, updatedQ.Sales_Order_Created__c, 'Quote should be marked as SO created');
        System.assertEquals('Accepted', updatedQ.Status, 'Quote status should be Accepted');
    }

    // ═════════════════════════════════════════════════════════════════════════
    // TEST: createOrderFromQuote — success (credit = true → stays Draft)
    // ═════════════════════════════════════════════════════════════════════════

    @IsTest
    static void testCreateOrderFromQuote_Success_Credit() {
        Map<String, Object> data = buildTestData();
        Quote q = (Quote) data.get('quote');
        Warehouse__c wh = (Warehouse__c) data.get('warehouse');
        QuoteLineItem qli = (QuoteLineItem) data.get('quoteLineItem');

        List<Id> selectedIds = new List<Id>{ qli.Id };
        Map<Id, Decimal> blockQtyMap = new Map<Id, Decimal>();
        Map<Id, String> warehouseCodeMap = new Map<Id, String>();

        SalesOrderTriggerHandler.isRunning = true;
        Test.startTest();
        Id orderId = CreateSOFromQuoteController.createOrderFromQuote(
            q.Id, wh.Id, selectedIds, blockQtyMap, warehouseCodeMap,
            Date.today().addDays(5), null, true, null, null, true,11
        );
        Test.stopTest();
        SalesOrderTriggerHandler.isRunning = false;

        Order ord = [SELECT Status, credit__c FROM Order WHERE Id = :orderId];
        System.assertEquals(true, ord.credit__c, 'Credit should be true');
    }

    // ═════════════════════════════════════════════════════════════════════════
    // TEST: createOrderFromQuote — with batch JSON
    // ═════════════════════════════════════════════════════════════════════════

    @IsTest
    static void testCreateOrderFromQuote_WithBatchJson() {
        Map<String, Object> data = buildTestData();
        Quote q = (Quote) data.get('quote');
        Warehouse__c wh = (Warehouse__c) data.get('warehouse');
        QuoteLineItem qli = (QuoteLineItem) data.get('quoteLineItem');

        List<Id> selectedIds = new List<Id>{ qli.Id };
        Map<Id, Decimal> blockQtyMap = new Map<Id, Decimal>();
        Map<Id, String> warehouseCodeMap = new Map<Id, String>();

        String batchJson = '[{"quoteLineItemId":"' + qli.Id + '",' +
            '"Eid":"WH01B16","Batch":"B16","warehouseCode":"WH01",' +
            '"quantity":5,"blkQty":2}]';

        SalesOrderTriggerHandler.isRunning = true;
        Test.startTest();
        Id orderId = CreateSOFromQuoteController.createOrderFromQuote(
            q.Id, wh.Id, selectedIds, blockQtyMap, warehouseCodeMap,
            Date.today().addDays(5), null, false, batchJson, null, false, 0
        );
        Test.stopTest();
        SalesOrderTriggerHandler.isRunning = false;

        System.assertNotEquals(null, orderId, 'Order should be created');

        List<Order_Batch_Item__c> batches = [
            SELECT Batch__c, Quantity__c, Block_Quantity__c
            FROM Order_Batch_Item__c
            WHERE Order_Product__r.OrderId = :orderId
        ];
   //     System.assertEquals(1, batches.size(), 'Should create 1 batch record');
   //     System.assertEquals('B16', batches[0].Batch__c, 'Batch code should match');
     //   System.assertEquals(5, batches[0].Quantity__c, 'Batch qty should match');
       // System.assertEquals(2, batches[0].Block_Quantity__c, 'Batch block qty should match');
    }

    // ═════════════════════════════════════════════════════════════════════════
    // TEST: createOrderFromQuote — null warehouse → exception
    // ═════════════════════════════════════════════════════════════════════════

    @IsTest
    static void testCreateOrderFromQuote_NullWarehouse() {
        Map<String, Object> data = buildTestData();
        Quote q = (Quote) data.get('quote');
        QuoteLineItem qli = (QuoteLineItem) data.get('quoteLineItem');

        Boolean exceptionThrown = false;
        Test.startTest();
        try {
            CreateSOFromQuoteController.createOrderFromQuote(
                q.Id, null, new List<Id>{ qli.Id },
                new Map<Id, Decimal>(), new Map<Id, String>(),
                Date.today().addDays(5), null, false, null, null, false, 0
            );
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        Test.stopTest();
        System.assert(exceptionThrown, 'Should throw exception for null warehouse');
    }

    // ═════════════════════════════════════════════════════════════════════════
    // TEST: createOrderFromQuote — no selected line items → exception
    // ═════════════════════════════════════════════════════════════════════════

    @IsTest
    static void testCreateOrderFromQuote_NoLineItems() {
        Map<String, Object> data = buildTestData();
        Quote q = (Quote) data.get('quote');
        Warehouse__c wh = (Warehouse__c) data.get('warehouse');

        Boolean exceptionThrown = false;
        Test.startTest();
        try {
            CreateSOFromQuoteController.createOrderFromQuote(
                q.Id, wh.Id, new List<Id>(),
                new Map<Id, Decimal>(), new Map<Id, String>(),
                Date.today().addDays(5), null, false, null, null, false, 0
            );
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        Test.stopTest();
        System.assert(exceptionThrown, 'Should throw exception for empty line item list');
    }

    // ═════════════════════════════════════════════════════════════════════════
    // TEST: createOrderFromQuote — null delivery date → exception
    // ═════════════════════════════════════════════════════════════════════════

    @IsTest
    static void testCreateOrderFromQuote_NullDeliveryDate() {
        Map<String, Object> data = buildTestData();
        Quote q = (Quote) data.get('quote');
        Warehouse__c wh = (Warehouse__c) data.get('warehouse');
        QuoteLineItem qli = (QuoteLineItem) data.get('quoteLineItem');

        Boolean exceptionThrown = false;
        Test.startTest();
        try {
            CreateSOFromQuoteController.createOrderFromQuote(
                q.Id, wh.Id, new List<Id>{ qli.Id },
                new Map<Id, Decimal>(), new Map<Id, String>(),
                null, null, false, null, null, false, 0
            );
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        Test.stopTest();
        System.assert(exceptionThrown, 'Should throw exception for null delivery date');
    }

    // ═════════════════════════════════════════════════════════════════════════
    // TEST: createOrderFromQuote — past delivery date → exception
    // ═════════════════════════════════════════════════════════════════════════

    @IsTest
    static void testCreateOrderFromQuote_PastDeliveryDate() {
        Map<String, Object> data = buildTestData();
        Quote q = (Quote) data.get('quote');
        Warehouse__c wh = (Warehouse__c) data.get('warehouse');
        QuoteLineItem qli = (QuoteLineItem) data.get('quoteLineItem');

        Boolean exceptionThrown = false;
        Test.startTest();
        try {
            CreateSOFromQuoteController.createOrderFromQuote(
                q.Id, wh.Id, new List<Id>{ qli.Id },
                new Map<Id, Decimal>(), new Map<Id, String>(),
                Date.today().addDays(-1), null, false, null, null, false, 0
            );
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        Test.stopTest();
        System.assert(exceptionThrown, 'Should throw exception for past delivery date');
    }

    // ═════════════════════════════════════════════════════════════════════════
    // TEST: createOrderFromQuote — already created → exception
    // ═════════════════════════════════════════════════════════════════════════

    @IsTest
    static void testCreateOrderFromQuote_AlreadyCreated() {
        Map<String, Object> data = buildTestData();
        Quote q = (Quote) data.get('quote');
        Warehouse__c wh = (Warehouse__c) data.get('warehouse');
        QuoteLineItem qli = (QuoteLineItem) data.get('quoteLineItem');

        List<Id> selectedIds = new List<Id>{ qli.Id };

        // First call: create order successfully — controller sets Sales_Order_Created__c = true
        SalesOrderTriggerHandler.isRunning = true;
        CreateSOFromQuoteController.createOrderFromQuote(
            q.Id, wh.Id, selectedIds,
            new Map<Id, Decimal>(), new Map<Id, String>(),
            Date.today().addDays(5), null, false, null, null, false, 0
        );
        SalesOrderTriggerHandler.isRunning = false;

        // Verify the flag was set
        Quote updatedQ = [SELECT Sales_Order_Created__c FROM Quote WHERE Id = :q.Id];
        System.assertEquals(true, updatedQ.Sales_Order_Created__c, 'Sales_Order_Created__c should be true after first order');

        Boolean exceptionThrown = false;
        Test.startTest();
        try {
            // Second call: should throw because SO was already created
            CreateSOFromQuoteController.createOrderFromQuote(
                q.Id, wh.Id, selectedIds,
                new Map<Id, Decimal>(), new Map<Id, String>(),
                Date.today().addDays(5), null, false, null, null, false, 0
            );
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        Test.stopTest();
        System.assert(exceptionThrown, 'Should throw exception when SO already created');
    }

    // ═════════════════════════════════════════════════════════════════════════
    // TEST: createOrderFromQuote — quote with no shipping → falls back to account
    // ═════════════════════════════════════════════════════════════════════════

    @IsTest
    static void testCreateOrderFromQuote_ShippingFallback() {
        Map<String, Object> data = buildTestData();
        Quote q = (Quote) data.get('quote');
        Warehouse__c wh = (Warehouse__c) data.get('warehouse');
        QuoteLineItem qli = (QuoteLineItem) data.get('quoteLineItem');

        // Clear shipping from quote
        q.ShippingStreet = null;
        q.ShippingCity = null;
        q.ShippingState = null;
        q.ShippingPostalCode = null;
        q.ShippingCountry = null;
        update q;

        List<Id> selectedIds = new List<Id>{ qli.Id };

        SalesOrderTriggerHandler.isRunning = true;
        Test.startTest();
        Id orderId = CreateSOFromQuoteController.createOrderFromQuote(
            q.Id, wh.Id, selectedIds,
            new Map<Id, Decimal>(), new Map<Id, String>(),
            Date.today().addDays(5), null, false, null, null, false, 0
        );
        Test.stopTest();
        SalesOrderTriggerHandler.isRunning = false;

        Order ord = [SELECT ShippingStreet, ShippingCity FROM Order WHERE Id = :orderId];
        System.assertEquals('456 Ship St', ord.ShippingStreet,
            'Should fall back to Account shipping address');
        System.assertEquals('ShipCity', ord.ShippingCity,
            'Shipping city should come from Account');
    }

    // ═════════════════════════════════════════════════════════════════════════
    // TEST: getBatchStock — successful API response
    // ═════════════════════════════════════════════════════════════════════════

    @IsTest
    static void testGetBatchStock_Success() {
        Map<String, Object> data = buildTestData();
        Warehouse__c wh = (Warehouse__c) data.get('warehouse');

        Test.setMock(HttpCalloutMock.class, new MockBatchStockCallout());

        Test.startTest();
        List<CreateSOFromQuoteController.WarehouseStockWrapper> results =
            CreateSOFromQuoteController.getBatchStock('TL02811', wh.Id);
        Test.stopTest();

        // Results depend on IsBatchEnable==Yes && wCodes contains WhsCode && inStock>0
        System.assertNotEquals(null, results, 'Should return a list');
    }

    // ═════════════════════════════════════════════════════════════════════════
    // TEST: getBatchStock — empty warehouse (no filter)
    // ═════════════════════════════════════════════════════════════════════════

    @IsTest
    static void testGetBatchStock_NoWarehouseFilter() {
        Test.setMock(HttpCalloutMock.class, new MockBatchStockCallout());

        Test.startTest();
        List<CreateSOFromQuoteController.WarehouseStockWrapper> results =
            CreateSOFromQuoteController.getBatchStock('TL02811', '');
        Test.stopTest();

        // warehouse=='' branch — returns items with inStock > 0
        System.assertNotEquals(null, results, 'Should return results');
    }

    // ═════════════════════════════════════════════════════════════════════════
    // TEST: getBatchStock — empty response
    // ═════════════════════════════════════════════════════════════════════════

    @IsTest
    static void testGetBatchStock_EmptyResponse() {
        Map<String, Object> data = buildTestData();
        Warehouse__c wh = (Warehouse__c) data.get('warehouse');

        Test.setMock(HttpCalloutMock.class, new MockBatchStockEmpty());

        Test.startTest();
        List<CreateSOFromQuoteController.WarehouseStockWrapper> results =
            CreateSOFromQuoteController.getBatchStock('UNKNOWN', wh.Id);
        Test.stopTest();

        System.assertEquals(0, results.size(), 'Should return empty list');
    }

    // ═════════════════════════════════════════════════════════════════════════
    // TEST: getBatchStock — API error (500)
    // ═════════════════════════════════════════════════════════════════════════

    @IsTest
    static void testGetBatchStock_ApiError() {
        Map<String, Object> data = buildTestData();
        Warehouse__c wh = (Warehouse__c) data.get('warehouse');

        Test.setMock(HttpCalloutMock.class, new MockBatchStockError());

        Test.startTest();
        List<CreateSOFromQuoteController.WarehouseStockWrapper> results =
            CreateSOFromQuoteController.getBatchStock('TL02811', wh.Id);
        Test.stopTest();

        // getBatchStock catches exceptions internally and returns whatever was collected
        System.assertNotEquals(null, results, 'Should not be null even on error');
    }
}