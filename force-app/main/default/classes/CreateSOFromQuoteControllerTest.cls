@IsTest
private class CreateSOFromQuoteControllerTest {

    /* =========================================================
       HTTP MOCK FOR getBatchStock
    ========================================================= */
    class BatchStockMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            res.setBody(
                '{"oMBatchStockLsts":[' +
                '{"Batch":"B1","Stock":10,"WhsCode":"WH1","WhsName":"Main WH","IsBatchEnable":"Yes","Reserved":"0","Billable":"10"}]}'
            );
            return res;
        }
    }

    /* =========================================================
       TEST DATA FACTORY
    ========================================================= */
    private static Map<String, Id> createTestData() {

        // ---------------- Account ----------------
        Account acc = new Account(Name='Test Account');
        insert acc;

        // ---------------- Contact ----------------
        Contact con = new Contact(
            FirstName='Test',
            LastName='Contact',
            AccountId=acc.Id,
            Phone='9999999999'
        );
        insert con;

        // ---------------- Standard Pricebook ----------------
        Id standardPBId = Test.getStandardPricebookId();

        // ---------------- Product ----------------
        Product2 prod = new Product2(
            Name='Test Product',
            IsActive=true,
            Product_Category__c='Cement'
        );
        insert prod;

        // Standard price entry (MANDATORY)
        PricebookEntry stdPBE = new PricebookEntry(
            Pricebook2Id=standardPBId,
            Product2Id=prod.Id,
            UnitPrice=100,
            IsActive=true
        );
        insert stdPBE;

        // ---------------- Custom Pricebook ----------------
        Pricebook2 customPB = new Pricebook2(
            Name='Custom PB',
            IsActive=true
        );
        insert customPB;

        PricebookEntry customPBE = new PricebookEntry(
            Pricebook2Id=customPB.Id,
            Product2Id=prod.Id,
            UnitPrice=100,
            IsActive=true
        );
        insert customPBE;

        // ---------------- Opportunity ----------------
        Opportunity opp = new Opportunity(
            Name='Test Opportunity',
            StageName='Prospecting',
            CloseDate=Date.today().addDays(5),
            AccountId=acc.Id,
            Pricebook2Id=customPB.Id
        );
        insert opp;

        // ---------------- Quote ----------------
        Quote q = new Quote(
            Name='Test Quote',
            OpportunityId=opp.Id,
            Pricebook2Id=customPB.Id,
            Status='Draft'
        );
        insert q;

        // ---------------- Quote Line Item ----------------
        QuoteLineItem qli = new QuoteLineItem(
            QuoteId=q.Id,
            PricebookEntryId=customPBE.Id,
            Quantity=5,
            UnitPrice=100
        );
        insert qli;

        // ---------------- Warehouse ----------------
        String validType;
        Schema.DescribeFieldResult fieldResult =
            Warehouse__c.Type__c.getDescribe();
        List<Schema.PicklistEntry> pickVals =
            fieldResult.getPicklistValues();

        if (!pickVals.isEmpty()) {
            validType = pickVals[0].getValue();
        }

        Warehouse__c wh = new Warehouse__c(
            Name='Main WH',
            Warehouse_Code__c='WH1',
            Location__c='LOC1',
            Type__c=validType
        );
        insert wh;

        return new Map<String, Id>{
            'QuoteId' => q.Id,
            'QLIId' => qli.Id,
            'WarehouseId' => wh.Id
        };
    }

    /* =========================================================
       TEST: getQuoteInfo
    ========================================================= */
    @IsTest
    static void testGetQuoteInfo() {
        Map<String, Id> data = createTestData();

        Test.startTest();
        Map<String, Object> result =
            CreateSOFromQuoteController.getQuoteInfo(data.get('QuoteId'));
        Test.stopTest();

        System.assertNotEquals(null, result);
    }

    /* =========================================================
       TEST: getQuoteLineItems
    ========================================================= */
    @IsTest
    static void testGetQuoteLineItems() {
        Map<String, Id> data = createTestData();

        Test.startTest();
        List<QuoteLineItem> items =
            CreateSOFromQuoteController.getQuoteLineItems(data.get('QuoteId'));
        Test.stopTest();

        System.assertEquals(1, items.size());
    }

    /* =========================================================
       TEST: createOrderFromQuote SUCCESS
    ========================================================= */
    @IsTest
    static void testCreateOrderSuccess() {

        Map<String, Id> data = createTestData();

        List<Id> selectedIds = new List<Id>{ data.get('QLIId') };

        Map<Id, Decimal> blockQtyMap = new Map<Id, Decimal>{
            data.get('QLIId') => 2
        };

        Map<Id, String> warehouseCodeMap = new Map<Id, String>{
            data.get('QLIId') => 'WH1'
        };

        CreateSOFromQuoteController.WarehouseStockWrapper wrap =
            new CreateSOFromQuoteController.WarehouseStockWrapper();
        wrap.quoteLineItemId = data.get('QLIId');
        wrap.quantity = 2;
        wrap.Batch = 'B1';
        wrap.warehouseCode = 'WH1';
        wrap.Eid = 'E1';
        wrap.blkQty = 1;

        String batchJson = JSON.serialize(
            new List<CreateSOFromQuoteController.WarehouseStockWrapper>{ wrap }
        );

        Test.startTest();

        Id orderId =
            CreateSOFromQuoteController.createOrderFromQuote(
                data.get('QuoteId'),
                data.get('WarehouseId'),
                selectedIds,
                blockQtyMap,
                warehouseCodeMap,
                Date.today().addDays(2),
                'Test Remarks',
                false,
                batchJson
            );

        Test.stopTest();

        Order ord = [SELECT Status FROM Order WHERE Id = :orderId];
        System.assertEquals('Approved', ord.Status);
    }

    /* =========================================================
       TEST: Validation (No Warehouse)
    ========================================================= */
    @IsTest
    static void testValidationNoWarehouse() {

        Map<String, Id> data = createTestData();

        try {
            CreateSOFromQuoteController.createOrderFromQuote(
                data.get('QuoteId'),
                null,
                new List<Id>{ data.get('QLIId') },
                null,
                null,
                Date.today().addDays(1),
                '',
                true,
                null
            );
            System.assert(false);
        } catch (Exception e) {
            System.assert(true);
        }
    }

    /* =========================================================
       TEST: getPaymentTypeOptions
    ========================================================= */
    @IsTest
    static void testGetPaymentOptions() {
        List<String> types =
            CreateSOFromQuoteController.getPaymentTypeOptions();
        System.assertEquals(2, types.size());
    }

    /* =========================================================
       TEST: getActiveWarehouses
    ========================================================= */
    @IsTest
    static void testGetActiveWarehouses() {
        createTestData();
        List<Warehouse__c> whs =
            CreateSOFromQuoteController.getActiveWarehouses();
        System.assert(whs.size() > 0);
    }

    /* =========================================================
       TEST: getBatchStock (Callout)
    ========================================================= */
    @IsTest
    static void testGetBatchStock() {

        Map<String, Id> data = createTestData();

        Test.setMock(HttpCalloutMock.class, new BatchStockMock());

        Test.startTest();
        List<CreateSOFromQuoteController.WarehouseStockWrapper> result =
            CreateSOFromQuoteController.getBatchStock('TL02811', data.get('WarehouseId'));
        Test.stopTest();

        System.assert(result.size() > 0);
    }
}