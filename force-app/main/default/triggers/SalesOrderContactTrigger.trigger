trigger SalesOrderContactTrigger on Order (after update, after insert, before delete) {

    // Handle before delete: reset QuoteLineItem.Order_Created__c
    if (Trigger.isDelete && Trigger.isBefore) {
        SalesOrderTriggerHandler.resetQuoteLineItemsOnOrderDelete(Trigger.old);
        return;
    }

    if (SalesOrderTriggerHandler.isRunning) {
        return;
    }
    SalesOrderTriggerHandler.isRunning = true;
system.debug('SalesOrderTriggerHandler.isRunning '+SalesOrderTriggerHandler.isRunning );


    // AFTER UPDATE
    if (Trigger.isUpdate) {

        List<Opportunity> oppsToUpdate = new List<Opportunity>();
        Set<Id> oppIdsToCheck = new Set<Id>();
        for (Order newRec : Trigger.new) {
            Order oldRec = Trigger.oldMap.get(newRec.Id);
            if (newRec.Order_Status__c == 'Completed' && oldRec.Order_Status__c != 'Completed' && newRec.OpportunityId != null) {
                oppIdsToCheck.add(newRec.OpportunityId);
            }
        }
        if (!oppIdsToCheck.isEmpty()) {
            Map<Id, List<Order>> oppIdToOrders = new Map<Id, List<Order>>();
            List<Order> allRelatedOrders = [SELECT Id, OpportunityId, Order_Status__c FROM Order WHERE OpportunityId IN :oppIdsToCheck];
            for (Order ord : allRelatedOrders) {
                if (!oppIdToOrders.containsKey(ord.OpportunityId)) {
                    oppIdToOrders.put(ord.OpportunityId, new List<Order>());
                }
                oppIdToOrders.get(ord.OpportunityId).add(ord);
            }
            for (Id oppId : oppIdsToCheck) {
                Boolean allCompleted = true;
                for (Order ord : oppIdToOrders.get(oppId)) {
                    if (ord.Order_Status__c != 'Completed') {
                        allCompleted = false;
                        break;
                    }
                }
                if (allCompleted) {
                    oppsToUpdate.add(new Opportunity(Id = oppId, StageName = 'Closed Won'));
                }
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