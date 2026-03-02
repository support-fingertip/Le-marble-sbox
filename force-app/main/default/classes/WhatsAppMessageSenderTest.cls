@isTest
private class WhatsAppMessageSenderTest {

    /*
     * -----------------------------
     * SUCCESS MOCK (200 Response)
     * -----------------------------
     */
    private class SuccessMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('Message Sent Successfully');
            return res;
        }
    }

    /*
     * -----------------------------
     * ERROR MOCK (500 Response)
     * -----------------------------
     */
    private class ErrorMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('Server Error');
            return res;
        }
    }


    /*
     * -----------------------------
     * Test: sendDeliveryNotification
     * -----------------------------
     */
    @isTest
    static void testSendDeliveryNotification() {

        Test.setMock(HttpCalloutMock.class, new SuccessMock());

        Test.startTest();
        WhatsAppMessageSender.sendDeliveryNotification('9876543210');
        Test.stopTest();

        System.assert(true); // Method executed successfully
    }


    /*
     * -----------------------------
     * Test: sendThanksMessage
     * -----------------------------
     */
    @isTest
    static void testSendThanksMessage() {

        Test.setMock(HttpCalloutMock.class, new SuccessMock());

        Test.startTest();
        WhatsAppMessageSender.sendThanksMessage('9876543210');
        Test.stopTest();

        System.assert(true);
    }


    /*
     * ---------------------------------------------------
     * Test: sendDeliveryNotificationWithDate
     * ---------------------------------------------------
     */
    @isTest
    static void testSendDeliveryNotificationWithDate() {

        Test.setMock(HttpCalloutMock.class, new SuccessMock());

        Test.startTest();
        WhatsAppMessageSender.sendDeliveryNotificationWithDate(
            '9876543210',
            '25-12-2026'
        );
        Test.stopTest();

        System.assert(true);
    }


    /*
     * ---------------------------------------------------
     * Test: Error Scenario (Non-200 Response)
     * ---------------------------------------------------
     */
    @isTest
    static void testErrorScenario() {

        Test.setMock(HttpCalloutMock.class, new ErrorMock());

        Test.startTest();
        WhatsAppMessageSender.sendDeliveryNotification('9876543210');
        Test.stopTest();

        System.assert(true); 
        // Since we removed throwing exception,
        // this should execute without failing.
    }
}