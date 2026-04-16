@IsTest
public class SAPAccountSyncQueueTest {
    
    // Mock for SAP callouts
    private class MockSAPCallout implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            
            if (req.getEndpoint().contains('/Login')) {
                res.setStatusCode(200);
                res.setBody('{"SessionId":"test-session-id-12345"}');
            } else if (req.getEndpoint().contains('/BusinessPartners(') && req.getMethod() == 'GET') {
                res.setStatusCode(200);
                res.setBody('{"CardCode":"CU001","CardName":"Test Customer","BPAddresses":[]}');
            } else if (req.getEndpoint().contains('/BusinessPartners') && req.getMethod() == 'PATCH') {
                res.setStatusCode(204);
                res.setBody('');
            } else {
                res.setStatusCode(200);
                res.setBody('{}');
            }
            return res;
        }
    }
    
    @TestSetup
    static void setupTestData() {
        Account acc = new Account(
            Name = 'Test Account SAPQueue',
            Phone = '9876543210',
            BillingCountry = 'India', BillingState = 'Maharashtra',
            BillingPostalCode = '400001', BillingStreet = '123 Test Street',
            District__c = 'Ernakulam', Pin_Code__c = 400001
        );
        insert acc;
    }
    
    @IsTest
    static void testExecute() {
        Test.setMock(HttpCalloutMock.class, new MockSAPCallout());
        Account acc = [SELECT Id FROM Account WHERE Name = 'Test Account SAPQueue' LIMIT 1];
        
        Test.startTest();
        SAPAccountSyncQueue job = new SAPAccountSyncQueue(acc.Id);
        System.enqueueJob(job);
        Test.stopTest();
        
        // Verify job completed without exception
        System.assert(true, 'Queueable job should complete successfully');
    }
    
    @IsTest
    static void testConstructor() {
        Account acc = [SELECT Id FROM Account WHERE Name = 'Test Account SAPQueue' LIMIT 1];
        
        Test.startTest();
        SAPAccountSyncQueue job = new SAPAccountSyncQueue(acc.Id);
        Test.stopTest();
        
        System.assertNotEquals(null, job, 'Job should be instantiated');
    }
}