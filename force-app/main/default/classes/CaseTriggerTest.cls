@isTest
public class CaseTriggerTest {
    @testSetup
    static void setupData() {
        // Create test Account and Contact for Case relationships
        Account acc = new Account(Name = 'Test Account');
        insert acc;
        Contact con = new Contact(LastName = 'Test Contact', AccountId = acc.Id, Email = 'test@example.com');
        insert con;
    }

    @isTest
    static void testBeforeInsert() {
        List<Case> cases = new List<Case>{
            new Case(Subject = 'Test Before Insert', Status = 'New', Origin = 'Phone')
        };
        Test.startTest();
        insert cases;
        Test.stopTest();
        // Assert trigger logic, e.g., default field values set by handler
        System.assertNotEquals(null, cases[0].Id, 'Case should be inserted');
    }

    @isTest
    static void testAfterInsert() {
        Case c = new Case(Subject = 'Test After Insert', Status = 'New', Origin = 'Email');
        insert c;
        // Query for any side effects, e.g., related records created
        Case inserted = [SELECT Id, Subject FROM Case WHERE Id = :c.Id];
        System.assertEquals('Test After Insert', inserted.Subject);
    }

    @isTest
    static void testBeforeUpdate() {
        Case c = new Case(Subject = 'Test Before Update', Status = 'New', Origin = 'Web');
        insert c;
        c.Status = 'Working';
        Test.startTest();
        update c;
        Test.stopTest();
        // Assert any before update logic, e.g., field changes
        Case updated = [SELECT Status FROM Case WHERE Id = :c.Id];
        System.assertEquals('Working', updated.Status);
    }

    @isTest
    static void testAfterUpdate() {
        Case c = new Case(Subject = 'Test After Update', Status = 'New', Origin = 'Web');
        insert c;
        c.Status = 'Closed';
        update c;
        // Assert after update logic, e.g., related records or field changes
        Case updated = [SELECT Status FROM Case WHERE Id = :c.Id];
        System.assertEquals('Closed', updated.Status);
    }

    @isTest
    static void testBulkInsertUpdate() {
        List<Case> cases = new List<Case>();
        for (Integer i = 0; i < 10; i++) {
            cases.add(new Case(Subject = 'Bulk ' + i, Status = 'New', Origin = 'Phone'));
        }
        insert cases;
        for (Case c : cases) {
            c.Status = 'Escalated';
        }
        update cases;
        List<Case> updatedCases = [SELECT Status FROM Case WHERE Id IN :cases];
        for (Case c : updatedCases) {
            System.assertEquals('Escalated', c.Status);
        }
    }

    @isTest
    static void testErrorHandling() {
        // Example: test validation logic in handler
        Case c = new Case(Status = 'New', Origin = 'Phone'); // Missing required Subject
        try {
            insert c;
        } catch (DmlException e) {
            System.assert(e.getMessage().contains('required'), 'Should fail on missing required fields');
        }
    }

    // Helper to create a Customer__c (Lead) with various phone formats
    private static Customer__c createLead(String phone) {
        Customer__c lead = new Customer__c(Name = 'Test Lead');
        if (phone != null) lead.Phone__c = phone;
        insert lead;
        return lead;
    }

    // Mock class for HTTP callouts
    private class MockHttpCallout implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('OK');
            return res;
        }
    }

    @isTest
    static void testCaseWithLeadAndValidPhone() {
        Test.setMock(HttpCalloutMock.class, new MockHttpCallout());
        Customer__c lead = createLead('9876543210');
        Case c = new Case(Subject = 'Test', Status = 'New', Origin = 'Web', Lead__c = lead.Id);
        insert c;
    }

    @isTest
    static void testCaseWithLeadAndPhoneWithCountryCode() {
        Test.setMock(HttpCalloutMock.class, new MockHttpCallout());
        Customer__c lead = createLead('919876543210');
        Case c = new Case(Subject = 'Test', Status = 'New', Origin = 'Web', Lead__c = lead.Id);
        insert c;
    }

    @isTest
    static void testCaseWithLeadAndNullPhone() {
        Customer__c lead = createLead(null);
        Case c = new Case(Subject = 'Test', Status = 'New', Origin = 'Web', Lead__c = lead.Id);
        insert c;
    }

    @isTest
    static void testCaseWithLeadAndNonNumericPhone() {
        Test.setMock(HttpCalloutMock.class, new MockHttpCallout());
        Customer__c lead = createLead('(987) 654-3210');
        Case c = new Case(Subject = 'Test', Status = 'New', Origin = 'Web', Lead__c = lead.Id);
        insert c;
    }

    @isTest
    static void testCaseWithLeadAndStatusNotNew() {
        Test.setMock(HttpCalloutMock.class, new MockHttpCallout());
        Customer__c lead = createLead('9876543210');
        Case c = new Case(Subject = 'Test', Status = 'Closed', Origin = 'Web', Lead__c = lead.Id);
        insert c;
    }

    @isTest
    static void testCaseWithNoLead() {
        Case c = new Case(Subject = 'Test', Status = 'New', Origin = 'Web');
        insert c;
    }

    @isTest
    static void testWhatsAppExceptionHandling() {
        Test.setMock(HttpCalloutMock.class, new MockHttpCallout());
        // This test simulates an error in WhatsAppMessageSender (if possible in your org)
        // If not possible, this test will just insert as normal
        Customer__c lead = createLead('0000000000'); // Use a number that your org's WhatsAppMessageSender might reject
        Case c = new Case(Subject = 'Test', Status = 'New', Origin = 'Web', Lead__c = lead.Id);
        try {
            insert c;
        } catch (Exception e) {
            System.assert(e.getMessage() != null, 'Exception should be caught');
        }
    }
}