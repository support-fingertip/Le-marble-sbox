@IsTest
public class PendingPurchaseUpdateTriggerTest {

    private static String getValidStatus(){
        return Pending_Purchase__c.Status__c.getDescribe().getPicklistValues()[0].getValue();
    }

    private static Account createVendor(){

        Account vendor = new Account(
            Name = 'Vendor Test',
            BillingCountry = 'India',
            BillingState = 'Karnataka',
            BillingCity = 'Bangalore',
            BillingStreet = 'Test Street',
            BillingPostalCode = '560001',
            District__c = '	Thiruvananthapuram',
            Pin_Code__c = 622627
        );

        insert vendor;
        return vendor;
    }

    @IsTest
    static void testUpdateRemarks(){

        Pending_Purchase__c purchase = new Pending_Purchase__c(
            Status__c = getValidStatus(),
            Remarks__c = 'Initial'
        );

        insert purchase;

        purchase.Remarks__c = 'Updated';

        Test.startTest();
        update purchase;
        Test.stopTest();

        System.assertEquals('Updated', purchase.Remarks__c);
    }

    @IsTest
    static void testUpdateVendor(){

        Account vendor = createVendor();

        Pending_Purchase__c purchase = new Pending_Purchase__c(
            Status__c = getValidStatus()
        );

        insert purchase;

        purchase.Vendor__c = vendor.Id;

        Test.startTest();
        update purchase;
        Test.stopTest();

        System.assertEquals(vendor.Id, purchase.Vendor__c);
    }

    @IsTest
    static void testUpdateReceivedDate(){

        Pending_Purchase__c purchase = new Pending_Purchase__c(
            Status__c = getValidStatus()
        );

        insert purchase;

        purchase.Received_Date__c = Date.today();

        Test.startTest();
        update purchase;
        Test.stopTest();

        System.assertEquals(Date.today(), purchase.Received_Date__c);
    }

    @IsTest
    static void testFinanceManagerApproval(){

        Pending_Purchase__c purchase = new Pending_Purchase__c(
            Status__c = getValidStatus()
        );

        insert purchase;

        purchase.Status__c = 'Finance Manager Approved';

        Test.startTest();
        update purchase;
        Test.stopTest();

        System.assertEquals('Finance Manager Approved', purchase.Status__c);
    }
}