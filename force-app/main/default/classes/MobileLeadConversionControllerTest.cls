@IsTest
private class MobileLeadConversionControllerTest {
    private class DummyHttpCalloutMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse response = new HttpResponse();
            response.setStatusCode(200);
            response.setBody('{"status":"ok"}');
            return response;
        }
    }

    @testSetup
    static void setupData() {
        Account existingAccount = new Account(Name = 'Existing Conversion Account');
        insert existingAccount;

        Opportunity existingOpportunity = new Opportunity(
            Name = 'Existing Conversion Opportunity',
            AccountId = existingAccount.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30)
        );
        insert existingOpportunity;

        Contact existingContact = new Contact(
            FirstName = 'Existing',
            LastName = 'Contact',
            AccountId = existingAccount.Id,
            Email = 'existing.contact@test.com'
        );
        insert existingContact;
    }

    @IsTest
    static void testGetConversionContextAndSearch() {
        Lead leadRecord = new Lead(
            FirstName = 'Rahul',
            LastName = 'Kumar',
            Company = 'Lead Company',
            Email = 'rahul.kumar@test.com',
            Country__c = 'IN'
        );
        insert leadRecord;

        Test.startTest();
        Map<String, Object> contextData = MobileLeadConversionController.getConversionContext(leadRecord.Id);
        List<Account> accounts = MobileLeadConversionController.searchAccounts('Existing');
        Id accountId = ((Account)accounts[0]).Id;
        List<Contact> contacts = MobileLeadConversionController.searchContacts(accountId, 'Existing');
        List<Opportunity> opportunities = MobileLeadConversionController.searchOpportunities(accountId, 'Existing');
        Test.stopTest();

        System.assertEquals(leadRecord.Id, (Id)contextData.get('leadId'));
        System.assertNotEquals(null, contextData.get('defaultConvertedStatus'));
        System.assert(accounts.size() > 0, 'Expected account search results.');
        System.assert(contacts.size() > 0, 'Expected contact search results.');
        System.assert(opportunities.size() > 0, 'Expected opportunity search results.');
    }

    @IsTest
    static void testConvertWithNewAccountAndContact() {
        Test.setMock(HttpCalloutMock.class, new DummyHttpCalloutMock());

        Lead leadRecord = new Lead(
            FirstName = 'Anu',
            LastName = 'Sharma',
            Company = 'Initial Company',
            Email = 'anu.sharma@test.com',
            Phone = '(987) 654-3210',
            Street = 'test street',
            City = 'test city',
            State = 'Karnataka',
            PostalCode = '890765',
            Country = 'IN',
            Country__c = 'IN',
            Check_List_Items__c = 'TILE',
            Product_Category__c = 'Tile',
            Branch_Location__c = 'HO'
        );
        insert leadRecord;

        String convertedStatus = [
            SELECT MasterLabel
            FROM LeadStatus
            WHERE IsConverted = true
            LIMIT 1
        ].MasterLabel;

        Test.startTest();
        Map<String, Id> result = MobileLeadConversionController.convertLeadForMobile(
            leadRecord.Id,
            convertedStatus,
            UserInfo.getUserId(),
            false,
            null,
            'Converted Account',
            false,
            null,
            'Anu',
            'Sharma Converted',
            true,
            null,
            false,
            null
        );
        Test.stopTest();

        System.assertNotEquals(null, result.get('accountId'));
        System.assertNotEquals(null, result.get('contactId'));
        System.assertEquals(null, result.get('opportunityId'));

        Lead convertedLead = [SELECT IsConverted, ConvertedAccountId, ConvertedContactId FROM Lead WHERE Id = :leadRecord.Id];
        System.assertEquals(true, convertedLead.IsConverted);
        System.assertEquals(result.get('accountId'), convertedLead.ConvertedAccountId);
        System.assertEquals(result.get('contactId'), convertedLead.ConvertedContactId);

        Account convertedAccount = [
            SELECT Id, Phone, BillingStreet, BillingCity, BillingState, BillingPostalCode, BillingCountry
            FROM Account
            WHERE Id = :result.get('accountId')
        ];
        Contact convertedContact = [
            SELECT Id, Phone, MailingStreet, MailingCity, MailingState, MailingPostalCode, MailingCountry
            FROM Contact
            WHERE Id = :result.get('contactId')
        ];

        System.assertEquals('9876543210', convertedAccount.Phone, 'Expected Lead phone to be copied to new Account.');
        System.assertEquals('9876543210', convertedContact.Phone, 'Expected Lead phone to be copied to new Contact.');
        System.assertEquals('test street', convertedAccount.BillingStreet);
        System.assertEquals('test city', convertedAccount.BillingCity);
        System.assertEquals('Karnataka', convertedAccount.BillingState);
        System.assertEquals('890765', convertedAccount.BillingPostalCode);
        System.assertEquals('IN', convertedAccount.BillingCountry);
        System.assertEquals('test street', convertedContact.MailingStreet);
        System.assertEquals('test city', convertedContact.MailingCity);
        System.assertEquals('Karnataka', convertedContact.MailingState);
        System.assertEquals('890765', convertedContact.MailingPostalCode);
        System.assertEquals('IN', convertedContact.MailingCountry);

        assertFieldEqualsIfPresent('Account', result.get('accountId'), 'Branch_Location__c', 'HO');
        assertFieldEqualsIfPresent('Contact', result.get('contactId'), 'Branch_Location__c', 'HO');
        assertFieldEqualsIfPresent('Account', result.get('accountId'), 'Product_Category__c', 'Tile');
        assertFieldEqualsIfPresent('Contact', result.get('contactId'), 'Product_Category__c', 'Tile');
    }

    @IsTest
    static void testConvertWithExistingAccountAndContact() {
        Account existingAccount = [SELECT Id FROM Account WHERE Name = 'Existing Conversion Account' LIMIT 1];
        Contact existingContact = [SELECT Id, AccountId FROM Contact WHERE AccountId = :existingAccount.Id LIMIT 1];

        Lead leadRecord = new Lead(
            FirstName = 'Sita',
            LastName = 'Menon',
            Company = 'Another Company',
            Email = 'sita.menon@test.com',
            Street = 'Existing St',
            City = 'Kochi',
            State = 'Kerala',
            PostalCode = '682001',
            Country = 'IN',
            Country__c = 'IN',
            Check_List_Items__c = 'TILE',
            Product_Category__c = 'Tile',
            Branch_Location__c = 'HO'
        );
        insert leadRecord;

        String convertedStatus = [
            SELECT MasterLabel
            FROM LeadStatus
            WHERE IsConverted = true
            LIMIT 1
        ].MasterLabel;

        Test.startTest();
        Map<String, Id> result = MobileLeadConversionController.convertLeadForMobile(
            leadRecord.Id,
            convertedStatus,
            UserInfo.getUserId(),
            true,
            existingAccount.Id,
            null,
            true,
            existingContact.Id,
            null,
            null,
            true,
            null,
            false,
            null
        );
        Test.stopTest();

        System.assertEquals(existingAccount.Id, result.get('accountId'));
        System.assertEquals(existingContact.Id, result.get('contactId'));

        Lead convertedLead = [SELECT IsConverted, ConvertedAccountId, ConvertedContactId FROM Lead WHERE Id = :leadRecord.Id];
        System.assertEquals(true, convertedLead.IsConverted);
        System.assertEquals(existingAccount.Id, convertedLead.ConvertedAccountId);
        System.assertEquals(existingContact.Id, convertedLead.ConvertedContactId);
    }

    @IsTest
    static void testConvertWithExistingOpportunity() {
        Account existingAccount = new Account(Name = 'Opportunity Link Account');
        insert existingAccount;

        Contact existingContact = new Contact(
            FirstName = 'Opportunity',
            LastName = 'Linked Contact',
            AccountId = existingAccount.Id
        );
        insert existingContact;

        Opportunity existingOpportunity = new Opportunity(
            Name = 'Opportunity Link Existing Opp',
            AccountId = existingAccount.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(20)
        );
        insert existingOpportunity;

        Lead leadRecord = new Lead(
            FirstName = 'Dev',
            LastName = 'Patel',
            Company = 'Sample Company',
            Email = 'dev.patel@test.com',
            Street = 'Opp Street',
            City = 'Bengaluru',
            State = 'Karnataka',
            PostalCode = '560001',
            Country = 'IN',
            Country__c = 'IN',
            Check_List_Items__c = 'TILE',
            Product_Category__c = 'Tile',
            Branch_Location__c = 'HO'
        );
        insert leadRecord;

        String convertedStatus = [
            SELECT MasterLabel
            FROM LeadStatus
            WHERE IsConverted = true
            LIMIT 1
        ].MasterLabel;

        Test.startTest();
        Map<String, Id> result = MobileLeadConversionController.convertLeadForMobile(
            leadRecord.Id,
            convertedStatus,
            UserInfo.getUserId(),
            true,
            existingAccount.Id,
            null,
            true,
            existingContact.Id,
            null,
            null,
            false,
            null,
            true,
            existingOpportunity.Id
        );
        Test.stopTest();

        System.assertEquals(existingOpportunity.Id, result.get('opportunityId'));
        System.assertEquals(existingAccount.Id, result.get('accountId'));
        System.assertEquals(existingContact.Id, result.get('contactId'));

        Integer roleCount = [
            SELECT COUNT()
            FROM OpportunityContactRole
            WHERE OpportunityId = :existingOpportunity.Id
            AND ContactId = :existingContact.Id
        ];
        System.assert(roleCount > 0, 'Expected contact role link to existing opportunity.');
    }

    @IsTest
    static void testConvertWithNewOpportunityMapsMissingFields() {
        Account existingAccount = new Account(Name = 'Mapped Opp Account');
        insert existingAccount;

        Contact existingContact = new Contact(
            FirstName = 'Mapped',
            LastName = 'Contact',
            AccountId = existingAccount.Id
        );
        insert existingContact;

        Opportunity existingOpportunity = new Opportunity(
            Name = 'Mapped Existing Opp',
            AccountId = existingAccount.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(15)
        );
        insert existingOpportunity;

        Lead leadRecord = new Lead(
            FirstName = 'Nila',
            LastName = 'Thomas',
            Company = 'Nila Interiors',
            Email = 'nila.thomas@test.com',
            Street = 'Map Street',
            City = 'Kozhikode',
            State = 'Kerala',
            PostalCode = '673001',
            Country = 'IN',
            Country__c = 'IN',
            Description = 'Opportunity conversion notes',
            Check_List_Items__c = 'TILE',
            Product_Category__c = 'Tile',
            Branch_Location__c = 'Vengeri',
            GST_Number__c = '29ABCDE1234F1Z5'
        );
        insert leadRecord;

        String convertedStatus = [
            SELECT MasterLabel
            FROM LeadStatus
            WHERE IsConverted = true
            LIMIT 1
        ].MasterLabel;

        Test.startTest();
        Map<String, Id> result = MobileLeadConversionController.convertLeadForMobile(
            leadRecord.Id,
            convertedStatus,
            UserInfo.getUserId(),
            true,
            existingAccount.Id,
            null,
            true,
            existingContact.Id,
            null,
            null,
            false,
            'Nila Opportunity',
            true,
            existingOpportunity.Id
        );
        Test.stopTest();

        System.assertEquals(existingOpportunity.Id, result.get('opportunityId'));

        Opportunity convertedOpportunity = [
            SELECT Id, Description
            FROM Opportunity
            WHERE Id = :result.get('opportunityId')
            LIMIT 1
        ];

        System.assertEquals('Opportunity conversion notes', convertedOpportunity.Description);
        assertTextLikeFieldEqualsIfPresent('Opportunity', result.get('opportunityId'), 'AddressLine1__c', 'Map Street');
        assertTextLikeFieldEqualsIfPresent('Opportunity', result.get('opportunityId'), 'Place__c', 'Kozhikode');
        assertTextLikeFieldEqualsIfPresent('Opportunity', result.get('opportunityId'), 'Pin_Code__c', '673001');
        assertFieldEqualsIfPresent('Opportunity', result.get('opportunityId'), 'GST_Number__c', '29ABCDE1234F1Z5');
    }

    @IsTest
    static void testConvertFailsWhenAddressMissing() {
        Lead leadRecord = new Lead(
            FirstName = 'Address',
            LastName = 'Missing',
            Company = 'No Address Co',
            Email = 'address.missing@test.com',
            Country__c = 'IN',
            Check_List_Items__c = 'TILE',
            Product_Category__c = 'Tile',
            Branch_Location__c = 'HO'
        );
        insert leadRecord;

        String convertedStatus = [
            SELECT MasterLabel
            FROM LeadStatus
            WHERE IsConverted = true
            LIMIT 1
        ].MasterLabel;

        Boolean didThrow = false;

        Test.startTest();
        try {
            MobileLeadConversionController.convertLeadForMobile(
                leadRecord.Id,
                convertedStatus,
                UserInfo.getUserId(),
                false,
                null,
                'No Address Account',
                false,
                null,
                'Address',
                'Missing',
                true,
                null,
                false,
                null
            );
        } catch (AuraHandledException ex) {
            didThrow = true;
            System.assert(String.isNotBlank(ex.getMessage()));
        }
        Test.stopTest();

        System.assertEquals(true, didThrow, 'Expected conversion to fail when Lead address is missing.');
    }

    @IsTest
    static void testConvertFailsWhenChecklistMissing() {
        Lead leadRecord = new Lead(
            FirstName = 'No',
            LastName = 'Checklist',
            Company = 'Validation Company',
            Email = 'no.checklist@test.com',
            Country__c = 'IN',
            Product_Category__c = 'Tile',
            Branch_Location__c = 'HO'
        );
        insert leadRecord;

        String convertedStatus = [
            SELECT MasterLabel
            FROM LeadStatus
            WHERE IsConverted = true
            LIMIT 1
        ].MasterLabel;

        Boolean didThrow = false;

        Test.startTest();
        try {
            MobileLeadConversionController.convertLeadForMobile(
                leadRecord.Id,
                convertedStatus,
                UserInfo.getUserId(),
                false,
                null,
                'Validation Account',
                false,
                null,
                'No',
                'Checklist',
                true,
                null,
                false,
                null
            );
        } catch (AuraHandledException ex) {
            didThrow = true;
            System.assert(String.isNotBlank(ex.getMessage()));
        }
        Test.stopTest();

        System.assertEquals(true, didThrow, 'Expected conversion to fail when checklist is missing.');
    }

    // =====================
    // TEST: getConversionContext — null leadId throws
    // =====================
    @IsTest
    static void testGetConversionContextNullLeadId() {
        Boolean didThrow = false;
        Test.startTest();
        try {
            MobileLeadConversionController.getConversionContext(null);
        } catch (AuraHandledException ex) {
            didThrow = true;
        }
        Test.stopTest();
        System.assertEquals(true, didThrow, 'Expected AuraHandledException for null leadId');
    }

    // =====================
    // TEST: searchAccounts — blank / too-short search returns empty
    // =====================
    @IsTest
    static void testSearchAccountsBlankAndShortTerm() {
        Test.startTest();
        List<Account> blankResult = MobileLeadConversionController.searchAccounts('');
        List<Account> shortResult = MobileLeadConversionController.searchAccounts('A');
        Test.stopTest();
        System.assertEquals(0, blankResult.size(), 'Blank search should return empty');
        System.assertEquals(0, shortResult.size(), 'Single-char search should return empty');
    }

    // =====================
    // TEST: searchContacts / searchOpportunities — null accountId returns empty
    // =====================
    @IsTest
    static void testSearchContactsAndOpportunitiesNullParams() {
        Test.startTest();
        List<Contact> contacts = MobileLeadConversionController.searchContacts(null, 'Test');
        List<Opportunity> opps = MobileLeadConversionController.searchOpportunities(null, 'Test');
        List<Contact> contactsBlank = MobileLeadConversionController.searchContacts(
            [SELECT Id FROM Account LIMIT 1].Id, ''
        );
        Test.stopTest();
        System.assertEquals(0, contacts.size(), 'Null accountId should return empty contacts');
        System.assertEquals(0, opps.size(), 'Null accountId should return empty opportunities');
        System.assertEquals(0, contactsBlank.size(), 'Blank searchTerm should return empty');
    }

    // =====================
    // TEST: getContactSummary — happy path and null Id
    // =====================
    @IsTest
    static void testGetContactSummary() {
        Contact c = [SELECT Id FROM Contact LIMIT 1];
        Test.startTest();
        Contact result = MobileLeadConversionController.getContactSummary(c.Id);
        Contact nullResult = MobileLeadConversionController.getContactSummary(null);
        Test.stopTest();
        System.assertNotEquals(null, result, 'Should return contact for valid Id');
        System.assertEquals(c.Id, result.Id);
        System.assertEquals(null, nullResult, 'Should return null for null Id');
    }

    // =====================
    // TEST: getOpportunitySummary — happy path and null Id
    // =====================
    @IsTest
    static void testGetOpportunitySummary() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Test.startTest();
        Opportunity result = MobileLeadConversionController.getOpportunitySummary(opp.Id);
        Opportunity nullResult = MobileLeadConversionController.getOpportunitySummary(null);
        Test.stopTest();
        System.assertNotEquals(null, result, 'Should return opportunity for valid Id');
        System.assertEquals(opp.Id, result.Id);
        System.assertEquals(null, nullResult, 'Should return null for null Id');
    }

    // =====================
    // TEST: convertLeadForMobile — null leadId throws
    // =====================
    @IsTest
    static void testConvertLeadNullId() {
        Boolean didThrow = false;
        Test.startTest();
        try {
            MobileLeadConversionController.convertLeadForMobile(
                null, 'Converted', UserInfo.getUserId(),
                false, null, 'Some Account',
                false, null, 'First', 'Last',
                true, null, false, null
            );
        } catch (AuraHandledException ex) {
            didThrow = true;
        }
        Test.stopTest();
        System.assertEquals(true, didThrow, 'Expected exception for null leadId');
    }

    // =====================
    // TEST: convertLeadForMobile — useExistingAccount=true but no account Id
    // =====================
    @IsTest
    static void testConvertUseExistingAccountNoId() {
        Lead lead = new Lead(FirstName = 'Test', LastName = 'Guard1', Company = 'Guard Co 1', Country__c = 'IN');
        insert lead;
        String status = [SELECT MasterLabel FROM LeadStatus WHERE IsConverted = true LIMIT 1].MasterLabel;

        Boolean didThrow = false;
        Test.startTest();
        try {
            MobileLeadConversionController.convertLeadForMobile(
                lead.Id, status, UserInfo.getUserId(),
                true, null, null,       // useExistingAccount=true, no existingAccountId
                false, null, 'First', 'Last',
                true, null, false, null
            );
        } catch (AuraHandledException ex) {
            didThrow = true;
        }
        Test.stopTest();
        System.assertEquals(true, didThrow, 'Expected exception for missing existing account Id');
    }

    // =====================
    // TEST: convertLeadForMobile — useExistingAccount=false but blank newAccountName
    // =====================
    @IsTest
    static void testConvertBlankAccountName() {
        Lead lead = new Lead(FirstName = 'Test', LastName = 'Guard2', Company = 'Guard Co 2', Country__c = 'IN');
        insert lead;
        String status = [SELECT MasterLabel FROM LeadStatus WHERE IsConverted = true LIMIT 1].MasterLabel;

        Boolean didThrow = false;
        Test.startTest();
        try {
            MobileLeadConversionController.convertLeadForMobile(
                lead.Id, status, UserInfo.getUserId(),
                false, null, '',        // useExistingAccount=false, blank name
                false, null, 'First', 'Last',
                true, null, false, null
            );
        } catch (AuraHandledException ex) {
            didThrow = true;
        }
        Test.stopTest();
        System.assertEquals(true, didThrow, 'Expected exception for blank account name');
    }

    // =====================
    // TEST: convertLeadForMobile — useExistingContact=true but no contact Id
    // =====================
    @IsTest
    static void testConvertUseExistingContactNoId() {
        Lead lead = new Lead(FirstName = 'Test', LastName = 'Guard3', Company = 'Guard Co 3', Country__c = 'IN');
        insert lead;
        String status = [SELECT MasterLabel FROM LeadStatus WHERE IsConverted = true LIMIT 1].MasterLabel;

        Boolean didThrow = false;
        Test.startTest();
        try {
            MobileLeadConversionController.convertLeadForMobile(
                lead.Id, status, UserInfo.getUserId(),
                false, null, 'Some Account',
                true, null, 'First', 'Last',  // useExistingContact=true, no existingContactId
                true, null, false, null
            );
        } catch (AuraHandledException ex) {
            didThrow = true;
        }
        Test.stopTest();
        System.assertEquals(true, didThrow, 'Expected exception for missing existing contact Id');
    }

    // =====================
    // TEST: convertLeadForMobile — useExistingContact=false but blank newContactLastName
    // =====================
    @IsTest
    static void testConvertBlankContactLastName() {
        Lead lead = new Lead(FirstName = 'Test', LastName = 'Guard4', Company = 'Guard Co 4', Country__c = 'IN');
        insert lead;
        String status = [SELECT MasterLabel FROM LeadStatus WHERE IsConverted = true LIMIT 1].MasterLabel;

        Boolean didThrow = false;
        Test.startTest();
        try {
            MobileLeadConversionController.convertLeadForMobile(
                lead.Id, status, UserInfo.getUserId(),
                false, null, 'Some Account',
                false, null, 'First', '',   // blank last name
                true, null, false, null
            );
        } catch (AuraHandledException ex) {
            didThrow = true;
        }
        Test.stopTest();
        System.assertEquals(true, didThrow, 'Expected exception for blank contact last name');
    }

    // =====================
    // TEST: convertLeadForMobile — useExistingOpportunity=true but no opportunity Id
    // =====================
    @IsTest
    static void testConvertUseExistingOpportunityNoId() {
        Lead lead = new Lead(FirstName = 'Test', LastName = 'Guard5', Company = 'Guard Co 5', Country__c = 'IN');
        insert lead;
        String status = [SELECT MasterLabel FROM LeadStatus WHERE IsConverted = true LIMIT 1].MasterLabel;

        Boolean didThrow = false;
        Test.startTest();
        try {
            MobileLeadConversionController.convertLeadForMobile(
                lead.Id, status, UserInfo.getUserId(),
                false, null, 'Some Account',
                false, null, 'First', 'Last',
                false, 'Some Opportunity',
                true, null              // useExistingOpportunity=true, no existingOpportunityId
            );
        } catch (AuraHandledException ex) {
            didThrow = true;
        }
        Test.stopTest();
        System.assertEquals(true, didThrow, 'Expected exception for missing existing opportunity Id');
    }

    // =====================
    // TEST: convertLeadForMobile — doNotCreateOpportunity=false but blank opportunityName
    // =====================
    @IsTest
    static void testConvertBlankOpportunityName() {
        Lead lead = new Lead(FirstName = 'Test', LastName = 'Guard6', Company = 'Guard Co 6', Country__c = 'IN');
        insert lead;
        String status = [SELECT MasterLabel FROM LeadStatus WHERE IsConverted = true LIMIT 1].MasterLabel;

        Boolean didThrow = false;
        Test.startTest();
        try {
            MobileLeadConversionController.convertLeadForMobile(
                lead.Id, status, UserInfo.getUserId(),
                false, null, 'Some Account',
                false, null, 'First', 'Last',
                false, '',              // doNotCreateOpportunity=false, blank opp name
                false, null
            );
        } catch (AuraHandledException ex) {
            didThrow = true;
        }
        Test.stopTest();
        System.assertEquals(true, didThrow, 'Expected exception for blank opportunity name');
    }

    // =====================
    // TEST: convertLeadForMobile — India MobilePhone != 10 digits throws
    // =====================
    @IsTest
    static void testConvertMobilePhoneValidationFails() {
        Test.setMock(HttpCalloutMock.class, new DummyHttpCalloutMock());
        Lead lead = new Lead(
            FirstName = 'Mobile',
            LastName = 'Bad',
            Company = 'Mobile Phone Test Co',
            MobilePhone = '999',        // only 3 digits
            Street = 'Mobile Street',
            City = 'Pune',
            State = 'Maharashtra',
            PostalCode = '411001',
            Country = 'IN',
            Country__c = 'IN',
            Check_List_Items__c = 'TILE',
            Product_Category__c = 'Tile',
            Branch_Location__c = 'HO'
        );
        insert lead;
        String status = [SELECT MasterLabel FROM LeadStatus WHERE IsConverted = true LIMIT 1].MasterLabel;

        Boolean didThrow = false;
        Test.startTest();
        try {
            MobileLeadConversionController.convertLeadForMobile(
                lead.Id, status, UserInfo.getUserId(),
                false, null, 'Mobile Phone Test Account',
                false, null, 'Mobile', 'Bad',
                true, null, false, null
            );
        } catch (AuraHandledException ex) {
            didThrow = true;
        }
        Test.stopTest();
        System.assertEquals(true, didThrow, 'Expected phone validation exception for India lead with short mobile phone');
    }

    // =====================
    // TEST: convertLeadForMobile — India phone != 10 digits throws
    // =====================
    @IsTest
    static void testConvertPhoneValidationFails() {
        Test.setMock(HttpCalloutMock.class, new DummyHttpCalloutMock());
        Lead lead = new Lead(
            FirstName = 'Phone',
            LastName = 'Bad',
            Company = 'Phone Test Co',
            Phone = '12345',            // only 5 digits
            Street = 'Phone Street',
            City = 'Chennai',
            State = 'Tamil Nadu',
            PostalCode = '600001',
            Country = 'IN',
            Country__c = 'IN',
            Check_List_Items__c = 'TILE',
            Product_Category__c = 'Tile',
            Branch_Location__c = 'HO'
        );
        insert lead;
        String status = [SELECT MasterLabel FROM LeadStatus WHERE IsConverted = true LIMIT 1].MasterLabel;

        Boolean didThrow = false;
        Test.startTest();
        try {
            MobileLeadConversionController.convertLeadForMobile(
                lead.Id, status, UserInfo.getUserId(),
                false, null, 'Phone Test Account',
                false, null, 'Phone', 'Bad',
                true, null, false, null
            );
        } catch (AuraHandledException ex) {
            didThrow = true;
        }
        Test.stopTest();
        System.assertEquals(true, didThrow, 'Expected phone validation exception for India lead');
    }

    // =====================
    // TEST: convertLeadForMobile — converts with new Opportunity created
    // =====================
    @IsTest
    static void testConvertWithNewOpportunity() {
        Test.setMock(HttpCalloutMock.class, new DummyHttpCalloutMock());
        Lead lead = new Lead(
            FirstName = 'NewOpp',
            LastName = 'Convert',
            Company = 'NewOpp Corp',
            Phone = '9876543210',
            Street = 'Opp Lane',
            City = 'Hyderabad',
            State = 'Telangana',
            PostalCode = '500001',
            Country = 'IN',
            Country__c = 'IN',
            Check_List_Items__c = 'TILE',
            Product_Category__c = 'Tile',
            Branch_Location__c = 'HO'
        );
        insert lead;
        String status = [SELECT MasterLabel FROM LeadStatus WHERE IsConverted = true LIMIT 1].MasterLabel;

        Test.startTest();
        Map<String, Id> result = MobileLeadConversionController.convertLeadForMobile(
            lead.Id,
            status,
            UserInfo.getUserId(),
            false, null, 'NewOpp Corporation',
            false, null, 'NewOpp', 'Convert',
            false, 'New Test Opportunity',  // doNotCreateOpportunity=false, with name
            false, null
        );
        Test.stopTest();

        System.assertNotEquals(null, result.get('accountId'), 'Account should be created');
        System.assertNotEquals(null, result.get('contactId'), 'Contact should be created');
        System.assertNotEquals(null, result.get('opportunityId'), 'Opportunity should be created');

        Lead converted = [SELECT IsConverted, ConvertedOpportunityId FROM Lead WHERE Id = :lead.Id];
        System.assertEquals(true, converted.IsConverted, 'Lead should be converted');
        System.assertEquals(result.get('opportunityId'), converted.ConvertedOpportunityId);
    }

    // =====================
    // TEST: convertLeadForMobile — auto-selects convertedStatus when blank provided
    // =====================
    @IsTest
    static void testConvertAutoSelectsConvertedStatus() {
        Lead lead = new Lead(
            FirstName = 'AutoStatus',
            LastName = 'Test',
            Company = 'AutoStatus Corp',
            Street = 'Auto Street',
            City = 'Pune',
            State = 'Maharashtra',
            PostalCode = '411001',
            Country = 'IN',
            Country__c = 'IN',
            Check_List_Items__c = 'TILE',
            Product_Category__c = 'Tile',
            Branch_Location__c = 'HO'
        );
        insert lead;

        Test.startTest();
        // Pass blank convertedStatus — controller should auto-pick from org config
        Map<String, Id> result = MobileLeadConversionController.convertLeadForMobile(
            lead.Id,
            '',                         // blank — auto-select
            UserInfo.getUserId(),
            false, null, 'AutoStatus Account',
            false, null, 'AutoStatus', 'Test',
            true, null, false, null
        );
        Test.stopTest();

        System.assertNotEquals(null, result.get('accountId'), 'Account should be created');
        Lead converted = [SELECT IsConverted FROM Lead WHERE Id = :lead.Id];
        System.assertEquals(true, converted.IsConverted, 'Lead should be converted with auto-selected status');
    }

    private static void assertFieldEqualsIfPresent(String objectApiName, Id recordId, String fieldApiName, Object expectedValue) {
        if (recordId == null) {
            return;
        }

        Map<String, Schema.SObjectType> globalDescribe = Schema.getGlobalDescribe();
        if (!globalDescribe.containsKey(objectApiName)) {
            return;
        }

        Map<String, Schema.SObjectField> fieldMap = globalDescribe.get(objectApiName).getDescribe().fields.getMap();
        if (!fieldMap.containsKey(fieldApiName)) {
            return;
        }

        SObject queriedRecord = Database.query(
            'SELECT ' + fieldApiName +
            ' FROM ' + objectApiName +
            ' WHERE Id = :recordId LIMIT 1'
        );

        System.assertEquals(
            expectedValue,
            queriedRecord.get(fieldApiName),
            'Expected field mapping for ' + objectApiName + '.' + fieldApiName
        );
    }

    private static void assertTextLikeFieldEqualsIfPresent(String objectApiName, Id recordId, String fieldApiName, String expectedValue) {
        if (recordId == null) {
            return;
        }

        Map<String, Schema.SObjectType> globalDescribe = Schema.getGlobalDescribe();
        if (!globalDescribe.containsKey(objectApiName)) {
            return;
        }

        Map<String, Schema.SObjectField> fieldMap = globalDescribe.get(objectApiName).getDescribe().fields.getMap();
        if (!fieldMap.containsKey(fieldApiName)) {
            return;
        }

        Schema.DisplayType fieldType = fieldMap.get(fieldApiName).getDescribe().getType();
        Set<Schema.DisplayType> textLikeTypes = new Set<Schema.DisplayType>{
            Schema.DisplayType.String,
            Schema.DisplayType.TextArea,
            Schema.DisplayType.Phone,
            Schema.DisplayType.Email,
            Schema.DisplayType.Url,
            Schema.DisplayType.EncryptedString,
            Schema.DisplayType.Picklist,
            Schema.DisplayType.MultiPicklist
        };

        if (!textLikeTypes.contains(fieldType)) {
            return;
        }

        assertFieldEqualsIfPresent(objectApiName, recordId, fieldApiName, expectedValue);
    }
}