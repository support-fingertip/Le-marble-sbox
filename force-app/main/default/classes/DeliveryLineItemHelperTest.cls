@isTest
public class DeliveryLineItemHelperTest {


@isTest
static void testUpdateOrderProductRollups() {

    Account acc = new Account(
        Name = 'Test Account',
        BillingStreet = 'Test Street',
        BillingCity = 'Patna',
        BillingState = 'Bihar',
        BillingPostalCode = '800001',
        BillingCountry = 'India',
        District__c = 'Patna',
        Pin_Code__c = 800001
    );
    insert acc;

    Id standardPricebookId = Test.getStandardPricebookId();

    Product2 prod = new Product2(
        Name = 'Test Product',
        IsActive = true
    );
    insert prod;

    PricebookEntry pbe = new PricebookEntry(
        Pricebook2Id = standardPricebookId,
        Product2Id = prod.Id,
        UnitPrice = 100,
        IsActive = true
    );
    insert pbe;

    Order ord = new Order(
        AccountId = acc.Id,
        Status = 'Draft',
        EffectiveDate = Date.today(),
        Pricebook2Id = standardPricebookId
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
        Delivery_Status__c = 'Draft'
    );
    insert dg;

    Delivery_Line_Item__c d1 = new Delivery_Line_Item__c(
        Sales_Order_Line_Item__c = oi.Id,
        Quantity__c = 4,
        Delivery_Group__c = dg.Id
    );

    Delivery_Line_Item__c d2 = new Delivery_Line_Item__c(
        Sales_Order_Line_Item__c = oi.Id,
        Quantity__c = 3,
        Delivery_Group__c = dg.Id
    );

    insert new List<Delivery_Line_Item__c>{d1, d2};

    Test.startTest();
    DeliveryLineItemHelper.updateOrderProductRollups(new Set<Id>{oi.Id});
    Test.stopTest();

    OrderItem updatedOI = [
        SELECT Delivered_Quantity__c,
               Pending_Quantity__c,
               Delivery_Status__c
        FROM OrderItem
        WHERE Id = :oi.Id
    ];

    System.assertEquals(7, updatedOI.Delivered_Quantity__c);
    System.assertEquals(3, updatedOI.Pending_Quantity__c);
    System.assertEquals('Partial', updatedOI.Delivery_Status__c);
}


}