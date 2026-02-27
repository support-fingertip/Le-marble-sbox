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
            Email = 'rahul.kumar@test.com'
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
            Country = 'India',
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
        System.assertEquals('India', convertedAccount.BillingCountry);
        System.assertEquals('test street', convertedContact.MailingStreet);
        System.assertEquals('test city', convertedContact.MailingCity);
        System.assertEquals('Karnataka', convertedContact.MailingState);
        System.assertEquals('890765', convertedContact.MailingPostalCode);
        System.assertEquals('India', convertedContact.MailingCountry);

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
            Country = 'India',
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
            Country = 'India',
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
            Country = 'India',
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
        assertTextLikeFieldEqualsIfPresent('Opportunity', result.get('opportunityId'), 'State__c', 'Kerala');
        assertTextLikeFieldEqualsIfPresent('Opportunity', result.get('opportunityId'), 'Pin_Code__c', '673001');
        assertTextLikeFieldEqualsIfPresent('Opportunity', result.get('opportunityId'), 'Country__c', 'India');
        assertFieldEqualsIfPresent('Opportunity', result.get('opportunityId'), 'GST_Number__c', '29ABCDE1234F1Z5');
    }

    @IsTest
    static void testConvertFailsWhenAddressMissing() {
        Lead leadRecord = new Lead(
            FirstName = 'Address',
            LastName = 'Missing',
            Company = 'No Address Co',
            Email = 'address.missing@test.com',
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