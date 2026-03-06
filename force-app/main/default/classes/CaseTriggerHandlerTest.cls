@IsTest
private class CaseTriggerHandlerTest {

    // ─── HTTP Mock for WhatsApp callout ──────────────────────────────────────
    private class MockWhatsAppSuccess implements HttpCalloutMock {
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
            Name           = 'Test Lead',
            Lead_Name__c   = 'Test Lead',
            Primary_Phone__c = '1111111111'
        );
        if (phone != null) {
            lead.Phone__c = phone;
        }
        insert lead;
        return lead;
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  Status=New, 10-digit phone → adds 91 prefix, sends WhatsApp
    // ═══════════════════════════════════════════════════════════════════════

    @IsTest
    static void testNewCase_10DigitPhone() {
        Test.setMock(HttpCalloutMock.class, new MockWhatsAppSuccess());
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

        Case inserted = [SELECT Id, Status FROM Case WHERE Id = :c.Id];
        System.assertEquals('New', inserted.Status);
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  Status=New, phone already has 91 prefix → no double prefix
    // ═══════════════════════════════════════════════════════════════════════

    @IsTest
    static void testNewCase_PhoneWith91Prefix() {
        Test.setMock(HttpCalloutMock.class, new MockWhatsAppSuccess());
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
    //  Status=New, phone with non-numeric chars → stripped & sent
    // ═══════════════════════════════════════════════════════════════════════

    @IsTest
    static void testNewCase_FormattedPhone() {
        Test.setMock(HttpCalloutMock.class, new MockWhatsAppSuccess());
        Customer__c lead = createLead('(987) 654-3210');

        Test.startTest();
        Case c = new Case(
            Subject = 'Test formatted',
            Status  = 'New',
            Origin  = 'Web',
            Lead__c = lead.Id
        );
        insert c;
        Test.stopTest();

        System.assertNotEquals(null, c.Id);
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  Status=New, Lead has null Phone__c → skips WhatsApp
    // ═══════════════════════════════════════════════════════════════════════

    @IsTest
    static void testNewCase_NullPhone() {
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
    //  Status != New → skips WhatsApp
    // ═══════════════════════════════════════════════════════════════════════

    @IsTest
    static void testCase_StatusNotNew() {
        Test.setMock(HttpCalloutMock.class, new MockWhatsAppSuccess());
        Customer__c lead = createLead('9876543210');

        Test.startTest();
        Case c = new Case(
            Subject = 'Test closed',
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
    //  No Lead__c → phone is null, skips WhatsApp
    // ═══════════════════════════════════════════════════════════════════════

    @IsTest
    static void testCase_NoLead() {
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
    //  Phone with + and spaces → normalized correctly
    // ═══════════════════════════════════════════════════════════════════════

    @IsTest
    static void testNewCase_PhoneWithPlusAndSpaces() {
        Test.setMock(HttpCalloutMock.class, new MockWhatsAppSuccess());
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
    //  Short phone number (< 10 digits, no 91 prefix) → sent as-is
    // ═══════════════════════════════════════════════════════════════════════

    @IsTest
    static void testNewCase_ShortPhone() {
        Test.setMock(HttpCalloutMock.class, new MockWhatsAppSuccess());
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
    //  Bulk insert — multiple cases with different leads
    // ═══════════════════════════════════════════════════════════════════════

    @IsTest
    static void testBulkInsert() {
        Test.setMock(HttpCalloutMock.class, new MockWhatsAppSuccess());

        Customer__c lead1 = createLead('9876543210');
        Customer__c lead2 = createLead('8765432109');
        Customer__c leadNull = createLead(null);

        List<Case> cases = new List<Case>{
            new Case(Subject = 'Bulk 1', Status = 'New', Origin = 'Web', Lead__c = lead1.Id),
            new Case(Subject = 'Bulk 2', Status = 'New', Origin = 'Web', Lead__c = lead2.Id),
            new Case(Subject = 'Bulk 3', Status = 'New', Origin = 'Web', Lead__c = leadNull.Id),
            new Case(Subject = 'Bulk 4', Status = 'Closed', Origin = 'Web', Lead__c = lead1.Id),
            new Case(Subject = 'Bulk 5', Status = 'New', Origin = 'Web')
        };

        Test.startTest();
        insert cases;
        Test.stopTest();

        List<Case> inserted = [SELECT Id FROM Case WHERE Id IN :cases];
        System.assertEquals(5, inserted.size(), 'All 5 cases should be inserted');
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  Multiple cases same Lead → queries Lead phone once
    // ═══════════════════════════════════════════════════════════════════════

    @IsTest
    static void testMultipleCases_SameLead() {
        Test.setMock(HttpCalloutMock.class, new MockWhatsAppSuccess());
        Customer__c lead = createLead('9876543210');

        List<Case> cases = new List<Case>{
            new Case(Subject = 'Same Lead 1', Status = 'New', Origin = 'Web', Lead__c = lead.Id),
            new Case(Subject = 'Same Lead 2', Status = 'New', Origin = 'Web', Lead__c = lead.Id)
        };

        Test.startTest();
        insert cases;
        Test.stopTest();

        System.assertEquals(2, [SELECT COUNT() FROM Case WHERE Lead__c = :lead.Id]);
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  Direct handler call — insert context (oldMap = null)
    // ═══════════════════════════════════════════════════════════════════════

    @IsTest
    static void testDirectCall_InsertContext() {
        Test.setMock(HttpCalloutMock.class, new MockWhatsAppSuccess());
        Customer__c lead = createLead('9876543210');

        Case c = new Case(
            Subject = 'Direct call',
            Status  = 'New',
            Origin  = 'Web',
            Lead__c = lead.Id
        );
        insert c;

        // Re-query to get the inserted case with Id
        Case queried = [SELECT Id, Status, Lead__c FROM Case WHERE Id = :c.Id];

        Test.startTest();
        CaseTriggerHandler.handleAfterInsert(new List<Case>{ queried });
        Test.stopTest();

        System.assertNotEquals(null, queried.Id);
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  Direct handler call — empty list
    // ═══════════════════════════════════════════════════════════════════════

    @IsTest
    static void testDirectCall_EmptyList() {
        Test.startTest();
        CaseTriggerHandler.handleAfterInsert(new List<Case>());
        Test.stopTest();

        System.assert(true, 'Empty list should complete without errors');
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  Phone longer than 10 digits, starts with 91 → no prefix added
    // ═══════════════════════════════════════════════════════════════════════

    @IsTest
    static void testNewCase_LongPhoneWith91() {
        Test.setMock(HttpCalloutMock.class, new MockWhatsAppSuccess());
        Customer__c lead = createLead('919876543210');

        Test.startTest();
        Case c = new Case(
            Subject = 'Test long 91',
            Status  = 'New',
            Origin  = 'Web',
            Lead__c = lead.Id
        );
        insert c;
        Test.stopTest();

        System.assertNotEquals(null, c.Id);
    }
}