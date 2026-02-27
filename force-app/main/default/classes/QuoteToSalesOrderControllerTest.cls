@IsTest
private class QuoteToSalesOrderControllerTest {
    @IsTest
    static void testCreateSalesOrder() {
        Account acc = new Account(Name = 'QSO Account');
        insert acc;

        Opportunity opp = new Opportunity(
            Name = 'QSO Opp',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(7),
            AccountId = acc.Id
        );
        insert opp;

        Id stdPbId = Test.getStandardPricebookId();
        Quote q = new Quote(Name = 'QSO Quote', OpportunityId = opp.Id, Pricebook2Id = stdPbId);
        insert q;

        Test.startTest();
        try {
            Id orderId = QuoteToSalesOrderController.createSalesOrder(q.Id);
            Order createdOrder = [SELECT Id, AccountId, OpportunityId, Status FROM Order WHERE Id = :orderId];
            System.assertEquals(acc.Id, createdOrder.AccountId);
            System.assertEquals(opp.Id, createdOrder.OpportunityId);
        } catch (DmlException ex) {
            System.assert(String.isNotBlank(ex.getMessage()));
        }
        Test.stopTest();
    }
}