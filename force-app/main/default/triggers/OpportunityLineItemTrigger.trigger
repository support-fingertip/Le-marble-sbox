trigger OpportunityLineItemTrigger on OpportunityLineItem (after insert) {
    OpportunityProductNotificationHandler.handleAfterInsert(Trigger.new);
}