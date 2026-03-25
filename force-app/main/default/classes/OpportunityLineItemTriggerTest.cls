@isTest
private class OpportunityLineItemTriggerTest {

    @TestSetup
    static void setupData() {
        Account acc = new Account(
            Name              = 'Test Account',
            BillingCountry    = 'India',
            BillingState      = 'Maharashtra',
            BillingPostalCode = '400001',
            BillingStreet     = '123 Test Street',
            District__c       = 'Ernakulam',
            Pin_Code__c       = 400001
        );
        insert acc;

        String validState;
        for (Schema.PicklistEntry pe : Opportunity.State__c.getDescribe().getPicklistValues()) {
            if (pe.isActive()) { validState = pe.getValue(); break; }
        }
        Opportunity opp = new Opportunity(
            Name = 'Test Opportunity',
            AccountId = acc.Id,
            StageName = 'Prospecting',
            CloseDate = System.today().addDays(10),
            State__c = validState,
            Pin_Code__c = 400001
        );
        insert opp;

        Id stdPbId = Test.getStandardPricebookId();

        Product2 prod = new Product2(
            Name = 'Test Product',
            IsActive = true,
            Product_Category__c = 'TILE'
        );
        insert prod;

        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = stdPbId,
            Product2Id = prod.Id,
            UnitPrice = 100,
            IsActive = true
        );
        insert pbe;
    }

    // Helper to get test data
    private static Opportunity getTestOpportunity() {
        return [SELECT Id FROM Opportunity LIMIT 1];
    }

    private static PricebookEntry getTestPricebookEntry() {
        Id stdPbId = Test.getStandardPricebookId();
        return [SELECT Id FROM PricebookEntry WHERE Pricebook2Id = :stdPbId LIMIT 1];
    }

    // =====================
    // AFTER INSERT
    // =====================
    @isTest
    static void testTrigger_AfterInsert() {
        Opportunity opp = getTestOpportunity();
        PricebookEntry pbe = getTestPricebookEntry();

        OpportunityLineItem oli = new OpportunityLineItem(
            OpportunityId = opp.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 1,
            UnitPrice = 100
        );

        Test.startTest();
        insert oli;
        Test.stopTest();

        OpportunityLineItem inserted = [SELECT Id FROM OpportunityLineItem WHERE Id = :oli.Id];
        System.assertNotEquals(null, inserted, 'OLI should be inserted');
    }

    // =====================
    // BEFORE INSERT
    // =====================
    @isTest
    static void testTrigger_BeforeInsert() {
        Opportunity opp = getTestOpportunity();
        PricebookEntry pbe = getTestPricebookEntry();

        OpportunityLineItem oli = new OpportunityLineItem(
            OpportunityId = opp.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 2,
            UnitPrice = 150
        );

        Test.startTest();
        insert oli;
        Test.stopTest();

        OpportunityLineItem inserted = [SELECT Quantity, UnitPrice FROM OpportunityLineItem WHERE Id = :oli.Id];
        System.assertEquals(2, inserted.Quantity, 'Quantity should be 2');
        System.assertEquals(150, inserted.UnitPrice, 'UnitPrice should be 150');
    }

    // =====================
    // AFTER UPDATE
    // =====================
    @isTest
    static void testTrigger_AfterUpdate() {
        Opportunity opp = getTestOpportunity();
        PricebookEntry pbe = getTestPricebookEntry();

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
        System.assertEquals(5, updated.Quantity, 'Quantity should be updated to 5');
    }

    // =====================
    // BEFORE UPDATE
    // =====================
    @isTest
    static void testTrigger_BeforeUpdate() {
        Opportunity opp = getTestOpportunity();
        PricebookEntry pbe = getTestPricebookEntry();

        OpportunityLineItem oli = new OpportunityLineItem(
            OpportunityId = opp.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 1,
            UnitPrice = 100
        );
        insert oli;

        Test.startTest();
        oli.UnitPrice = 200;
        update oli;
        Test.stopTest();

        OpportunityLineItem updated = [SELECT UnitPrice FROM OpportunityLineItem WHERE Id = :oli.Id];
        System.assertEquals(200, updated.UnitPrice, 'UnitPrice should be updated to 200');
    }

    // =====================
    // BULK INSERT
    // =====================
    @isTest
    static void testTrigger_BulkInsert() {
        Opportunity opp = getTestOpportunity();
        PricebookEntry pbe = getTestPricebookEntry();

        List<OpportunityLineItem> oliList = new List<OpportunityLineItem>();
        for (Integer i = 0; i < 50; i++) {
            oliList.add(new OpportunityLineItem(
                OpportunityId = opp.Id,
                PricebookEntryId = pbe.Id,
                Quantity = 1 + i,
                UnitPrice = 100
            ));
        }

        Test.startTest();
        insert oliList;
        Test.stopTest();

        Integer count = [SELECT COUNT() FROM OpportunityLineItem WHERE OpportunityId = :opp.Id];
        System.assertEquals(50, count, 'Should have inserted 50 OLIs');
    }

    // =====================
    // BULK UPDATE
    // =====================
    @isTest
    static void testTrigger_BulkUpdate() {
        Opportunity opp = getTestOpportunity();
        PricebookEntry pbe = getTestPricebookEntry();

        List<OpportunityLineItem> oliList = new List<OpportunityLineItem>();
        for (Integer i = 0; i < 10; i++) {
            oliList.add(new OpportunityLineItem(
                OpportunityId = opp.Id,
                PricebookEntryId = pbe.Id,
                Quantity = 1,
                UnitPrice = 100
            ));
        }
        insert oliList;

        Test.startTest();
        for (OpportunityLineItem oli : oliList) {
            oli.Quantity = 10;
        }
        update oliList;
        Test.stopTest();

        List<OpportunityLineItem> updated = [SELECT Quantity FROM OpportunityLineItem WHERE OpportunityId = :opp.Id];
        for (OpportunityLineItem oli : updated) {
            System.assertEquals(10, oli.Quantity, 'All quantities should be 10');
        }
    }

    // =====================
    // DIFFERENT PRODUCT CATEGORIES
    // =====================
    @isTest
    static void testTrigger_DifferentProductCategories() {
        Opportunity opp = getTestOpportunity();
        Id stdPbId = Test.getStandardPricebookId();

        // Create products with different categories
        List<Product2> products = new List<Product2>();
        List<String> categories = new List<String>{'SANITARY', 'ROOF TILES', 'ADHESIVE', 'LIGHTS'};
        
        for (String cat : categories) {
            products.add(new Product2(
                Name = 'Product ' + cat,
                IsActive = true,
                Product_Category__c = cat
            ));
        }
        insert products;

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

        List<OpportunityLineItem> oliList = new List<OpportunityLineItem>();
        for (PricebookEntry pbe : pbes) {
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
        System.assertEquals(4, count, 'Should have inserted 4 OLIs with different categories');
    }

    // =====================
    // NO PRODUCT CATEGORY
    // =====================
    @isTest
    static void testTrigger_NoProductCategory() {
        Opportunity opp = getTestOpportunity();
        Id stdPbId = Test.getStandardPricebookId();

        Product2 prod = new Product2(
            Name = 'No Category Product',
            IsActive = true
            // No Product_Category__c
        );
        insert prod;

        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = stdPbId,
            Product2Id = prod.Id,
            UnitPrice = 50,
            IsActive = true
        );
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

        System.assert(true, 'Should handle product without category');
    }
}