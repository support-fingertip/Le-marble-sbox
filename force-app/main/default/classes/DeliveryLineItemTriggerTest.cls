@IsTest
public class DeliveryLineItemTriggerTest {

    // Wrapper to return multiple records
    private class TestDataWrapper {
        OrderItem orderItem;
        Delivery_Group__c deliveryGroup;
    }

    // Common test data setup
    private static TestDataWrapper createTestData() {

        TestDataWrapper data = new TestDataWrapper();

        // Account
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        // Standard Pricebook
        Id stdPricebookId = Test.getStandardPricebookId();

        // Order
        Order ord = new Order(
            AccountId = acc.Id,
            EffectiveDate = Date.today(),
            Status = 'Draft',
            Pricebook2Id = stdPricebookId
        );
        insert ord;

        // Product
        Product2 prod = new Product2(
            Name = 'Test Product',
            IsActive = true
        );
        insert prod;

        // Pricebook Entry
        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = stdPricebookId,
            Product2Id = prod.Id,
            UnitPrice = 100,
            IsActive = true
        );
        insert pbe;

        // Order Item
        OrderItem oi = new OrderItem(
            OrderId = ord.Id,
            Quantity = 10,
            UnitPrice = 100,
            PricebookEntryId = pbe.Id
        );
        insert oi;

        // Delivery Group (Delivery Plan)
        Delivery_Group__c dg = new Delivery_Group__c(
            Name = 'Test Delivery Plan',
            Sales_Order__c = ord.Id,
            Quantity__c = 10,
            Delivery_Status__c = 'Draft',
            Approval_Status__c = 'Draft'
        );
        insert dg;

        data.orderItem = oi;
        data.deliveryGroup = dg;

        return data;
    }

    // Test insert of Delivery Line Item
    @IsTest
    static void testInsertDeliveryLineItem() {

        TestDataWrapper data = createTestData();

        Test.startTest();
        Delivery_Line_Item__c dli = new Delivery_Line_Item__c(
            Delivery_Group__c = data.deliveryGroup.Id,
            Sales_Order_Line_Item__c = data.orderItem.Id,
            Quantity__c = 4
        );
        insert dli;
        Test.stopTest();

        OrderItem updatedOi = [
            SELECT Delivered_Quantity__c, Pending_Quantity__c, Delivery_Status__c
            FROM OrderItem
            WHERE Id = :data.orderItem.Id
        ];

        System.assertEquals(4, updatedOi.Delivered_Quantity__c);
        System.assertEquals(6, updatedOi.Pending_Quantity__c);
        System.assertEquals('Partial', updatedOi.Delivery_Status__c);
    }

    // Test update of Delivery Line Item
    @IsTest
    static void testUpdateDeliveryLineItem() {

        TestDataWrapper data = createTestData();

        Delivery_Line_Item__c dli = new Delivery_Line_Item__c(
            Delivery_Group__c = data.deliveryGroup.Id,
            Sales_Order_Line_Item__c = data.orderItem.Id,
            Quantity__c = 3
        );
        insert dli;

        Test.startTest();
        dli.Quantity__c = 7;
        update dli;
        Test.stopTest();

        OrderItem updatedOi = [
            SELECT Delivered_Quantity__c, Pending_Quantity__c, Delivery_Status__c
            FROM OrderItem
            WHERE Id = :data.orderItem.Id
        ];

        System.assertEquals(7, updatedOi.Delivered_Quantity__c);
        System.assertEquals(3, updatedOi.Pending_Quantity__c);
        System.assertEquals('Partial', updatedOi.Delivery_Status__c);
    }

    // Test delete of Delivery Line Item
    @IsTest
    static void testDeleteDeliveryLineItem() {

        TestDataWrapper data = createTestData();

        Delivery_Line_Item__c dli = new Delivery_Line_Item__c(
            Delivery_Group__c = data.deliveryGroup.Id,
            Sales_Order_Line_Item__c = data.orderItem.Id,
            Quantity__c = 5
        );
        insert dli;

        Test.startTest();
        delete dli;
        Test.stopTest();

        OrderItem updatedOi = [
            SELECT Delivered_Quantity__c, Pending_Quantity__c, Delivery_Status__c
            FROM OrderItem
            WHERE Id = :data.orderItem.Id
        ];

        System.assertEquals(0, updatedOi.Delivered_Quantity__c);
        System.assertEquals(10, updatedOi.Pending_Quantity__c);
        System.assertEquals('Pending', updatedOi.Delivery_Status__c);
    }

    // Test full delivery scenario
    @IsTest
    static void testFullDelivery() {

        TestDataWrapper data = createTestData();

        Test.startTest();
        Delivery_Line_Item__c dli = new Delivery_Line_Item__c(
            Delivery_Group__c = data.deliveryGroup.Id,
            Sales_Order_Line_Item__c = data.orderItem.Id,
            Quantity__c = 10
        );
        insert dli;
        Test.stopTest();

        OrderItem updatedOi = [
            SELECT Delivered_Quantity__c, Pending_Quantity__c, Delivery_Status__c
            FROM OrderItem
            WHERE Id = :data.orderItem.Id
        ];

        System.assertEquals(10, updatedOi.Delivered_Quantity__c);
        System.assertEquals(0, updatedOi.Pending_Quantity__c);
        System.assertEquals('Delivered', updatedOi.Delivery_Status__c);
    }
}