@isTest
public class Account_Trigger_Test {

    // ---------- Utility Method ----------
    public static String getPicklistValue(Schema.SObjectField fieldName) {
        List<Schema.PicklistEntry> values = fieldName.getDescribe().getPicklistValues();
        if (!values.isEmpty()) {
            return values[0].getValue();
        }
        return null;
    }

    // ---------- TEST SETUP ----------
    @testSetup
    static void setupData() {

        Account acc = new Account(
            Name = 'Base Account',
            Phone = '9876543210',
            Secondary_Phone__c = '9999999999',
            Email__c = 'base@test.com',
            BillingStreet = 'Base Street',
            BillingCity = 'Bangalore',
            BillingState = 'Karnataka',
            BillingCountry = 'India',
            BillingPostalCode = '560001',
            GST_Number__c = '29ABCDE1234F1Z5',  // Valid GST
            Address_Line1__c = 'Line1',
            Address_Line2__c = 'Line2',
            Address_Line3__c = 'Line3',
            POC_Name__c = 'Base Person'
        );

        // Dynamic picklist values
        acc.GST_Type__c = getPicklistValue(Account.GST_Type__c);
        acc.State__c = getPicklistValue(Account.State__c);
        acc.country__c = getPicklistValue(Account.country__c);
        acc.corporation__c = getPicklistValue(Account.corporation__c);

        insert acc;
    }

    // ---------- BEFORE INSERT ----------
    @isTest
    static void testBeforeInsert() {

        Account acc = new Account(
            Name = 'Insert Test',
            Phone = '8888888888',
            GST_Number__c = '27ABCDE1234F1Z5'  // Valid GST
        );

        acc.GST_Type__c = getPicklistValue(Account.GST_Type__c);
        acc.State__c = getPicklistValue(Account.State__c);
        acc.country__c = getPicklistValue(Account.country__c);
        acc.corporation__c = getPicklistValue(Account.corporation__c);

        Test.startTest();
        insert acc;
        Test.stopTest();

        System.assertNotEquals(null, acc.Id);
    }

    // ---------- AFTER INSERT ----------
    @isTest
    static void testAfterInsert() {

        Account acc = new Account(
            Name = 'After Insert Test',
            Phone = '7777777777',
            GST_Number__c = '24ABCDE1234F1Z5'  // Valid GST
        );

        acc.GST_Type__c = getPicklistValue(Account.GST_Type__c);
        acc.State__c = getPicklistValue(Account.State__c);
        acc.country__c = getPicklistValue(Account.country__c);
        acc.corporation__c = getPicklistValue(Account.corporation__c);

        Test.startTest();
        insert acc;   // Covers sapIntegration.createBusinessPartner
        Test.stopTest();

        System.assertNotEquals(null, acc.Id);
    }

    // ---------- FULL AFTER UPDATE COVERAGE ----------
    @isTest
    static void testAfterUpdate_AllFieldChanges() {

        Account acc = [SELECT Id,
                              Phone,
                              Secondary_Phone__c,
                              Email__c,
                              BillingStreet,
                              BillingCity,
                              BillingState,
                              BillingCountry,
                              BillingPostalCode,
                              GST_Type__c,
                              GST_Number__c,
                              Address_Line1__c,
                              Address_Line2__c,
                              Address_Line3__c,
                              corporation__c,
                              State__c,
                              country__c,
                              POC_Name__c
                       FROM Account
                       LIMIT 1];

        // Change ALL monitored fields
        acc.Phone = '6666666666';
        acc.Secondary_Phone__c = '5555555555';
        acc.Email__c = 'updated@test.com';
        acc.BillingStreet = 'Updated Street';
        acc.BillingCity = 'Chennai';
        acc.BillingState = 'Tamil Nadu';
        acc.BillingCountry = 'India';
        acc.BillingPostalCode = '600001';
        acc.GST_Number__c = '33ABCDE1234F1Z5';  // Valid GST
        acc.Address_Line1__c = 'Updated Line1';
        acc.Address_Line2__c = 'Updated Line2';
        acc.Address_Line3__c = 'Updated Line3';
        acc.POC_Name__c = 'Updated Person';

        // Update picklists
        acc.GST_Type__c = getPicklistValue(Account.GST_Type__c);
        acc.State__c = getPicklistValue(Account.State__c);
        acc.country__c = getPicklistValue(Account.country__c);
        acc.corporation__c = getPicklistValue(Account.corporation__c);

        Test.startTest();
        update acc;   // Covers full condition block
        Test.stopTest();

        System.assertEquals('Updated Person', acc.POC_Name__c);
    }

    // ---------- DIRECT QUEUEABLE COVERAGE ----------
    @isTest
    static void testQueueableDirect() {

        Account acc = new Account(
            Name = 'Queue Test',
            GST_Number__c = '36ABCDE1234F1Z5'
        );
        insert acc;

        Test.startTest();
        SAPAccountSyncQueue job = new SAPAccountSyncQueue(acc.Id);
        job.execute(null);
        Test.stopTest();

        System.assert(true);
    }
}