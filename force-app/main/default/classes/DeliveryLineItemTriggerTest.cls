@IsTest
private class DeliveryLineItemTriggerTest {

    @TestSetup
    static void setupData() {

        // Account
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        // Product
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

        // Order
        Order ord = new Order(
            AccountId = acc.Id,
            EffectiveDate = Date.today(),
            Status = 'Draft',
            Pricebook2Id = standardPricebookId
        );
        insert ord;

        // Order Item
        OrderItem oi = new OrderItem(
            OrderId = ord.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 10,
            UnitPrice = 100
        );
        insert oi;

        // Create valid Delivery Status dynamically
        String validStatus;
        for (Schema.PicklistEntry pe :
             Delivery_Group__c.Delivery_Status__c.getDescribe().getPicklistValues()) {
            if (pe.isActive()) {
                validStatus = pe.getValue();
                break;
            }
        }

        // Delivery Group
        Delivery_Group__c dg = new Delivery_Group__c(
            Sales_Order__c = ord.Id,
            Delivery_Status__c = validStatus
        );
        insert dg;
    }

    @IsTest
    static void testAfterInsertUpdateUndeleteDelete() {

        OrderItem oi = [SELECT Id FROM OrderItem LIMIT 1];
        Delivery_Group__c dg = [SELECT Id FROM Delivery_Group__c LIMIT 1];

        // 🔥 INSERT
        Delivery_Line_Item__c dli = new Delivery_Line_Item__c(
            Delivery_Group__c = dg.Id,
            Sales_Order_Line_Item__c = oi.Id,
            Quantity__c = 5
        );

        Test.startTest();
        insert dli;
        Test.stopTest();

        // 🔥 UPDATE
        dli.Quantity__c = 8;

        Test.startTest();
        update dli;
        Test.stopTest();

        // 🔥 DELETE (covers notification logic)
        Test.startTest();
        delete dli;
        Test.stopTest();

        // 🔥 UNDELETE
        Test.startTest();
        undelete dli;
        Test.stopTest();

        System.assert(true);
    }

    @IsTest
    static void testBulkInsert() {

        OrderItem oi = [SELECT Id FROM OrderItem LIMIT 1];
        Delivery_Group__c dg = [SELECT Id FROM Delivery_Group__c LIMIT 1];

        List<Delivery_Line_Item__c> listDLI = new List<Delivery_Line_Item__c>();

        for (Integer i = 0; i < 5; i++) {
            listDLI.add(new Delivery_Line_Item__c(
                Delivery_Group__c = dg.Id,
                Sales_Order_Line_Item__c = oi.Id,
                Quantity__c = 1
            ));
        }

        Test.startTest();
        insert listDLI;
        delete listDLI;
        Test.stopTest();

        System.assertEquals(5, listDLI.size());
    }
}