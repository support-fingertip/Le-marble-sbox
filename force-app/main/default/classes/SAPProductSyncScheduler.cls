global class SAPProductSyncScheduler implements Schedulable {
    global void execute(SchedulableContext sc) {
        try {
            // Enqueue the actual sync logic
            System.enqueueJob(new SAPProductSyncQueueable());

            // Abort this scheduler run
            System.abortJob(sc.getTriggerId());

            // Schedule next run 10 minutes later
            Datetime nextRun = Datetime.now().addMinutes(10);
            String cronExp = nextRun.second() + ' ' +
                             nextRun.minute() + ' ' +
                             nextRun.hour() + ' ' +
                             nextRun.day() + ' ' +
                             nextRun.month() + ' ? ' +
                             nextRun.year();

            System.schedule('SAP Product Sync - ' + nextRun.format(), cronExp, new SAPProductSyncScheduler());

            System.debug('Next SAP sync scheduled for: ' + nextRun.format());
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Scheduler Error: ' + e.getMessage());
        }
    }
}