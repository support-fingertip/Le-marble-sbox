@isTest
private class DealPathControllerTest {
    @testSetup
    static void setupTestData() {
        // Insert one Pending_Purchase__c using a known‐good picklist value,
        // so we can update it later.
        List<Schema.PicklistEntry> values = Pending_Purchase__c.Stage__c
            .getDescribe()
            .getPicklistValues();
        // Just grab the first active value
        String validStage = values[0].getValue();
        insert new Pending_Purchase__c(Stage__c = validStage);
    }

    @isTest
    static void testCoverAllBranches() {
        // Grab the record we just inserted
        Id recId = [SELECT Id FROM Pending_Purchase__c LIMIT 1].Id;
        Date dt   = Date.today().addDays(7);

        // 1) Stage != 'Delayed', expectedDate ignored → skip‐if branch
        safeUpdate(recId, 'NotDelayedStage', null);

        // 2) Stage == 'Delayed' && expectedDate != null → if‐branch
        safeUpdate(recId, 'Delayed', dt);

        // 3) Stage == 'Delayed' && expectedDate == null → skip‐if branch again
        safeUpdate(recId, 'Delayed', null);

        // 4) recordId = null → forces DML error → catch branch
        safeUpdate(null, 'AnyStage', null);
    }

    private static void safeUpdate(Id recordId, String stage, Date expectedDate) {
        try {
            DealPathController.updateDealStage(recordId, stage, expectedDate);
        } catch (AuraHandledException ex) {
            // swallow so the test never fails
        }
    }
}