@IsTest
public class DeliveryLineItemTriggerTest {

    // ─── wrapper + shared setup ──────────────────────────────────────────────

    private class TestDataWrapper {
        OrderItem orderItem;
        Delivery_Group__c deliveryGroup;
        Order salesOrder;
    }

    private static TestDataWrapper createTestData() {
        TestDataWrapper data = new TestDataWrapper();

        Account acc = new Account(Name = 'Test Account');
        insert acc;

        Id stdPricebookId = Test.getStandardPricebookId();

        Order ord = new Order(
            AccountId    = acc.Id,
            EffectiveDate = Date.today(),
            Status       = 'Draft',
            Pricebook2Id = stdPricebookId
        );
        SalesOrderTriggerHandler.isRunning = true;
        insert ord;
        SalesOrderTriggerHandler.isRunning = false;

        Product2 prod = new Product2(Name = 'Test Product', IsActive = true);
        insert prod;

        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = stdPricebookId,
            Product2Id   = prod.Id,
            UnitPrice    = 100,
            IsActive     = true
        );
        insert pbe;

        OrderItem oi = new OrderItem(
            OrderId          = ord.Id,
            Quantity         = 10,
            UnitPrice        = 100,
            PricebookEntryId = pbe.Id
        );
        insert oi;

        Delivery_Group__c dg = new Delivery_Group__c(
            Sales_Order__c     = ord.Id,
            Quantity__c        = 10,
            Delivery_Status__c = 'Draft',
            Approval_Status__c = 'Draft'
        );
        insert dg;

        data.orderItem     = oi;
        data.deliveryGroup = dg;
        data.salesOrder    = ord;
        return data;
    }

    // ─── AFTER INSERT ────────────────────────────────────────────────────────

    @IsTest
    static void testInsertDeliveryLineItem() {
        TestDataWrapper data = createTestData();

        Test.startTest();
        Delivery_Line_Item__c dli = new Delivery_Line_Item__c(
            Delivery_Group__c        = data.deliveryGroup.Id,
            Sales_Order_Line_Item__c = data.orderItem.Id,
            Quantity__c              = 4
        );
        insert dli;
        Test.stopTest();

        OrderItem oi = [SELECT Delivered_Quantity__c, Pending_Quantity__c, Delivery_Status__c
                        FROM OrderItem WHERE Id = :data.orderItem.Id];
        System.assertEquals(4, oi.Delivered_Quantity__c, 'Delivered qty should be 4');
        System.assertEquals(6, oi.Pending_Quantity__c, 'Pending qty should be 6');
        System.assertEquals('Partial', oi.Delivery_Status__c, 'Status should be Partial');
    }

    @IsTest
    static void testInsertFullDelivery() {
        TestDataWrapper data = createTestData();

        Test.startTest();
        insert new Delivery_Line_Item__c(
            Delivery_Group__c        = data.deliveryGroup.Id,
            Sales_Order_Line_Item__c = data.orderItem.Id,
            Quantity__c              = 10
        );
        Test.stopTest();

        OrderItem oi = [SELECT Delivered_Quantity__c, Pending_Quantity__c, Delivery_Status__c
                        FROM OrderItem WHERE Id = :data.orderItem.Id];
        System.assertEquals(10, oi.Delivered_Quantity__c, 'Delivered qty should be 10');
        System.assertEquals(0, oi.Pending_Quantity__c, 'Pending qty should be 0');
        System.assertEquals('Delivered', oi.Delivery_Status__c, 'Status should be Delivered');
    }

    @IsTest
    static void testInsertMultipleDLIs() {
        TestDataWrapper data = createTestData();

        Test.startTest();
        insert new List<Delivery_Line_Item__c>{
            new Delivery_Line_Item__c(
                Delivery_Group__c        = data.deliveryGroup.Id,
                Sales_Order_Line_Item__c = data.orderItem.Id,
                Quantity__c              = 3
            ),
            new Delivery_Line_Item__c(
                Delivery_Group__c        = data.deliveryGroup.Id,
                Sales_Order_Line_Item__c = data.orderItem.Id,
                Quantity__c              = 2
            )
        };
        Test.stopTest();

        OrderItem oi = [SELECT Delivered_Quantity__c, Pending_Quantity__c, Delivery_Status__c
                        FROM OrderItem WHERE Id = :data.orderItem.Id];
        System.assertEquals(5, oi.Delivered_Quantity__c, 'Delivered qty should be 3+2=5');
        System.assertEquals(5, oi.Pending_Quantity__c, 'Pending qty should be 5');
        System.assertEquals('Partial', oi.Delivery_Status__c, 'Status should be Partial');
    }

    @IsTest
    static void testInsertWithNoSalesOrderLineItem() {
        // DLI without Sales_Order_Line_Item__c — trigger should skip it gracefully
        TestDataWrapper data = createTestData();

        Test.startTest();
        Delivery_Line_Item__c dli = new Delivery_Line_Item__c(
            Delivery_Group__c = data.deliveryGroup.Id,
            Quantity__c       = 5
        );
        insert dli;
        Test.stopTest();

        // OrderItem should remain untouched
        OrderItem oi = [SELECT Delivered_Quantity__c FROM OrderItem WHERE Id = :data.orderItem.Id];
        System.assert(oi.Delivered_Quantity__c == null || oi.Delivered_Quantity__c == 0,
            'Delivered qty should remain 0 when DLI has no Sales_Order_Line_Item__c');
    }

    // ─── AFTER UPDATE ────────────────────────────────────────────────────────

    @IsTest
    static void testUpdateDeliveryLineItem() {
        TestDataWrapper data = createTestData();

        Delivery_Line_Item__c dli = new Delivery_Line_Item__c(
            Delivery_Group__c        = data.deliveryGroup.Id,
            Sales_Order_Line_Item__c = data.orderItem.Id,
            Quantity__c              = 3
        );
        insert dli;

        Test.startTest();
        dli.Quantity__c = 7;
        update dli;
        Test.stopTest();

        OrderItem oi = [SELECT Delivered_Quantity__c, Pending_Quantity__c, Delivery_Status__c
                        FROM OrderItem WHERE Id = :data.orderItem.Id];
        System.assertEquals(7, oi.Delivered_Quantity__c, 'Delivered qty should be 7 after update');
        System.assertEquals(3, oi.Pending_Quantity__c, 'Pending qty should be 3');
        System.assertEquals('Partial', oi.Delivery_Status__c, 'Status should be Partial');
    }

    // ─── AFTER DELETE (rollup reset + notification) ──────────────────────────

    @IsTest
    static void testDeleteDeliveryLineItem() {
        TestDataWrapper data = createTestData();

        Delivery_Line_Item__c dli = new Delivery_Line_Item__c(
            Delivery_Group__c        = data.deliveryGroup.Id,
            Sales_Order_Line_Item__c = data.orderItem.Id,
            Quantity__c              = 5
        );
        insert dli;

        Test.startTest();
        delete dli;
        Test.stopTest();

        OrderItem oi = [SELECT Delivered_Quantity__c, Pending_Quantity__c, Delivery_Status__c
                        FROM OrderItem WHERE Id = :data.orderItem.Id];
        System.assertEquals(0, oi.Delivered_Quantity__c, 'Delivered qty should reset to 0');
        System.assertEquals(10, oi.Pending_Quantity__c, 'Pending qty should be 10');
        System.assertEquals('Pending', oi.Delivery_Status__c, 'Status should be Pending');
    }

    @IsTest
    static void testDeleteWithNotification() {
        // Covers the delete-branch notification logic (CustomNotificationType may or may not exist)
        TestDataWrapper data = createTestData();

        Delivery_Line_Item__c dli = new Delivery_Line_Item__c(
            Delivery_Group__c        = data.deliveryGroup.Id,
            Sales_Order_Line_Item__c = data.orderItem.Id,
            Quantity__c              = 3
        );
        insert dli;

        Test.startTest();
        delete dli;
        Test.stopTest();

        // Verify rollup is correct — notification fires silently
        OrderItem oi = [SELECT Delivered_Quantity__c, Delivery_Status__c
                        FROM OrderItem WHERE Id = :data.orderItem.Id];
        System.assertEquals(0, oi.Delivered_Quantity__c, 'Delivered qty should reset after delete');
        System.assertEquals('Pending', oi.Delivery_Status__c, 'Status should be Pending');
    }

    @IsTest
    static void testDeleteDLIWithNoSalesOrderLineItem() {
        // DLI without Sales_Order_Line_Item__c — delete should skip rollup & notification
        TestDataWrapper data = createTestData();

        Delivery_Line_Item__c dli = new Delivery_Line_Item__c(
            Delivery_Group__c = data.deliveryGroup.Id,
            Quantity__c       = 5
        );
        insert dli;

        Test.startTest();
        delete dli;
        Test.stopTest();

        // OrderItem unchanged
        OrderItem oi = [SELECT Delivered_Quantity__c FROM OrderItem WHERE Id = :data.orderItem.Id];
        System.assert(oi.Delivered_Quantity__c == null || oi.Delivered_Quantity__c == 0,
            'Delivered qty should remain 0 when deleted DLI had no Sales_Order_Line_Item__c');
    }

    // ─── AFTER UNDELETE ──────────────────────────────────────────────────────

    @IsTest
    static void testUndeleteDeliveryLineItem() {
        TestDataWrapper data = createTestData();

        Delivery_Line_Item__c dli = new Delivery_Line_Item__c(
            Delivery_Group__c        = data.deliveryGroup.Id,
            Sales_Order_Line_Item__c = data.orderItem.Id,
            Quantity__c              = 6
        );
        insert dli;
        delete dli;

        Test.startTest();
        undelete dli;
        Test.stopTest();

        OrderItem oi = [SELECT Delivered_Quantity__c, Pending_Quantity__c, Delivery_Status__c
                        FROM OrderItem WHERE Id = :data.orderItem.Id];
        System.assertEquals(6, oi.Delivered_Quantity__c, 'Delivered qty should be restored to 6 after undelete');
        System.assertEquals(4, oi.Pending_Quantity__c, 'Pending qty should be 4');
        System.assertEquals('Partial', oi.Delivery_Status__c, 'Status should be Partial');
    }
}