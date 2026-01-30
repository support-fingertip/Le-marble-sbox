public class QuoteLineItem_Handler {
//Update the oppo line items with quote fields
 /*   public static void afterInsertMethod(List<QuoteLineItem> newList) {
	System.debug('afterInsertMethod ');
        Map<Id, QuoteLineItem> qliByOliId = new Map<Id, QuoteLineItem>();
        for (QuoteLineItem qli : newList) {
            System.debug('qli.OpportunityItemId__c '+qli.OpportunityItemId__c);
            if (qli.OpportunityItemId__c != null) {
                qliByOliId.put(qli.OpportunityItemId__c, qli);
            }
        }

        if (qliByOliId.isEmpty()) return;

        List<OpportunityLineItem> olis = [
            SELECT Id, Area__c,MSP__c,Disc_Type__c
            FROM OpportunityLineItem
            WHERE Id IN :qliByOliId.keySet()
        ];
List<OpportunityLineItem> olist= new List<OpportunityLineItem>();
        for (OpportunityLineItem oli : olis) {
            QuoteLineItem qli = qliByOliId.get(oli.Id);
            oli.Area__c = qli.Area__c;
             oli.MSP__c = qli.MSP__c;
            oli.Disc_Type__c = qli.Disc_Type__c;
            oli.Dis_Value__c = qli.Dis_Value__c;
            olist.add(oli);
        }
  System.debug('.olist '+olist);
        if (!olist.isEmpty()) {
            update olist;
        }
    }*/
}