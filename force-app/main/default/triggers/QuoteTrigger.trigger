trigger QuoteTrigger on Quote (before insert) {
    if (Trigger.isBefore && Trigger.isInsert) {
        QuoteTriggerHandler.beforeInsert(Trigger.new);
    }
}