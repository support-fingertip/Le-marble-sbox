@isTest
public class CustomerWhatsappTriggerTest {

    @isTest
    static void testTrigger_With10DigitNumber() {
        Customer__c cust = new Customer__c(
            Name = 'Test 1',
            Lead_Name__c = 'Lead Test 1',
            Primary_Phone__c = '9876543210',
            Phone__c = '9876543210'
        );

        Test.startTest();
        insert cust;
        Test.stopTest();

        System.assertNotEquals(null, cust.Id);
    }

    @isTest
    static void testTrigger_With91PrefixedNumber() {
        Customer__c cust = new Customer__c(
            Name = 'Test 2',
            Lead_Name__c = 'Lead Test 2',
            Primary_Phone__c = '919876543210',
            Phone__c = '919876543210'
        );

        Test.startTest();
        insert cust;
        Test.stopTest();

        System.assertNotEquals(null, cust.Id);
    }

    @isTest
    static void testTrigger_WithSpecialCharacters() {
        Customer__c cust = new Customer__c(
            Name = 'Test 3',
            Lead_Name__c = 'Lead Test 3',
            Primary_Phone__c = '+91-98765-43210',
            Phone__c = '+91-98765-43210'
        );

        Test.startTest();
        insert cust;
        Test.stopTest();

        System.assertNotEquals(null, cust.Id);
    }

    @isTest
    static void testTrigger_WithNullPhone() {
        Customer__c cust = new Customer__c(
            Name = 'Test 4',
            Lead_Name__c = 'Lead Test 4',
            Primary_Phone__c = '9876543211'
            // Phone__c intentionally null
        );

        Test.startTest();
        insert cust;
        Test.stopTest();

        System.assertNotEquals(null, cust.Id);
    }
}