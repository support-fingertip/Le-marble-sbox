public class InvoiceMasterQueueable  implements Queueable, Database.AllowsCallouts {
/*
 * Created by Roopesh
 * Purpose: the invoice api runs at minute 50 of every hour,
 *          driven by InvoiceMasterScheduler's cron expression.
 * */
    public void execute(QueueableContext context) {

        Integration_Config__mdt cfg =
            Integration_Config__mdt.getInstance('InvoiceScheduler');

        if (cfg == null || !cfg.Enable_Invoice_Master__c) {
            System.debug('Invoice Master Sync is DISABLED');
            return;
        }

        // Cadence is owned by InvoiceMasterScheduler's cron expression
        // ('0 50 * * * ?'), so this Queueable just performs one sync pass.
        sapIntegration.getInvoiceMaster('');
    }
}