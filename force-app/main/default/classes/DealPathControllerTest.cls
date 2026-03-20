@IsTest
private class DealPathControllerTest {

    // Utility method to get a valid picklist value dynamically
    private static String getValidStageValue() {
        Schema.DescribeFieldResult fieldResult = 
            Pending_Purchase__c.Stage__c.getDescribe();
        
        List<Schema.PicklistEntry> picklistValues = fieldResult.getPicklistValues();
        
        return picklistValues.isEmpty() ? null : picklistValues[0].getValue();
    }

    @TestSetup
    static void setupData() {

        String validStage = getValidStageValue();

        Pending_Purchase__c purchase = new Pending_Purchase__c(
            Stage__c = validStage
        );

        insert purchase;
    }

    // ✅ Test Delayed scenario
    @IsTest
    static void testUpdateDealStage_Delayed() {

        Pending_Purchase__c purchase =
            [SELECT Id FROM Pending_Purchase__c LIMIT 1];

        Date expectedDate = Date.today().addDays(5);

        Test.startTest();
        DealPathController.updateDealStage(
            purchase.Id,
            'Delayed',
            expectedDate
        );
        Test.stopTest();

        Pending_Purchase__c updated =
            [SELECT Stage__c, Expected_Date__c 
             FROM Pending_Purchase__c 
             WHERE Id = :purchase.Id];

        System.assertEquals('Delayed', updated.Stage__c);
        System.assertEquals(expectedDate, updated.Expected_Date__c);
    }

    // ✅ Test non-delayed scenario
    @IsTest
    static void testUpdateDealStage_NotDelayed() {

        Pending_Purchase__c purchase =
            [SELECT Id FROM Pending_Purchase__c LIMIT 1];

        String validStage = getValidStageValue();

        Test.startTest();
        DealPathController.updateDealStage(
            purchase.Id,
            validStage,
            Date.today().addDays(3)
        );
        Test.stopTest();

        Pending_Purchase__c updated =
            [SELECT Stage__c, Expected_Date__c 
             FROM Pending_Purchase__c 
             WHERE Id = :purchase.Id];

        System.assertEquals(validStage, updated.Stage__c);
        System.assertEquals(null, updated.Expected_Date__c);
    }

    // ✅ Exception test
    @IsTest
    static void testUpdateDealStage_Exception() {

        Test.startTest();
        try {
            DealPathController.updateDealStage(
                null,
                'Delayed',
                Date.today()
            );
            System.assert(false, 'Exception should have been thrown');
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e.getMessage());
        }
        Test.stopTest();
    }
}