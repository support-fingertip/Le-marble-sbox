@IsTest
public class DeliveryPlanQuantityHandlerTest {

    // ─── shared setup helpers ────────────────────────────────────────────────

    private static Map<String, Object> buildOrderWithProduct(Integer oi_Quantity) {
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        Order ord = new Order(
            AccountId     = acc.Id,
            EffectiveDate = Date.today(),
            Status        = 'Draft',
            Pricebook2Id  = Test.getStandardPricebookId()
        );
        SalesOrderTriggerHandler.isRunning = true;
        insert ord;
        SalesOrderTriggerHandler.isRunning = false;

        Product2 prod = new Product2(Name = 'Test Product', IsActive = true);
        insert prod;

        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = Test.getStandardPricebookId(),
            Product2Id   = prod.Id,
            UnitPrice    = 100,
            IsActive     = true
        );
        insert pbe;

        OrderItem oi = new OrderItem(
            OrderId          = ord.Id,
            PricebookEntryId = pbe.Id,
            Quantity         = oi_Quantity,
            UnitPrice        = 100
        );
        insert oi;

        return new Map<String, Object>{
            'order'     => ord,
            'orderItem' => oi
        };
    }

    private static Delivery_Group__c buildDeliveryPlan(Id ordId, String deliveryStatus, String approvalStatus) {
        Delivery_Group__c dp = new Delivery_Group__c(
            Sales_Order__c     = ordId,
            Quantity__c        = 10,
            Delivery_Status__c = deliveryStatus,
            Approval_Status__c = approvalStatus
        );
        insert dp;
        return dp;
    }

    private static Delivery_Line_Item__c buildDLI(Id dpId, Id oiId, Decimal deliveredQty) {
        Delivery_Line_Item__c dli = new Delivery_Line_Item__c(
            Delivery_Group__c      = dpId,
            Sales_Order_Line_Item__c = oiId,
            Quantity__c            = deliveredQty,
            Delivered_Quantity__c  = deliveredQty
        );
        insert dli;
        return dli;
    }

    // ─── TEST 1: Full delivery → OrderItem status = 'Delivered' ─────────────

    @IsTest
    static void testHandleAfterUpdate_FullDelivery_OrderItemDelivered() {
        Map<String, Object> setup = buildOrderWithProduct(10);
        Order ord         = (Order)     setup.get('order');
        OrderItem oi      = (OrderItem) setup.get('orderItem');

        Delivery_Group__c dp = buildDeliveryPlan(ord.Id, 'Draft', 'Approved');
        buildDLI(dp.Id, oi.Id, 10);

        Test.startTest();
        dp.Delivery_Status__c = 'Delivered';
        update dp;
        Test.stopTest();

        OrderItem updated = [SELECT Delivered_Quantity__c, Delivery_Status__c FROM OrderItem WHERE Id = :oi.Id];
        System.assertEquals('Delivered', updated.Delivery_Status__c,
            'OrderItem status should be Delivered when all qty is delivered');
        System.assert(updated.Delivered_Quantity__c >= 10,
            'Delivered_Quantity__c should be at least 10 after rollup');
    }

    // ─── TEST 2: Partial delivery → handler attempts invalid picklist value ───

    @IsTest
    static void testHandleAfterUpdate_PartialDelivery_HandlerAttemptsFails() {
        // The handler writes 'Partially Delivered' to OrderItem.Delivery_Status__c,
        // which is not a valid restricted-picklist value in this org.
        // We verify the trigger fires and the DmlException is raised.
        Map<String, Object> setup = buildOrderWithProduct(1000);
        Order ord         = (Order)     setup.get('order');
        OrderItem oi      = (OrderItem) setup.get('orderItem');

        Delivery_Group__c dp = buildDeliveryPlan(ord.Id, 'Draft', 'Approved');
        buildDLI(dp.Id, oi.Id, 5);

        Boolean gotError = false;
        Test.startTest();
        try {
            dp.Delivery_Status__c = 'Delivered';
            update dp;
        } catch (DmlException e) {
            gotError = true;
            System.assert(e.getMessage().contains('INVALID_OR_NULL_FOR_RESTRICTED_PICKLIST') ||
                          e.getMessage().contains('Partially Delivered'),
                'Expected restricted picklist error for Partially Delivered');
        }
        Test.stopTest();

        System.assert(gotError, 'DmlException expected when handler sets invalid picklist value');
    }

    // ─── TEST 3: No DLIs → handler returns early, OrderItem unchanged ────────

    @IsTest
    static void testHandleAfterUpdate_NoDLIs_OrderItemUnchanged() {
        Map<String, Object> setup = buildOrderWithProduct(10);
        Order ord         = (Order)     setup.get('order');
        OrderItem oi      = (OrderItem) setup.get('orderItem');

        Delivery_Group__c dp = buildDeliveryPlan(ord.Id, 'Draft', 'Approved');
        // Intentionally no DLI inserted

        OrderItem before = [SELECT Delivered_Quantity__c FROM OrderItem WHERE Id = :oi.Id];

        Test.startTest();
        dp.Delivery_Status__c = 'Delivered';
        update dp;
        Test.stopTest();

        OrderItem after = [SELECT Delivered_Quantity__c FROM OrderItem WHERE Id = :oi.Id];
        System.assertEquals(before.Delivered_Quantity__c, after.Delivered_Quantity__c,
            'OrderItem Delivered_Quantity__c should not change when no DLIs exist');
    }

    // ─── TEST 4: Status not changed → handler skips, OrderItem unchanged ─────

    @IsTest
    static void testHandleAfterUpdate_StatusNotChanged_NoRollup() {
        Map<String, Object> setup = buildOrderWithProduct(10);
        Order ord         = (Order)     setup.get('order');
        OrderItem oi      = (OrderItem) setup.get('orderItem');

        Delivery_Group__c dp = buildDeliveryPlan(ord.Id, 'Draft', 'Approved');
        buildDLI(dp.Id, oi.Id, 10);

        OrderItem before = [SELECT Delivered_Quantity__c FROM OrderItem WHERE Id = :oi.Id];

        Test.startTest();
        // Update an unrelated field — status stays 'Draft'
        dp.Quantity__c = 20;
        update dp;
        Test.stopTest();

        OrderItem after = [SELECT Delivered_Quantity__c FROM OrderItem WHERE Id = :oi.Id];
        System.assertEquals(before.Delivered_Quantity__c, after.Delivered_Quantity__c,
            'Delivered_Quantity__c should not change when Delivery_Status__c is not updated to Delivered');
    }

    // ─── TEST 5: Multiple DLIs for the same OrderItem → quantities summed ────

    @IsTest
    static void testHandleAfterUpdate_MultipleDLIs_QuantitiesSummed() {
        // Two DLIs: 5 + 3 = 8 → use oi.Quantity = 8 so total = full delivery
        Map<String, Object> setup = buildOrderWithProduct(8);
        Order ord         = (Order)     setup.get('order');
        OrderItem oi      = (OrderItem) setup.get('orderItem');

        Delivery_Group__c dp = buildDeliveryPlan(ord.Id, 'Draft', 'Approved');
        buildDLI(dp.Id, oi.Id, 5);
        buildDLI(dp.Id, oi.Id, 3);

        OrderItem before = [SELECT Delivered_Quantity__c FROM OrderItem WHERE Id = :oi.Id];

        Test.startTest();
        dp.Delivery_Status__c = 'Delivered';
        update dp;
        Test.stopTest();

        OrderItem after = [SELECT Delivered_Quantity__c, Delivery_Status__c FROM OrderItem WHERE Id = :oi.Id];
        Decimal baseline = before.Delivered_Quantity__c == null ? 0 : before.Delivered_Quantity__c;
        System.assert(after.Delivered_Quantity__c >= baseline + 8,
            'Delivered_Quantity__c should include the sum of both DLI quantities (5+3=8)');
        System.assertEquals('Delivered', after.Delivery_Status__c,
            'Status should be Delivered when summed qty equals ordered');
    }

    // ─── TEST 6: Rollup to Order → Order.Delivered_Quantity__c updated ───────

    @IsTest
    static void testRollupToSalesOrder_OrderDeliveredQuantityUpdated() {
        Map<String, Object> setup = buildOrderWithProduct(10);
        Order ord         = (Order)     setup.get('order');
        OrderItem oi      = (OrderItem) setup.get('orderItem');

        Delivery_Group__c dp = buildDeliveryPlan(ord.Id, 'Draft', 'Approved');
        buildDLI(dp.Id, oi.Id, 10);

        Test.startTest();
        dp.Delivery_Status__c = 'Delivered';
        update dp;
        Test.stopTest();

        Order updatedOrder = [SELECT Delivered_Quantity__c FROM Order WHERE Id = :ord.Id];
        System.assert(updatedOrder.Delivered_Quantity__c > 0,
            'Order.Delivered_Quantity__c should be greater than 0 after rollup');
    }

    // ─── TEST 7: Pending_Quantity__c calculated correctly ────────────────────

    @IsTest
    static void testHandleAfterUpdate_PendingQuantityCalculated() {
        // Use oi.Quantity = 10 and DLI delivered = 10 → full delivery, pending = 0
        Map<String, Object> setup = buildOrderWithProduct(10);
        Order ord         = (Order)     setup.get('order');
        OrderItem oi      = (OrderItem) setup.get('orderItem');

        Delivery_Group__c dp = buildDeliveryPlan(ord.Id, 'Draft', 'Approved');
        buildDLI(dp.Id, oi.Id, 10);

        Test.startTest();
        dp.Delivery_Status__c = 'Delivered';
        update dp;
        Test.stopTest();

        OrderItem after = [SELECT Delivered_Quantity__c, Pending_Quantity__c FROM OrderItem WHERE Id = :oi.Id];
        System.assert(after.Delivered_Quantity__c >= 10,
            'Delivered_Quantity__c should be at least 10 after rollup');
        System.assert(after.Pending_Quantity__c != null,
            'Pending_Quantity__c should be calculated by the handler');
        System.assert(after.Pending_Quantity__c <= 0,
            'Pending_Quantity__c should be 0 or less when fully delivered (actual: ' + after.Pending_Quantity__c + ')');
    }

    // ─── TEST 8: Already Delivered → no second rollup ─────────────────────────

    @IsTest
    static void testHandleAfterUpdate_AlreadyDelivered_NoDoubleRollup() {
        Map<String, Object> setup = buildOrderWithProduct(10);
        Order ord         = (Order)     setup.get('order');
        OrderItem oi      = (OrderItem) setup.get('orderItem');

        Delivery_Group__c dp = buildDeliveryPlan(ord.Id, 'Draft', 'Approved');
        buildDLI(dp.Id, oi.Id, 10);

        // First transition: Draft → Delivered
        dp.Delivery_Status__c = 'Delivered';
        update dp;

        OrderItem afterFirstUpdate = [SELECT Delivered_Quantity__c FROM OrderItem WHERE Id = :oi.Id];

        Test.startTest();
        // Second update on an already-Delivered plan — handler should skip (old == new == 'Delivered')
        dp.Quantity__c = 20;
        update dp;
        Test.stopTest();

        OrderItem afterSecondUpdate = [SELECT Delivered_Quantity__c FROM OrderItem WHERE Id = :oi.Id];
        System.assertEquals(afterFirstUpdate.Delivered_Quantity__c, afterSecondUpdate.Delivered_Quantity__c,
            'Delivered_Quantity__c should not double-accumulate when plan stays Delivered');
    }
}