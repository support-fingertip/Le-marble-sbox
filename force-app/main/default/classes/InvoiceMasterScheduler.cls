global class InvoiceMasterScheduler implements Schedulable {
   global void execute(SchedulableContext sc) {
        System.enqueueJob(new InvoiceMasterQueueable());
    }
/*
 *System.schedule(
    'Invoice Master Starter',
    '0 0 2 * * ?',   
    new InvoiceMasterScheduler()
); 
 InvoiceMasterQueueable Queueable runs

Repeats every 55 minutes automatically
 * */
}