public with sharing class DealPathController {
    @AuraEnabled
    public static void updateDealStage(Id recordId, String stage, Date expectedDate) {
        try {
            Pending_Purchase__c purchase = new Pending_Purchase__c(
                Id = recordId,
                Stage__c = stage
            );
            
            // Only update Expected_Date__c if stage is Delayed and expectedDate is provided
            if (stage == 'Delayed' && expectedDate != null) {
                purchase.Expected_Date__c = expectedDate;
            }
            
            update purchase;
        } catch(Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}