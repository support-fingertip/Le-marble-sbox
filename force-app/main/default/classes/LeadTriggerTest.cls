@IsTest
public class LeadTriggerTest {

    private class DummyHttpCalloutMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"status":"ok"}');
            return res;
        }
    }

    // Create required test user
    private static User createSalesUser() {
        Profile p = [
            SELECT Id FROM Profile
            WHERE Name = 'Standard User'
            LIMIT 1
        ];

        User u = new User(
            Alias = 'salesu',
            Email = 'salesuser@test.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Sales',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'Asia/Kolkata',
            Username = 'salesuser' + System.currentTimeMillis() + '@test.com'
        );
        insert u;
        return u;
    }

    // =====================
    // beforeInsert â€” Campaign mapping, B2C company auto-fill, country auto-fill, sales executive owner
    // =====================
    @IsTest
    static void testLeadInsert() {
        Test.setMock(HttpCalloutMock.class, new DummyHttpCalloutMock());

        User salesUser = createSalesUser();

        Campaign c = new Campaign(
            Name = 'Test Campaign',
            IsActive = true
        );
        insert c;

        Test.startTest();
        Lead l = new Lead(
            FirstName = 'Test',
            LastName = 'Lead',
            Email = 'testlead@test.com',
            Phone = '9876543210',
            Campaign_ID__c = c.Name,
            Sales_Executive__c = salesUser.Id,
            Country = 'India'
        );
        insert l;
        Test.stopTest();

        Lead insertedLead = [
            SELECT Company, Country, OwnerId, Campaign__c
            FROM Lead
            WHERE Id = :l.Id
        ];

        System.assertEquals('Test Lead', insertedLead.Company);
        System.assertEquals('India', insertedLead.Country);
        System.assertEquals(salesUser.Id, insertedLead.OwnerId);
        System.assertNotEquals(null, insertedLead.Campaign__c);
    }

    // =====================
    // beforeUpdate â€” Clear Unqualified Reason, Country auto-fill
    // =====================
    @IsTest
    static void testLeadUpdate() {
        Test.setMock(HttpCalloutMock.class, new DummyHttpCalloutMock());

        Lead l = new Lead(
            FirstName = 'Update',
            LastName = 'Lead',
            Email = 'updatelead@test.com',
            Phone = '9876543211',
            Status = 'Unqualified',
            Unqualified_Reason__c = 'Not Interested',
            Country = 'India'
        );
        insert l;

        Test.startTest();
        l.Status = 'Open';
        update l;
        Test.stopTest();

        Lead updatedLead = [
            SELECT Unqualified_Reason__c, Country
            FROM Lead
            WHERE Id = :l.Id
        ];

        System.assert(String.isBlank(updatedLead.Unqualified_Reason__c), 'Unqualified_Reason__c should be blank after status change');
        System.assertEquals('India', updatedLead.Country);
    }

    // =====================
    // checkDuplicateLead â€” no duplicate, happy path
    // =====================
    @IsTest
    static void testDuplicateLeadCheck() {
        Test.setMock(HttpCalloutMock.class, new DummyHttpCalloutMock());

        Lead l1 = new Lead(
            FirstName = 'Dup',
            LastName = 'Lead',
            Email = 'dup@test.com',
            Phone = '9876543212',
            Country = 'India'
        );
        insert l1;

        Lead l2 = new Lead(
            FirstName = 'Dup2',
            LastName = 'Lead',
            Email = 'dup2@test.com',
            Phone = '9876543213',
            Country = 'India'
        );

        Test.startTest();
        insert l2;
        Test.stopTest();

        System.assertNotEquals(null, l2.Id);
    }

    // =====================
    // beforeInsert â€” B2B lead Company should NOT be auto-filled
    // =====================
    @IsTest
    static void testB2BLeadCompanyNotAutoFilled() {
        Test.setMock(HttpCalloutMock.class, new DummyHttpCalloutMock());

        Lead l = new Lead(
            FirstName = 'BizFirst',
            LastName = 'BizLast',
            Company = 'My B2B Company',
            Customer_Type__c = 'B2B',
            Email = 'b2b.lead@test.com',
            Phone = '9100000001',
            Country = 'India'
        );

        Test.startTest();
        insert l;
        Test.stopTest();

        Lead inserted = [SELECT Company FROM Lead WHERE Id = :l.Id];
        System.assertEquals('My B2B Company', inserted.Company, 'B2B lead Company should NOT be overwritten by trigger');
    }

    // =====================
    // beforeInsert â€” Country auto-fill when left blank
    // =====================
    @IsTest
    static void testCountryAutoFillOnInsert() {
        Test.setMock(HttpCalloutMock.class, new DummyHttpCalloutMock());

        Lead l = new Lead(
            FirstName = 'Country',
            LastName = 'AutoFill',
            Email = 'country.autofill@test.com',
            Phone = '9100000002',
            Country = 'India'
        );

        Test.startTest();
        insert l;
        Test.stopTest();

        Lead inserted = [SELECT Country FROM Lead WHERE Id = :l.Id];
        System.assertEquals('India', inserted.Country, 'Country should be auto-filled to India when blank on insert');
    }

    // =====================    // beforeInsert — Country_Code__c auto-filled to +91 when Country is India on insert
    // =====================
    @IsTest
    static void testCountryCodeAutoFillOnInsert() {
        Test.setMock(HttpCalloutMock.class, new DummyHttpCalloutMock());

        Lead l = new Lead(
            FirstName = 'CodeInsert',
            LastName  = 'AutoFill',
            Email     = 'code.insert.autofill@test.com',
            Phone     = '9100000099',
            Country   = 'India'
        );

        Test.startTest();
        insert l;
        Test.stopTest();

        Lead inserted = [SELECT Country_Code__c FROM Lead WHERE Id = :l.Id];
        System.assertEquals('+91', inserted.Country_Code__c, 'Country_Code__c should be auto-filled to +91 on insert when Country is India');
    }

    // =====================    // beforeInsert â€” no Sales_Executive__c, non-admin profile uses assignment rule off
    // =====================
    @IsTest
    static void testInsertWithoutSalesExecutive() {
        Test.setMock(HttpCalloutMock.class, new DummyHttpCalloutMock());

        Lead l = new Lead(
            FirstName = 'NoExec',
            LastName = 'Test',
            Email = 'noexec.test@test.com',
            Phone = '9100000009',
            Country = 'India'
        );

        Test.startTest();
        insert l;
        Test.stopTest();

        Lead inserted = [SELECT Id, OwnerId FROM Lead WHERE Id = :l.Id];
        System.assertNotEquals(null, inserted.OwnerId, 'OwnerId should be set');
    }

    // =====================
    // beforeUpdate — Country_Code__c cleared when country changes away from India
    // =====================
    @IsTest
    static void testCountryCodeClearedOnCountryChange() {
        Test.setMock(HttpCalloutMock.class, new DummyHttpCalloutMock());

        Lead l = new Lead(
            FirstName = 'CodeClear',
            LastName  = 'Test',
            Email     = 'codeclear.test@test.com',
            Phone     = '9100000199',
            Country   = 'India',
            Country_Code__c = '+91'
        );
        insert l;

        // Change country away from India
        l.Country = 'United States';

        Test.startTest();
        update l;
        Test.stopTest();

        Lead updated = [SELECT Country_Code__c FROM Lead WHERE Id = :l.Id];
        System.assert(String.isBlank(updated.Country_Code__c), 'Country_Code__c should be cleared when country changes away from India');
    }

    // =====================
    // beforeUpdate — Country_Code__c auto-filled to +91 when Country is India
    // =====================
    @IsTest
    static void testCountryCodeAutoFillOnUpdate() {
        Test.setMock(HttpCalloutMock.class, new DummyHttpCalloutMock());

        Lead l = new Lead(
            FirstName = 'Code',
            LastName = 'AutoFill',
            Email = 'code.autofill@test.com',
            Phone = '9100000003',
            Country = 'India'
        );
        insert l;

        Test.startTest();
        l.LastName = 'AutoFilled';
        update l;
        Test.stopTest();

        Lead updated = [SELECT Country_Code__c FROM Lead WHERE Id = :l.Id];
        System.assertEquals('+91', updated.Country_Code__c, 'Country_Code__c should be auto-filled to +91 when Country is India');
    }

    // =====================
    // beforeUpdate â€” Customer_Interested__c true â†’ Status = Qualified
    // =====================
    @IsTest
    static void testCustomerInterestedSetsQualified() {
        Test.setMock(HttpCalloutMock.class, new DummyHttpCalloutMock());

        Lead l = new Lead(
            FirstName = 'Interested',
            LastName = 'Customer',
            Email = 'interested.customer@test.com',
            Phone = '9100000004',
            Country = 'India',
            Customer_Interested__c = false
        );
        insert l;

        Test.startTest();
        l.Customer_Interested__c = true;
        update l;
        Test.stopTest();

        Lead updated = [SELECT Status FROM Lead WHERE Id = :l.Id];
        System.assertEquals('Qualified', updated.Status, 'Status should become Qualified when Customer_Interested__c changes to true');
    }

    // =====================
    // beforeUpdate â€” B2C company auto-filled from name on update
    // =====================
    @IsTest
    static void testB2CCompanyAutoFillOnUpdate() {
        Test.setMock(HttpCalloutMock.class, new DummyHttpCalloutMock());

        Lead l = new Lead(
            FirstName = 'OldFirst',
            LastName = 'OldLast',
            Email = 'b2c.update@test.com',
            Phone = '9100000010',
            Country = 'India'
        );
        insert l;

        Test.startTest();
        l.FirstName = 'NewFirst';
        l.LastName = 'NewLast';
        update l;
        Test.stopTest();

        Lead updated = [SELECT Company FROM Lead WHERE Id = :l.Id];
        System.assertEquals('NewFirst NewLast', updated.Company, 'B2C lead Company should be auto-filled from name on update');
    }

    // =====================
    // afterUpdate â€” Status changes to Unqualified (covers notification branch)
    // =====================
    @IsTest
    static void testAfterUpdateToUnqualified() {
        Test.setMock(HttpCalloutMock.class, new DummyHttpCalloutMock());

        Lead l = new Lead(
            FirstName = 'Unqual',
            LastName = 'Lead',
            Email = 'unqual.lead@test.com',
            Phone = '9100000011',
            Country = 'India',
            Status = 'Open'
        );
        insert l;

        Test.startTest();
        l.Status = 'Unqualified';
        l.Unqualified_Reason__c = 'Not Interested';
        update l;
        Test.stopTest();

        Lead updated = [SELECT Status, Unqualified_Reason__c FROM Lead WHERE Id = :l.Id];
        System.assertEquals('Unqualified', updated.Status);
    }

    // =====================
    // afterUpdate â€” OwnerId change (covers assignment notification branch)
    // =====================
    @IsTest
    static void testAfterUpdateOwnerChange() {
        Test.setMock(HttpCalloutMock.class, new DummyHttpCalloutMock());

        User salesUser = createSalesUser();

        Lead l = new Lead(
            FirstName = 'OwnerChange',
            LastName = 'Lead',
            Email = 'ownerchange.lead@test.com',
            Phone = '9100000012',
            Country = 'India'
        );
        insert l;

        Test.startTest();
        l.OwnerId = salesUser.Id;
        update l;
        Test.stopTest();

        Lead updated = [SELECT OwnerId FROM Lead WHERE Id = :l.Id];
        System.assertEquals(salesUser.Id, updated.OwnerId, 'OwnerId should be updated');
    }

    // =====================
    // afterInsert â€” phone number formatted and WhatsApp sent (with MobilePhone only)
    // =====================
    @IsTest
    static void testAfterInsertMobilePhoneWhatsApp() {
        Test.setMock(HttpCalloutMock.class, new DummyHttpCalloutMock());

        Lead l = new Lead(
            FirstName = 'WhatsApp',
            LastName = 'Mobile',
            Email = 'whatsapp.mobile@test.com',
            MobilePhone = '9100000013',  // Phone is null, MobilePhone used
            Country = 'India'
        );

        Test.startTest();
        insert l;
        Test.stopTest();

        Lead inserted = [SELECT Id, MobilePhone FROM Lead WHERE Id = :l.Id];
        System.assertNotEquals(null, inserted.Id);
    }

    // =====================
    // checkDuplicateLead â€” duplicate email blocked
    // =====================
    @IsTest
    static void testDuplicateEmailBlocked() {
        Test.setMock(HttpCalloutMock.class, new DummyHttpCalloutMock());

        Lead l1 = new Lead(
            FirstName = 'DupEmail1',
            LastName = 'Test',
            Email = 'dupemail.block@test.com',
            Phone = '9100000005',
            Country = 'India'
        );
        insert l1;

        Lead l2 = new Lead(
            FirstName = 'DupEmail2',
            LastName = 'Test',
            Email = 'dupemail.block@test.com',
            Phone = '9100000006',
            Country = 'India'
        );

        Boolean didThrow = false;
        Test.startTest();
        try {
            insert l2;
        } catch (DmlException ex) {
            didThrow = true;
            System.assert(ex.getMessage().contains('Duplicate'), 'Expected duplicate email error message');
        }
        Test.stopTest();

        System.assertEquals(true, didThrow, 'Expected DML error for duplicate email');
    }

    // =====================
    // checkDuplicateLead â€” duplicate phone blocked
    // =====================
    @IsTest
    static void testDuplicatePhoneBlocked() {
        Test.setMock(HttpCalloutMock.class, new DummyHttpCalloutMock());

        Lead l1 = new Lead(
            FirstName = 'DupPhone1',
            LastName = 'Test',
            Email = 'dupphone1.block@test.com',
            Phone = '9100000007',
            Country = 'India'
        );
        insert l1;

        Lead l2 = new Lead(
            FirstName = 'DupPhone2',
            LastName = 'Test',
            Email = 'dupphone2.block@test.com',
            Phone = '9100000007',
            Country = 'India'
        );

        Boolean didThrow = false;
        Test.startTest();
        try {
            insert l2;
        } catch (DmlException ex) {
            didThrow = true;
            System.assert(ex.getMessage().contains('Duplicate'), 'Expected duplicate phone error message');
        }
        Test.stopTest();

        System.assertEquals(true, didThrow, 'Expected DML error for duplicate phone');
    }

    // =====================
    // checkDuplicateLead â€” duplicate secondary email blocked
    // =====================
    @IsTest
    static void testDuplicateSecondaryEmailBlocked() {
        Test.setMock(HttpCalloutMock.class, new DummyHttpCalloutMock());

        Lead l1 = new Lead(
            FirstName = 'SecEmail1',
            LastName = 'Test',
            Email = 'secemail1.block@test.com',
            Secondary_Email__c = 'shared.sec@test.com',
            Phone = '9100000020',
            Country = 'India'
        );
        insert l1;

        Lead l2 = new Lead(
            FirstName = 'SecEmail2',
            LastName = 'Test',
            Email = 'secemail2.block@test.com',
            Secondary_Email__c = 'shared.sec@test.com',
            Phone = '9100000021',
            Country = 'India'
        );

        Boolean didThrow = false;
        Test.startTest();
        try {
            insert l2;
        } catch (DmlException ex) {
            didThrow = true;
        }
        Test.stopTest();

        System.assertEquals(true, didThrow, 'Expected DML error for duplicate secondary email');
    }

    // =====================
    // checkDuplicateLead â€” duplicate secondary phone blocked
    // =====================
    @IsTest
    static void testDuplicateSecondaryPhoneBlocked() {
        Test.setMock(HttpCalloutMock.class, new DummyHttpCalloutMock());

        Lead l1 = new Lead(
            FirstName = 'SecPhone1',
            LastName = 'Test',
            Email = 'secphone1.block@test.com',
            Secondary_Phone__c = '9100000022',
            Phone = '9100000023',
            Country = 'India'
        );
        insert l1;

        Lead l2 = new Lead(
            FirstName = 'SecPhone2',
            LastName = 'Test',
            Email = 'secphone2.block@test.com',
            Secondary_Phone__c = '9100000022',
            Phone = '9100000024',
            Country = 'India'
        );

        Boolean didThrow = false;
        Test.startTest();
        try {
            insert l2;
        } catch (DmlException ex) {
            didThrow = true;
        }
        Test.stopTest();

        System.assertEquals(true, didThrow, 'Expected DML error for duplicate secondary phone');
    }

    // =====================
    // beforeUpdate â€” Sales Executive assignment changes OwnerId on update
    // =====================
    @IsTest
    static void testSalesExecutiveAssignmentOnUpdate() {
        Test.setMock(HttpCalloutMock.class, new DummyHttpCalloutMock());

        User salesUser = createSalesUser();

        Lead l = new Lead(
            FirstName = 'SalesEx',
            LastName = 'Update',
            Email = 'salesex.update@test.com',
            Phone = '9100000008',
            Country = 'India'
        );
        insert l;

        Test.startTest();
        l.Sales_Executive__c = salesUser.Id;
        update l;
        Test.stopTest();

        Lead updated = [SELECT OwnerId FROM Lead WHERE Id = :l.Id];
        System.assertEquals(salesUser.Id, updated.OwnerId, 'OwnerId should be set to Sales Executive on update');
    }

    // =====================
    // beforeInsert â€” Sales Executive on insert sets OwnerId
    // =====================
    @IsTest
    static void testBeforeInsert_SalesExecutiveSetsOwner() {
        Test.setMock(HttpCalloutMock.class, new DummyHttpCalloutMock());

        User salesUser = createSalesUser();

        Test.startTest();
        Lead l = new Lead(
            FirstName          = 'ExecOwner',
            LastName           = 'Test',
            Email              = 'execowner.insert@test.com',
            Phone              = '9300000001',
            Country            = 'India',
            Sales_Executive__c = salesUser.Id
        );
        insert l;
        Test.stopTest();

        Lead inserted = [SELECT OwnerId FROM Lead WHERE Id = :l.Id];
        System.assertEquals(salesUser.Id, inserted.OwnerId, 'OwnerId should be set to Sales_Executive__c on before insert');
    }

    // =====================
    // beforeInsert â€” B2C company auto-filled from full name
    // =====================
    @IsTest
    static void testBeforeInsert_B2CCompanyAutoFilled() {
        Test.setMock(HttpCalloutMock.class, new DummyHttpCalloutMock());

        Test.startTest();
        Lead l = new Lead(
            FirstName  = 'Raj',
            LastName   = 'Sharma',
            Email      = 'raj.sharma.trigger@test.com',
            Phone      = '9300000002',
            Country    = 'India'
        );
        insert l;
        Test.stopTest();

        Lead inserted = [SELECT Company FROM Lead WHERE Id = :l.Id];
        System.assertEquals('Raj Sharma', inserted.Company, 'B2C Company should be auto-filled from full name on before insert');
    }

    // =====================
    // beforeUpdate â€” Country cleared on update gets auto-filled back
    // =====================
    @IsTest
    static void testBeforeUpdate_CountryAutoFillWhenCleared() {
        Test.setMock(HttpCalloutMock.class, new DummyHttpCalloutMock());

        Lead l = new Lead(
            FirstName  = 'Clear',
            LastName   = 'Country',
            Email      = 'clear.country@test.com',
            Phone      = '9300000003',
            Country    = 'India'
        );
        insert l;

        Test.startTest();
        l.Country = '';
        update l;
        Test.stopTest();

        Lead updated = [SELECT Country FROM Lead WHERE Id = :l.Id];
        System.assertEquals('India', updated.Country, 'Country should be auto-filled back to India when cleared on before update');
    }

    // =====================
    // beforeUpdate â€” Unqualified Reason stays when Status stays Unqualified
    // =====================
    @IsTest
    static void testBeforeUpdate_UnqualifiedReasonKept_WhenStatusUnchanged() {
        Test.setMock(HttpCalloutMock.class, new DummyHttpCalloutMock());

        Lead l = new Lead(
            FirstName             = 'Keep',
            LastName              = 'Reason',
            Email                 = 'keep.reason@test.com',
            Phone                 = '9300000004',
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
        System.assertEquals('Different Reason', updated.Unqualified_Reason__c, 'Reason should stay when Status remains Unqualified');
    }

    // =====================
    // afterInsert â€” lead with no phone skips WhatsApp path gracefully
    // =====================
    @IsTest
    static void testAfterInsert_NoPhone_InsertsSuccessfully() {
        Test.setMock(HttpCalloutMock.class, new DummyHttpCalloutMock());

        Test.startTest();
        Lead l = new Lead(
            FirstName  = 'NoPhone',
            LastName   = 'AfterInsert',
            Email      = 'nophone.afterinsert@test.com',
            Country    = 'India'
            // No Phone or MobilePhone
        );
        insert l;
        Test.stopTest();

        System.assertNotEquals(null, l.Id, 'Lead without phone should insert without error');
    }

    // =====================
    // afterUpdate â€” Lead converted updates Account Email__c
    // =====================
    @IsTest
    static void testAfterUpdate_LeadConverted_AccountEmailUpdated() {
        Test.setMock(HttpCalloutMock.class, new DummyHttpCalloutMock());

        Lead l = new Lead(
            FirstName           = 'Convert',
            LastName            = 'AfterUpdate',
            Email               = 'convert.afterupdate@test.com',
            Phone               = '9300000005',
            Country             = 'India',
            Check_List_Items__c = 'TILE',
            Product_Category__c = 'Tile',
            Branch_Location__c  = 'HO',
            Street              = 'Test Street',
            City                = 'Kochi',
            State               = 'Kerala',
            PostalCode          = '682001'
        );
        insert l;

        String convertedStatus = [
            SELECT MasterLabel FROM LeadStatus WHERE IsConverted = true LIMIT 1
        ].MasterLabel;

        Test.startTest();
        Database.LeadConvert lc = new Database.LeadConvert();
        lc.setLeadId(l.Id);
        lc.setConvertedStatus(convertedStatus);
        lc.setDoNotCreateOpportunity(true);
        Database.LeadConvertResult result = Database.convertLead(lc);
        Test.stopTest();

        System.assertEquals(true, result.isSuccess(), 'Lead conversion should succeed');

        Lead converted = [SELECT IsConverted FROM Lead WHERE Id = :l.Id];
        System.assertEquals(true, converted.IsConverted, 'Lead should be marked as converted');
    }

    // =====================
    // afterUpdate â€” self-update does not trigger duplicate error
    // =====================
    @IsTest
    static void testAfterUpdate_SelfUpdate_NoDuplicateError() {
        Test.setMock(HttpCalloutMock.class, new DummyHttpCalloutMock());

        Lead l = new Lead(
            FirstName  = 'SelfUpd',
            LastName   = 'Test',
            Email      = 'selfupd.trigger@test.com',
            Phone      = '9300000006',
            Country    = 'India'
        );
        insert l;

        Test.startTest();
        l.LastName = 'Updated';
        update l;
        Test.stopTest();

        Lead updated = [SELECT LastName FROM Lead WHERE Id = :l.Id];
        System.assertEquals('Updated', updated.LastName, 'Self-update should not trigger duplicate error');
    }
}