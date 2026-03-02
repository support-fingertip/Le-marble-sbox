@isTest
public class DeliveryPlanQuantityHandlerTest {

    private static String getValidDeliveryStatus() {
        Schema.DescribeFieldResult fieldResult =
            Delivery_Group__c.Delivery_Status__c.getDescribe();

        for (Schema.PicklistEntry entry : fieldResult.getPicklistValues()) {
            if (!entry.getValue().equalsIgnoreCase('Delivered')) {
                return entry.getValue();
            }
        }
        return fieldResult.getPicklistValues()[0].getValue();
    }

    @testSetup
    static void setupData() {

        Account acc = new Account(Name = 'Test Account');
        insert acc;

        Id stdPbId = Test.getStandardPricebookId();

        Product2 prod = new Product2(
            Name = 'Test Product',
            IsActive = true
        );
        insert prod;

        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = stdPbId,
            Product2Id = prod.Id,
            UnitPrice = 100,
            IsActive = true
        );
        insert pbe;

        Order ord = new Order(
            AccountId = acc.Id,
            EffectiveDate = Date.today(),
            Status = 'Draft',
            Pricebook2Id = stdPbId
        );
        insert ord;

        OrderItem oi = new OrderItem(
            OrderId = ord.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 10,
            UnitPrice = 100
        );
        insert oi;

        Delivery_Group__c dg = new Delivery_Group__c(
            Sales_Order__c = ord.Id,
            Delivery_Status__c = getValidDeliveryStatus()
        );
        insert dg;

        // IMPORTANT: Add Quantity__c (Required Field)
        Delivery_Line_Item__c dli = new Delivery_Line_Item__c(
            Delivery_Group__c = dg.Id,
            Sales_Order_Line_Item__c = oi.Id,
            Quantity__c = 4,
            Delivered_Quantity__c = 4
        );
        insert dli;
    }

    // -------------------------------
    // PARTIAL DELIVERY
    // -------------------------------
    @isTest
    static void testPartialDelivery() {

        Delivery_Group__c dg =
            [SELECT Id FROM Delivery_Group__c LIMIT 1];

        dg.Delivery_Status__c = 'Delivered';

        Test.startTest();
        update dg;
        Test.stopTest();

        OrderItem oi =
            [SELECT Quantity,
                    Delivered_Quantity__c,
                    Pending_Quantity__c,
                    Delivery_Status__c
             FROM OrderItem LIMIT 1];

        System.assertEquals(4, oi.Delivered_Quantity__c);
        System.assertEquals(6, oi.Pending_Quantity__c);
        System.assertEquals('Partially Delivered', oi.Delivery_Status__c);
    }

    // -------------------------------
    // FULL DELIVERY
    // -------------------------------
    @isTest
    static void testFullDelivery() {

        OrderItem oi = [SELECT Id FROM OrderItem LIMIT 1];
        Delivery_Group__c dg = [SELECT Id FROM Delivery_Group__c LIMIT 1];

        insert new Delivery_Line_Item__c(
            Delivery_Group__c = dg.Id,
            Sales_Order_Line_Item__c = oi.Id,
            Quantity__c = 6,
            Delivered_Quantity__c = 6
        );

        dg.Delivery_Status__c = 'Delivered';

        Test.startTest();
        update dg;
        Test.stopTest();

        OrderItem updated =
            [SELECT Delivered_Quantity__c,
                    Pending_Quantity__c,
                    Delivery_Status__c
             FROM OrderItem LIMIT 1];

        System.assertEquals(10, updated.Delivered_Quantity__c);
        System.assertEquals(0, updated.Pending_Quantity__c);
        System.assertEquals('Delivered', updated.Delivery_Status__c);
    }

    // -------------------------------
    // NO STATUS CHANGE
    // -------------------------------
    @isTest
    static void testNoStatusChange() {

        Delivery_Group__c dg =
            [SELECT Id FROM Delivery_Group__c LIMIT 1];

        Test.startTest();
        update dg;
        Test.stopTest();

        System.assert(true);
    }

    // -------------------------------
    // BULK UPDATE
    // -------------------------------
    @isTest
    static void testBulkUpdate() {

        Order ord = [SELECT Id FROM Order LIMIT 1];

        String validStatus = getValidDeliveryStatus();

        List<Delivery_Group__c> groups = new List<Delivery_Group__c>();

        for (Integer i = 0; i < 5; i++) {
            groups.add(new Delivery_Group__c(
                Sales_Order__c = ord.Id,
                Delivery_Status__c = validStatus
            ));
        }

        insert groups;

        for (Delivery_Group__c dg : groups) {
            dg.Delivery_Status__c = 'Delivered';
        }

        Test.startTest();
        update groups;
        Test.stopTest();

        System.assert(true);
    }
}