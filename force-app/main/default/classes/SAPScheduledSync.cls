public class SAPScheduledSync implements Schedulable {
    public void execute(SchedulableContext sc) {
        try {
            // First, check if there's already a sync in progress
            SAP_Sync_Setting__c setting = SAP_Sync_Setting__c.getValues('Global');
            if (setting != null && setting.Last_Sync__c != null && 
                System.now().addMinutes(-5) < setting.Last_Sync__c) {
                System.debug('Sync already in progress or recently completed. Skipping this run.');
                return;
            }

            // Create or update the sync setting
            if (setting == null) {
                setting = new SAP_Sync_Setting__c(Name = 'Global');
                insert setting;
            }

            // Run the sync processes
            System.enqueueJob(new SAPInvoiceSyncQueueable());
            System.enqueueJob(new SAPPaymentSyncQueueable());

            // Update the Last_Sync__c field
            setting.Last_Sync__c = System.now();
            update setting;

            // Schedule the next run immediately
            scheduleNextRun();
        } catch (Exception e) {
            System.debug('SAPScheduledSync Exception: ' + e.getMessage() + '\nStack Trace: ' + e.getStackTraceString());
            // Even if there's an error, try to schedule the next run
            try {
                scheduleNextRun();
            } catch (Exception ex) {
                System.debug('Failed to schedule next run: ' + ex.getMessage());
            }
        }
    }

    private void scheduleNextRun() {
        // Schedule the next run in 10 minutes
        Datetime nextRun = Datetime.now().addMinutes(10);
        String cronExp = '0 ' + nextRun.minute() + ' ' + nextRun.hour() + ' ' + 
                        nextRun.day() + ' ' + nextRun.month() + ' ? ' + nextRun.year();
        String jobName = 'SAP Sync ' + String.valueOf(Datetime.now().getTime());
        System.schedule(jobName, cronExp, new SAPScheduledSync());
    }

    public static void startScheduler() {
        try {
            // First, abort any existing jobs to start fresh
            List<CronTrigger> existingJobs = [
                SELECT Id, CronJobDetail.Name
                FROM CronTrigger
                WHERE CronJobDetail.Name LIKE 'SAP Sync%'
                AND State = 'WAITING'
                LIMIT 100
            ];
            
            for (CronTrigger job : existingJobs) {
                System.abortJob(job.Id);
                System.debug('Aborted job: ' + job.CronJobDetail.Name);
            }

            // Schedule the first run to start in 1 minute
            Datetime nextRun = Datetime.now().addMinutes(1);
            String cronExp = '0 ' + nextRun.minute() + ' ' + nextRun.hour() + ' ' + 
                            nextRun.day() + ' ' + nextRun.month() + ' ? ' + nextRun.year();
            String jobName = 'SAP Sync ' + String.valueOf(Datetime.now().getTime());
            System.schedule(jobName, cronExp, new SAPScheduledSync());
            
            System.debug('Successfully scheduled SAP Sync. First run will be at: ' + nextRun);
        } catch (Exception e) {
            System.debug('Error starting scheduler: ' + e.getMessage() + '\nStack Trace: ' + e.getStackTraceString());
            throw e;
        }
    }
}