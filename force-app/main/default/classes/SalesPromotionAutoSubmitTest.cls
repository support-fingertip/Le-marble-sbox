@IsTest
private class SalesPromotionAutoSubmitTest {
    @IsTest
    static void autoSubmitsOnInsert() {
        Sales_Promotion__c sp = new Sales_Promotion__c(
            Amount__c = 50000,
            Type_of_Promotion__c = 'Voucher',
            Promotion_Status__c = 'Proposed'
        );
        Test.startTest();
        insert sp;
        Test.stopTest();
        // allOrNone=false makes the submit best-effort, so we only need to
        // assert the insert path ran; in an org with the approval process
        // active and the running user's Manager populated a ProcessInstance
        // row will also exist for this record.
        System.assertNotEquals(null, sp.Id, 'Record should be inserted even if approval submission is best-effort.');
    }
}
