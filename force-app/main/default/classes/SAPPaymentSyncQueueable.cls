public class SAPPaymentSyncQueueable implements Queueable {
    public void execute(QueueableContext context) {
        SAPPaymentSync.fetchDownPaymentsData();
        SAPPaymentSync.fetchIncomingPaymentsData();
    }
}