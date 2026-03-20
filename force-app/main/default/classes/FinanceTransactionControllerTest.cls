@isTest(SeeAllData=false)
private class FinanceTransactionControllerTest {
    @testSetup
    static void setupTestData() {
        // Find a picklist entry whose value contains "credit", plus a fallback
        Schema.DescribeFieldResult dr = Payment__c.Payment_Type__c.getDescribe();
        String creditType;
        String fallbackType;
        for (Schema.PicklistEntry pe : dr.getPicklistValues()) {
            if (creditType == null && pe.getValue().toLowerCase().contains('credit')) {
                creditType = pe.getValue();
            }
            if (fallbackType == null) {
                fallbackType = pe.getValue();
            }
        }
        if (creditType == null) {
            creditType   = dr.getPicklistValues()[0].getValue();
            fallbackType = dr.getPicklistValues().size()>1
                         ? dr.getPicklistValues()[1].getValue()
                         : creditType;
        }
        
        // Insert two payments: one “credit-ish” and one fallback
        insert new Payment__c(
            Name               = 'Pay_Credit_Received',
            Payment_Status__c  = 'Received',
            Payment_Type__c    = creditType
        );
        insert new Payment__c(
            Name               = 'Pay_NonCredit_Applied',
            Payment_Status__c  = 'Applied',
            Payment_Type__c    = fallbackType
        );
    }
    
    static testMethod void testGetFinanceTransactions() {
        List<Payment__c> payments = FinanceTransactionController.getFinanceTransactions();
        System.assert(payments.size() >= 2,
            'Should return at least the two records from setup');
    }
    
    static testMethod void testUpdatePaymentStatus_Valid() {
        Payment__c rec = [SELECT Id, Payment_Status__c, Payment_Date__c
                          FROM Payment__c
                          WHERE Name = 'Pay_Credit_Received'
                          LIMIT 1];
        Test.startTest();
            FinanceTransactionController.updatePaymentStatus(rec.Id, 'Applied');
        Test.stopTest();
        
        rec = [SELECT Payment_Status__c, Payment_Date__c
               FROM Payment__c
               WHERE Id = :rec.Id];
        System.assertEquals('Applied', rec.Payment_Status__c);
        System.assertEquals(Date.today(), rec.Payment_Date__c);
    }
    
    static testMethod void testUpdatePaymentStatus_Invalid() {
        Payment__c rec = [SELECT Id
                          FROM Payment__c
                          WHERE Name = 'Pay_NonCredit_Applied'
                          LIMIT 1];
        Boolean threw = false;
        Test.startTest();
            try {
                FinanceTransactionController.updatePaymentStatus(rec.Id, 'Overdue');
            } catch (AuraHandledException e) {
                threw = true;
            }
        Test.stopTest();
        System.assert(threw, 'Invalid transition should throw AuraHandledException');
    }
    
    static testMethod void testUpdateTransactionReference() {
        Payment__c rec = [SELECT Id, Doc_Entry__c
                          FROM Payment__c
                          WHERE Name = 'Pay_Credit_Received'
                          LIMIT 1];
        FinanceTransactionController.updateTransactionReference(rec.Id, 'DOC-12345');
        rec = [SELECT Doc_Entry__c FROM Payment__c WHERE Id = :rec.Id];
        System.assertEquals('DOC-12345', rec.Doc_Entry__c);
    }
    
    static testMethod void testUpdateDueDate_AlwaysThrows() {
        List<Payment__c> all = [SELECT Id FROM Payment__c
                                WHERE Name IN ('Pay_Credit_Received','Pay_NonCredit_Applied')];
        Test.startTest();
            for (Payment__c p : all) {
                Boolean threw = false;
                try {
                    FinanceTransactionController.updateDueDate(p.Id, Date.today().addDays(5));
                } catch (AuraHandledException e) {
                    threw = true;
                }
                System.assert(threw, 'updateDueDate should throw for Id=' + p.Id);
            }
        Test.stopTest();
    }
    
    static testMethod void testPicklistOptions() {
        List<Map<String,String>> types    = FinanceTransactionController.getPaymentTypeOptions();
        List<Map<String,String>> statuses = FinanceTransactionController.getPaymentStatusOptions();
        System.assert(!types.isEmpty(),    'Payment_Type__c options should not be empty');
        System.assert(!statuses.isEmpty(), 'Payment_Status__c options should not be empty');
    }
}