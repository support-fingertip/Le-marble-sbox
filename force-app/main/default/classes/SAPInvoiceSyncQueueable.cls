public class SAPInvoiceSyncQueueable implements Queueable {
    public void execute(QueueableContext context) {
        SAPInvoiceSync.fetchInvoicesData();
    }
}