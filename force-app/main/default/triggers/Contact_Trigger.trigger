trigger Contact_Trigger on Contact (before insert, before update) {
    if (Trigger.isBefore && (Trigger.isInsert || Trigger.isUpdate)) {
        ContactTriggerHandler.checkDuplicateContacts(Trigger.new, Trigger.oldMap);
    }
}