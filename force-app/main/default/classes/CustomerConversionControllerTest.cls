@IsTest
public class CustomerConversionControllerTest {

    private static Customer__c createCustomer() {
        Customer__c cust = new Customer__c(
            Name = 'Test Customer',
            Lead_Name__c = 'Test Lead',
            Primary_Phone__c = '9876543210',
            Status1__c = 'New'
        );
        insert cust;
        return cust;
    }

    private static Deals__c createDeal(Id customerId) {
        Deals__c deal = new Deals__c(
            Name = 'Test Deal',
            Customer__c = customerId
        );
        insert deal;
        return deal;
    }

    @IsTest
    static void testSuccess() {

        Customer__c cust = createCustomer();
        Deals__c deal = createDeal(cust.Id);

        Test.startTest();
        Map<String, String> result =
            CustomerConversionController.convertToOpportunity(cust.Id);
        Test.stopTest();

        System.assertEquals(deal.Id, result.get('dealId'));

        Customer__c updated =
            [SELECT Status1__c FROM Customer__c WHERE Id = :cust.Id];
        System.assertEquals('Converted', updated.Status1__c);
    }

    @IsTest
    static void testNoDealPath() {

        Customer__c cust = createCustomer();

        Test.startTest();
        try {
            CustomerConversionController.convertToOpportunity(cust.Id);
            System.assert(false);
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('No Deal'));
        }
        Test.stopTest();
    }

    @IsTest
    static void testNullIdPath() {

        Test.startTest();
        try {
            CustomerConversionController.convertToOpportunity(null);
            System.assert(false);
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Customer Id'));
        }
        Test.stopTest();
    }
}