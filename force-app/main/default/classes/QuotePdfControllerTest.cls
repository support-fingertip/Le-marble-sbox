@IsTest
private class QuotePdfControllerTest {
    private static Quote createQuote() {
        Account acc = new Account(Name = 'QPDF Account');
        insert acc;

        Opportunity opp = new Opportunity(
            Name = 'QPDF Opp',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(5),
            AccountId = acc.Id
        );
        insert opp;

        Id stdPbId = Test.getStandardPricebookId();
        Quote q = new Quote(Name = 'QPDF Quote', OpportunityId = opp.Id, Pricebook2Id = stdPbId);
        insert q;
        return q;
    }

    @IsTest
    static void testControllerConstructor() {
        Quote q = createQuote();

        Test.startTest();
        ApexPages.StandardController std = new ApexPages.StandardController(q);
        QuotePdfController controller = new QuotePdfController(std);
        Test.stopTest();

        System.assertNotEquals(null, controller);
        System.assertEquals(q.Id, controller.cart.Id);
        System.assertNotEquals(null, controller.products);
    }

    @IsTest
    static void testConstructorWithSelectedItemsParam() {
        Quote q = createQuote();
        ApexPages.currentPage().getParameters().put('selectedItems', '');

        Test.startTest();
        ApexPages.StandardController std = new ApexPages.StandardController(q);
        QuotePdfController controller = new QuotePdfController(std);
        Test.stopTest();

        System.assertNotEquals(null, controller);
        System.assertEquals(q.Id, controller.cart.Id);
    }
}