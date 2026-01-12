trigger OrderProductTrigger on OrderItem (before insert, before update) {
    OrderProductTriggerHandler.updateDeliveryStatus(Trigger.new);
}