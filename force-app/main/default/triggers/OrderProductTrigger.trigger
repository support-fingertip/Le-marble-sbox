trigger OrderProductTrigger on OrderItem (before insert, before update,after insert, after update) {
     if (Trigger.isbefore) {
    OrderProductTriggerHandler.updateDeliveryStatus(Trigger.new);
     }
     if (Trigger.isAfter) {
        OrderProductTriggerHandler.updateSalesOrderStatus(Trigger.new);
    }
}