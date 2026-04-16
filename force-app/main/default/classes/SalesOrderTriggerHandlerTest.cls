@IsTest
public class SalesOrderTriggerHandlerTest {

    @IsTest
    static void testResetQuoteLineItemsOnOrderDelete() {

        // Create Account
        Account acc = new Account(
    Name = 'Test Account',
    BillingCountry = 'India',
    BillingState = 'KA',
    BillingCity = 'Bangalore',
    BillingPostalCode = '560001',
    BillingStreet = 'Test Street',
    District__c = '	Ernakulam',
    Pin_Code__c = 766562
);
        insert acc;

        // Create Opportunity
        Opportunity opp = new Opportunity(
            Name = 'Test Opp',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(10),
            AccountId = acc.Id,
            State__c = 'PB',
            Pin_Code__c = 766562

            
        );
        insert opp;

        // Get Standard Pricebook
        Id pricebookId = Test.getStandardPricebookId();

        // Create Quote
        Quote q = new Quote(
            Name = 'Test Quote',
            OpportunityId = opp.Id,
            Pricebook2Id = pricebookId,
            Sales_Order_Created__c = true,
            Status = 'Draft'
        );
        insert q;

        // Create Product
        Product2 prod = new Product2(
            Name = 'Test Product',
            IsActive = true
        );
        insert prod;

        // Create PricebookEntry
        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = pricebookId,
            Product2Id = prod.Id,
            UnitPrice = 100,
            IsActive = true,
            UseStandardPrice = false
        );
        insert pbe;

        // Create QuoteLineItem
        QuoteLineItem qli = new QuoteLineItem(
            QuoteId = q.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 1,
            UnitPrice = 100,
            Order_Created__c = true
        );
        insert qli;

        // Create Order
        Order ord = new Order(
            Name = 'Test Order',
            AccountId = acc.Id,
            EffectiveDate = Date.today(),
            Status = 'Draft',
            QuoteId = q.Id,
             Pricebook2Id = pricebookId
        );
        insert ord;

        // Create OrderItem linked to QuoteLineItem
        OrderItem oi = new OrderItem(
            OrderId = ord.Id,
            Quantity = 1,
            UnitPrice = 100,
            PricebookEntryId = pbe.Id,
            QuoteLineItemId = qli.Id
            
        );
        insert oi;

        Test.startTest();

        // Simulate order delete trigger call
        SalesOrderTriggerHandler.resetQuoteLineItemsOnOrderDelete(
            new List<Order>{ord}
        );

        Test.stopTest();

        // Reload records
        qli = [SELECT Order_Created__c FROM QuoteLineItem WHERE Id = :qli.Id];
        q = [SELECT Sales_Order_Created__c, Status FROM Quote WHERE Id = :q.Id];

        // Assertions
        System.assertEquals(false, qli.Order_Created__c);
        System.assertEquals(false, q.Sales_Order_Created__c);
        System.assertEquals('Presented', q.Status);
    }
}