public class SyncQuoteToOppQueueable implements Queueable {
    private Map<Id, Id> oppToQuoteMap;

    public SyncQuoteToOppQueueable(Map<Id, Id> oppToQuoteMap) {
        this.oppToQuoteMap = oppToQuoteMap;
    }
	
    public void execute(QueueableContext context) {
        List<Opportunity> oppsToUpdate = new List<Opportunity>();
        for (Id oppId : oppToQuoteMap.keySet()) {
            oppsToUpdate.add(new Opportunity(
                Id = oppId,
                SyncedQuoteId = oppToQuoteMap.get(oppId)
            ));
        }
        if (!oppsToUpdate.isEmpty()) {
            update oppsToUpdate;
        }
    }
}