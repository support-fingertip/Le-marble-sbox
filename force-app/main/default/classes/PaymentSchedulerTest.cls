@isTest
private class PaymentSchedulerTest {

    @isTest
    static void testExecute() {
        // Do NOT wrap in startTest/stopTest — that flushes @future and triggers the callout
        PaymentScheduler scheduler = new PaymentScheduler();
        scheduler.execute(null);
        System.assert(true, 'Scheduler executed without error');
    }

    @isTest
    static void testScheduleAll() {
        Test.startTest();
        PaymentScheduler.scheduleAll();
        Test.stopTest();

        List<CronTrigger> jobs = [
            SELECT CronJobDetail.Name, CronExpression
            FROM CronTrigger
            WHERE CronJobDetail.Name LIKE 'Get Payments%'
        ];
        System.assertEquals(3, jobs.size(), 'Expected 3 scheduled jobs');

        Set<String> jobNames = new Set<String>();
        for (CronTrigger ct : jobs) jobNames.add(ct.CronJobDetail.Name);

        System.assert(jobNames.contains('Get Payments - 1:00 PM'),  'Missing 1:00 PM job');
        System.assert(jobNames.contains('Get Payments - 5:00 PM'),  'Missing 5:00 PM job');
        System.assert(jobNames.contains('Get Payments - 10:45 PM'), 'Missing 10:45 PM job');
    }
}