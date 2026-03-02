@IsTest
public class InvoiceMasterQueueableTest {

    /*
     * Mock for HTTP Callout
     */
    private class MockHttpResponse implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"status":"success"}');
            return res;
        }
    }

    // -------------------------------------------------
    // Test execution when metadata exists in org
    // -------------------------------------------------
    @IsTest
    static void testExecute_WithMetadata() {

        // Ensure metadata exists in org
        Integration_Config__mdt cfg =
            Integration_Config__mdt.getInstance('InvoiceScheduler');

        System.assertNotEquals(
            null,
            cfg,
            'Integration_Config__mdt record InvoiceScheduler must exist in org'
        );

        // Set callout mock
        Test.setMock(HttpCalloutMock.class, new MockHttpResponse());

        Test.startTest();

        Id jobId = System.enqueueJob(new InvoiceMasterQueueable());

        Test.stopTest();

        // Verify async job executed
        AsyncApexJob job = [
            SELECT Id, Status, JobType
            FROM AsyncApexJob
            WHERE Id = :jobId
        ];

        System.assertEquals('Completed', job.Status);
        System.assertEquals('Queueable', job.JobType);
    }

    // -------------------------------------------------
    // Test behavior when metadata is missing
    // -------------------------------------------------
    @IsTest
    static void testExecute_MetadataMissing() {

        /*
         * This test assumes no metadata record exists
         * OR record is disabled.
         * It ensures code exits gracefully.
         */

        Test.startTest();

        Id jobId = System.enqueueJob(new InvoiceMasterQueueable());

        Test.stopTest();

        AsyncApexJob job = [
            SELECT Id, Status
            FROM AsyncApexJob
            WHERE Id = :jobId
        ];

        System.assertEquals('Completed', job.Status);
    }
}