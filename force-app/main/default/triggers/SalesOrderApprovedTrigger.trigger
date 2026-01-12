trigger SalesOrderApprovedTrigger on Sales_Confirmation__c (after update) {
    List<Sales_Confirmation__c> approvedOrders = new List<Sales_Confirmation__c>();

    for (Sales_Confirmation__c order : Trigger.new) {
        Sales_Confirmation__c oldOrder = Trigger.oldMap.get(order.Id);
        if (order.Approval_Status__c == 'Approved' && oldOrder.Approval_Status__c != 'Approved') {
            approvedOrders.add(order);
        }
    }

    if (!approvedOrders.isEmpty()) {
        System.enqueueJob(new SAPOrderQueueable(approvedOrders));
    }
}