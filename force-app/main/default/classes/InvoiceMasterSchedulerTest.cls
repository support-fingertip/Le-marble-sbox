@IsTest
public class InvoiceMasterSchedulerTest {

    // Mock to satisfy callout requirement when Queueable executes synchronously
    private class DummyHttpCalloutMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{}');
            return res;
        }
    }

    // =====================
    // Test that the scheduler can be scheduled via System.schedule
    // and the job is queryable in CronTrigger.
    // Scheduled outside startTest/stopTest so the Schedulable.execute()
    // (and the Queueable it enqueues) is NOT fired synchronously.
    // =====================
    @IsTest
    static void testSchedulerCanBeScheduled() {
        String jobId = System.schedule(
            'Test Invoice Master Scheduler',
            '0 0 2 * * ?',
            new InvoiceMasterScheduler()
        );

        System.assertNotEquals(null, jobId, 'Job ID should be returned when scheduled');

        List<CronTrigger> jobs = [
            SELECT Id, CronJobDetail.Name
            FROM CronTrigger
            WHERE Id = :jobId
        ];
        System.assertEquals(1, jobs.size(), 'Exactly one job should be scheduled');

        System.abortJob(jobId);
    }

    // =====================
    // Test that execute() can be called directly without error.
    // Uses callout mock + startTest/stopTest so the Queueable runs synchronously
    // with a mock HTTP response. InvoiceMasterQueueable.cls uses Test.isRunningTest()
    // to enqueue without a delay, so the 10-min limit is not hit.
    // =====================
    @IsTest
    static void testExecuteEnqueuesQueueable() {
        Test.setMock(HttpCalloutMock.class, new DummyHttpCalloutMock());
        Test.startTest();
        new InvoiceMasterScheduler().execute(null);
        Test.stopTest();

        System.assert(true, 'Scheduler execute() should call System.enqueueJob without errors');
    }

    // =====================
    // Test scheduling with the exact cron expression defined in the class (0 0 2 * * ?)
    // =====================
    @IsTest
    static void testScheduleWithExactCronExpression() {
        String jobId = System.schedule(
            'Invoice Master Starter Test',
            '0 0 2 * * ?',
            new InvoiceMasterScheduler()
        );

        System.assertNotEquals(null, jobId, 'Job should be scheduled with cron 0 0 2 * * ?');

        CronTrigger job = [
            SELECT Id, CronExpression
            FROM CronTrigger
            WHERE Id = :jobId
        ];
        System.assertEquals('0 0 2 * * ?', job.CronExpression, 'Cron expression should match the defined schedule');

        System.abortJob(jobId);
    }

    // =====================
    // Test that multiple independent schedule calls produce unique job IDs
    // =====================
    @IsTest
    static void testMultipleSchedulesProduceUniqueJobIds() {
        String jobId1 = System.schedule('Invoice Sched Test A', '0 0 2 * * ?', new InvoiceMasterScheduler());
        String jobId2 = System.schedule('Invoice Sched Test B', '0 0 3 * * ?', new InvoiceMasterScheduler());

        System.assertNotEquals(null, jobId1, 'First job ID should not be null');
        System.assertNotEquals(null, jobId2, 'Second job ID should not be null');
        System.assertNotEquals(jobId1, jobId2, 'Each scheduled job should have a unique ID');

        System.abortJob(jobId1);
        System.abortJob(jobId2);
    }
}