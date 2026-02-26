@IsTest
private class CreateSOFromQuoteControllerTest {
    private static Quote createQuoteWithLine() {
        Account acc = new Account(Name = 'CSQ Account');
        insert acc;

        Opportunity opp = new Opportunity(
            Name = 'CSQ Opportunity',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(10),
            AccountId = acc.Id
        );
        insert opp;

        Id stdPbId = Test.getStandardPricebookId();
        Product2 prod = new Product2(Name = 'CSQ Product', IsActive = true);
        insert prod;

        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = stdPbId,
            Product2Id = prod.Id,
            UnitPrice = 100,
            IsActive = true
        );
        insert pbe;

        Quote q = new Quote(
            Name = 'CSQ Quote',
            OpportunityId = opp.Id,
            Pricebook2Id = stdPbId,
            Email = 'csq@test.com'
        );
        insert q;

        QuoteLineItem qli = new QuoteLineItem(
            QuoteId = q.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 1,
            UnitPrice = 100
        );
        insert qli;

        return q;
    }

    @IsTest
    static void testQuoteInfoAndLines() {
        Quote q = createQuoteWithLine();

        Test.startTest();
        Map<String, Object> info = CreateSOFromQuoteController.getQuoteInfo(q.Id);
        List<QuoteLineItem> lines = CreateSOFromQuoteController.getQuoteLineItems(q.Id);
        List<String> paymentTypes = CreateSOFromQuoteController.getPaymentTypeOptions();
        Test.stopTest();

        System.assertNotEquals(null, info);
        System.assertEquals('csq@test.com', (String)info.get('email'));
        System.assert(lines.size() > 0, 'Expected quote line items.');
        System.assert(paymentTypes.contains('Cash'));
        System.assert(paymentTypes.contains('Credit'));
    }

    @IsTest
    static void testGetActiveWarehouses() {
        User adminUser = [SELECT Id FROM User WHERE Profile.Name = 'System Administrator' AND IsActive = true LIMIT 1];

        Warehouse__c wh = new Warehouse__c(
            Name = 'CSQ WH',
            Warehouse_Manager__c = adminUser.Id,
            Location__c = 'CSQ Loc',
            Total_Capacity__c = 100
        );
        insert wh;

        Test.startTest();
        List<Warehouse__c> rows = CreateSOFromQuoteController.getActiveWarehouses();
        Test.stopTest();

        System.assertNotEquals(null, rows);
        System.assert(rows.size() > 0);
    }
}