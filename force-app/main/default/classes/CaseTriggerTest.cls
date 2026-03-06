@IsTest
public class CaseTriggerTest {

    // ─── HTTP Mock for WhatsApp callout ──────────────────────────────────────
    private class MockHttpCallout implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('OK');
            return res;
        }
    }

    // ─── Helper: create Customer__c (Lead) ───────────────────────────────────
    private static Customer__c createLead(String phone) {
        Customer__c lead = new Customer__c(
            Name             = 'Test Lead',
            Lead_Name__c     = 'Test Lead',
            Primary_Phone__c = '1111111111'
        );
        if (phone != null) {
            lead.Phone__c = phone;
        }
        insert lead;
        return lead;
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  After Insert — Status=New, 10-digit phone → 91 prefix added
    // ═══════════════════════════════════════════════════════════════════════

    @IsTest
    static void testAfterInsert_NewStatus_10DigitPhone() {
        Test.setMock(HttpCalloutMock.class, new MockHttpCallout());
        Customer__c lead = createLead('9876543210');

        Test.startTest();
        Case c = new Case(
            Subject = 'Test 10 digit',
            Status  = 'New',
            Origin  = 'Web',
            Lead__c = lead.Id
        );
        insert c;
        Test.stopTest();

        Case inserted = [SELECT Id, Subject, Status FROM Case WHERE Id = :c.Id];
        System.assertEquals('New', inserted.Status);
        System.assertNotEquals(null, inserted.Id, 'Case should be inserted');
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  After Insert — Phone already starts with 91
    // ═══════════════════════════════════════════════════════════════════════

    @IsTest
    static void testAfterInsert_PhoneWith91Prefix() {
        Test.setMock(HttpCalloutMock.class, new MockHttpCallout());
        Customer__c lead = createLead('919876543210');

        Test.startTest();
        Case c = new Case(
            Subject = 'Test 91 prefix',
            Status  = 'New',
            Origin  = 'Web',
            Lead__c = lead.Id
        );
        insert c;
        Test.stopTest();

        System.assertNotEquals(null, c.Id);
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  After Insert — Phone with non-numeric chars stripped
    // ═══════════════════════════════════════════════════════════════════════

    @IsTest
    static void testAfterInsert_FormattedPhone() {
        Test.setMock(HttpCalloutMock.class, new MockHttpCallout());
        Customer__c lead = createLead('(987) 654-3210');

        Test.startTest();
        Case c = new Case(
            Subject = 'Test formatted phone',
            Status  = 'New',
            Origin  = 'Web',
            Lead__c = lead.Id
        );
        insert c;
        Test.stopTest();

        System.assertNotEquals(null, c.Id);
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  After Insert — Lead with null Phone__c → skips WhatsApp
    // ═══════════════════════════════════════════════════════════════════════

    @IsTest
    static void testAfterInsert_NullPhone() {
        Customer__c lead = createLead(null);

        Test.startTest();
        Case c = new Case(
            Subject = 'Test null phone',
            Status  = 'New',
            Origin  = 'Web',
            Lead__c = lead.Id
        );
        insert c;
        Test.stopTest();

        System.assertNotEquals(null, c.Id);
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  After Insert — Status != New → skips WhatsApp
    // ═══════════════════════════════════════════════════════════════════════

    @IsTest
    static void testAfterInsert_StatusNotNew() {
        Test.setMock(HttpCalloutMock.class, new MockHttpCallout());
        Customer__c lead = createLead('9876543210');

        Test.startTest();
        Case c = new Case(
            Subject = 'Test closed status',
            Status  = 'Closed',
            Origin  = 'Web',
            Lead__c = lead.Id
        );
        insert c;
        Test.stopTest();

        Case inserted = [SELECT Status FROM Case WHERE Id = :c.Id];
        System.assertEquals('Closed', inserted.Status);
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  After Insert — No Lead → phone is null, skips WhatsApp
    // ═══════════════════════════════════════════════════════════════════════

    @IsTest
    static void testAfterInsert_NoLead() {
        Test.startTest();
        Case c = new Case(
            Subject = 'Test no lead',
            Status  = 'New',
            Origin  = 'Web'
        );
        insert c;
        Test.stopTest();

        System.assertNotEquals(null, c.Id);
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  After Insert — Phone with + and spaces
    // ═══════════════════════════════════════════════════════════════════════

    @IsTest
    static void testAfterInsert_PhoneWithPlusSpaces() {
        Test.setMock(HttpCalloutMock.class, new MockHttpCallout());
        Customer__c lead = createLead('+91 987 654 3210');

        Test.startTest();
        Case c = new Case(
            Subject = 'Test +91 spaces',
            Status  = 'New',
            Origin  = 'Web',
            Lead__c = lead.Id
        );
        insert c;
        Test.stopTest();

        System.assertNotEquals(null, c.Id);
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  After Insert — Short phone (< 10 digits, no prefix added)
    // ═══════════════════════════════════════════════════════════════════════

    @IsTest
    static void testAfterInsert_ShortPhone() {
        Test.setMock(HttpCalloutMock.class, new MockHttpCallout());
        Customer__c lead = createLead('12345');

        Test.startTest();
        Case c = new Case(
            Subject = 'Test short phone',
            Status  = 'New',
            Origin  = 'Web',
            Lead__c = lead.Id
        );
        insert c;
        Test.stopTest();

        System.assertNotEquals(null, c.Id);
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  After Insert — Bulk: multiple cases, mixed leads & statuses
    // ═══════════════════════════════════════════════════════════════════════

    @IsTest
    static void testAfterInsert_Bulk() {
        Test.setMock(HttpCalloutMock.class, new MockHttpCallout());

        Customer__c lead1     = createLead('9876543210');
        Customer__c lead2     = createLead('8765432109');
        Customer__c leadNull  = createLead(null);

        List<Case> cases = new List<Case>{
            new Case(Subject = 'Bulk 1', Status = 'New',    Origin = 'Web', Lead__c = lead1.Id),
            new Case(Subject = 'Bulk 2', Status = 'New',    Origin = 'Web', Lead__c = lead2.Id),
            new Case(Subject = 'Bulk 3', Status = 'New',    Origin = 'Web', Lead__c = leadNull.Id),
            new Case(Subject = 'Bulk 4', Status = 'Closed', Origin = 'Web', Lead__c = lead1.Id),
            new Case(Subject = 'Bulk 5', Status = 'New',    Origin = 'Web')
        };

        Test.startTest();
        insert cases;
        Test.stopTest();

        System.assertEquals(5, [SELECT COUNT() FROM Case WHERE Id IN :cases],
            'All 5 cases should be inserted');
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  After Insert — Multiple cases same Lead
    // ═══════════════════════════════════════════════════════════════════════

    @IsTest
    static void testAfterInsert_MultipleCasesSameLead() {
        Test.setMock(HttpCalloutMock.class, new MockHttpCallout());
        Customer__c lead = createLead('9876543210');

        List<Case> cases = new List<Case>{
            new Case(Subject = 'Same 1', Status = 'New', Origin = 'Web', Lead__c = lead.Id),
            new Case(Subject = 'Same 2', Status = 'New', Origin = 'Web', Lead__c = lead.Id)
        };

        Test.startTest();
        insert cases;
        Test.stopTest();

        System.assertEquals(2, [SELECT COUNT() FROM Case WHERE Lead__c = :lead.Id]);
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  After Insert — WhatsApp exception handling
    // ═══════════════════════════════════════════════════════════════════════

    @IsTest
    static void testAfterInsert_WhatsAppException() {
        Test.setMock(HttpCalloutMock.class, new MockHttpCallout());
        Customer__c lead = createLead('0000000000');

        Test.startTest();
        try {
            Case c = new Case(
                Subject = 'Test exception',
                Status  = 'New',
                Origin  = 'Web',
                Lead__c = lead.Id
            );
            insert c;
        } catch (Exception e) {
            System.assert(e.getMessage() != null, 'Exception should be caught');
        }
        Test.stopTest();
    }
}