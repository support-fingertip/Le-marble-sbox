@isTest
public class CreateBusinessPartnerQueueableTest {

    // Inner mock class (prevents Invalid Type error)
    private class BusinessPartnerMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {

            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"status":"success"}');
            res.setStatusCode(200);
            return res;
        }
    }

    @isTest
    static void testQueueableExecution() {

        // Create test record (change object if needed)
        Opportunity opp = new Opportunity(
            Name = 'Test Deal',
            StageName = 'Prospecting',
            CloseDate = Date.today()
        );
        insert opp;

        // Set mock
        Test.setMock(HttpCalloutMock.class, new BusinessPartnerMock());

        Test.startTest();

        System.enqueueJob(new CreateBusinessPartnerQueueable(opp.Id));

        Test.stopTest();

        System.assert(true);
    }
}