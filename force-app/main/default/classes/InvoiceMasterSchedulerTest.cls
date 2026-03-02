@IsTest
public class InvoiceMasterSchedulerTest {

    @IsTest
    static void testSchedulerExecution() {

        Test.startTest();

        // Schedule the job using CRON expression
        String cronExp = '0 0 2 * * ?';  // 2 AM daily

        String jobId = System.schedule(
            'Test Invoice Master Scheduler',
            cronExp,
            new InvoiceMasterScheduler()
        );

        Test.stopTest(); // Executes scheduled job + queueable

        // Verify Scheduled Job exists
        CronTrigger ct = [
            SELECT Id, CronExpression, State
            FROM CronTrigger
            WHERE Id = :jobId
        ];

        System.assertEquals('WAITING', ct.State,
            'Scheduled job should be in waiting state');
        System.assertEquals(cronExp, ct.CronExpression);

        // Verify Async Job (Queueable) executed
        List<AsyncApexJob> jobs = [
            SELECT Id, JobType, Status
            FROM AsyncApexJob
            WHERE JobType = 'Queueable'
        ];

        System.assert(jobs.size() > 0,
            'Queueable job should be enqueued');

        System.assertEquals('Completed', jobs[0].Status,
            'Queueable job should complete successfully');
    }
}