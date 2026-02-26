@IsTest
private class NewDeliveryPlanControllerTest {
    private static Order buildApprovedOrder() {
        Account acc = new Account(Name = 'NDP Account');
        insert acc;

        Id stdPbId = Test.getStandardPricebookId();
        Order ord = new Order(
            AccountId = acc.Id,
            EffectiveDate = Date.today(),
            Status = 'Draft',
            Pricebook2Id = stdPbId,
            Freight_Charge__c = 50,
            Loading_Charges__c = 10,
            Unloading_Charges__c = 5,
            Remarks__c = 'NDP Remarks'
        );
        SalesOrderTriggerHandler.isRunning = true;
        insert ord;
        SalesOrderTriggerHandler.isRunning = false;

        Product2 prod = new Product2(Name = 'NDP Product', IsActive = true);
        insert prod;

        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = stdPbId,
            Product2Id = prod.Id,
            UnitPrice = 100,
            IsActive = true
        );
        insert pbe;

        OrderItem oi = new OrderItem(
            OrderId = ord.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 5,
            UnitPrice = 100
        );
        insert oi;

        Delivery_Group__c dg = new Delivery_Group__c(
            Sales_Order__c = ord.Id,
            Quantity__c = 1,
            Delivery_Status__c = 'Draft',
            Approval_Status__c = 'Draft'
        );
        insert dg;

        Delivery_Line_Item__c dli = new Delivery_Line_Item__c(
            Delivery_Group__c = dg.Id,
            Sales_Order_Line_Item__c = oi.Id,
            Quantity__c = 2
        );
        insert dli;

        return ord;
    }

    @IsTest
    static void testSearchAndAvailableProducts() {
        Order ord = buildApprovedOrder();

        Test.startTest();
        List<Order> orders = NewDeliveryPlanController.searchSalesOrders('');
        List<OrderItem> available = NewDeliveryPlanController.getAvailableProducts(ord.Id);
        Test.stopTest();

        System.assertNotEquals(null, orders);
        System.assertNotEquals(null, available);
        System.assert(available.size() > 0, 'Expected at least one order item with pending quantity.');
    }

    @IsTest
    static void testPicklistAndOrderFieldHelpers() {
        Order ord = buildApprovedOrder();

        Test.startTest();
        List<User> drivers = NewDeliveryPlanController.getDrivers();
        List<String> vehicleTypes = NewDeliveryPlanController.getVehicleTypeOptions();
        List<String> driverOptions = NewDeliveryPlanController.getDriverPicklistOptions();
        List<String> vehicleNumbers = NewDeliveryPlanController.getVehicleNumberOptions();
        Decimal freight = NewDeliveryPlanController.getSalesOrderFreight(ord.Id);
        Decimal loading = NewDeliveryPlanController.getSalesOrderLoading(ord.Id);
        Decimal unloading = NewDeliveryPlanController.getSalesOrderUnloading(ord.Id);
        String remarks = NewDeliveryPlanController.getSalesOrderRemarks(ord.Id);
        Test.stopTest();

        System.assertNotEquals(null, drivers);
        System.assertNotEquals(null, vehicleTypes);
        System.assertNotEquals(null, driverOptions);
        System.assertNotEquals(null, vehicleNumbers);
        System.assertEquals(50, freight);
        System.assertEquals(10, loading);
        System.assertEquals(5, unloading);
        System.assertEquals('NDP Remarks', remarks);
    }
}