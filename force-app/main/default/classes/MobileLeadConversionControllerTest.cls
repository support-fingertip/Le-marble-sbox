@IsTest
private class MobileLeadConversionControllerTest {

    /* =========================================================
       Helper: Get Valid Converted Status
    ========================================================= */
    private static String getConvertedStatus() {
        return [
            SELECT MasterLabel
            FROM LeadStatus
            WHERE IsConverted = true
            LIMIT 1
        ].MasterLabel;
    }

    /* =========================================================
       Helper: Get Valid Checklist Picklist Value
    ========================================================= */
    private static String getValidChecklistValue() {
        Schema.DescribeFieldResult fieldDescribe =
            Lead.Check_List_Items__c.getDescribe();

        List<Schema.PicklistEntry> entries =
            fieldDescribe.getPicklistValues();

        if (!entries.isEmpty()) {
            return entries[0].getValue();
        }

        return null;
    }

    /* =========================================================
       Helper: Create Valid Lead
    ========================================================= */
   private static Lead createValidLead() {

    // Get valid checklist value
    String checklistValue;
    for (Schema.PicklistEntry pe :
         Lead.Check_List_Items__c.getDescribe().getPicklistValues()) {
        if (pe.isActive()) {
            checklistValue = pe.getValue();
            break;
        }
    }

    Lead l = new Lead(
        FirstName = 'Test',
        LastName = 'Lead',
        Company = 'Test Company',
        Status = 'Open - Not Contacted',
        Phone = '9876543210',
        MobilePhone = '9876543210',
        Street = 'Street',
        City = 'City',
        State = 'State',
        PostalCode = '123456',
        Country = 'India',
        Check_List_Items__c = checklistValue
    );

    // Only set Country_Code__c if field exists and required
    if (Schema.SObjectType.Lead.fields.getMap().containsKey('Country_Code__c')) {

        List<Schema.PicklistEntry> codes =
            Lead.Country_Code__c.getDescribe().getPicklistValues();

        for (Schema.PicklistEntry pe : codes) {

            // If India exists, prefer that
            if (pe.getValue().contains('91')) {
                l.Country_Code__c = pe.getValue();
                break;
            }
        }

        // If nothing matched, just assign first active value
        if (l.Country_Code__c == null && !codes.isEmpty()) {
            l.Country_Code__c = codes[0].getValue();
        }
    }

    insert l;
    return l;
}

    /* =========================================================
       Test: getConversionContext
    ========================================================= */
    @IsTest
    static void testGetConversionContext() {

        Lead l = createValidLead();

        Test.startTest();
        Map<String,Object> result =
            MobileLeadConversionController.getConversionContext(l.Id);
        Test.stopTest();

        System.assertEquals(l.Id, result.get('leadId'));
        System.assertNotEquals(null, result.get('convertedStatuses'));
        System.assertNotEquals(null, result.get('defaultOpportunityName'));
    }

    /* =========================================================
       Test: Search Methods
    ========================================================= */
    @IsTest
    static void testSearchMethods() {

        Account acc = new Account(Name='SearchAccount');
        insert acc;

        Contact con = new Contact(
            FirstName='Search',
            LastName='Contact',
            AccountId=acc.Id
        );
        insert con;

        Opportunity opp = new Opportunity(
            Name='SearchOpp',
            StageName='Prospecting',
            CloseDate=Date.today().addDays(5),
            AccountId=acc.Id
        );
        insert opp;

        Test.startTest();

        System.assertEquals(1,
            MobileLeadConversionController.searchAccounts('Search').size());

        System.assertEquals(1,
            MobileLeadConversionController.searchContacts(acc.Id,'Search').size());

        System.assertEquals(1,
            MobileLeadConversionController.searchOpportunities(acc.Id,'Search').size());

        System.assertEquals(con.Id,
            MobileLeadConversionController.getContactSummary(con.Id).Id);

        System.assertEquals(opp.Id,
            MobileLeadConversionController.getOpportunitySummary(opp.Id).Id);

        Test.stopTest();
    }

    /* =========================================================
       Test: Convert Lead - New Account/Contact/Opportunity
    ========================================================= */
    @IsTest
    static void testConvertLead_NewAll() {

        Lead l = createValidLead();
        String convertedStatus = getConvertedStatus();

        Test.startTest();
        Map<String,Id> result =
            MobileLeadConversionController.convertLeadForMobile(
                l.Id,
                convertedStatus,
                null,
                false, null, 'New Account',
                false, null, 'First', 'Last',
                false,
                'New Opportunity',
                false, null
            );
        Test.stopTest();

        System.assertNotEquals(null, result.get('accountId'));
        System.assertNotEquals(null, result.get('contactId'));
        System.assertNotEquals(null, result.get('opportunityId'));
    }

    /* =========================================================
       Test: Convert Lead - Existing Account
    ========================================================= */
    @IsTest
    static void testConvertLead_ExistingAccount() {

        Lead l = createValidLead();
        Account acc = new Account(Name='ExistingAcc');
        insert acc;

        String convertedStatus = getConvertedStatus();

        Test.startTest();
        Map<String,Id> result =
            MobileLeadConversionController.convertLeadForMobile(
                l.Id,
                convertedStatus,
                null,
                true, acc.Id, null,
                false, null, 'First', 'Last',
                true,
                null,
                false, null
            );
        Test.stopTest();

        System.assertEquals(acc.Id, result.get('accountId'));
    }

    /* =========================================================
       Test: Validation - Missing Checklist
    ========================================================= */
    @IsTest
    static void testValidation_MissingChecklist() {

        Lead l = new Lead(
            FirstName = 'No',
            LastName = 'Checklist',
            Company = 'Test',
            Status = 'Open - Not Contacted',
            Street = 'Street',
            City = 'City',
            State = 'State',
            PostalCode = '123456',
            Country = 'India'
        );
        insert l;

        String convertedStatus = getConvertedStatus();

        Test.startTest();
        try {
            MobileLeadConversionController.convertLeadForMobile(
                l.Id,
                convertedStatus,
                null,
                false, null, 'Acc',
                false, null, 'F', 'L',
                false,
                'Opp',
                false, null
            );
            System.assert(false);
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Checklist'));
        }
        Test.stopTest();
    }

    /* =========================================================
       Test: Validation - Invalid Indian Phone
    ========================================================= */
    @IsTest
    static void testValidation_InvalidPhone() {

        Lead l = createValidLead();
        l.Phone = '123'; // invalid
        update l;

        String convertedStatus = getConvertedStatus();

        Test.startTest();
        try {
            MobileLeadConversionController.convertLeadForMobile(
                l.Id,
                convertedStatus,
                null,
                false, null, 'Acc',
                false, null, 'F', 'L',
                false,
                'Opp',
                false, null
            );
            System.assert(false);
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Phone'));
        }
        Test.stopTest();
    }
}