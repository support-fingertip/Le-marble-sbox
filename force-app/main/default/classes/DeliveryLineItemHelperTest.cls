@IsTest
public class DeliveryLineItemHelperTest {

    // ─── shared setup ────────────────────────────────────────────────────────

    private static OrderItem createOrderItemWithDLIs(Integer oiQty, List<Integer> dliQuantities) {
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        Id stdPb = Test.getStandardPricebookId();

        Order ord = new Order(
            AccountId     = acc.Id,
            EffectiveDate = Date.today(),
            Status        = 'Draft',
            Pricebook2Id  = stdPb
        );
        SalesOrderTriggerHandler.isRunning = true;
        insert ord;
        SalesOrderTriggerHandler.isRunning = false;

        Product2 prod = new Product2(Name = 'Test Product', IsActive = true);
        insert prod;

        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = stdPb,
            Product2Id   = prod.Id,
            UnitPrice    = 100,
            IsActive     = true
        );
        insert pbe;

        OrderItem oi = new OrderItem(
            OrderId          = ord.Id,
            Quantity         = oiQty,
            UnitPrice        = 100,
            PricebookEntryId = pbe.Id
        );
        insert oi;

        if (dliQuantities != null && !dliQuantities.isEmpty()) {
            Delivery_Group__c dg = new Delivery_Group__c(
                Sales_Order__c     = ord.Id,
                Quantity__c        = oiQty,
                Delivery_Status__c = 'Draft',
                Approval_Status__c = 'Draft'
            );
            insert dg;

            List<Delivery_Line_Item__c> dlis = new List<Delivery_Line_Item__c>();
            for (Integer q : dliQuantities) {
                dlis.add(new Delivery_Line_Item__c(
                    Delivery_Group__c        = dg.Id,
                    Sales_Order_Line_Item__c = oi.Id,
                    Quantity__c              = q
                ));
            }
            insert dlis;
        }

        return oi;
    }

    // ─── TEST 1: Null input — early return ───────────────────────────────────

    @IsTest
    static void testNullInput_NoError() {
        Test.startTest();
        DeliveryLineItemHelper.updateOrderProductRollups(null);
        Test.stopTest();
        // No exception = pass
    }

    // ─── TEST 2: Empty set — early return ────────────────────────────────────

    @IsTest
    static void testEmptySet_NoError() {
        Test.startTest();
        DeliveryLineItemHelper.updateOrderProductRollups(new Set<Id>());
        Test.stopTest();
    }

    // ─── TEST 3: No DLIs exist — status = Pending, delivered = 0 ─────────────

    @IsTest
    static void testNoDLIs_StatusPending() {
        OrderItem oi = createOrderItemWithDLIs(10, null);

        Test.startTest();
        DeliveryLineItemHelper.updateOrderProductRollups(new Set<Id>{ oi.Id });
        Test.stopTest();

        OrderItem updated = [SELECT Delivered_Quantity__c, Pending_Quantity__c, Delivery_Status__c
                             FROM OrderItem WHERE Id = :oi.Id];
        System.assertEquals(0, updated.Delivered_Quantity__c, 'Delivered should be 0');
        System.assertEquals(10, updated.Pending_Quantity__c, 'Pending should be 10');
        System.assertEquals('Pending', updated.Delivery_Status__c, 'Status should be Pending');
    }

    // ─── TEST 4: Partial delivery — status = Partial ─────────────────────────

    @IsTest
    static void testPartialDelivery_StatusPartial() {
        OrderItem oi = createOrderItemWithDLIs(10, new List<Integer>{ 4 });

        Test.startTest();
        DeliveryLineItemHelper.updateOrderProductRollups(new Set<Id>{ oi.Id });
        Test.stopTest();

        OrderItem updated = [SELECT Delivered_Quantity__c, Pending_Quantity__c, Delivery_Status__c
                             FROM OrderItem WHERE Id = :oi.Id];
        System.assertEquals(4, updated.Delivered_Quantity__c, 'Delivered should be 4');
        System.assertEquals(6, updated.Pending_Quantity__c, 'Pending should be 6');
        System.assertEquals('Partial', updated.Delivery_Status__c, 'Status should be Partial');
    }

    // ─── TEST 5: Full delivery — status = Delivered ──────────────────────────

    @IsTest
    static void testFullDelivery_StatusDelivered() {
        OrderItem oi = createOrderItemWithDLIs(10, new List<Integer>{ 10 });

        Test.startTest();
        DeliveryLineItemHelper.updateOrderProductRollups(new Set<Id>{ oi.Id });
        Test.stopTest();

        OrderItem updated = [SELECT Delivered_Quantity__c, Pending_Quantity__c, Delivery_Status__c
                             FROM OrderItem WHERE Id = :oi.Id];
        System.assertEquals(10, updated.Delivered_Quantity__c, 'Delivered should be 10');
        System.assertEquals(0, updated.Pending_Quantity__c, 'Pending should be 0');
        System.assertEquals('Delivered', updated.Delivery_Status__c, 'Status should be Delivered');
    }

    // ─── TEST 6: Over-delivery — pending clamped to 0 ────────────────────────

    @IsTest
    static void testOverDelivery_PendingClampedToZero() {
        OrderItem oi = createOrderItemWithDLIs(5, new List<Integer>{ 8 });

        Test.startTest();
        DeliveryLineItemHelper.updateOrderProductRollups(new Set<Id>{ oi.Id });
        Test.stopTest();

        OrderItem updated = [SELECT Delivered_Quantity__c, Pending_Quantity__c, Delivery_Status__c
                             FROM OrderItem WHERE Id = :oi.Id];
        System.assertEquals(8, updated.Delivered_Quantity__c, 'Delivered should be 8');
        System.assertEquals(0, updated.Pending_Quantity__c, 'Pending should be clamped to 0');
        System.assertEquals('Delivered', updated.Delivery_Status__c, 'Status should be Delivered');
    }

    // ─── TEST 7: Multiple DLIs summed ────────────────────────────────────────

    @IsTest
    static void testMultipleDLIs_QuantitiesSummed() {
        OrderItem oi = createOrderItemWithDLIs(10, new List<Integer>{ 3, 2, 1 });

        Test.startTest();
        DeliveryLineItemHelper.updateOrderProductRollups(new Set<Id>{ oi.Id });
        Test.stopTest();

        OrderItem updated = [SELECT Delivered_Quantity__c, Pending_Quantity__c, Delivery_Status__c
                             FROM OrderItem WHERE Id = :oi.Id];
        System.assertEquals(6, updated.Delivered_Quantity__c, 'Delivered should be 3+2+1=6');
        System.assertEquals(4, updated.Pending_Quantity__c, 'Pending should be 4');
        System.assertEquals('Partial', updated.Delivery_Status__c, 'Status should be Partial');
    }

    // ─── TEST 8: Already up-to-date — no unnecessary DML ────────────────────

    @IsTest
    static void testAlreadyUpToDate_NoRedundantUpdate() {
        OrderItem oi = createOrderItemWithDLIs(10, new List<Integer>{ 5 });

        // First call sets the values
        DeliveryLineItemHelper.updateOrderProductRollups(new Set<Id>{ oi.Id });

        Test.startTest();
        // Second call with same data — needsUpdate should be false, no DML
        DeliveryLineItemHelper.updateOrderProductRollups(new Set<Id>{ oi.Id });
        Test.stopTest();

        OrderItem updated = [SELECT Delivered_Quantity__c, Pending_Quantity__c, Delivery_Status__c
                             FROM OrderItem WHERE Id = :oi.Id];
        System.assertEquals(5, updated.Delivered_Quantity__c, 'Delivered should still be 5');
        System.assertEquals(5, updated.Pending_Quantity__c, 'Pending should still be 5');
        System.assertEquals('Partial', updated.Delivery_Status__c, 'Status should still be Partial');
    }

    // ─── TEST 9: Invalid OrderItem Id — no exception ─────────────────────────

    @IsTest
    static void testInvalidOrderItemId_NoError() {
        // Pass a fabricated Id that doesn't exist — should not throw
        Id fakeId = OrderItem.SObjectType.getDescribe().getKeyPrefix() + '000000000001';

        Test.startTest();
        DeliveryLineItemHelper.updateOrderProductRollups(new Set<Id>{ fakeId });
        Test.stopTest();
        // No exception = pass
    }
}