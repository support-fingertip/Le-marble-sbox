public class QuoteTriggerHandler {

    public static void beforeInsert(List<Quote> newQuotes) {
        populateEmailFromAccount(newQuotes);
    }

    private static void populateEmailFromAccount(List<Quote> newQuotes) {

        Set<Id> oppIds = new Set<Id>();

        for (Quote q : newQuotes) {
            if (q.OpportunityId != null && q.Email == null) {
                oppIds.add(q.OpportunityId);
            }
        }

        if (oppIds.isEmpty()) return;

        Map<Id, Opportunity> oppMap = new Map<Id, Opportunity>(
            [SELECT Id, Account.Email__c FROM Opportunity WHERE Id IN :oppIds]
        );

        for (Quote q : newQuotes) {
            Opportunity opp = oppMap.get(q.OpportunityId);
            if (opp?.Account?.Email__c != null) {
                q.Email = opp.Account.Email__c;
            }
        }
    }
  

}