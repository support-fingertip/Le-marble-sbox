trigger OpportunityLineItemTrigger on OpportunityLineItem (after insert,after update,before insert, before update) {
    if(trigger.isafter){
        OpportunityItemHandler.handleAfterInsert(Trigger.new);
    }
    if(trigger.isbefore){
        OpportunityItemHandler.handleBefore(Trigger.new);
    }
}