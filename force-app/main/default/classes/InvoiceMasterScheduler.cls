global class InvoiceMasterScheduler implements Schedulable {

    @TestVisible
    private static final Integer INTERVAL_MINUTES = 55;

    global void execute(SchedulableContext sc) {
        // Kick off the invoice-master sync
        System.enqueueJob(new InvoiceMasterQueueable());

        // Re-schedule this class to fire 55 minutes from now.
        // (System.enqueueJob's delay argument is capped at 10 minutes, so the
        //  Queueable itself cannot self-chain at a 55-minute cadence — we drive
        //  the cadence from the Schedulable instead.)
        if (sc != null) {
            System.abortJob(sc.getTriggerId());
        }
        DateTime next = System.now().addMinutes(INTERVAL_MINUTES);
        String cron = String.valueOf(next.second()) + ' '
                    + String.valueOf(next.minute()) + ' '
                    + String.valueOf(next.hour())   + ' '
                    + String.valueOf(next.day())    + ' '
                    + String.valueOf(next.month())  + ' ? '
                    + String.valueOf(next.year());
        System.schedule(
            'InvoiceMasterScheduler-' + next.getTime(),
            cron,
            new InvoiceMasterScheduler()
        );
    }
/*
 * Kick off once via the developer console:
 *   System.schedule(
 *       'Invoice Master Starter',
 *       '0 0 2 * * ?',
 *       new InvoiceMasterScheduler()
 *   );
 * After the first run, each execution re-schedules itself 55 minutes later.
 */
}