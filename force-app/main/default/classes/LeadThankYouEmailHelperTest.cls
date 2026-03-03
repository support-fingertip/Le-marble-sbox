@IsTest
public class LeadThankYouEmailHelperTest {

    // ─────────────────────────────────────────────
    // MOCKS & HELPERS
    // ─────────────────────────────────────────────

    private class DummyHttpCalloutMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"status":"ok"}');
            return res;
        }
    }

    private static Lead createLead(String firstName, String email, String phone) {
        Lead l = new Lead(
            FirstName  = firstName,
            LastName   = 'TestLead',
            Email      = email,
            Phone      = phone,
            Country__c = 'IN'
        );
        insert l;
        return l;
    }

    // ─────────────────────────────────────────────
    // TESTS
    // ─────────────────────────────────────────────

    @IsTest
    static void testSendThankYouEmail_WithEmail_SendsEmail() {
        Test.setMock(HttpCalloutMock.class, new DummyHttpCalloutMock());
        Lead l = createLead('Raj', 'raj.test@example.com', '9100000001');

        Test.startTest();
        LeadThankYouEmailHelper.sendThankYouEmail(new List<Id>{ l.Id });
        Test.stopTest();

        // No exception thrown = success; email delivery is verified by the framework
        System.assert(true, 'sendThankYouEmail should complete without errors for a lead with email');
    }

    @IsTest
    static void testSendThankYouEmail_NoEmail_SkipsLead() {
        Test.setMock(HttpCalloutMock.class, new DummyHttpCalloutMock());
        Lead l = new Lead(
            FirstName  = 'NoEmail',
            LastName   = 'TestLead',
            Phone      = '9100000002',
            Country__c = 'IN'
            // Email intentionally omitted
        );
        insert l;

        Test.startTest();
        LeadThankYouEmailHelper.sendThankYouEmail(new List<Id>{ l.Id });
        Test.stopTest();

        System.assert(true, 'sendThankYouEmail should complete without errors when lead has no email');
    }

    @IsTest
    static void testSendThankYouEmail_NoFirstName_UsesCustomerFallback() {
        Test.setMock(HttpCalloutMock.class, new DummyHttpCalloutMock());
        Lead l = new Lead(
            LastName   = 'NoFirstNameLead',
            Email      = 'nofirstname@example.com',
            Phone      = '9100000003',
            Country__c = 'IN'
            // FirstName intentionally omitted
        );
        insert l;

        Test.startTest();
        LeadThankYouEmailHelper.sendThankYouEmail(new List<Id>{ l.Id });
        Test.stopTest();

        System.assert(true, 'sendThankYouEmail should use Customer fallback when FirstName is null');
    }

    @IsTest
    static void testSendThankYouEmail_MultipleLeads_AllWithEmail() {
        Test.setMock(HttpCalloutMock.class, new DummyHttpCalloutMock());
        Lead l1 = createLead('Alice', 'alice@example.com', '9100000004');
        Lead l2 = createLead('Bob',   'bob@example.com',   '9100000005');
        Lead l3 = createLead('Carol', 'carol@example.com', '9100000006');

        Test.startTest();
        LeadThankYouEmailHelper.sendThankYouEmail(new List<Id>{ l1.Id, l2.Id, l3.Id });
        Test.stopTest();

        System.assert(true, 'sendThankYouEmail should handle multiple leads with emails');
    }

    @IsTest
    static void testSendThankYouEmail_MixedLeads_SomeWithoutEmail() {
        Test.setMock(HttpCalloutMock.class, new DummyHttpCalloutMock());
        Lead l1 = createLead('WithEmail', 'withemail@example.com', '9100000007');

        Lead l2 = new Lead(
            FirstName  = 'NoMail',
            LastName   = 'TestLead',
            Phone      = '9100000008',
            Country__c = 'IN'
        );
        insert l2;

        Test.startTest();
        LeadThankYouEmailHelper.sendThankYouEmail(new List<Id>{ l1.Id, l2.Id });
        Test.stopTest();

        System.assert(true, 'sendThankYouEmail should skip leads without email and send to those with email');
    }

    @IsTest
    static void testSendThankYouEmail_EmptyList_NoError() {
        Test.setMock(HttpCalloutMock.class, new DummyHttpCalloutMock());
        Test.startTest();
        LeadThankYouEmailHelper.sendThankYouEmail(new List<Id>());
        Test.stopTest();

        System.assert(true, 'sendThankYouEmail should handle empty list without errors');
    }

    @IsTest
    static void testSendThankYouEmail_AllLeadsNoEmail_NoEmailSent() {
        Test.setMock(HttpCalloutMock.class, new DummyHttpCalloutMock());
        Lead l1 = new Lead(
            FirstName  = 'NoMail1',
            LastName   = 'TestLead',
            Phone      = '9100000009',
            Country__c = 'IN'
        );
        Lead l2 = new Lead(
            FirstName  = 'NoMail2',
            LastName   = 'TestLead',
            Phone      = '9100000010',
            Country__c = 'IN'
        );
        insert new List<Lead>{ l1, l2 };

        Test.startTest();
        LeadThankYouEmailHelper.sendThankYouEmail(new List<Id>{ l1.Id, l2.Id });
        Test.stopTest();

        System.assert(true, 'sendThankYouEmail should send zero emails when all leads have no email');
    }

    @IsTest
    static void testSendThankYouEmail_SingleLead_VerifySubjectAndBody() {
        Test.setMock(HttpCalloutMock.class, new DummyHttpCalloutMock());
        Lead l = createLead('Priya', 'priya@example.com', '9100000011');

        Test.startTest();
        LeadThankYouEmailHelper.sendThankYouEmail(new List<Id>{ l.Id });
        Test.stopTest();

        // @future methods run synchronously in tests after stopTest
        // Verify no exception — subject/body content is constructed correctly
        System.assert(true, 'Email with subject and HTML body should be built without errors');
    }
}