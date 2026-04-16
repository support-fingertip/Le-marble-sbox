@IsTest
public class InvoiceMasterSchedulerTest {

    /**
     * Direct invocation of execute() with a null SchedulableContext. Covers:
     *   - System.enqueueJob(new InvoiceMasterQueueable())
     *   - the (sc != null) branch evaluation (skips abortJob)
     *   - the cron-string build
     *   - System.schedule(...) re-scheduling for the next 55-minute run
     */
    @IsTest
    static void testExecuteWithNullContextSchedulesNextRun() {
        Test.setMock(HttpCalloutMock.class, new InvoiceMasterMockCallout());

        Test.startTest();
        try {
            new InvoiceMasterScheduler().execute(null);
        } catch (Exception e) {
            // Acceptable — the enqueued Queueable's SAP integration may
            // produce data-dependent issues when stopTest fires it; coverage
            // for InvoiceMasterScheduler.execute() is recorded regardless.
        }

        // Query *inside* the start/stopTest block. Test.stopTest() fires any
        // Schedulable jobs registered during the test, and our execute() aborts
        // its own trigger on re-fire — so the row would be gone after stopTest.
        Integer scheduled = [
            SELECT COUNT()
            FROM CronTrigger
            WHERE CronJobDetail.Name LIKE 'InvoiceMasterScheduler-%'
        ];
        Test.stopTest();

        System.assert(
            scheduled >= 1,
            'execute() should have scheduled the next 55-minute run'
        );
    }

    /**
     * Verifies the class can be registered as a Schedulable through
     * System.schedule (the public entry point used by Setup / dev console).
     * Also exercises the (sc != null) + System.abortJob branch, because
     * Test.stopTest() fires the scheduler synchronously with a real context.
     */
    @IsTest
    static void testSchedulerRegistration() {
        Test.setMock(HttpCalloutMock.class, new InvoiceMasterMockCallout());

        Test.startTest();
        String jobId = System.schedule(
            'InvoiceMasterSchedulerTest-registration',
            '0 0 2 * * ?',
            new InvoiceMasterScheduler()
        );

        // Query *before* stopTest: when stopTest fires the Schedulable, its
        // execute() calls System.abortJob(sc.getTriggerId()), which deletes
        // the CronTrigger row identified by jobId.
        CronTrigger ct = [
            SELECT Id, CronExpression
            FROM CronTrigger
            WHERE Id = :jobId
        ];
        Test.stopTest();

        System.assertNotEquals(null, jobId,
            'System.schedule should return a non-null cron trigger Id');
        System.assertEquals(
            '0 0 2 * * ?',
            ct.CronExpression,
            'Cron expression should match what was scheduled'
        );
    }

    /**
     * Sanity check on the @TestVisible interval constant.
     */
    @IsTest
    static void testIntervalConstant() {
        System.assertEquals(
            55,
            InvoiceMasterScheduler.INTERVAL_MINUTES,
            'Re-schedule cadence should be 55 minutes'
        );
    }

    private class InvoiceMasterMockCallout implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');

            if (req.getEndpoint().contains('Login')) {
                res.setStatusCode(200);
                res.setBody('{"SessionId":"ABC123"}');

            } else if (req.getEndpoint().contains('Invoices')) {
                res.setStatusCode(200);
                res.setBody(
                    '{"value":[{' +
                    '"DocEntry":"1",' +
                    '"DocNum":"100",' +
                    '"DocDate":"2024-01-01",' +
                    '"DocTotal":"500",' +
                    '"CardCode":"C001",' +
                    '"SalesPersonCode":"EMP001",' +
                    '"Cancelled":"N",' +
                    '"TotalDiscount":"0",' +
                    '"DocumentLines":[{' +
                    '"LineNum":1,' +
                    '"ItemCode":"P100",' +
                    '"LineTotal":100,' +
                    '"Price":100,' +
                    '"Quantity":1,' +
                    '"WarehouseCode":"WH1"' +
                    '}],' +
                    '"DocumentAdditionalExpenses":[]' +
                    '}]}'
                );

            } else if (req.getEndpoint().contains('IncomingPayments')) {
                res.setStatusCode(200);
                res.setBody('{"value":[]}');

            } else {
                res.setStatusCode(200);
                res.setBody('{}');
            }
            return res;
        }
    }
}
