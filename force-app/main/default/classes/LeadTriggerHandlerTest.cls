@IsTest
public class LeadTriggerHandlerTest {

    /* ============================================
       TEST SETUP
    ============================================ */
    @TestSetup
    static void setupData() {

        // Campaign
        Campaign camp = new Campaign(
            Name = 'Digital_' + System.currentTimeMillis(),
            IsActive = true
        );
        insert camp;

        // User
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];

        User u = new User(
            FirstName = 'Sales',
            LastName = 'Exec',
            Email = 'sales' + System.currentTimeMillis() + '@test.com',
            Username = 'sales' + System.currentTimeMillis() + '@test.com',
            Alias = 'salex',
            TimeZoneSidKey = 'Asia/Kolkata',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = p.Id,
            LanguageLocaleKey = 'en_US'
        );
        insert u;
    }


    /* ============================================
       BEFORE INSERT TEST
    ============================================ */
    @IsTest
    static void testBeforeInsert() {

        Campaign camp = [SELECT Id, Name FROM Campaign LIMIT 1];
        User u = [SELECT Id FROM User LIMIT 1];

        Lead l = new Lead(
            FirstName = 'John',
            LastName = 'Doe',
            Company = 'TempCompany',
            Campaign_ID__c = camp.Name,
            Customer_Type__c = 'B2C',
            Sales_Executive__c = u.Id,
            Email = 'john' + System.currentTimeMillis() + '@test.com',
            Phone = '9876543210',
            Country = 'India',
            Country_Code__c = '+91'
        );

        Test.startTest();
        insert l;
        Test.stopTest();

        Lead inserted = [
            SELECT Campaign__c, Company, OwnerId, Country, Country_Code__c
            FROM Lead WHERE Id = :l.Id
        ];

        System.assertEquals('India', inserted.Country);
        System.assertEquals('+91', inserted.Country_Code__c);
        System.assertEquals(u.Id, inserted.OwnerId);
        System.assertEquals(camp.Id, inserted.Campaign__c);
    }


    /* ============================================
       DUPLICATE CHECK TEST
    ============================================ */
    @IsTest
    static void testDuplicateCheck() {

        String email = 'dup' + System.currentTimeMillis() + '@test.com';

        Lead l1 = new Lead(
            LastName = 'Test1',
            Company = 'ABC',
            Email = email,
            Country = 'India',
            Country_Code__c = '+91'
        );
        insert l1;

        Lead l2 = new Lead(
            LastName = 'Test2',
            Company = 'XYZ',
            Email = email,
            Country = 'India',
            Country_Code__c = '+91'
        );

        Database.SaveResult sr = Database.insert(l2, false);

        System.assert(!sr.isSuccess());
    }


    /* ============================================
       BEFORE UPDATE TEST
    ============================================ */
    @IsTest
    static void testBeforeUpdate() {

        Lead l = new Lead(
            LastName = 'UpdateTest',
            Company = 'ABC',
            Status = 'Unqualified',
            Unqualified_Reason__c = 'Reason',
            Customer_Interested__c = false,
            Country = 'India',
            Country_Code__c = '+91'
        );
        insert l;

        l.Status = 'Open';
        l.Customer_Interested__c = true;

        Test.startTest();
        update l;
        Test.stopTest();

        Lead updated = [
            SELECT Status, Unqualified_Reason__c
            FROM Lead WHERE Id = :l.Id
        ];

        System.assertEquals('Qualified', updated.Status);
        System.assertEquals(null, updated.Unqualified_Reason__c);
    }


    /* ============================================
       OWNER CHANGE TEST
    ============================================ */
    @IsTest
    static void testOwnerChange() {

        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];

        User u2 = new User(
            FirstName = 'New',
            LastName = 'Owner',
            Email = 'owner' + System.currentTimeMillis() + '@test.com',
            Username = 'owner' + System.currentTimeMillis() + '@test.com',
            Alias = 'newow',
            TimeZoneSidKey = 'Asia/Kolkata',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = p.Id,
            LanguageLocaleKey = 'en_US'
        );
        insert u2;

        Lead l = new Lead(
            LastName = 'OwnerChange',
            Company = 'ABC',
            Email = 'own' + System.currentTimeMillis() + '@test.com',
            Country = 'India',
            Country_Code__c = '+91'
        );
        insert l;

        l.OwnerId = u2.Id;
        update l;

        Lead updated = [SELECT OwnerId FROM Lead WHERE Id = :l.Id];

        System.assertEquals(u2.Id, updated.OwnerId);
    }
}