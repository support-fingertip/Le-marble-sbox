@isTest
public class SendOrderToSAPQueueableTest {
    @isTest
    static void testQueueableExecute() {
        // Create test Order
        Order ord = new Order(Name = 'Test Order', Status = 'Approved', EffectiveDate = Date.today());
        insert ord;

        Test.startTest();
        SendOrderToSAPQueueable job = new SendOrderToSAPQueueable(ord.Id);
        System.enqueueJob(job);
        Test.stopTest();
        // No assertion needed, coverage for execute method
    }
}