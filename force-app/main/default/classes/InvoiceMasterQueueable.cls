public class InvoiceMasterQueueable  implements Queueable, Database.AllowsCallouts {
/*
 * Created by Roopesh
 * Purpose: the invoice api runs every 55 minutes exactly
 * */
    public void execute(QueueableContext context) {

        Integration_Config__mdt cfg =
            Integration_Config__mdt.getInstance('InvoiceScheduler');

        if (cfg == null || !cfg.Enable_Invoice_Master__c) {
            System.debug('Invoice Master Sync is DISABLED');
            return;
        }

        // Re-scheduling on a 55-minute cadence is handled by InvoiceMasterScheduler.
        // System.enqueueJob(...,delay) caps the delay at 10 minutes, so we cannot
        // self-chain here to achieve a 55-minute interval.
        sapIntegration.getInvoiceMaster('');
    }
}