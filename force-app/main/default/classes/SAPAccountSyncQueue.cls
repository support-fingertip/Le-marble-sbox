public class SAPAccountSyncQueue implements Queueable, Database.AllowsCallouts {

    private Id accountId;
    private boolean iscreation;

    public SAPAccountSyncQueue(Id accId,boolean isNew) {
        this.accountId = accId;
        this.iscreation = isNew;
    }

    public void execute(QueueableContext qc) {
        Account acc = [
            SELECT Id, Name//, Customer_Status__c, ERP_Check__c
            FROM Account
            WHERE Id = :accountId
        ];

        sapIntegration.createBusinessPartner(acc.id);//iscreation
    }
}