trigger DeliveryPlanTrigger on Delivery_Group__c (
    before insert,
    before update,
    after insert,
    after update
) {

    // Populate Warehouse Manager
    if (Trigger.isBefore) {
        DeliveryPlanTriggerHandler.populateWarehouseManager(
            Trigger.new,
            Trigger.oldMap
        );
    }

    // Block Delivered status without approval
    if (Trigger.isBefore && Trigger.isUpdate) {
        DeliveryPlanTriggerHandler.beforeUpdate(
            Trigger.new,Trigger.oldMap
        );
    }

    // Notify Admin on Delivery Plan creation
    if (Trigger.isAfter && Trigger.isInsert) {
        DeliveryPlanTriggerHandler.afterInsert(
            Trigger.new
        );
    }

    // Notify Admin when Delivery Plan is marked Delivered
    // Update Order Product quantities
    if (Trigger.isAfter && Trigger.isUpdate) {
        DeliveryPlanTriggerHandler.afterUpdate(
            Trigger.new,
            Trigger.oldMap
        );

        DeliveryPlanQuantityHandler.handleAfterUpdate(
            Trigger.new,
            Trigger.oldMap
        );
    }
}