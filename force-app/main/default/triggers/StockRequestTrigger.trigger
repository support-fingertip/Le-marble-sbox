trigger StockRequestTrigger on Stock_Request__c (after insert) {
    if (Trigger.isAfter && Trigger.isInsert) {
        StockRequestTriggerHandler.handleAfterInsert(Trigger.new);
    }
}
