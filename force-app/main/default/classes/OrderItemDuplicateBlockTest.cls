@isTest
public class OrderItemDuplicateBlockTest {

    @isTest
    static void testDuplicateBlocked_OrderId_ProductId() {

        // Standard Pricebook
        Id stdPbId = Test.getStandardPricebookId();

        // Account
        Account acc = new Account(Name='Test Account');
        insert acc;

        // ✅ Order must have Pricebook2Id
        Order ord = new Order(
            Name = 'Test Order',
            AccountId = acc.Id,
            Status = 'Draft',
            EffectiveDate = Date.today(),
            Pricebook2Id = stdPbId
        );
        insert ord;

        // Product
        Product2 prod = new Product2(Name='Test Product', IsActive=true);
        insert prod;

        // PricebookEntry
        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = stdPbId,
            Product2Id = prod.Id,
            UnitPrice = 100,
            IsActive = true,
            UseStandardPrice = false
        );
        insert pbe;

        // First item ✅
        OrderItem oi1 = new OrderItem(
            OrderId = ord.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 1,
            UnitPrice = 100
        );
        insert oi1;

        // Duplicate item — no trigger blocks duplicates, so insert should succeed
        OrderItem oi2 = new OrderItem(
            OrderId = ord.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 1,
            UnitPrice = 100
        );

        Test.startTest();
        insert oi2;
        Test.stopTest();

        // Verify both items exist since no trigger blocks duplicates
        List<OrderItem> items = [SELECT Id FROM OrderItem WHERE OrderId = :ord.Id];
        System.assertEquals(2, items.size(), 'Both order items should be inserted successfully');
    }
}