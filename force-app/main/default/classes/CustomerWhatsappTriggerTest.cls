@isTest
private class CustomerWhatsappTriggerTest {

    @isTest
    static void testDebug() {
        Test.setMock(HttpCalloutMock.class, new WhatsAppMessageSenderMock());

        // Step 1: Check what fields Customer__c has
        Schema.DescribeSObjectResult descResult = Customer__c.SObjectType.getDescribe();
        Map<String, Schema.SObjectField> fieldMap = descResult.fields.getMap();
        for (String fieldName : fieldMap.keySet()) {
            System.debug('FIELD: ' + fieldName + ' => ' + fieldMap.get(fieldName).getDescribe().getType());
        }

        // Step 2: Try insert and catch any error
        try {
            Test.startTest();
            Customer__c cust = new Customer__c();
            // Set ALL fields you know about
            for (String fieldName : fieldMap.keySet()) {
                System.debug('Field: ' + fieldName + 
                    ' | Required: ' + !fieldMap.get(fieldName).getDescribe().isNillable() +
                    ' | Type: ' + fieldMap.get(fieldName).getDescribe().getType());
            }
            Test.stopTest();
        } catch (Exception e) {
            System.debug('ERROR: ' + e.getMessage());
            System.debug('STACK: ' + e.getStackTraceString());
        }
    }

    private class WhatsAppMessageSenderMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"status":"success"}');
            return res;
        }
    }
}