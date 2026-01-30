public class SAPAccountSyncQueue implements Queueable, Database.AllowsCallouts {

    private Id accountId;

    public SAPAccountSyncQueue(Id accId) {
        this.accountId = accId;
    }

    public void execute(QueueableContext qc) {
        Account acc = [
            SELECT Id, Name//, Customer_Status__c, ERP_Check__c
            FROM Account
            WHERE Id = :accountId
        ];

        sapIntegration.updateBusinessPartner(acc.id);
    }
}