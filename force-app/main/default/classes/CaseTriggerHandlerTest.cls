@isTest
public class CaseTriggerHandlerTest {

    // ===============================
    // Test 1: Status = 'New' with Phone
    // ===============================
    @isTest
    static void testHandleAfterInsert_StatusNew_WithPhone() {

        Customer__c testCustomer = new Customer__c(
            Lead_Name__c = 'Test Lead 1',
            Primary_Phone__c = '9876543210',
            Phone__c = '9876543210'
        );
        insert testCustomer;

        Case testCase = new Case(
            Subject = 'Test Case 1',
            Status = 'New',
            Lead__c = testCustomer.Id
        );

        Test.startTest();
        insert testCase;
        Test.stopTest();

        System.assertNotEquals(null, testCase.Id);
    }


    // ===============================
    // Test 2: Status NOT 'New'
    // ===============================
    @isTest
    static void testHandleAfterInsert_StatusNotNew() {

        Customer__c testCustomer = new Customer__c(
            Lead_Name__c = 'Test Lead 2',
            Primary_Phone__c = '9123456780',
            Phone__c = '9123456780'
        );
        insert testCustomer;

        Case testCase = new Case(
            Subject = 'Test Case 2',
            Status = 'Closed',
            Lead__c = testCustomer.Id
        );

        Test.startTest();
        insert testCase;
        Test.stopTest();

        System.assertNotEquals(null, testCase.Id);
    }


    // ===============================
    // Test 3: Phone is NULL
    // ===============================
    @isTest
    static void testHandleAfterInsert_NoPhone() {

        Customer__c testCustomer = new Customer__c(
            Lead_Name__c = 'Test Lead 3',
            Primary_Phone__c = '9000000000'
            // Phone__c intentionally left null
        );
        insert testCustomer;

        Case testCase = new Case(
            Subject = 'Test Case 3',
            Status = 'New',
            Lead__c = testCustomer.Id
        );

        Test.startTest();
        insert testCase;
        Test.stopTest();

        System.assertNotEquals(null, testCase.Id);
    }
}