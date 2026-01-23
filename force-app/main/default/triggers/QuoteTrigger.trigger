trigger QuoteTrigger on Quote (
    before insert,
    after insert,
    after update
) {

    /* =========================
       BEFORE INSERT
       ========================= 
    if (Trigger.isBefore && Trigger.isInsert) {
        QuoteTriggerHandler.beforeInsert(Trigger.new);
    }
*/
    /* =========================
       AFTER INSERT
       ========================= */
    if (Trigger.isAfter && Trigger.isInsert) {

        // Existing task-related logic
        QuoteTriggerHandler.handleAfterSave(
            Trigger.new,
            null,
            true
        );
    }

    /* =========================
       AFTER UPDATE
       ========================= */
    if (Trigger.isAfter && Trigger.isUpdate) {

        // Close follow-up tasks based on status
        QuoteTriggerHandler.handleAfterSave(
            Trigger.new,
            Trigger.oldMap,
            false
        );

        // Checker / Manager approval notifications
        QuoteTriggerHandler.handleStatusBasedNotifications(
            Trigger.new,
            Trigger.oldMap
        );

        
        QuoteTriggerHandler.handleCustomerAcceptedNotification(
            Trigger.new,
            Trigger.oldMap
        );

        // Notify ONLY Quote Owner AFTER approval
        QuoteTriggerHandler.handleApprovalOwnerNotification(
            Trigger.new,
            Trigger.oldMap
        );
    }
}