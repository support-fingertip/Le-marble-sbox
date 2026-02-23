trigger SalesOrderContactTrigger on Order (after update) {
 /*   if (Trigger.isBefore && (Trigger.isInsert || Trigger.isUpdate)) {
        SalesOrderTriggerHandler.populateContactDetails(Trigger.new);
    }*/
    
    if (SalesOrderTriggerHandler.isRunning) {
        return;
    }
    SalesOrderTriggerHandler.isRunning = true;
 for (Integer i = 0; i < Trigger.new.size(); i++) {

        Order newRec = Trigger.new[i];
        Order oldRec = Trigger.old[i];
system.debug('newRec.Status>>'+newRec.Status + '   ---   '+ newRec.SAP_Doc_Num__c);
        if (newRec.Status == 'Approved' && oldRec.Status != 'Approved' && newRec.SAP_Doc_Num__c==null) {

            System.enqueueJob(
                new SendOrderToSAPQueueable(newRec.Id)
            );
        }
    }
}