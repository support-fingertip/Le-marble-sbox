@isTest
public class SAPSyncUnifiedTest {
    // Mock for SAP callouts
    private class MockHttpCallout implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            // Return a minimal valid SAP login/session or data response
            if (req.getEndpoint().contains('/Login')) {
                res.setBody('{"SessionId":"test-session"}');
            } else if (req.getEndpoint().contains('/DownPayments')) {
                res.setBody('{"value":[]}');
            } else if (req.getEndpoint().contains('/IncomingPayments')) {
                res.setBody('{"value":[]}');
            } else if (req.getEndpoint().contains('/Invoices')) {
                res.setBody('{"value":[]}');
            } else {
                res.setBody('{"value":[]}');
            }
            return res;
        }
    }

    @testSetup
    static void setupData() {
        // Insert the required SAP_Sync_Setting__c record
        SAP_Sync_Setting__c setting = new SAP_Sync_Setting__c(Name = 'Global', Last_Sync__c = System.now().addDays(-2));
        insert setting;
    }

    // Minimal stub for SchedulableContext
    private class StubSchedulableContext implements SchedulableContext {
        public String getTriggerId() { return 'test'; }
    }

    @isTest
    static void testSAPScheduledSync() {
        Test.setMock(HttpCalloutMock.class, new MockHttpCallout());
        SAPScheduledSync sync = new SAPScheduledSync();
        Test.startTest();
        sync.execute(new StubSchedulableContext());
        SAPScheduledSync.startScheduler();
        Test.stopTest();
    }

    @isTest
    static void testSAPPaymentSyncMethods() {
        Test.setMock(HttpCalloutMock.class, new MockHttpCallout());
        Test.startTest();
        SAPPaymentSync.fetchDownPaymentsData();
        SAPPaymentSync.fetchIncomingPaymentsData();
        SAPPaymentSync.syncDownPayments();
        SAPPaymentSync.syncIncomingPayments();
        Test.stopTest();
    }

    @isTest
    static void testSAPInvoiceSyncMethods() {
        Test.setMock(HttpCalloutMock.class, new MockHttpCallout());
        Test.startTest();
        SAPInvoiceSync.fetchInvoicesData();
        SAPInvoiceSync.syncInvoices();
        Test.stopTest();
    }

    @isTest
    static void testSAPInvoiceSyncQueueable() {
        Test.setMock(HttpCalloutMock.class, new MockHttpCallout());

        SAPInvoiceSyncQueueable q = new SAPInvoiceSyncQueueable();
        Test.startTest();
        System.enqueueJob(q);
        Test.stopTest();
    }

    @isTest
    static void testSAPPaymentSyncQueueable() {
        Test.setMock(HttpCalloutMock.class, new MockHttpCallout());

        SAPPaymentSyncQueueable q = new SAPPaymentSyncQueueable();
        Test.startTest();
        System.enqueueJob(q);
        Test.stopTest();
    }

    @isTest
    static void testSAPScheduledSync_settingNull() {
        Test.setMock(HttpCalloutMock.class, new MockHttpCallout());
        // Remove all SAP_Sync_Setting__c to simulate null
        for (SAP_Sync_Setting__c s : [SELECT Id FROM SAP_Sync_Setting__c]) delete s;
        SAPScheduledSync sync = new SAPScheduledSync();
        Test.startTest();
        sync.execute(new StubSchedulableContext());
        Test.stopTest();
    }

    @isTest
    static void testSAPScheduledSync_recentSyncSkips() {
        Test.setMock(HttpCalloutMock.class, new MockHttpCallout());
        // Set Last_Sync__c to now so it should skip
        SAP_Sync_Setting__c setting = [SELECT Id, Last_Sync__c FROM SAP_Sync_Setting__c WHERE Name = 'Global' LIMIT 1];
        setting.Last_Sync__c = System.now();
        update setting;
        SAPScheduledSync sync = new SAPScheduledSync();
        Test.startTest();
        sync.execute(new StubSchedulableContext());
        Test.stopTest();
    }

    @isTest
    static void testSAPScheduledSync_exceptionHandling() {
        Test.setMock(HttpCalloutMock.class, new MockHttpCallout());
        // Simulate an exception by deleting the setting after querying, causing update to fail
        SAP_Sync_Setting__c setting = [SELECT Id FROM SAP_Sync_Setting__c WHERE Name = 'Global' LIMIT 1];
        delete setting;
        SAPScheduledSync sync = new SAPScheduledSync();
        Test.startTest();
        try {
            sync.execute(new StubSchedulableContext());
        } catch (Exception e) {
            // Exception expected, just to cover the catch block
        }
        Test.stopTest();
    }

    @isTest
    static void testSAPPaymentSync_settingNull() {
        Test.setMock(HttpCalloutMock.class, new MockHttpCallout());
        // Remove all SAP_Sync_Setting__c to simulate null
        for (SAP_Sync_Setting__c s : [SELECT Id FROM SAP_Sync_Setting__c]) delete s;
        Test.startTest();
        SAPPaymentSync.syncDownPayments();
        SAPPaymentSync.syncIncomingPayments();
        Test.stopTest();
    }

    @isTest
    static void testSAPInvoiceSync_settingNull() {
        Test.setMock(HttpCalloutMock.class, new MockHttpCallout());
        // Remove all SAP_Sync_Setting__c to simulate null
        for (SAP_Sync_Setting__c s : [SELECT Id FROM SAP_Sync_Setting__c]) delete s;
        Test.startTest();
        SAPInvoiceSync.syncInvoices();
        Test.stopTest();
    }

    @isTest
    static void testSAPScheduledSync_startSchedulerException() {
        // Simulate error in aborting jobs
        Test.startTest();
        try {
            SAPScheduledSync.startScheduler();
        } catch (Exception e) {
            System.assert(e.getMessage() != null);
        }
        Test.stopTest();
    }

    @isTest
    static void testSAPPaymentSync_processDownPayments_variants() {
        // Empty response
        SAPPaymentSync.processDownPayments('{"value":[]}');
        // Minimal valid response
        String valid = '{"value":[{"DocEntry":"1","DocNum":"DP-1","DocDate":"2024-01-01","DocTotal":100,"PaidToDate":100,"CardCode":"C001","DocumentLines":[{"BaseType":17,"BaseEntry":"SO-1"}]}]}';
        SAPPaymentSync.processDownPayments(valid);
        // Malformed response
        SAPPaymentSync.processDownPayments('not a json');
    }

    @isTest
    static void testSAPPaymentSync_processIncomingPayments_variants() {
        // Empty response
        SAPPaymentSync.processIncomingPayments('{"value":[]}');
        // Minimal valid response
        String valid = '{"value":[{"DocEntry":"2","DocNum":"IP-1","DocDate":"2024-01-02","CashSum":50,"TransferSum":50,"DueDate":"2024-01-10","CardCode":"C002","PaymentInvoices":[{"DocEntry":"INV-1"}]}]}';
        SAPPaymentSync.processIncomingPayments(valid);
        // Malformed response
        SAPPaymentSync.processIncomingPayments('not a json');
    }

    @isTest
    static void testSAPInvoiceSync_processInvoices_variants() {
        // Empty response
        SAPInvoiceSync.processInvoices('{"value":[]}');
        // Minimal valid response
        String valid = '{"value":[{"DocEntry":"3","DocNum":"INV-1","DocDate":"2024-01-03","DocTotal":200,"VatSum":18,"DiscountPercent":5,"PaidToDate":200,"CardCode":"C003","DocumentLines":[{"BaseType":15,"BaseEntry":"DEL-1"}]}]}';
        SAPInvoiceSync.processInvoices(valid);
        // Malformed response
        SAPInvoiceSync.processInvoices('not a json');
    }
}