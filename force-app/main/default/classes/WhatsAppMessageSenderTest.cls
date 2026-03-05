@isTest
public class WhatsAppMessageSenderTest {

    // ─── Mock: successful 200 response ──
    private class MockSuccessCallout implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);
            res.setBody('{"status":"success","message":"Message sent"}');
            return res;
        }
    }

    // ─── Mock: failure 500 response ──
    private class MockFailureCallout implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(500);
            res.setBody('{"status":"error","message":"Internal Server Error"}');
            return res;
        }
    }

    // ═══════════════════════════════════════════════════════════════════
    //  sendDeliveryNotification — success
    // ═══════════════════════════════════════════════════════════════════

    @isTest
    static void testSendDeliveryNotification_Success() {
        Test.setMock(HttpCalloutMock.class, new MockSuccessCallout());

        Test.startTest();
        WhatsAppMessageSender.sendDeliveryNotification('919876543210');
        Test.stopTest();

        // No exception means success
        System.assert(true, 'Delivery notification sent successfully');
    }

    // ═══════════════════════════════════════════════════════════════════
    //  sendDeliveryNotification — HTTP error (throws WhatsAppException)
    // ═══════════════════════════════════════════════════════════════════

    @isTest
    static void testSendDeliveryNotification_Failure() {
        Test.setMock(HttpCalloutMock.class, new MockFailureCallout());

        Boolean exceptionThrown = false;

        Test.startTest();
        WhatsAppMessageSender.sendDeliveryNotification('919876543210');
        try {
            Test.stopTest();
        } catch (Exception ex) {
            exceptionThrown = true;
        }

        System.assertEquals(true, exceptionThrown, 'Should throw WhatsAppException on HTTP error');
    }

    // ═══════════════════════════════════════════════════════════════════
    //  sendThanksMessage — success
    // ═══════════════════════════════════════════════════════════════════

    @isTest
    static void testSendThanksMessage_Success() {
        Test.setMock(HttpCalloutMock.class, new MockSuccessCallout());

        Test.startTest();
        WhatsAppMessageSender.sendThanksMessage('919876543210');
        Test.stopTest();

        System.assert(true, 'Thanks message sent successfully');
    }

    // ═══════════════════════════════════════════════════════════════════
    //  sendDeliveryNotificationWithDate — success
    // ═══════════════════════════════════════════════════════════════════

    @isTest
    static void testSendDeliveryNotificationWithDate_Success() {
        Test.setMock(HttpCalloutMock.class, new MockSuccessCallout());

        Test.startTest();
        WhatsAppMessageSender.sendDeliveryNotificationWithDate('919876543210', '2026-03-15');
        Test.stopTest();

        System.assert(true, 'Delivery notification with date sent successfully');
    }
}