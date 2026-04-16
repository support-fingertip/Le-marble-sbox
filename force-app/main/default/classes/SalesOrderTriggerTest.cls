@IsTest
public class SalesOrderTriggerTest {

    @IsTest
    static void testAfterInsertApproved() {

        Sales_Confirmation__c sc = new Sales_Confirmation__c(
           
            Approval_Status__c = 'Approved',
            Sales_Order_Id__c = '12345'
        );

        Test.startTest();
        insert sc;
        Test.stopTest();

        Sales_Confirmation__c result = [
            SELECT Id, Approval_Status__c 
            FROM Sales_Confirmation__c 
            WHERE Id = :sc.Id
        ];

        System.assertEquals('Approved', result.Approval_Status__c);
    }


    @IsTest
    static void testAfterInsertWarehouseLocked() {

        Sales_Confirmation__c sc = new Sales_Confirmation__c(
         
            Approval_Status__c = 'Approved',
            Sales_Order_Id__c = 'WAREHOUSE_LOCKED'
        );

        Test.startTest();
        insert sc;
        Test.stopTest();

        Sales_Confirmation__c result = [
            SELECT Id, Approval_Status__c 
            FROM Sales_Confirmation__c 
            WHERE Id = :sc.Id
        ];

        System.assertEquals('Pending', result.Approval_Status__c);
    }


    @IsTest
    static void testAfterUpdateToApproved() {

        Sales_Confirmation__c sc = new Sales_Confirmation__c(
         
            Approval_Status__c = 'Pending',
            Sales_Order_Id__c = '12345'
        );

        insert sc;

        sc.Approval_Status__c = 'Approved';

        Test.startTest();
        update sc;
        Test.stopTest();

        Sales_Confirmation__c result = [
            SELECT Id, Approval_Status__c 
            FROM Sales_Confirmation__c 
            WHERE Id = :sc.Id
        ];

        System.assertEquals('Approved', result.Approval_Status__c);
    }


    @IsTest
    static void testInsertNotApproved() {

        Sales_Confirmation__c sc = new Sales_Confirmation__c(
          
            Approval_Status__c = 'Pending',
            Sales_Order_Id__c = '12345'
        );

        Test.startTest();
        insert sc;
        Test.stopTest();

        System.assertNotEquals(null, sc.Id);
    }
}