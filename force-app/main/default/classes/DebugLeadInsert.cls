@isTest
private class DebugLeadInsert {

    private class MockHttpResponse implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"status":"success"}');
            return res;
        }
    }

    @isTest static void tryInsertLead() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponse());

        Lead l = new Lead(
            FirstName = 'Test',
            LastName = 'Debug',
            Company = 'Debug Co',
            Phone = '9876543210',
            Email = 'debug' + System.currentTimeMillis() + '@example.com',
            Country__c = 'IN',
            Status = 'New'
        );
        Test.startTest();
        insert l;
        Test.stopTest();
        
        Lead inserted = [SELECT Id, LastName FROM Lead WHERE Id = :l.Id];
        System.assertNotEquals(null, inserted.Id, 'Lead should be inserted');
    }
}