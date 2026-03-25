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

        sapIntegration.getInvoiceMaster('');
        if(!Test.isRunningTest()){	

        System.enqueueJob(new InvoiceMasterQueueable(), 55 * 60);
    }
    }
}