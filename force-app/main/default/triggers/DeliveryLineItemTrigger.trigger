trigger DeliveryLineItemTrigger on Delivery_Line_Item__c (
    after insert, after update, after delete, after undelete
) {

    Set<Id> orderItemIds = new Set<Id>();

    // Insert, Update, Undelete
    if (Trigger.isInsert || Trigger.isUpdate || Trigger.isUndelete) {
        for (Delivery_Line_Item__c dli : Trigger.new) {
            if (dli.Sales_Order_Line_Item__c != null) {
                orderItemIds.add(dli.Sales_Order_Line_Item__c);
            }
        }
    }

    // Delete
    if (Trigger.isDelete) {
        for (Delivery_Line_Item__c dli : Trigger.old) {
            if (dli.Sales_Order_Line_Item__c != null) {
                orderItemIds.add(dli.Sales_Order_Line_Item__c);
            }
        }
    }

    // Call helper ONLY if we have data
    if (!orderItemIds.isEmpty()) {
        DeliveryLineItemHelper.updateOrderProductRollups(orderItemIds);
    }
}