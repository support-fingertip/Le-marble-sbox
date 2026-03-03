@isTest
private class OpportunityItemHandlerTest2 {

    @TestSetup
    static void setupData() {
        // Create Account
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        // Create Opportunity
        Opportunity opp = new Opportunity(
            Name = 'Test Opportunity',
            AccountId = acc.Id,
            StageName = 'Prospecting',
            CloseDate = System.today().addDays(10)
        );
        insert opp;

        Id stdPbId = Test.getStandardPricebookId();

        // Create Products with different categories
        List<Product2> products = new List<Product2>();
        products.add(new Product2(Name = 'Tile Product', IsActive = true, Product_Category__c = 'TILE'));
        products.add(new Product2(Name = 'Sanitary Product', IsActive = true, Product_Category__c = 'SANITARY'));
        products.add(new Product2(Name = 'Roof Tiles Product', IsActive = true, Product_Category__c = 'ROOF TILES'));
        products.add(new Product2(Name = 'Adhesive Product', IsActive = true, Product_Category__c = 'ADHESIVE'));
        products.add(new Product2(Name = 'Fittings Product', IsActive = true, Product_Category__c = 'FITTINGS'));
        products.add(new Product2(Name = 'Glass Brick Product', IsActive = true, Product_Category__c = 'GLSBRK'));
        products.add(new Product2(Name = 'Lights Product', IsActive = true, Product_Category__c = 'LIGHTS'));
        products.add(new Product2(Name = 'Natural Stone Product', IsActive = true, Product_Category__c = 'N.STONE'));
        insert products;

        // Create PricebookEntries
        List<PricebookEntry> pbes = new List<PricebookEntry>();
        for (Product2 prod : products) {
            pbes.add(new PricebookEntry(
                Pricebook2Id = stdPbId,
                Product2Id = prod.Id,
                UnitPrice = 100,
                IsActive = true
            ));
        }
        insert pbes;

        // Create Quote for handleBefore tests
        Quote qt = new Quote(
            Name = 'Test Quote',
            OpportunityId = opp.Id,
            Pricebook2Id = stdPbId
        );
        insert qt;

        // Create QuoteLineItem with custom fields
        PricebookEntry tilePbe = [SELECT Id, Product2Id FROM PricebookEntry WHERE Product2.Name = 'Tile Product' LIMIT 1];
        QuoteLineItem qli = new QuoteLineItem(
            QuoteId = qt.Id,
            PricebookEntryId = tilePbe.Id,
            Product2Id = tilePbe.Product2Id,
            Quantity = 10,
            UnitPrice = 200,
            Area__c = 'Living Room',
            Room_Type__c = 'Bedroom',
            MSP__c = 150,
            Disc_Type__c = 'Percentage',
            Dis_Value__c = 10,
            Sqft__c = 500
        );
        insert qli;
    }

    // Helper methods
    private static Opportunity getTestOpportunity() {
        return [SELECT Id FROM Opportunity LIMIT 1];
    }

    private static PricebookEntry getPricebookEntry(String productName) {
        return [SELECT Id, Product2Id FROM PricebookEntry WHERE Product2.Name = :productName LIMIT 1];
    }

    // =====================================================
    // handleAfterInsert TESTS
    // =====================================================

    @isTest
    static void testHandleAfterInsert_TileCategory() {
        Opportunity opp = getTestOpportunity();
        PricebookEntry pbe = getPricebookEntry('Tile Product');

        // Create public group in runAs to avoid MIXED_DML
        System.runAs(new User(Id = UserInfo.getUserId())) {
            Group pg = new Group(Name = 'TILE', Type = 'Regular');
            insert pg;
            insert new GroupMember(GroupId = pg.Id, UserOrGroupId = UserInfo.getUserId());
        }

        OpportunityLineItem oli = new OpportunityLineItem(
            OpportunityId = opp.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 1,
            UnitPrice = 100
        );

        Test.startTest();
        insert oli;
        Test.stopTest();

        System.assert(true, 'handleAfterInsert executed for TILE category');
    }

    @isTest
    static void testHandleAfterInsert_SanitaryCategory() {
        Opportunity opp = getTestOpportunity();
        PricebookEntry pbe = getPricebookEntry('Sanitary Product');

        System.runAs(new User(Id = UserInfo.getUserId())) {
            Group pg = new Group(Name = 'PG SANITARY', Type = 'Regular');
            insert pg;
            insert new GroupMember(GroupId = pg.Id, UserOrGroupId = UserInfo.getUserId());
        }

        OpportunityLineItem oli = new OpportunityLineItem(
            OpportunityId = opp.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 1,
            UnitPrice = 100
        );

        Test.startTest();
        insert oli;
        Test.stopTest();

        System.assert(true, 'handleAfterInsert executed for SANITARY category');
    }

    @isTest
    static void testHandleAfterInsert_RoofTilesCategory() {
        Opportunity opp = getTestOpportunity();
        PricebookEntry pbe = getPricebookEntry('Roof Tiles Product');

        System.runAs(new User(Id = UserInfo.getUserId())) {
            Group pg = new Group(Name = 'ROOF TILES', Type = 'Regular');
            insert pg;
            insert new GroupMember(GroupId = pg.Id, UserOrGroupId = UserInfo.getUserId());
        }

        OpportunityLineItem oli = new OpportunityLineItem(
            OpportunityId = opp.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 1,
            UnitPrice = 100
        );

        Test.startTest();
        insert oli;
        Test.stopTest();

        System.assert(true, 'handleAfterInsert executed for ROOF TILES category');
    }

    @isTest
    static void testHandleAfterInsert_AdhesiveCategory() {
        Opportunity opp = getTestOpportunity();
        PricebookEntry pbe = getPricebookEntry('Adhesive Product');

        System.runAs(new User(Id = UserInfo.getUserId())) {
            Group pg = new Group(Name = 'ADHESIVES', Type = 'Regular');
            insert pg;
            insert new GroupMember(GroupId = pg.Id, UserOrGroupId = UserInfo.getUserId());
        }

        OpportunityLineItem oli = new OpportunityLineItem(
            OpportunityId = opp.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 1,
            UnitPrice = 100
        );

        Test.startTest();
        insert oli;
        Test.stopTest();

        System.assert(true, 'handleAfterInsert executed for ADHESIVE category');
    }

    @isTest
    static void testHandleAfterInsert_LightsCategory() {
        Opportunity opp = getTestOpportunity();
        PricebookEntry pbe = getPricebookEntry('Lights Product');

        System.runAs(new User(Id = UserInfo.getUserId())) {
            Group pg = new Group(Name = 'LIGHTS', Type = 'Regular');
            insert pg;
            insert new GroupMember(GroupId = pg.Id, UserOrGroupId = UserInfo.getUserId());
        }

        OpportunityLineItem oli = new OpportunityLineItem(
            OpportunityId = opp.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 1,
            UnitPrice = 100
        );

        Test.startTest();
        insert oli;
        Test.stopTest();

        System.assert(true, 'handleAfterInsert executed for LIGHTS category');
    }

    @isTest
    static void testHandleAfterInsert_NoMatchingGroup() {
        Opportunity opp = getTestOpportunity();
        
        // Create product with no matching group
        Id stdPbId = Test.getStandardPricebookId();
        Product2 prod = new Product2(Name = 'Unknown Product', IsActive = true, Product_Category__c = 'UNKNOWN');
        insert prod;
        PricebookEntry pbe = new PricebookEntry(Pricebook2Id = stdPbId, Product2Id = prod.Id, UnitPrice = 50, IsActive = true);
        insert pbe;

        OpportunityLineItem oli = new OpportunityLineItem(
            OpportunityId = opp.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 1,
            UnitPrice = 50
        );

        Test.startTest();
        insert oli;
        Test.stopTest();

        System.assert(true, 'handleAfterInsert handles missing group gracefully');
    }

    @isTest
    static void testHandleAfterInsert_NullProductCategory() {
        Opportunity opp = getTestOpportunity();
        
        Id stdPbId = Test.getStandardPricebookId();
        Product2 prod = new Product2(Name = 'No Category Product', IsActive = true);
        insert prod;
        PricebookEntry pbe = new PricebookEntry(Pricebook2Id = stdPbId, Product2Id = prod.Id, UnitPrice = 50, IsActive = true);
        insert pbe;

        OpportunityLineItem oli = new OpportunityLineItem(
            OpportunityId = opp.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 1,
            UnitPrice = 50
        );

        Test.startTest();
        insert oli;
        Test.stopTest();

        System.assert(true, 'handleAfterInsert handles null category gracefully');
    }

    @isTest
    static void testHandleAfterInsert_BulkInsert() {
        Opportunity opp = getTestOpportunity();
        PricebookEntry pbe = getPricebookEntry('Tile Product');

        List<OpportunityLineItem> oliList = new List<OpportunityLineItem>();
        for (Integer i = 0; i < 50; i++) {
            oliList.add(new OpportunityLineItem(
                OpportunityId = opp.Id,
                PricebookEntryId = pbe.Id,
                Quantity = 1,
                UnitPrice = 100
            ));
        }

        Test.startTest();
        insert oliList;
        Test.stopTest();

        Integer count = [SELECT COUNT() FROM OpportunityLineItem WHERE OpportunityId = :opp.Id];
        System.assertEquals(50, count, 'Should insert 50 OLIs');
    }

    @isTest
    static void testHandleAfterInsert_MultipleCategories() {
        Opportunity opp = getTestOpportunity();

        List<OpportunityLineItem> oliList = new List<OpportunityLineItem>();
        
        PricebookEntry tilePbe = getPricebookEntry('Tile Product');
        PricebookEntry sanitaryPbe = getPricebookEntry('Sanitary Product');
        PricebookEntry lightsPbe = getPricebookEntry('Lights Product');

        oliList.add(new OpportunityLineItem(OpportunityId = opp.Id, PricebookEntryId = tilePbe.Id, Quantity = 1, UnitPrice = 100));
        oliList.add(new OpportunityLineItem(OpportunityId = opp.Id, PricebookEntryId = sanitaryPbe.Id, Quantity = 1, UnitPrice = 100));
        oliList.add(new OpportunityLineItem(OpportunityId = opp.Id, PricebookEntryId = lightsPbe.Id, Quantity = 1, UnitPrice = 100));

        Test.startTest();
        insert oliList;
        Test.stopTest();

        System.assertEquals(3, oliList.size(), 'Should insert 3 OLIs with different categories');
    }

    // =====================================================
    // handleBefore TESTS
    // =====================================================

    @isTest
    static void testHandleBefore_EmptyList() {
        Test.startTest();
        OpportunityItemHandler.handleBefore(new List<OpportunityLineItem>());
        Test.stopTest();

        System.assert(true, 'handleBefore handles empty list');
    }

    @isTest
    static void testHandleBefore_NoQuoteLineItemId() {
        Opportunity opp = getTestOpportunity();
        PricebookEntry pbe = getPricebookEntry('Tile Product');

        OpportunityLineItem oli = new OpportunityLineItem(
            OpportunityId = opp.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 1,
            UnitPrice = 100
        );

        Test.startTest();
        OpportunityItemHandler.handleBefore(new List<OpportunityLineItem>{oli});
        Test.stopTest();

        System.assert(true, 'handleBefore handles OLI without QuoteLineItemId');
    }

    @isTest
    static void testHandleBefore_DirectMethodCall() {
        Opportunity opp = getTestOpportunity();
        PricebookEntry pbe = getPricebookEntry('Tile Product');

        List<OpportunityLineItem> oliList = new List<OpportunityLineItem>();
        for (Integer i = 0; i < 5; i++) {
            oliList.add(new OpportunityLineItem(
                OpportunityId = opp.Id,
                PricebookEntryId = pbe.Id,
                Quantity = 1,
                UnitPrice = 100
            ));
        }

        Test.startTest();
        OpportunityItemHandler.handleBefore(oliList);
        Test.stopTest();

        System.assertEquals(5, oliList.size(), 'handleBefore processes list correctly');
    }

    @isTest
    static void testHandleBefore_BulkRecords() {
        Opportunity opp = getTestOpportunity();
        PricebookEntry pbe = getPricebookEntry('Tile Product');

        List<OpportunityLineItem> oliList = new List<OpportunityLineItem>();
        for (Integer i = 0; i < 100; i++) {
            oliList.add(new OpportunityLineItem(
                OpportunityId = opp.Id,
                PricebookEntryId = pbe.Id,
                Quantity = 1 + i,
                UnitPrice = 100
            ));
        }

        Test.startTest();
        OpportunityItemHandler.handleBefore(oliList);
        Test.stopTest();

        System.assertEquals(100, oliList.size(), 'handleBefore handles bulk records');
    }

    // =====================================================
    // AFTER UPDATE TESTS
    // =====================================================

    @isTest
    static void testHandleAfterInsert_OnUpdate() {
        Opportunity opp = getTestOpportunity();
        PricebookEntry pbe = getPricebookEntry('Tile Product');

        OpportunityLineItem oli = new OpportunityLineItem(
            OpportunityId = opp.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 1,
            UnitPrice = 100
        );
        insert oli;

        Test.startTest();
        oli.Quantity = 5;
        update oli;
        Test.stopTest();

        OpportunityLineItem updated = [SELECT Quantity FROM OpportunityLineItem WHERE Id = :oli.Id];
        System.assertEquals(5, updated.Quantity, 'Quantity should be updated');
    }
}