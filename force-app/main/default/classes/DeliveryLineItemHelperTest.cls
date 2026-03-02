@IsTest
private class DeliveryLineItemHelperTest {

    @TestSetup
    static void setupData() {

        Account acc = new Account(Name = 'Test Account');
        insert acc;

        Product2 prod = new Product2(
            Name = 'Test Product',
            IsActive = true
        );
        insert prod;

        Id standardPricebookId = Test.getStandardPricebookId();

        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = standardPricebookId,
            Product2Id = prod.Id,
            UnitPrice = 100,
            IsActive = true
        );
        insert pbe;

        Order ord = new Order(
            AccountId = acc.Id,
            EffectiveDate = Date.today(),
            Status = 'Draft',
            Pricebook2Id = standardPricebookId
        );
        insert ord;

        List<OrderItem> orderItems = new List<OrderItem>{
            new OrderItem(
                OrderId = ord.Id,
                PricebookEntryId = pbe.Id,
                Quantity = 10,
                UnitPrice = 100
            ),
            new OrderItem(
                OrderId = ord.Id,
                PricebookEntryId = pbe.Id,
                Quantity = 20,
                UnitPrice = 100
            ),
            new OrderItem(
                OrderId = ord.Id,
                PricebookEntryId = pbe.Id,
                Quantity = 5,
                UnitPrice = 100
            )
        };
        insert orderItems;

        // 🔥 Dynamically get valid picklist value
        String validStatus;
        Schema.DescribeFieldResult fieldResult =
            Delivery_Group__c.Delivery_Status__c.getDescribe();

        for (Schema.PicklistEntry pe : fieldResult.getPicklistValues()) {
            if (pe.isActive()) {
                validStatus = pe.getValue();
                break;
            }
        }

        // Delivery Group with valid picklist value
        Delivery_Group__c dg = new Delivery_Group__c(
            Sales_Order__c = ord.Id,
            Delivery_Status__c = validStatus
        );
        insert dg;

        List<Delivery_Line_Item__c> deliveries = new List<Delivery_Line_Item__c>{
            new Delivery_Line_Item__c(
                Delivery_Group__c = dg.Id,
                Sales_Order_Line_Item__c = orderItems[0].Id,
                Quantity__c = 10
            ),
            new Delivery_Line_Item__c(
                Delivery_Group__c = dg.Id,
                Sales_Order_Line_Item__c = orderItems[1].Id,
                Quantity__c = 5
            ),
            new Delivery_Line_Item__c(
                Delivery_Group__c = dg.Id,
                Sales_Order_Line_Item__c = orderItems[2].Id,
                Quantity__c = 7
            )
        };
        insert deliveries;
    }

    @IsTest
    static void testRollupLogic() {

        Set<Id> orderItemIds = new Set<Id>();
        for (OrderItem oi : [SELECT Id FROM OrderItem]) {
            orderItemIds.add(oi.Id);
        }

        Test.startTest();
        DeliveryLineItemHelper.updateOrderProductRollups(orderItemIds);
        Test.stopTest();

        List<OrderItem> results = [
            SELECT Quantity,
                   Delivered_Quantity__c,
                   Pending_Quantity__c,
                   Delivery_Status__c
            FROM OrderItem
        ];

        for (OrderItem oi : results) {

            if (oi.Quantity == 10) {
                System.assertEquals(10, oi.Delivered_Quantity__c);
                System.assertEquals(0, oi.Pending_Quantity__c);
                System.assertEquals('Delivered', oi.Delivery_Status__c);
            }

            if (oi.Quantity == 20) {
                System.assertEquals(5, oi.Delivered_Quantity__c);
                System.assertEquals(15, oi.Pending_Quantity__c);
                System.assertEquals('Partial', oi.Delivery_Status__c);
            }

            if (oi.Quantity == 5) {
                System.assertEquals(7, oi.Delivered_Quantity__c);
                System.assertEquals(0, oi.Pending_Quantity__c);
                System.assertEquals('Delivered', oi.Delivery_Status__c);
            }
        }
    }

    @IsTest
    static void testNullAndEmptyInput() {
        Test.startTest();
        DeliveryLineItemHelper.updateOrderProductRollups(null);
        DeliveryLineItemHelper.updateOrderProductRollups(new Set<Id>());
        Test.stopTest();
        System.assert(true);
    }
}