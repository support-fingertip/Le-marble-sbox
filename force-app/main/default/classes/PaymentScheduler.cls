public class PaymentScheduler implements Schedulable {
    
    public void execute(SchedulableContext sc) {
            if (Test.isRunningTest()) return;
        sapIntegration.getPayments();
    }
    
    // Schedule 3 times daily: 1:00 PM, 5:00 PM, 10:45 PM
    public static void scheduleAll() {
        System.schedule('Get Payments - 1:00 PM', '0 0 13 * * ?', new PaymentScheduler());
        System.schedule('Get Payments - 5:00 PM', '0 0 17 * * ?', new PaymentScheduler());
        System.schedule('Get Payments - 10:45 PM', '0 45 22 * * ?', new PaymentScheduler());


        /*
        for (CronTrigger ct : [SELECT Id FROM CronTrigger WHERE CronJobDetail.Name LIKE 'Get Payments%']) {
    System.abortJob(ct.Id);
}

PaymentScheduler.scheduleAll();
    */
    }
}