public with sharing class EditQuoteController {

    public class QuoteWrapper {
        @AuraEnabled public Quote quoteRecord;
        @AuraEnabled public List<QuoteLineItem> lineItems;
    }

    @AuraEnabled(cacheable=true)
    public static QuoteWrapper loadQuote(Id quoteId){

        QuoteWrapper wrapper = new QuoteWrapper();
system.debug('QuoteId received: ' + quoteId);
        wrapper.quoteRecord = [
            SELECT Id,
                   Name,
                   Freight_Charge__c,
                   Loading_Charge__c,
                   Unloading_Charge__c,
                   Round_Off__c,
                   Pricebook2Id
            FROM Quote
            WHERE Id = :quoteId
            LIMIT 1
        ];

        wrapper.lineItems = [
            SELECT Id,
                   Product2Id,
                   Product2.Name,
                   Product2.Product_Code__c,
                   Product2.Product_Category__c,
                   Product2.Tax__c,
                   Product2.Sqft_Piece__c,
                   Quantity,
                   UnitPrice,
                   Disc_Type__c,
                   Dis_Value__c,
                   Sqft__c,
                   Area__c,
                   Room_Type__c,
                   Description,
                   PricebookEntryId
            FROM QuoteLineItem
            WHERE QuoteId = :quoteId
        ];

        return wrapper;
    }

    @AuraEnabled
    public static void saveQuote(
        Quote quoteRec,
        List<QuoteLineItem> itemsToUpsert,
        List<Id> deleteIds
    ){

        update quoteRec;

        if(!itemsToUpsert.isEmpty()){
            upsert itemsToUpsert;
        }

        if(!deleteIds.isEmpty()){
            delete [SELECT Id FROM QuoteLineItem WHERE Id IN :deleteIds];
        }
    }
}