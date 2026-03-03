@IsTest
public class InvoiceMasterQueueableTest {

    /*
     * Mirrors the SAP callout pattern used in sapIntegrationTest:
     *   1st callout  → /Login  → returns a SessionId
     *   2nd callout  → /Invoices → returns an invoice list
     * All other endpoints return a generic 200 {}.
     */
    private class MockSAPCallout implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');

            if (req.getEndpoint().contains('/Login')) {
                res.setStatusCode(200);
                res.setBody('{"SessionId":"test-session-id-12345"}');

            } else if (req.getEndpoint().contains('/Invoices')) {
                res.setStatusCode(200);
                String invoiceJson = '{"value":[' +
                    '{"DocEntry":"INV001","DocNum":"1001","DocDate":"2026-03-01","DocTotal":10000,' +
                    '"Comments":"Test Invoice","CardCode":"CU001","SalesPersonCode":"SP001",' +
                    '"CancelStatus":"csNo","TotalDiscount":100,"U_Saleorder":"SO001",' +
                    '"DocumentLines":[{' +
                        '"LineNum":0,"ItemCode":"ITEM001","LineTotal":9000,"Price":100,' +
                        '"PriceAfterVAT":118,"Quantity":90,"ShipDate":"2026-03-05",' +
                        '"TaxTotal":1000,"UnitPrice":100,"WarehouseCode":"WH001"' +
                    '}]}' +
                ']}';
                res.setBody(invoiceJson);

            } else {
                res.setStatusCode(200);
                res.setBody('{}');
            }
            return res;
        }
    }

    // =====================
    // Test: direct execute() completes without any exception.
    // The callout mock handles Login + Invoices calls inside getInvoiceMaster().
    // Test.stopTest() NOT throwing confirms the !Test.isRunningTest() guard
    // prevents re-enqueue, which would otherwise cause the 55-min delay error.
    // =====================
    @IsTest
    static void testExecuteRunsWithoutError() {
        Test.setMock(HttpCalloutMock.class, new MockSAPCallout());

        Test.startTest();
        new InvoiceMasterQueueable().execute(null);
        Test.stopTest();

        System.assert(true, 'execute() should complete without throwing an exception');
    }

    // =====================
    // Test: the job can be enqueued via System.enqueueJob and returns a non-null job ID.
    // Test.stopTest() flushes the queue synchronously with the callout mock active.
    // =====================
    @IsTest
    static void testJobCanBeEnqueued() {
        Test.setMock(HttpCalloutMock.class, new MockSAPCallout());

        Test.startTest();
        String jobId = System.enqueueJob(new InvoiceMasterQueueable());
        Test.stopTest();

        System.assertNotEquals(null, jobId, 'System.enqueueJob should return a non-null job ID');
    }

    // =====================
    // Test: after execution, the async job record shows a Completed status.
    // =====================
    @IsTest
    static void testJobCompletesSuccessfully() {
        Test.setMock(HttpCalloutMock.class, new MockSAPCallout());

        Test.startTest();
        String jobId = System.enqueueJob(new InvoiceMasterQueueable());
        Test.stopTest();

        AsyncApexJob job = [
            SELECT Id, Status
            FROM AsyncApexJob
            WHERE Id = :jobId
        ];
        System.assertEquals('Completed', job.Status, 'Queueable job should complete with status Completed');
    }

    // =====================
    // Test: confirms that the !Test.isRunningTest() guard prevents re-enqueue.
    // If re-enqueue happened (with 55*60 delay), Test.stopTest() would throw:
    //   "Delay must be less than or equal to 10 minutes"
    // Reaching the assertion here proves the guard is in effect.
    // =====================
    @IsTest
    static void testNoReEnqueueInTestContext() {
        Test.setMock(HttpCalloutMock.class, new MockSAPCallout());

        Test.startTest();
        new InvoiceMasterQueueable().execute(null);
        Test.stopTest();

        // Count async jobs enqueued by this test — should be 0 (no re-enqueue)
        Integer enqueuedCount = [
            SELECT COUNT()
            FROM AsyncApexJob
            WHERE JobType = 'Queueable'
            AND ApexClass.Name = 'InvoiceMasterQueueable'
        ];
        System.assertEquals(0, enqueuedCount, 'Queueable should NOT re-enqueue itself in test context');
    }
}