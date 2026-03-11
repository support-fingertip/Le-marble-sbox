trigger SalesOrderContactTrigger on Order (after update, after insert) {

    if (SalesOrderTriggerHandler.isRunning) {
        return;
    }
    SalesOrderTriggerHandler.isRunning = true;
system.debug('SalesOrderTriggerHandler.isRunning '+SalesOrderTriggerHandler.isRunning );
    // AFTER INSERT
    if (Trigger.isInsert) {

        for (Order newRec : Trigger.new) {
system.debug('newRec.Order_Status__c>>'+newRec.Order_Status__c);
            if (newRec.Order_Status__c == 'Approved' ) {

                System.enqueueJob(
                    new SendOrderToSAPQueueable(newRec.Id)
                );
            }
        }
    }

    // AFTER UPDATE
    if (Trigger.isUpdate) {

        List<Opportunity> oppsToUpdate = new List<Opportunity>();
        for (Order newRec : Trigger.new) {
            Order oldRec = Trigger.oldMap.get(newRec.Id);
            // Mark Opportunity as Closed Won if Order is Completed
            if (newRec.Order_Status__c == 'Completed' && oldRec.Order_Status__c != 'Completed' && newRec.OpportunityId != null) {
                oppsToUpdate.add(new Opportunity(Id = newRec.OpportunityId, StageName = 'Closed Won'));
            }
            // Existing SAP logic
            if (newRec.Order_Status__c == 'Approved' &&
                oldRec.Order_Status__c != 'Approved' &&
                newRec.SAP_Doc_Num__c == null) {
                System.enqueueJob(
                    new SendOrderToSAPQueueable(newRec.Id)
                );
            }
        }
        if (!oppsToUpdate.isEmpty()) {
            try {
                update oppsToUpdate;
            } catch (DmlException e) {
                System.debug('Opportunity update error: ' + e.getMessage());
            }
        }
    }
}