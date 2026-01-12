public class QuoteLineItem_Handler {
//Update the oppo line items with quote fields
    public static void afterInsertMethod(List<QuoteLineItem> newList) {

        Map<Id, QuoteLineItem> qliByOliId = new Map<Id, QuoteLineItem>();
        for (QuoteLineItem qli : newList) {
            if (qli.OpportunityLineItemId != null) {
                qliByOliId.put(qli.OpportunityLineItemId, qli);
            }
        }

        if (qliByOliId.isEmpty()) return;

        List<OpportunityLineItem> olis = [
            SELECT Id, Area__c,MSP__c,Disc_Type__c
            FROM OpportunityLineItem
            WHERE Id IN :qliByOliId.keySet()
        ];

        for (OpportunityLineItem oli : olis) {
            QuoteLineItem qli = qliByOliId.get(oli.Id);
            oli.Area__c = qli.Area__c;
             oli.MSP__c = qli.MSP__c;
           // oli.Disc_Type__c = qli.Disc_Type__c;
        }

        if (!olis.isEmpty()) {
            update olis;
        }
    }
}