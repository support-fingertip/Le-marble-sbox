public class GetPaymentsQueueable implements Queueable, Database.AllowsCallouts {
    public void execute(QueueableContext context) {
        sapIntegration.getPayments();
    }
    
    // not using 
}