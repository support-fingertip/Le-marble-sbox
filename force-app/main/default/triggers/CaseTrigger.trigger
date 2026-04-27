trigger CaseTrigger on Case (after insert, after update) {
    if(Trigger.isAfter && Trigger.isInsert) {
        CaseTriggerHandler.handleAfterInsert(Trigger.new);
    }
    if(Trigger.isAfter && Trigger.isUpdate) {
        CaseTriggerHandler.handleAfterUpdate(Trigger.new, Trigger.oldMap);
    }
}