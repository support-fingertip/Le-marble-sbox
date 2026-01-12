@IsTest
public class QuoteLineItem_HandlerTest {

    @IsTest
    static void testAfterInsertMethod() {

        Account acc = new Account(Name = 'Test Account');
        insert acc;

        Opportunity opp = new Opportunity(
            Name = 'Test Opp',
            StageName = 'Prospecting',
            CloseDate = Date.today(),
            AccountId = acc.Id
        );
        insert opp;

       
        Id standardPbId = Test.getStandardPricebookId();

        Product2 prod = new Product2(
            Name = 'Test Product',
            IsActive = true
        );
        insert prod;

        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = standardPbId,
            Product2Id = prod.Id,
            UnitPrice = 100,
            IsActive = true
        );
        insert pbe;

        OpportunityLineItem oli = new OpportunityLineItem(
            OpportunityId = opp.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 1,
            TotalPrice = 100
        );
        insert oli;

        Quote q = new Quote(
            Name = 'Test Quote',
            OpportunityId = opp.Id,
            Pricebook2Id = standardPbId
        );
        insert q;

        QuoteLineItem qli = new QuoteLineItem(
            QuoteId = q.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 1,
            UnitPrice = 100,
            OpportunityLineItemId = oli.Id,
            Area__c = 'North',
            MSP__c = 50
        );

        Test.startTest();
        insert qli;
        Test.stopTest();

        OpportunityLineItem updatedOli = [
            SELECT Area__c, MSP__c
            FROM OpportunityLineItem
            WHERE Id = :oli.Id
        ];

        System.assertEquals('North', updatedOli.Area__c);
        System.assertEquals(50, updatedOli.MSP__c);
    }
}