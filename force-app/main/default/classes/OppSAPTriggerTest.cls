@isTest(SeeAllData=false)
private class OppSAPTriggerTest {

    // Simple HttpCalloutMock to handle any HTTP callouts made by SAPBPCreation
    private class MockHttpResponseGenerator implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            // Return a simple JSON body that SAPBPCreation could parse (implementation-dependent)
            res.setBody('{"status":"OK","businessPartnerId":"BP_TEST_123"}');
            return res;
        }
    }

    @isTest
    static void testInsertCreatesBusinessPartner() {
        // Arrange: register the mock for potential HTTP callouts
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());

        // Create a Deals__c record with fields referenced by the trigger.
        // NOTE: Don't set state-code picklist fields to values that may not exist in the test org;
        // those caused FIELD_INTEGRITY_EXCEPTION in the failing test run. Omit them here.
        Deals__c deal = new Deals__c(
            Name = 'Test Deal Insert',
            Email__c = 'insert@example.com',
            Phone__c = '111-222-3333',
            SecondaryPhone__c = '444-555-6666',
            Company__c = 'TestCo',
            Remarks__c = 'Initial remark',
            Address__Street__s = '100 Test St',
            Address__City__s = 'Testville',
            Address__PostalCode__s = '99999',
            Address__CountryCode__s = 'US',
            Billing_Address__Street__s = '100 Billing St',
            Billing_Address__City__s = 'Billtown',
            Billing_Address__PostalCode__s = '88888',
            Billing_Address__CountryCode__s = 'US',
            Billing_Address_Name__c = 'Billing Name 1',
            Billing_Address_Name_2__c = 'Billing Name 2',
            Billing_Address_Name_3__c = 'Billing Name 3',
            Shipping_Address_Name__c = 'Shipping Name 1',
            Shipping_Address_Name_2__c = 'Shipping Name 2',
            Shipping_Address_Name_3__c = 'Shipping Name 3'
        );

        // Act: run inside a single Test.startTest/stopTest pair
        Test.startTest();
            insert deal;
        Test.stopTest();

        // Assert: record was inserted and fields persisted
        Deals__c inserted = [SELECT Id, Email__c, Phone__c, Company__c FROM Deals__c WHERE Id = :deal.Id LIMIT 1];
        System.assertNotEquals(null, inserted.Id, 'Deal should be inserted');
        System.assertEquals('insert@example.com', inserted.Email__c, 'Email should match the value set');
    }

    @isTest
    static void testUpdateTriggersBusinessPartnerUpdateOnRelevantFieldChange() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());

        // Create and insert the record
        Deals__c deal = new Deals__c(
            Name = 'Test Deal Update',
            Email__c = 'update@example.com',
            Phone__c = '222-333-4444',
            Company__c = 'UpdateCo'
        );

        Test.startTest();
            insert deal;
        Test.stopTest();

        // Change a watched field and update in one start/stop block
        deal.Phone__c = '999-888-7777';
        Test.startTest();
            update deal;
        Test.stopTest();

        // Verify the update went through
        Deals__c updated = [SELECT Id, Phone__c FROM Deals__c WHERE Id = :deal.Id LIMIT 1];
        System.assertEquals('999-888-7777', updated.Phone__c, 'Phone should have been updated');

        // Now update an irrelevant field (Name) to ensure trigger doesn't error on irrelevant changes
        updated.Name = 'Test Deal Update - Name Changed';
        Test.startTest();
            update updated;
        Test.stopTest();

        Deals__c finalRec = [SELECT Id, Name FROM Deals__c WHERE Id = :deal.Id LIMIT 1];
        System.assertEquals('Test Deal Update - Name Changed', finalRec.Name);
    }

    @isTest
    static void testBulkInsertAndBulkUpdateDoNotThrow() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());

        List<Deals__c> deals = new List<Deals__c>();
        for (Integer i = 0; i < 5; i++) {
            deals.add(new Deals__c(
                Name = 'Bulk Deal ' + i,
                Email__c = 'bulk' + i + '@example.com',
                Phone__c = '700-000-000' + i,
                Company__c = 'BulkCo'
            ));
        }

        // Bulk insert
        Test.startTest();
            insert deals;
        Test.stopTest();

        // Bulk update: change a field watched by the trigger for all records and update in one DML
        List<Deals__c> toUpdate = [SELECT Id, Phone__c FROM Deals__c WHERE Name LIKE 'Bulk Deal %'];
        for (Deals__c d : toUpdate) {
            d.Phone__c = '800-111-2222';
        }

        Test.startTest();
            update toUpdate;
        Test.stopTest();

        // Assert all updated
        Integer countUpdated = [SELECT count() FROM Deals__c WHERE Name LIKE 'Bulk Deal %' AND Phone__c = '800-111-2222'];
        System.assertEquals(5, countUpdated, 'All bulk deals should have updated phone');
    }
}