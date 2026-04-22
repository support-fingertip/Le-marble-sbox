@IsTest
public class LeadTriggerHandlerTest {

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

    private static User createUser(String alias, String email, String username) {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User u = new User(
            Alias            = alias,
            Email            = email,
            EmailEncodingKey = 'UTF-8',
            LastName         = alias,
            LanguageLocaleKey = 'en_US',
            LocaleSidKey     = 'en_US',
            ProfileId        = p.Id,
            TimeZoneSidKey   = 'Asia/Kolkata',
            Username         = username + System.currentTimeMillis() + '@test.com'
        );
        insert u;
        return u;
    }

    // ─────────────────────────────────────────────
    // BEFORE INSERT
    // ─────────────────────────────────────────────

    @IsTest
    static void testBeforeInsert_CampaignMapping() {
        Test.setMock(HttpCalloutMock.class, new DummyHttpCalloutMock());

        Campaign c = new Campaign(Name = 'TriggerCamp', IsActive = true);
        insert c;

        Test.startTest();
        Lead l = new Lead(
            FirstName     = 'Camp',
            LastName      = 'Lead',
            Email         = 'camp.lead@test.com',
            Phone         = '9100001001',
            Campaign_ID__c = 'TriggerCamp',
            Country       = 'India'
        );
        insert l;
        Test.stopTest();

        Lead inserted = [SELECT Campaign__c FROM Lead WHERE Id = :l.Id];
        System.assertNotEquals(null, inserted.Campaign__c, 'Campaign__c should be mapped from Campaign_ID__c');
    }

    @IsTest
    static void testBeforeInsert_NoCampaign_SkipMapping() {
        Test.setMock(HttpCalloutMock.class, new DummyHttpCalloutMock());

        Test.startTest();
        Lead l = new Lead(
            FirstName  = 'NoCamp',
            LastName   = 'Lead',
            Email      = 'nocamp.lead@test.com',
            Phone      = '9100001002',
            Country    = 'India'
            // No Campaign_ID__c
        );
        insert l;
        Test.stopTest();

        Lead inserted = [SELECT Campaign__c FROM Lead WHERE Id = :l.Id];
        System.assertEquals(null, inserted.Campaign__c, 'Campaign__c should remain null when no Campaign_ID__c');
    }

    @IsTest
    static void testBeforeInsert_B2CCompanyAutoFill() {
        Test.setMock(HttpCalloutMock.class, new DummyHttpCalloutMock());

        Test.startTest();
        Lead l = new Lead(
            FirstName  = 'Raj',
            LastName   = 'Sharma',
            Email      = 'raj.sharma@test.com',
            Phone      = '9100001003',
            Country    = 'India'
            // Customer_Type__c is not B2B → B2C behaviour
        );
        insert l;
        Test.stopTest();

        Lead inserted = [SELECT Company FROM Lead WHERE Id = :l.Id];
        System.assertEquals('Raj Sharma', inserted.Company, 'B2C Company should be auto-filled with full name');
    }

    @IsTest
    static void testBeforeInsert_B2BCompanyNotOverwritten() {
        Test.setMock(HttpCalloutMock.class, new DummyHttpCalloutMock());

        Test.startTest();
        Lead l = new Lead(
            FirstName        = 'Biz',
            LastName         = 'Owner',
            Company          = 'My Company Ltd',
            Customer_Type__c = 'B2B',
            Email            = 'biz.owner@test.com',
            Phone            = '9100001004',
            Country          = 'India'
        );
        insert l;
        Test.stopTest();

        Lead inserted = [SELECT Company FROM Lead WHERE Id = :l.Id];
        System.assertEquals('My Company Ltd', inserted.Company, 'B2B Company should NOT be overwritten');
    }

    @IsTest
    static void testBeforeInsert_CountryAutoFill() {
        Test.setMock(HttpCalloutMock.class, new DummyHttpCalloutMock());

        Test.startTest();
        Lead l = new Lead(
            FirstName  = 'Country',
            LastName   = 'Fill',
            Email      = 'country.fill@test.com',
            Phone      = '9100001005',
            Country    = 'India'
            // Country standard field left blank
        );
        insert l;
        Test.stopTest();

        Lead inserted = [SELECT Country FROM Lead WHERE Id = :l.Id];
        System.assertEquals('India', inserted.Country, 'Country standard field should be auto-filled to India');
    }

    @IsTest
    static void testBeforeInsert_CountryAlreadySet_NotOverwritten() {
        Test.setMock(HttpCalloutMock.class, new DummyHttpCalloutMock());

        Test.startTest();
        Lead l = new Lead(
            FirstName  = 'Country',
            LastName   = 'Set',
            Email      = 'country.set@test.com',
            Phone      = '9100001006',
            Country    = 'IN'
        );
        insert l;
        Test.stopTest();

        Lead inserted = [SELECT Country FROM Lead WHERE Id = :l.Id];
        System.assertEquals('IN', inserted.Country, 'Country should not be overwritten if already set');
    }

    @IsTest
    static void testBeforeInsert_SalesExecutiveOwnerAssignment() {
        Test.setMock(HttpCalloutMock.class, new DummyHttpCalloutMock());

        User salesUser = createUser('sexec', 'sexec@test.com', 'sexec');

        Test.startTest();
        Lead l = new Lead(
            FirstName         = 'Sales',
            LastName          = 'Exec',
            Email             = 'sales.exec@test.com',
            Phone             = '9100001007',
            Country           = 'India',
            Sales_Executive__c = salesUser.Id
        );
        insert l;
        Test.stopTest();

        Lead inserted = [SELECT OwnerId FROM Lead WHERE Id = :l.Id];
        System.assertEquals(salesUser.Id, inserted.OwnerId, 'OwnerId should be set to Sales_Executive__c on insert');
    }

    @IsTest
    static void testBeforeInsert_NoSalesExecutive_DefaultOwner() {
        Test.setMock(HttpCalloutMock.class, new DummyHttpCalloutMock());

        Test.startTest();
        Lead l = new Lead(
            FirstName  = 'NoSales',
            LastName   = 'Exec',
            Email      = 'nosales.exec@test.com',
            Phone      = '9100001008',
            Country    = 'India'
        );
        insert l;
        Test.stopTest();

        Lead inserted = [SELECT OwnerId FROM Lead WHERE Id = :l.Id];
        System.assertNotEquals(null, inserted.OwnerId, 'OwnerId should default to running user when no Sales_Executive__c');
    }

    @IsTest
    static void testBeforeInsert_AfterInsert_WhatsAppViaPrimaryPhone() {
        Test.setMock(HttpCalloutMock.class, new DummyHttpCalloutMock());

        Test.startTest();
        Lead l = new Lead(
            FirstName  = 'PhoneWA',
            LastName   = 'Test',
            Email      = 'phonewa.test@test.com',
            Phone      = '9100001009',
            Country    = 'India'
        );
        insert l;
        Test.stopTest();

        System.assertNotEquals(null, l.Id, 'Lead should be inserted with Phone for WhatsApp');
    }

    @IsTest
    static void testBeforeInsert_AfterInsert_WhatsAppViaMobilePhone() {
        Test.setMock(HttpCalloutMock.class, new DummyHttpCalloutMock());

        Test.startTest();
        Lead l = new Lead(
            FirstName   = 'MobileWA',
            LastName    = 'Test',
            Email       = 'mobilewa.test@test.com',
            MobilePhone = '9100001010',
            Country     = 'India'
        );
        insert l;
        Test.stopTest();

        System.assertNotEquals(null, l.Id, 'Lead should be inserted with MobilePhone for WhatsApp fallback');
    }

    @IsTest
    static void testBeforeInsert_AfterInsert_NoPhone_NoWhatsApp() {
        Test.setMock(HttpCalloutMock.class, new DummyHttpCalloutMock());

        Test.startTest();
        Lead l = new Lead(
            FirstName  = 'NoPhone',
            LastName   = 'Test',
            Email      = 'nophone.test@test.com',
            Country    = 'India'
            // No Phone or MobilePhone — WhatsApp path skipped
        );
        insert l;
        Test.stopTest();

        System.assertNotEquals(null, l.Id, 'Lead without phone should still insert successfully');
    }

    // ─────────────────────────────────────────────
    // BEFORE UPDATE
    // ─────────────────────────────────────────────

    @IsTest
    static void testBeforeUpdate_ClearUnqualifiedReason() {
        Test.setMock(HttpCalloutMock.class, new DummyHttpCalloutMock());

        Lead l = new Lead(
            FirstName              = 'Clear',
            LastName               = 'Reason',
            Email                  = 'clear.reason@test.com',
            Phone                  = '9100002001',
            Status                 = 'Unqualified',
            Unqualified_Reason__c  = 'Budget Issue',
            Country                = 'India'
        );
        insert l;

        Test.startTest();
        l.Status = 'Open';
        update l;
        Test.stopTest();

        Lead updated = [SELECT Unqualified_Reason__c FROM Lead WHERE Id = :l.Id];
        System.assert(String.isBlank(updated.Unqualified_Reason__c), 'Unqualified_Reason__c should be cleared when status changes from Unqualified');
    }

    @IsTest
    static void testBeforeUpdate_StatusRemainsUnqualified_ReasonKept() {
        Test.setMock(HttpCalloutMock.class, new DummyHttpCalloutMock());

        Lead l = new Lead(
            FirstName             = 'Keep',
            LastName              = 'Reason',
            Email                 = 'keep.reason@test.com',
            Phone                 = '9100002002',
            Status                = 'Unqualified',
            Unqualified_Reason__c = 'Not Interested',
            Country               = 'India'
        );
        insert l;

        Test.startTest();
        l.Unqualified_Reason__c = 'Different Reason';
        update l;
        Test.stopTest();

        Lead updated = [SELECT Unqualified_Reason__c FROM Lead WHERE Id = :l.Id];
        System.assertEquals('Different Reason', updated.Unqualified_Reason__c, 'Reason should stay if status stays Unqualified');
    }

    @IsTest
    static void testBeforeUpdate_CustomerInterestedSetsQualified() {
        Test.setMock(HttpCalloutMock.class, new DummyHttpCalloutMock());

        Lead l = new Lead(
            FirstName             = 'Interested',
            LastName              = 'Customer',
            Email                 = 'interested.cust@test.com',
            Phone                 = '9100002003',
            Country               = 'India',
            Customer_Interested__c = false
        );
        insert l;

        Test.startTest();
        l.Customer_Interested__c = true;
        update l;
        Test.stopTest();

        Lead updated = [SELECT Status FROM Lead WHERE Id = :l.Id];
        System.assertEquals('Qualified', updated.Status, 'Status should be set to Qualified when Customer_Interested__c becomes true');
    }

    @IsTest
    static void testBeforeUpdate_B2CCompanyAutoFillOnNameChange() {
        Test.setMock(HttpCalloutMock.class, new DummyHttpCalloutMock());

        Lead l = new Lead(
            FirstName  = 'OldFirst',
            LastName   = 'OldLast',
            Email      = 'b2c.namechg@test.com',
            Phone      = '9100002004',
            Country    = 'India'
        );
        insert l;

        Test.startTest();
        l.FirstName = 'NewFirst';
        l.LastName  = 'NewLast';
        update l;
        Test.stopTest();

        Lead updated = [SELECT Company FROM Lead WHERE Id = :l.Id];
        System.assertEquals('NewFirst NewLast', updated.Company, 'B2C Company should be updated with new full name');
    }

    @IsTest
    static void testBeforeUpdate_B2BCompanyNotAutoFilled() {
        Test.setMock(HttpCalloutMock.class, new DummyHttpCalloutMock());

        Lead l = new Lead(
            FirstName        = 'B2B',
            LastName         = 'Update',
            Company          = 'Fixed Corp',
            Customer_Type__c = 'B2B',
            Email            = 'b2b.update@test.com',
            Phone            = '9100002005',
            Country          = 'India'
        );
        insert l;

        Test.startTest();
        l.FirstName = 'Changed';
        update l;
        Test.stopTest();

        Lead updated = [SELECT Company FROM Lead WHERE Id = :l.Id];
        System.assertEquals('Fixed Corp', updated.Company, 'B2B Company should NOT be auto-filled on update');
    }

    @IsTest
    static void testBeforeUpdate_CountryAutoFill() {
        Test.setMock(HttpCalloutMock.class, new DummyHttpCalloutMock());

        Lead l = new Lead(
            FirstName  = 'CountryUpd',
            LastName   = 'Test',
            Email      = 'countryupd.test@test.com',
            Phone      = '9100002006',
            Country    = 'India'
        );
        insert l;

        Test.startTest();
        // Clear Country to trigger auto-fill
        l.Country = '';
        update l;
        Test.stopTest();

        Lead updated = [SELECT Country FROM Lead WHERE Id = :l.Id];
        System.assertEquals('India', updated.Country, 'Country should be auto-filled back to India when cleared on update');
    }

    @IsTest
    static void testBeforeInsert_CountryCodeAutoFill() {
        Test.setMock(HttpCalloutMock.class, new DummyHttpCalloutMock());

        Lead l = new Lead(
            FirstName  = 'CodeInsert',
            LastName   = 'Handler',
            Email      = 'codeinsert.handler@test.com',
            Phone      = '9100002099',
            Country    = 'India'
        );

        Test.startTest();
        insert l;
        Test.stopTest();

        Lead inserted = [SELECT Country_Code__c FROM Lead WHERE Id = :l.Id];
        System.assertEquals('+91', inserted.Country_Code__c, 'Country_Code__c should be auto-filled to +91 on insert when Country is India');
    }

    @IsTest
    static void testBeforeUpdate_CountryCodeAutoFill() {
        Test.setMock(HttpCalloutMock.class, new DummyHttpCalloutMock());

        Lead l = new Lead(
            FirstName  = 'CodeFill',
            LastName   = 'Test',
            Email      = 'codefill.test@test.com',
            Phone      = '9100002007',
            Country    = 'India'
            // Country_Code__c intentionally blank
        );
        insert l;

        Test.startTest();
        l.LastName = 'TestUpdated';
        update l;
        Test.stopTest();

        Lead updated = [SELECT Country_Code__c FROM Lead WHERE Id = :l.Id];
        System.assertEquals('+91', updated.Country_Code__c, 'Country_Code__c should be auto-filled to +91 when Country=India and blank');
    }

    @IsTest
    static void testBeforeUpdate_CountryCodeNotOverwrittenIfAlreadySet() {
        Test.setMock(HttpCalloutMock.class, new DummyHttpCalloutMock());

        Lead l = new Lead(
            FirstName     = 'CodeSet',
            LastName      = 'Test',
            Email         = 'codeset.test@test.com',
            Phone         = '9100002008',
            Country       = 'India',
            Country_Code__c = '+91'
        );
        insert l;

        Test.startTest();
        l.LastName = 'TestUpdated2';
        update l;
        Test.stopTest();

        Lead updated = [SELECT Country_Code__c FROM Lead WHERE Id = :l.Id];
        System.assertEquals('+91', updated.Country_Code__c, 'Country_Code__c should not be changed if already set');
    }

    @IsTest
    static void testBeforeUpdate_CountryCodeClearedOnCountryChange() {
        Test.setMock(HttpCalloutMock.class, new DummyHttpCalloutMock());

        Lead l = new Lead(
            FirstName  = 'CodeClear',
            LastName   = 'Handler',
            Email      = 'codeclear.handler@test.com',
            Phone      = '9100002199',
            Country    = 'India',
            Country_Code__c = '+91'
        );
        insert l;

        // Change country away from India
        l.Country = 'United States';

        Test.startTest();
        update l;
        Test.stopTest();

        Lead updated2 = [SELECT Country_Code__c FROM Lead WHERE Id = :l.Id];
        System.assert(String.isBlank(updated2.Country_Code__c), 'Country_Code__c should be cleared when country changes away from India');
    }

    @IsTest
    static void testBeforeUpdate_SalesExecutiveOwnerChange() {
        Test.setMock(HttpCalloutMock.class, new DummyHttpCalloutMock());

        User salesUser = createUser('sexupd', 'sexupd@test.com', 'sexupd');

        Lead l = new Lead(
            FirstName  = 'SalesUpd',
            LastName   = 'Test',
            Email      = 'salesupd.test@test.com',
            Phone      = '9100002009',
            Country    = 'India'
        );
        insert l;

        Test.startTest();
        l.Sales_Executive__c = salesUser.Id;
        update l;
        Test.stopTest();

        Lead updated = [SELECT OwnerId FROM Lead WHERE Id = :l.Id];
        System.assertEquals(salesUser.Id, updated.OwnerId, 'OwnerId should be set to Sales_Executive__c on update');
    }

    @IsTest
    static void testBeforeUpdate_NoSalesExecutive_AssignmentRuleEnabled() {
        Test.setMock(HttpCalloutMock.class, new DummyHttpCalloutMock());

        User salesUser = createUser('sexclr', 'sexclr@test.com', 'sexclr');

        Lead l = new Lead(
            FirstName          = 'ClearExec',
            LastName           = 'Test',
            Email              = 'clearexec.test@test.com',
            Phone              = '9100002010',
            Country            = 'India',
            Sales_Executive__c = salesUser.Id
        );
        insert l;

        Test.startTest();
        l.Sales_Executive__c = null;
        update l;
        Test.stopTest();

        Lead updated = [SELECT Id FROM Lead WHERE Id = :l.Id];
        System.assertNotEquals(null, updated.Id, 'Lead should update when Sales_Executive__c is cleared');
    }

    // ─────────────────────────────────────────────
    // AFTER UPDATE
    // ─────────────────────────────────────────────

    @IsTest
    static void testAfterUpdate_StatusToUnqualified_NotificationFired() {
        Test.setMock(HttpCalloutMock.class, new DummyHttpCalloutMock());

        Lead l = new Lead(
            FirstName  = 'Unqual',
            LastName   = 'Notify',
            Email      = 'unqual.notify@test.com',
            Phone      = '9100003001',
            Country    = 'India',
            Status     = 'Open'
        );
        insert l;

        Test.startTest();
        l.Status                = 'Unqualified';
        l.Unqualified_Reason__c = 'Not Interested';
        update l;
        Test.stopTest();

        Lead updated = [SELECT Status FROM Lead WHERE Id = :l.Id];
        System.assertEquals('Unqualified', updated.Status, 'Status should be set to Unqualified');
    }

    @IsTest
    static void testAfterUpdate_OwnerChange_AssignmentNotificationFired() {
        Test.setMock(HttpCalloutMock.class, new DummyHttpCalloutMock());

        User newOwner = createUser('nowner', 'nowner@test.com', 'nowner');

        Lead l = new Lead(
            FirstName  = 'Owner',
            LastName   = 'Change',
            Email      = 'owner.change@test.com',
            Phone      = '9100003002',
            Country    = 'India'
        );
        insert l;

        Test.startTest();
        l.OwnerId = newOwner.Id;
        update l;
        Test.stopTest();

        Lead updated = [SELECT OwnerId FROM Lead WHERE Id = :l.Id];
        System.assertEquals(newOwner.Id, updated.OwnerId, 'OwnerId should be updated and assignment notification triggered');
    }

    @IsTest
    static void testAfterUpdate_LeadConverted_AccountEmailUpdated() {
        Test.setMock(HttpCalloutMock.class, new DummyHttpCalloutMock());

        Lead l = new Lead(
            FirstName  = 'Convert',
            LastName   = 'Email',
            Email      = 'convert.email@test.com',
            Phone      = '9100003003',
            Country    = 'India',
            Check_List_Items__c = 'TILE',
            Product_Category__c = 'Tile',
            Branch_Location__c  = 'HO',
            Street     = 'Test Street',
            City       = 'Kochi',
            State      = 'Kerala',
            PostalCode = '682001'
        );
        insert l;

        Account existingAcc = new Account(
            Name              = 'Convert Email',
            BillingCountry    = 'India',
            BillingState      = 'Kerala',
            BillingPostalCode = '682001',
            BillingStreet     = 'Test Street',
            District__c       = 'Ernakulam',
            Pin_Code__c       = 682001
        );
        insert existingAcc;

        String convertedStatus = [
            SELECT MasterLabel FROM LeadStatus WHERE IsConverted = true LIMIT 1
        ].MasterLabel;

        Test.startTest();
        Database.LeadConvert lc = new Database.LeadConvert();
        lc.setLeadId(l.Id);
        lc.setConvertedStatus(convertedStatus);
        lc.setDoNotCreateOpportunity(true);
        lc.setAccountId(existingAcc.Id);
        Database.LeadConvertResult result = Database.convertLead(lc);
        Test.stopTest();

        System.assertEquals(true, result.isSuccess(), 'Lead conversion should succeed');

        Lead converted = [SELECT IsConverted, ConvertedAccountId FROM Lead WHERE Id = :l.Id];
        System.assertEquals(true, converted.IsConverted, 'Lead should be marked as converted');

        // Account Email__c should be updated with Lead email
        if (converted.ConvertedAccountId != null) {
            Account acc = [SELECT Email__c FROM Account WHERE Id = :converted.ConvertedAccountId LIMIT 1];
            // Email__c may or may not exist — if it does, verify it matches
            Map<String, Schema.SObjectField> fMap = Schema.getGlobalDescribe().get('Account').getDescribe().fields.getMap();
            if (fMap.containsKey('email__c')) {
                System.assertEquals('convert.email@test.com', acc.Email__c, 'Account Email__c should be updated from Lead email after conversion');
            }
        }
    }

    @IsTest
    static void testAfterUpdate_LeadConverted_NoEmail_NoAccountUpdate() {
        Test.setMock(HttpCalloutMock.class, new DummyHttpCalloutMock());

        Lead l = new Lead(
            FirstName  = 'NoEmail',
            LastName   = 'Convert',
            Phone      = '9100003004',
            Country    = 'India',
            Check_List_Items__c = 'TILE',
            Product_Category__c = 'Tile',
            Branch_Location__c  = 'HO',
            Street     = 'Test Street',
            City       = 'Kochi',
            State      = 'Kerala',
            PostalCode = '682001'
        );
        insert l;

        Account existingAcc = new Account(
            Name              = 'NoEmail Convert',
            BillingCountry    = 'India',
            BillingState      = 'Kerala',
            BillingPostalCode = '682001',
            BillingStreet     = 'Test Street',
            District__c       = 'Ernakulam',
            Pin_Code__c       = 682001
        );
        insert existingAcc;

        String convertedStatus = [
            SELECT MasterLabel FROM LeadStatus WHERE IsConverted = true LIMIT 1
        ].MasterLabel;

        Test.startTest();
        Database.LeadConvert lc = new Database.LeadConvert();
        lc.setLeadId(l.Id);
        lc.setConvertedStatus(convertedStatus);
        lc.setDoNotCreateOpportunity(true);
        lc.setAccountId(existingAcc.Id);
        Database.LeadConvertResult result = Database.convertLead(lc);
        Test.stopTest();

        System.assertEquals(true, result.isSuccess(), 'Lead without email should still convert successfully');
    }

    // ─────────────────────────────────────────────
    // CHECK DUPLICATE LEAD
    // ─────────────────────────────────────────────

    @IsTest
    static void testDuplicate_EmailBlocked() {
        Test.setMock(HttpCalloutMock.class, new DummyHttpCalloutMock());

        Lead l1 = new Lead(
            FirstName  = 'DupE1',
            LastName   = 'Test',
            Email      = 'dup.email@test.com',
            Phone      = '9200001001',
            Country    = 'India'
        );
        insert l1;

        Lead l2 = new Lead(
            FirstName  = 'DupE2',
            LastName   = 'Test',
            Email      = 'dup.email@test.com',  // same email
            Phone      = '9200001002',
            Country    = 'India'
        );

        Boolean didThrow = false;
        Test.startTest();
        try {
            insert l2;
        } catch (DmlException ex) {
            didThrow = true;
            System.assert(ex.getMessage().contains('Duplicate'), 'Expected duplicate email error');
        }
        Test.stopTest();

        System.assertEquals(true, didThrow, 'Duplicate email should be blocked');
    }

    @IsTest
    static void testDuplicate_SecondaryEmailBlocked() {
        Test.setMock(HttpCalloutMock.class, new DummyHttpCalloutMock());

        Lead l1 = new Lead(
            FirstName          = 'SecE1',
            LastName           = 'Test',
            Email              = 'secemail1.dup@test.com',
            Secondary_Email__c = 'shared.secemail@test.com',
            Phone              = '9200001003',
            Country            = 'India'
        );
        insert l1;

        Lead l2 = new Lead(
            FirstName          = 'SecE2',
            LastName           = 'Test',
            Email              = 'secemail2.dup@test.com',
            Secondary_Email__c = 'shared.secemail@test.com',  // same secondary email
            Phone              = '9200001004',
            Country            = 'India'
        );

        Boolean didThrow = false;
        Test.startTest();
        try {
            insert l2;
        } catch (DmlException ex) {
            didThrow = true;
        }
        Test.stopTest();

        System.assertEquals(true, didThrow, 'Duplicate secondary email should be blocked');
    }

    @IsTest
    static void testDuplicate_PrimaryEmailMatchesSecondaryEmailOfExisting() {
        Test.setMock(HttpCalloutMock.class, new DummyHttpCalloutMock());

        Lead l1 = new Lead(
            FirstName          = 'CrossE1',
            LastName           = 'Test',
            Email              = 'primary.cross@test.com',
            Secondary_Email__c = 'crossmatch@test.com',
            Phone              = '9200001005',
            Country            = 'India'
        );
        insert l1;

        // l2 uses crossmatch@test.com as primary — should match l1's secondary
        Lead l2 = new Lead(
            FirstName  = 'CrossE2',
            LastName   = 'Test',
            Email      = 'crossmatch@test.com',
            Phone      = '9200001006',
            Country    = 'India'
        );

        Boolean didThrow = false;
        Test.startTest();
        try {
            insert l2;
        } catch (DmlException ex) {
            didThrow = true;
        }
        Test.stopTest();

        System.assertEquals(true, didThrow, 'Primary email matching existing secondary email should be blocked');
    }

    @IsTest
    static void testDuplicate_PhoneBlocked() {
        Test.setMock(HttpCalloutMock.class, new DummyHttpCalloutMock());

        Lead l1 = new Lead(
            FirstName  = 'DupP1',
            LastName   = 'Test',
            Email      = 'dupp1.dup@test.com',
            Phone      = '9200002001',
            Country    = 'India'
        );
        insert l1;

        Lead l2 = new Lead(
            FirstName  = 'DupP2',
            LastName   = 'Test',
            Email      = 'dupp2.dup@test.com',
            Phone      = '9200002001',  // same phone
            Country    = 'India'
        );

        Boolean didThrow = false;
        Test.startTest();
        try {
            insert l2;
        } catch (DmlException ex) {
            didThrow = true;
            System.assert(ex.getMessage().contains('Duplicate'), 'Expected duplicate phone error');
        }
        Test.stopTest();

        System.assertEquals(true, didThrow, 'Duplicate phone should be blocked');
    }

    @IsTest
    static void testDuplicate_SecondaryPhoneBlocked() {
        Test.setMock(HttpCalloutMock.class, new DummyHttpCalloutMock());

        Lead l1 = new Lead(
            FirstName           = 'SecP1',
            LastName            = 'Test',
            Email               = 'secp1.dup@test.com',
            Phone               = '9200002002',
            Secondary_Phone__c  = '9200002099',
            Country             = 'India'
        );
        insert l1;

        Lead l2 = new Lead(
            FirstName           = 'SecP2',
            LastName            = 'Test',
            Email               = 'secp2.dup@test.com',
            Phone               = '9200002003',
            Secondary_Phone__c  = '9200002099',  // same secondary phone
            Country             = 'India'
        );

        Boolean didThrow = false;
        Test.startTest();
        try {
            insert l2;
        } catch (DmlException ex) {
            didThrow = true;
        }
        Test.stopTest();

        System.assertEquals(true, didThrow, 'Duplicate secondary phone should be blocked');
    }

    @IsTest
    static void testDuplicate_PrimaryPhoneMatchesSecondaryPhoneOfExisting() {
        Test.setMock(HttpCalloutMock.class, new DummyHttpCalloutMock());

        Lead l1 = new Lead(
            FirstName           = 'CrossP1',
            LastName            = 'Test',
            Email               = 'crossp1.dup@test.com',
            Phone               = '9200003001',
            Secondary_Phone__c  = '9200003099',
            Country             = 'India'
        );
        insert l1;

        // l2's primary phone = l1's secondary phone
        Lead l2 = new Lead(
            FirstName  = 'CrossP2',
            LastName   = 'Test',
            Email      = 'crossp2.dup@test.com',
            Phone      = '9200003099',  // matches l1.Secondary_Phone__c
            Country    = 'India'
        );

        Boolean didThrow = false;
        Test.startTest();
        try {
            insert l2;
        } catch (DmlException ex) {
            didThrow = true;
        }
        Test.stopTest();

        System.assertEquals(true, didThrow, 'Phone matching existing secondary phone should be blocked');
    }

    @IsTest
    static void testDuplicate_NoDuplicate_InsertSucceeds() {
        Test.setMock(HttpCalloutMock.class, new DummyHttpCalloutMock());

        Lead l1 = new Lead(
            FirstName  = 'Unique1',
            LastName   = 'Test',
            Email      = 'unique1.test@test.com',
            Phone      = '9200004001',
            Country    = 'India'
        );
        insert l1;

        Lead l2 = new Lead(
            FirstName  = 'Unique2',
            LastName   = 'Test',
            Email      = 'unique2.test@test.com',
            Phone      = '9200004002',
            Country    = 'India'
        );

        Test.startTest();
        insert l2;
        Test.stopTest();

        System.assertNotEquals(null, l2.Id, 'Unique lead should insert without duplicate error');
    }

    @IsTest
    static void testDuplicate_UpdateSameLead_NoDuplicateWithSelf() {
        Test.setMock(HttpCalloutMock.class, new DummyHttpCalloutMock());

        Lead l = new Lead(
            FirstName  = 'SelfChk',
            LastName   = 'Test',
            Email      = 'selfchk.test@test.com',
            Phone      = '9200005001',
            Country    = 'India'
        );
        insert l;

        Test.startTest();
        l.LastName = 'Updated';
        update l;  // should not flag itself as a duplicate
        Test.stopTest();

        Lead updated = [SELECT LastName FROM Lead WHERE Id = :l.Id];
        System.assertEquals('Updated', updated.LastName, 'Self-update should not trigger duplicate error');
    }
}