public with sharing class QuoteToSalesOrderController {

    @AuraEnabled
    public static Id createSalesOrder(Id quoteId) {

     
        Quote q = [
            SELECT Id, Name, AccountId, OpportunityId
            FROM Quote
            WHERE Id = :quoteId
            LIMIT 1
        ];

    
        Order so = new Order();
        so.Name = 'SO - ' + q.Name;
        so.AccountId = q.AccountId;
        so.OpportunityId = q.OpportunityId;

 
        so.EffectiveDate = Date.today();
        so.Status = 'Draft';

        insert so;


        return so.Id;
    }
}