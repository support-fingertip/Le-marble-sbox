trigger SalesOrderContactTrigger on Order (after update, after insert) {

    if (SalesOrderTriggerHandler.isRunning) {
        return;
    }
    SalesOrderTriggerHandler.isRunning = true;

    // AFTER INSERT
    if (Trigger.isInsert) {

        for (Order newRec : Trigger.new) {

            if (newRec.Order_Status__c == 'Approved' ) {

                System.enqueueJob(
                    new SendOrderToSAPQueueable(newRec.Id)
                );
            }
        }
    }

    // AFTER UPDATE
    if (Trigger.isUpdate) {

        for (Order newRec : Trigger.new) {
system.debug('newRec>>>>>>>>'+newRec);
            Order oldRec = Trigger.oldMap.get(newRec.Id);
system.debug('newRecStatus>>>>>>>>'+newRec.Order_Status__c);

            if (newRec.Order_Status__c == 'Approved' &&
                oldRec.Order_Status__c != 'Approved' &&
                newRec.SAP_Doc_Num__c == null) {
                System.enqueueJob(
                    new SendOrderToSAPQueueable(newRec.Id)
                );
            }
        }
    }
}