@IsTest
public class SalesOrderTriggerHandlerTest {

    @TestSetup
    static void buildTestData() {
        Account acc = new Account(Name = 'SO Test Account');
        insert acc;

        Opportunity opp = new Opportunity(
            Name      = 'SO Test Opp',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            AccountId = acc.Id
        );
        insert opp;

        Id stdPbId = Test.getStandardPricebookId();

        Product2 prod = new Product2(Name = 'SO Test Product', IsActive = true);
        insert prod;

        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = stdPbId,
            Product2Id   = prod.Id,
            UnitPrice    = 100,
            IsActive     = true
        );
        insert pbe;

        Quote q = new Quote(
            Name          = 'SO Test Quote',
            OpportunityId = opp.Id,
            Pricebook2Id  = stdPbId,
            Sales_Order_Created__c = true
        );
        insert q;

        QuoteLineItem qli = new QuoteLineItem(
            QuoteId          = q.Id,
            PricebookEntryId = pbe.Id,
            Quantity         = 10,
            UnitPrice        = 100,
            Order_Created__c = true
        );
        insert qli;

        // Create Order linked to the Quote
        Order ord = new Order(
            AccountId     = acc.Id,
            EffectiveDate = Date.today(),
            Status        = 'Draft',
            Pricebook2Id  = stdPbId,
            QuoteId       = q.Id
        );
        SalesOrderTriggerHandler.isRunning = true;
        insert ord;
        SalesOrderTriggerHandler.isRunning = false;

        OrderItem oi = new OrderItem(
            OrderId          = ord.Id,
            PricebookEntryId = pbe.Id,
            Quantity         = 10,
            UnitPrice        = 100,
            QuoteLineItemId  = qli.Id
        );
        insert oi;
    }

    // ── isRunning flag tests ──

    @IsTest
    static void testIsRunningFlag() {
        System.assertEquals(false, SalesOrderTriggerHandler.isRunning,
            'isRunning should default to false');

        SalesOrderTriggerHandler.isRunning = true;
        System.assertEquals(true, SalesOrderTriggerHandler.isRunning,
            'isRunning should be true after setting');

        SalesOrderTriggerHandler.isRunning = false;
        System.assertEquals(false, SalesOrderTriggerHandler.isRunning,
            'isRunning should be false after resetting');
    }

    @IsTest
    static void testClassInstantiation() {
        SalesOrderTriggerHandler handler = new SalesOrderTriggerHandler();
        System.assertNotEquals(null, handler, 'Handler should be instantiated');
    }

    // ── resetQuoteLineItemsOnOrderDelete tests ──

    @IsTest
    static void testResetQuoteLineItemsOnOrderDelete() {
        Order ord = [SELECT Id, QuoteId FROM Order LIMIT 1];
        QuoteLineItem qli = [SELECT Id, Order_Created__c FROM QuoteLineItem LIMIT 1];
        Quote q = [SELECT Id, Sales_Order_Created__c FROM Quote WHERE Id = :ord.QuoteId];

        // Verify preconditions
        System.assertEquals(true, qli.Order_Created__c,
            'QuoteLineItem should start with Order_Created__c = true');
        System.assertEquals(true, q.Sales_Order_Created__c,
            'Quote should start with Sales_Order_Created__c = true');

        Test.startTest();
        SalesOrderTriggerHandler.resetQuoteLineItemsOnOrderDelete(
            new List<Order>{ ord }
        );
        Test.stopTest();

        // QuoteLineItem flag should be reset
        qli = [SELECT Id, Order_Created__c FROM QuoteLineItem WHERE Id = :qli.Id];
        System.assertEquals(false, qli.Order_Created__c,
            'Order_Created__c should be reset to false after order delete');

        // Quote flag should be reset
        q = [SELECT Id, Sales_Order_Created__c FROM Quote WHERE Id = :q.Id];
        System.assertEquals(false, q.Sales_Order_Created__c,
            'Sales_Order_Created__c should be reset to false after order delete');
    }

    @IsTest
    static void testResetWithOrderHavingNoQuote() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Id stdPbId = Test.getStandardPricebookId();

        // Order without a Quote
        Order ordNoQuote = new Order(
            AccountId     = acc.Id,
            EffectiveDate = Date.today(),
            Status        = 'Draft',
            Pricebook2Id  = stdPbId
        );
        SalesOrderTriggerHandler.isRunning = true;
        insert ordNoQuote;
        SalesOrderTriggerHandler.isRunning = false;

        Test.startTest();
        SalesOrderTriggerHandler.resetQuoteLineItemsOnOrderDelete(
            new List<Order>{ ordNoQuote }
        );
        Test.stopTest();

        // Original Quote/QLI should remain unchanged
        QuoteLineItem qli = [SELECT Id, Order_Created__c FROM QuoteLineItem LIMIT 1];
        System.assertEquals(true, qli.Order_Created__c,
            'QuoteLineItem flag should remain unchanged for unrelated order');
    }

    @IsTest
    static void testResetWithEmptyOrderList() {
        Test.startTest();
        SalesOrderTriggerHandler.resetQuoteLineItemsOnOrderDelete(
            new List<Order>()
        );
        Test.stopTest();

        // Nothing should change — no exceptions thrown
        QuoteLineItem qli = [SELECT Id, Order_Created__c FROM QuoteLineItem LIMIT 1];
        System.assertEquals(true, qli.Order_Created__c,
            'QuoteLineItem flag should remain unchanged for empty list');
    }

    @IsTest
    static void testResetWithMultipleOrders() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Id stdPbId = Test.getStandardPricebookId();
        PricebookEntry pbe = [SELECT Id FROM PricebookEntry LIMIT 1];

        // Create a second Quote + QLI + Order + OrderItem
        Quote q2 = new Quote(
            Name          = 'SO Test Quote 2',
            OpportunityId = opp.Id,
            Pricebook2Id  = stdPbId,
            Sales_Order_Created__c = true
        );
        insert q2;

        QuoteLineItem qli2 = new QuoteLineItem(
            QuoteId          = q2.Id,
            PricebookEntryId = pbe.Id,
            Quantity         = 5,
            UnitPrice        = 200,
            Order_Created__c = true
        );
        insert qli2;

        Order ord2 = new Order(
            AccountId     = acc.Id,
            EffectiveDate = Date.today(),
            Status        = 'Draft',
            Pricebook2Id  = stdPbId,
            QuoteId       = q2.Id
        );
        SalesOrderTriggerHandler.isRunning = true;
        insert ord2;
        SalesOrderTriggerHandler.isRunning = false;

        OrderItem oi2 = new OrderItem(
            OrderId          = ord2.Id,
            PricebookEntryId = pbe.Id,
            Quantity         = 5,
            UnitPrice        = 200,
            QuoteLineItemId  = qli2.Id
        );
        insert oi2;

        // Grab both orders
        Order ord1 = [SELECT Id, QuoteId FROM Order WHERE QuoteId != :q2.Id LIMIT 1];

        Test.startTest();
        SalesOrderTriggerHandler.resetQuoteLineItemsOnOrderDelete(
            new List<Order>{ ord1, ord2 }
        );
        Test.stopTest();

        // Both QuoteLineItems should be reset
        for (QuoteLineItem qli : [
            SELECT Id, Order_Created__c FROM QuoteLineItem
        ]) {
            System.assertEquals(false, qli.Order_Created__c,
                'All QuoteLineItem flags should be reset');
        }

        // Both Quotes should be reset
        for (Quote q : [
            SELECT Id, Sales_Order_Created__c FROM Quote
        ]) {
            System.assertEquals(false, q.Sales_Order_Created__c,
                'All Quote flags should be reset');
        }
    }
}
