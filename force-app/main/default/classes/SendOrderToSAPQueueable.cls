public class SendOrderToSAPQueueable implements Queueable, Database.AllowsCallouts {
     private Id orderId;
/* calling from SalesOrderContactTrigger
 * 
 * */
    // Constructor
    public SendOrderToSAPQueueable(Id orderId) {
        this.orderId = orderId;
    }
public void execute(QueueableContext context) {
system.debug('SendOrderToSAPQueueable  '+this.orderId);
    Order ord = [
        SELECT Id, Status, SAP_Doc_Num__c
        FROM Order
        WHERE Id = :orderId
    ];
system.debug('ord  '+ord);
  /*  if (ord.SAP_Doc_Num__c==null || ord.Status != 'Approved') {
        return;
    }*/

    sapIntegration.sendOrderToSAP(orderId);

 //   ord.Sent_To_SAP__c = true;
   // update ord;
}

}