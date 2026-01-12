public class SAPOrderQueueable implements Queueable, Database.AllowsCallouts {
    private List<Sales_Confirmation__c> orders;
    
    public SAPOrderQueueable(List<Sales_Confirmation__c> orders) {
        this.orders = orders;
    }
    
    public void execute(QueueableContext context) {
        SAPOrderService.createSAPOrders(orders);
    }
}