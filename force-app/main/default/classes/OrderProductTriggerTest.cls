@isTest
private class OrderProductTriggerTest {

    @testSetup
    static void setupData() {

        // Create Account
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

        // Get Standard Pricebook Id (Correct way in test context)
        Id stdPricebookId = Test.getStandardPricebookId();

        // Activate Standard Pricebook
        Pricebook2 pb = new Pricebook2(
            Id = stdPricebookId,
            IsActive = true
        );
        update pb;

        // Create Product
        Product2 prod = new Product2(
            Name = 'Test Product',
            IsActive = true
        );
        insert prod;

        // Create Pricebook Entry
        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = stdPricebookId,
            Product2Id = prod.Id,
            UnitPrice = 100,
            IsActive = true
        );
        insert pbe;

        // Create Order
        Order ord = new Order(
            AccountId = acc.Id,
            EffectiveDate = Date.today(),
            Status = 'Draft',
            Pricebook2Id = stdPricebookId
        );
        insert ord;
    }

    // -----------------------------
    // BEFORE INSERT + AFTER INSERT
    // -----------------------------
    @isTest
    static void testInsertFlow() {

        Order ord = [SELECT Id FROM Order LIMIT 1];
        PricebookEntry pbe = [SELECT Id FROM PricebookEntry LIMIT 1];

        OrderItem oi = new OrderItem(
            OrderId = ord.Id,
            Quantity = 2,
            UnitPrice = 100,
            PricebookEntryId = pbe.Id
        );

        Test.startTest();
        insert oi;
        Test.stopTest();

        OrderItem insertedItem = [
            SELECT Id, Quantity 
            FROM OrderItem 
            WHERE Id = :oi.Id
        ];

        System.assertEquals(2, insertedItem.Quantity);
    }

    // -----------------------------
    // BEFORE UPDATE + AFTER UPDATE
    // -----------------------------
    @isTest
    static void testUpdateFlow() {

        Order ord = [SELECT Id FROM Order LIMIT 1];
        PricebookEntry pbe = [SELECT Id FROM PricebookEntry LIMIT 1];

        OrderItem oi = new OrderItem(
            OrderId = ord.Id,
            Quantity = 1,
            UnitPrice = 100,
            PricebookEntryId = pbe.Id
        );
        insert oi;

        oi.Quantity = 5;

        Test.startTest();
        update oi;
        Test.stopTest();

        OrderItem updatedItem = [
            SELECT Quantity 
            FROM OrderItem 
            WHERE Id = :oi.Id
        ];

        System.assertEquals(5, updatedItem.Quantity);
    }

    // -----------------------------
    // BULK COVERAGE
    // -----------------------------
    @isTest
    static void testBulkFlow() {

        Order ord = [SELECT Id FROM Order LIMIT 1];
        PricebookEntry pbe = [SELECT Id FROM PricebookEntry LIMIT 1];

        List<OrderItem> items = new List<OrderItem>();

        for(Integer i = 0; i < 10; i++) {
            items.add(new OrderItem(
                OrderId = ord.Id,
                Quantity = 1,
                UnitPrice = 100,
                PricebookEntryId = pbe.Id
            ));
        }

        Test.startTest();
        insert items;

        System.assertEquals(10, items.size());

        for(OrderItem oi : items) {
            oi.Quantity = 3;
        }

        update items;
        Test.stopTest();

        List<OrderItem> updated = [
            SELECT Quantity 
            FROM OrderItem 
            WHERE OrderId = :ord.Id
        ];

        System.assertEquals(3, updated[0].Quantity);
    }
}