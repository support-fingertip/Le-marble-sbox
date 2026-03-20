@IsTest
public class OpportunityContactRoleTriggerTest {

    // Utility: Get first valid picklist value
    private static String getPicklistValue(Schema.SObjectField field) {
        List<Schema.PicklistEntry> values =
            field.getDescribe().getPicklistValues();

        return values.isEmpty() ? null : values[0].getValue();
    }

    @TestSetup
    static void setupData() {

        Account acc = new Account(Name = 'Test Account');
        insert acc;

        Contact con1 = new Contact(
            FirstName = 'John',
            LastName = 'Doe',
            Phone = '9999999999',
            AccountId = acc.Id
        );

        Contact con2 = new Contact(
            FirstName = 'Jane',
            LastName = 'Smith',
            Phone = '8888888888',
            AccountId = acc.Id
        );

        insert new List<Contact>{con1, con2};

        String branchValue =
            getPicklistValue(Opportunity.Branch_Location__c);

        String productValue =
            getPicklistValue(Opportunity.Product_Category__c);

        Opportunity opp1 = new Opportunity(
            Name = 'Test Opp 1',
            AccountId = acc.Id,
            StageName = 'Prospecting',
            CloseDate = System.today().addDays(10),
            Branch_Location__c = branchValue,
            Product_Category__c = productValue
        );

        Opportunity opp2 = new Opportunity(
            Name = 'Test Opp 2',
            AccountId = acc.Id,
            StageName = 'Prospecting',
            CloseDate = System.today().addDays(15)
        );

        insert new List<Opportunity>{opp1, opp2};
    }

    @IsTest
    static void testPrimaryContactRole() {

        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Contact con = [SELECT Id, Name, Phone FROM Contact LIMIT 1];

        Test.startTest();

        insert new OpportunityContactRole(
            OpportunityId = opp.Id,
            ContactId = con.Id,
            Role = 'Decision Maker',
            IsPrimary = true
        );

        Test.stopTest();

        Opportunity updatedOpp = [
            SELECT Contact_Person_Name__c, Contact_Number__c
            FROM Opportunity
            WHERE Id = :opp.Id
        ];

        System.assertEquals(con.Name, updatedOpp.Contact_Person_Name__c);
        System.assertEquals(con.Phone, updatedOpp.Contact_Number__c);
    }

    @IsTest
    static void testNonPrimary_NoUpdate() {

        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Contact con = [SELECT Id FROM Contact LIMIT 1];

        insert new OpportunityContactRole(
            OpportunityId = opp.Id,
            ContactId = con.Id,
            Role = 'Influencer',
            IsPrimary = false
        );

        Opportunity result = [
            SELECT Contact_Person_Name__c
            FROM Opportunity
            WHERE Id = :opp.Id
        ];

        System.assertEquals(null, result.Contact_Person_Name__c);
    }

    @IsTest
    static void testAlreadyPopulated_NoOverwrite() {

        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Contact con = [SELECT Id FROM Contact LIMIT 1];

        update new Opportunity(
            Id = opp.Id,
            Contact_Person_Name__c = 'Existing'
        );

        insert new OpportunityContactRole(
            OpportunityId = opp.Id,
            ContactId = con.Id,
            Role = 'Decision Maker',
            IsPrimary = true
        );

        Opportunity result = [
            SELECT Contact_Person_Name__c
            FROM Opportunity
            WHERE Id = :opp.Id
        ];

        System.assertEquals('Existing', result.Contact_Person_Name__c);
    }

    @IsTest
    static void testBulkInsert() {

        List<Opportunity> opps = [SELECT Id FROM Opportunity];
        Contact con = [SELECT Id FROM Contact LIMIT 1];

        List<OpportunityContactRole> ocrList = new List<OpportunityContactRole>();

        for (Opportunity opp : opps) {
            ocrList.add(new OpportunityContactRole(
                OpportunityId = opp.Id,
                ContactId = con.Id,
                Role = 'Decision Maker',
                IsPrimary = true
            ));
        }

        Test.startTest();
        insert ocrList;
        Test.stopTest();

        List<Opportunity> updatedOpps =
            [SELECT Contact_Person_Name__c FROM Opportunity];

        for (Opportunity opp : updatedOpps) {
            System.assertNotEquals(null, opp.Contact_Person_Name__c);
        }
    }
}