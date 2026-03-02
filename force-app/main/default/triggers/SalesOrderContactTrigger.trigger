trigger SalesOrderContactTrigger on Order (after update, after insert) {

    if (SalesOrderTriggerHandler.isRunning) {
        return;
    }
    SalesOrderTriggerHandler.isRunning = true;

    // AFTER INSERT
    if (Trigger.isInsert) {

        for (Order newRec : Trigger.new) {

            if (newRec.Status == 'Approved' &&
                newRec.SAP_Doc_Num__c == null) {

                System.enqueueJob(
                    new SendOrderToSAPQueueable(newRec.Id)
                );
            }
        }
    }

    // AFTER UPDATE
    if (Trigger.isUpdate) {

        for (Order newRec : Trigger.new) {

            Order oldRec = Trigger.oldMap.get(newRec.Id);

            if (newRec.Status == 'Approved' &&
                oldRec.Status != 'Approved' &&
                newRec.SAP_Doc_Num__c == null) {

                System.enqueueJob(
                    new SendOrderToSAPQueueable(newRec.Id)
                );
            }
        }
    }
}