@IsTest
public class LeadTriggerTest {


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

    // Test Lead before & after insert
    @IsTest
    static void testLeadInsert() {

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
        Sales_Executive__c = salesUser.Id
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

    // Test Lead before update logic
    @IsTest
    static void testLeadUpdate() {

        Lead l = new Lead(
            FirstName = 'Update',
            LastName = 'Lead',
            Email = 'updatelead@test.com',
            Phone = '9876543211',
            Status = 'Unqualified',
            Unqualified_Reason__c = 'Not Interested'
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

        System.assertEquals('', updatedLead.Unqualified_Reason__c);
        System.assertEquals('India', updatedLead.Country);
    }

    // Test duplicate validation execution (no failure)
    @IsTest
    static void testDuplicateLeadCheck() {

        Lead l1 = new Lead(
            FirstName = 'Dup',
            LastName = 'Lead',
            Email = 'dup@test.com',
            Phone = '9876543212'
        );
        insert l1;

        Lead l2 = new Lead(
            FirstName = 'Dup2',
            LastName = 'Lead',
            Email = 'dup2@test.com',
            Phone = '9876543213'
        );

        Test.startTest();
        insert l2;
        Test.stopTest();

        System.assertNotEquals(null, l2.Id);
    }
}