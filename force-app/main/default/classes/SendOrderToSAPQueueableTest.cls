@isTest
public class SendOrderToSAPQueueableTest {
    @isTest
    static void testExecute() {
        // Set mock for callouts
        Test.setMock(HttpCalloutMock.class, new MockSAPCallout());
        // Create a test Account
        Account acc = new Account(Name = 'Test Account For Order');
        insert acc;
        // Create a test Order with Status 'Draft' to pass validation
        Order ord = new Order(
            Name = 'Test Order',
            Status = 'Draft',
            EffectiveDate = Date.today(),
            AccountId = acc.Id
        );
        insert ord;
        // Enqueue the job
        Test.startTest();
        SendOrderToSAPQueueable job = new SendOrderToSAPQueueable(ord.Id);
        System.enqueueJob(job);
        Test.stopTest();
    }

    // Minimal mock for SAP callout
    class MockSAPCallout implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            // Return a valid JSON body to avoid System.JSONException
            res.setBody('{"success":true}');
            return res;
        }
    }
}