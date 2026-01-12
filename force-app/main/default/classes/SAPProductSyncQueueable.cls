public class SAPProductSyncQueueable implements Queueable, Database.AllowsCallouts {
    public void execute(QueueableContext context) {
        SAPProductSyncJob.runSync(); // Reuse your existing static method
    }
}