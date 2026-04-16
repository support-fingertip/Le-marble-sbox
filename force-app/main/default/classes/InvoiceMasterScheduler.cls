global class InvoiceMasterScheduler implements Schedulable {

    // Fires at minute 50 of every hour: 00:50, 01:50, 02:50, ...
    @TestVisible
    public static final String HOURLY_AT_MIN_50 = '0 50 * * * ?';

    global void execute(SchedulableContext sc) {
        // The cron expression drives cadence — just kick off the sync.
        System.enqueueJob(new InvoiceMasterQueueable());
    }

/*
 * Kick off once via the developer console (only needed when the job
 * is not already scheduled in Setup → Scheduled Jobs):
 *
 *   System.schedule(
 *       'Invoice Master Scheduler',
 *       InvoiceMasterScheduler.HOURLY_AT_MIN_50,   // '0 50 * * * ?'
 *       new InvoiceMasterScheduler()
 *   );
 *
 * Thereafter the platform fires the job automatically at :50 every hour.
 */
}
