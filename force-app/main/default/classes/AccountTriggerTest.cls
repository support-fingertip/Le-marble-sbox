@IsTest
private class AccountTriggerTest {

    // ─── HTTP Mock — covers sapIntegration & SAPAccountSyncQueue callouts ────
    private class MockSAPCallout implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);
            res.setBody('{"SessionId":"mock-session"}');
            return res;
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  BEFORE INSERT — duplicate Phone blocked
    // ═══════════════════════════════════════════════════════════════════════

    @IsTest
    static void testBeforeInsert_DuplicatePhone() {
        Test.setMock(HttpCalloutMock.class, new MockSAPCallout());

        Account acc1 = new Account(Name = 'A1', Phone = '9991112222');
        insert acc1;

        Account acc2 = new Account(Name = 'A2', Phone = '9991112222');

        Test.startTest();
        Database.SaveResult sr = Database.insert(acc2, false);
        Test.stopTest();

        System.assert(!sr.isSuccess(), 'Should fail for duplicate Phone');
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  BEFORE INSERT — duplicate Secondary Phone blocked
    // ═══════════════════════════════════════════════════════════════════════

    @IsTest
    static void testBeforeInsert_DuplicateSecondaryPhone() {
        Test.setMock(HttpCalloutMock.class, new MockSAPCallout());

        Account acc1 = new Account(Name = 'A1', Secondary_Phone__c = '8881112222');
        insert acc1;

        Account acc2 = new Account(Name = 'A2', Secondary_Phone__c = '8881112222');

        Test.startTest();
        Database.SaveResult sr = Database.insert(acc2, false);
        Test.stopTest();

        System.assert(!sr.isSuccess(), 'Should fail for duplicate Secondary Phone');
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  BEFORE INSERT — cross: Phone matches existing Secondary Phone
    // ═══════════════════════════════════════════════════════════════════════

    @IsTest
    static void testBeforeInsert_CrossPhoneToSecondary() {
        Test.setMock(HttpCalloutMock.class, new MockSAPCallout());

        Account acc1 = new Account(Name = 'A1', Secondary_Phone__c = '9991112222');
        insert acc1;

        Account acc2 = new Account(Name = 'A2', Phone = '9991112222');

        Test.startTest();
        Database.SaveResult sr = Database.insert(acc2, false);
        Test.stopTest();

        System.assert(!sr.isSuccess(), 'Phone should not match existing Secondary Phone');
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  BEFORE INSERT — cross: Secondary Phone matches existing Phone
    // ═══════════════════════════════════════════════════════════════════════

    @IsTest
    static void testBeforeInsert_CrossSecondaryToPhone() {
        Test.setMock(HttpCalloutMock.class, new MockSAPCallout());

        Account acc1 = new Account(Name = 'A1', Phone = '8881112222');
        insert acc1;

        Account acc2 = new Account(Name = 'A2', Secondary_Phone__c = '8881112222');

        Test.startTest();
        Database.SaveResult sr = Database.insert(acc2, false);
        Test.stopTest();

        System.assert(!sr.isSuccess(), 'Secondary Phone should not match existing Phone');
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  BEFORE INSERT — duplicate GST
    // ═══════════════════════════════════════════════════════════════════════

    @IsTest
    static void testBeforeInsert_DuplicateGST() {
        Test.setMock(HttpCalloutMock.class, new MockSAPCallout());

        Account acc1 = new Account(Name = 'B1', GST_Number__c = '29ABCDE1234F1Z5');
        insert acc1;

        Account acc2 = new Account(Name = 'B2', GST_Number__c = '29ABCDE1234F1Z5');

        Test.startTest();
        Database.SaveResult sr = Database.insert(acc2, false);
        Test.stopTest();

        System.assert(!sr.isSuccess(), 'Should fail for duplicate GST');
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  BEFORE INSERT — duplicate PAN
    // ═══════════════════════════════════════════════════════════════════════

    @IsTest
    static void testBeforeInsert_DuplicatePAN() {
        Test.setMock(HttpCalloutMock.class, new MockSAPCallout());

        Account acc1 = new Account(Name = 'B1', PAN_Number__c = 'ABCDE1234F');
        insert acc1;

        Account acc2 = new Account(Name = 'B2', PAN_Number__c = 'ABCDE1234F');

        Test.startTest();
        Database.SaveResult sr = Database.insert(acc2, false);
        Test.stopTest();

        System.assert(!sr.isSuccess(), 'Should fail for duplicate PAN');
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  BEFORE INSERT — clean insert (no duplicates)
    // ═══════════════════════════════════════════════════════════════════════

    @IsTest
    static void testBeforeInsert_NoDuplicates() {
        Test.setMock(HttpCalloutMock.class, new MockSAPCallout());

        Account acc = new Account(
            Name              = 'Clean',
            Phone             = '1112223333',
            Secondary_Phone__c = '4445556666',
            GST_Number__c     = '07BBBCC2222G1Z3',
            PAN_Number__c     = 'BBBCC2222G'
        );

        Test.startTest();
        Database.SaveResult sr = Database.insert(acc, false);
        Test.stopTest();

        System.assert(sr.isSuccess(), 'No duplicates — should succeed');
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  BEFORE INSERT — blank fields (nothing to check)
    // ═══════════════════════════════════════════════════════════════════════

    @IsTest
    static void testBeforeInsert_BlankFields() {
        Test.setMock(HttpCalloutMock.class, new MockSAPCallout());

        Account acc = new Account(Name = 'Blank');

        Test.startTest();
        Database.SaveResult sr = Database.insert(acc, false);
        Test.stopTest();

        System.assert(sr.isSuccess(), 'Blank fields — no dup check needed');
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  AFTER INSERT — fires sapIntegration.createBusinessPartner
    // ═══════════════════════════════════════════════════════════════════════

    @IsTest
    static void testAfterInsert_CreatesBP() {
        Test.setMock(HttpCalloutMock.class, new MockSAPCallout());

        Test.startTest();
        Account acc = new Account(Name = 'BP Test');
        insert acc;
        Test.stopTest();

        // After insert fires @future createBusinessPartner
        Account inserted = [SELECT Id, Name FROM Account WHERE Id = :acc.Id];
        System.assertEquals('BP Test', inserted.Name);
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  AFTER INSERT — bulk (multiple accounts trigger BP creation)
    // ═══════════════════════════════════════════════════════════════════════

    @IsTest
    static void testAfterInsert_Bulk() {
        Test.setMock(HttpCalloutMock.class, new MockSAPCallout());

        List<Account> accounts = new List<Account>();
        for (Integer i = 0; i < 5; i++) {
            accounts.add(new Account(Name = 'Bulk ' + i, Phone = String.valueOf(1000000000 + i)));
        }

        Test.startTest();
        insert accounts;
        Test.stopTest();

        System.assertEquals(5, [SELECT COUNT() FROM Account WHERE Id IN :accounts]);
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  BEFORE UPDATE — Phone changed to duplicate
    // ═══════════════════════════════════════════════════════════════════════

    @IsTest
    static void testBeforeUpdate_DuplicatePhone() {
        Test.setMock(HttpCalloutMock.class, new MockSAPCallout());

        Account acc1 = new Account(Name = 'U1', Phone = '1234567890');
        Account acc2 = new Account(Name = 'U2', Phone = '0987654321');
        insert new List<Account>{ acc1, acc2 };

        acc2.Phone = '1234567890';

        Test.startTest();
        Database.SaveResult sr = Database.update(acc2, false);
        Test.stopTest();

        System.assert(!sr.isSuccess(), 'Should fail — Phone updated to duplicate');
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  BEFORE UPDATE — GST changed to duplicate
    // ═══════════════════════════════════════════════════════════════════════

    @IsTest
    static void testBeforeUpdate_DuplicateGST() {
        Test.setMock(HttpCalloutMock.class, new MockSAPCallout());

        Account acc1 = new Account(Name = 'U1', GST_Number__c = '29CCCDD3333H1Z4');
        Account acc2 = new Account(Name = 'U2', GST_Number__c = '27DDDEE4444J1Z6');
        insert new List<Account>{ acc1, acc2 };

        acc2.GST_Number__c = '29CCCDD3333H1Z4';

        Test.startTest();
        Database.SaveResult sr = Database.update(acc2, false);
        Test.stopTest();

        System.assert(!sr.isSuccess(), 'Should fail — GST updated to duplicate');
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  BEFORE UPDATE — no change (should pass)
    // ═══════════════════════════════════════════════════════════════════════

    @IsTest
    static void testBeforeUpdate_NoChange() {
        Test.setMock(HttpCalloutMock.class, new MockSAPCallout());

        Account acc = new Account(Name = 'NoChange', Phone = '1231231234');
        insert acc;

        acc.Name = 'NoChange Updated';

        Test.startTest();
        Database.SaveResult sr = Database.update(acc, false);
        Test.stopTest();

        System.assert(sr.isSuccess(), 'No dup-field change — should succeed');
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  AFTER UPDATE — Email changed → enqueues SAPAccountSyncQueue
    // ═══════════════════════════════════════════════════════════════════════

    @IsTest
    static void testAfterUpdate_EmailChange() {
        Test.setMock(HttpCalloutMock.class, new MockSAPCallout());

        Account acc = new Account(Name = 'Sync1', Email__c = 'old@test.com');
        insert acc;

        acc.Email__c = 'new@test.com';

        Test.startTest();
        update acc;
        Test.stopTest();

        // SAPAccountSyncQueue enqueued — verify account still exists
        Account updated = [SELECT Email__c FROM Account WHERE Id = :acc.Id];
        System.assertEquals('new@test.com', updated.Email__c);
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  AFTER UPDATE — Phone changed → enqueues SAPAccountSyncQueue
    // ═══════════════════════════════════════════════════════════════════════

    @IsTest
    static void testAfterUpdate_PhoneChange() {
        Test.setMock(HttpCalloutMock.class, new MockSAPCallout());

        Account acc = new Account(Name = 'Sync2', Phone = '1111111111');
        insert acc;

        acc.Phone = '2222222222';

        Test.startTest();
        update acc;
        Test.stopTest();

        Account updated = [SELECT Phone FROM Account WHERE Id = :acc.Id];
        System.assertEquals('2222222222', updated.Phone);
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  AFTER UPDATE — Secondary Phone changed → enqueues sync
    // ═══════════════════════════════════════════════════════════════════════

    @IsTest
    static void testAfterUpdate_SecondaryPhoneChange() {
        Test.setMock(HttpCalloutMock.class, new MockSAPCallout());

        Account acc = new Account(Name = 'Sync3', Secondary_Phone__c = '3333333333');
        insert acc;

        acc.Secondary_Phone__c = '4444444444';

        Test.startTest();
        update acc;
        Test.stopTest();

        Account updated = [SELECT Secondary_Phone__c FROM Account WHERE Id = :acc.Id];
        System.assertEquals('4444444444', updated.Secondary_Phone__c);
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  AFTER UPDATE — Billing address changed → enqueues sync
    // ═══════════════════════════════════════════════════════════════════════

    @IsTest
    static void testAfterUpdate_BillingAddressChange() {
        Test.setMock(HttpCalloutMock.class, new MockSAPCallout());

        Account acc = new Account(
            Name           = 'Sync4',
            BillingStreet  = '100 Old St',
            BillingCity    = 'OldCity',
            BillingState   = 'KA',
            BillingPostalCode = '560001',
            BillingCountry = 'India'
        );
        insert acc;

        acc.BillingStreet = '200 New St';

        Test.startTest();
        update acc;
        Test.stopTest();

        Account updated = [SELECT BillingStreet FROM Account WHERE Id = :acc.Id];
        System.assertEquals('200 New St', updated.BillingStreet);
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  AFTER UPDATE — GST fields changed → enqueues sync
    // ═══════════════════════════════════════════════════════════════════════

    @IsTest
    static void testAfterUpdate_GSTChange() {
        Test.setMock(HttpCalloutMock.class, new MockSAPCallout());

        Account acc = new Account(Name = 'Sync5', GST_Number__c = '29EEEGG5555K1Z7');
        insert acc;

        acc.GST_Number__c = '06FFFHH6666L1Z8';

        Test.startTest();
        update acc;
        Test.stopTest();

        Account updated = [SELECT GST_Number__c FROM Account WHERE Id = :acc.Id];
        System.assertEquals('06FFFHH6666L1Z8', updated.GST_Number__c);
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  AFTER UPDATE — Address Line fields changed → enqueues sync
    // ═══════════════════════════════════════════════════════════════════════

    @IsTest
    static void testAfterUpdate_AddressLineChange() {
        Test.setMock(HttpCalloutMock.class, new MockSAPCallout());

        Account acc = new Account(Name = 'Sync6', Address_Line1__c = 'Old Line 1');
        insert acc;

        acc.Address_Line1__c = 'New Line 1';

        Test.startTest();
        update acc;
        Test.stopTest();

        Account updated = [SELECT Address_Line1__c FROM Account WHERE Id = :acc.Id];
        System.assertEquals('New Line 1', updated.Address_Line1__c);
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  AFTER UPDATE — Corporation changed → enqueues sync
    // ═══════════════════════════════════════════════════════════════════════

    @IsTest
    static void testAfterUpdate_CorporationChange() {
        Test.setMock(HttpCalloutMock.class, new MockSAPCallout());

        Account acc = new Account(Name = 'Sync7');
        insert acc;

        acc.corporation__c = 'New Corp';

        Test.startTest();
        update acc;
        Test.stopTest();

        Account updated = [SELECT corporation__c FROM Account WHERE Id = :acc.Id];
        System.assertEquals('New Corp', updated.corporation__c);
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  AFTER UPDATE — State/Country changed → enqueues sync
    // ═══════════════════════════════════════════════════════════════════════

    @IsTest
    static void testAfterUpdate_StateCountryChange() {
        Test.setMock(HttpCalloutMock.class, new MockSAPCallout());

        Account acc = new Account(Name = 'Sync8');
        insert acc;

        acc.country__c = 'IN';

        Test.startTest();
        update acc;
        Test.stopTest();

        Account updated = [SELECT country__c FROM Account WHERE Id = :acc.Id];
        System.assertEquals('IN', updated.country__c);
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  AFTER UPDATE — POC_Name changed → enqueues sync
    // ═══════════════════════════════════════════════════════════════════════

    @IsTest
    static void testAfterUpdate_POCNameChange() {
        Test.setMock(HttpCalloutMock.class, new MockSAPCallout());

        Account acc = new Account(Name = 'Sync9', POC_Name__c = 'Old POC');
        insert acc;

        acc.POC_Name__c = 'New POC';

        Test.startTest();
        update acc;
        Test.stopTest();

        Account updated = [SELECT POC_Name__c FROM Account WHERE Id = :acc.Id];
        System.assertEquals('New POC', updated.POC_Name__c);
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  AFTER UPDATE — no tracked field changed → no sync enqueued
    // ═══════════════════════════════════════════════════════════════════════

    @IsTest
    static void testAfterUpdate_NoTrackedFieldChange() {
        Test.setMock(HttpCalloutMock.class, new MockSAPCallout());

        Account acc = new Account(Name = 'NoSync');
        insert acc;

        acc.Name = 'NoSync Updated';

        Test.startTest();
        update acc;
        Test.stopTest();

        Account updated = [SELECT Name FROM Account WHERE Id = :acc.Id];
        System.assertEquals('NoSync Updated', updated.Name);
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  AFTER UPDATE — multiple fields changed at once
    // ═══════════════════════════════════════════════════════════════════════

    @IsTest
    static void testAfterUpdate_MultipleFieldsChanged() {
        Test.setMock(HttpCalloutMock.class, new MockSAPCallout());

        Account acc = new Account(
            Name         = 'Multi',
            Email__c     = 'old@test.com',
            Phone        = '1111111111',
            GST_Number__c = '29GGGII7777M1Z9',
            POC_Name__c  = 'Old POC'
        );
        insert acc;

        acc.Email__c      = 'new@test.com';
        acc.Phone         = '2222222222';
        acc.GST_Number__c = '08HHHKK8888N1Z1';
        acc.POC_Name__c   = 'New POC';

        Test.startTest();
        update acc;
        Test.stopTest();

        Account updated = [SELECT Email__c, Phone, GST_Number__c, POC_Name__c
                           FROM Account WHERE Id = :acc.Id];
        System.assertEquals('new@test.com', updated.Email__c);
        System.assertEquals('2222222222', updated.Phone);
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  BULK UPDATE — mixed: some with tracked changes, some without
    // ═══════════════════════════════════════════════════════════════════════

    @IsTest
    static void testAfterUpdate_Bulk() {
        Test.setMock(HttpCalloutMock.class, new MockSAPCallout());

        List<Account> accounts = new List<Account>();
        for (Integer i = 0; i < 5; i++) {
            accounts.add(new Account(
                Name  = 'BulkUpd ' + i,
                Phone = String.valueOf(3000000000L + i)
            ));
        }
        insert accounts;

        // Change tracked field on first 3, leave rest unchanged
        accounts[0].Email__c = 'changed0@test.com';
        accounts[1].Phone = '9999999990';
        accounts[2].POC_Name__c = 'New POC';
        accounts[3].Name = 'BulkUpd 3 Renamed';
        accounts[4].Name = 'BulkUpd 4 Renamed';

        Test.startTest();
        update accounts;
        Test.stopTest();

        System.assertEquals(5, [SELECT COUNT() FROM Account WHERE Id IN :accounts]);
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  AFTER UPDATE — GST_Type changed → enqueues sync
    // ═══════════════════════════════════════════════════════════════════════

    @IsTest
    static void testAfterUpdate_GSTTypeChange() {
        Test.setMock(HttpCalloutMock.class, new MockSAPCallout());

        Account acc = new Account(Name = 'GSTType');
        insert acc;

        acc.GST_Type__c = 'Registered';

        Test.startTest();
        update acc;
        Test.stopTest();

        Account updated = [SELECT GST_Type__c FROM Account WHERE Id = :acc.Id];
        System.assertEquals('Registered', updated.GST_Type__c);
    }
}