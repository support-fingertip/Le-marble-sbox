@IsTest
private class MobileLeadConversionControllerTest {
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
        Lead leadRecord = new Lead(
            FirstName = 'Anu',
            LastName = 'Sharma',
            Company = 'Initial Company',
            Email = 'anu.sharma@test.com',
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
}