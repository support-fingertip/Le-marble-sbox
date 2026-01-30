trigger SalesOrderTrigger on Sales_Confirmation__c (after insert, after update) {
    if(Trigger.isAfter) {
        try {
            List<Sales_Confirmation__c> approvedOrders = new List<Sales_Confirmation__c>();

            if(Trigger.isInsert) {
                for (Sales_Confirmation__c order : Trigger.new) {
                    if (order.Approval_Status__c == 'Approved') {
                        approvedOrders.add(order);
                    }
                }
            }
            
            if(Trigger.isUpdate) {
                for (Sales_Confirmation__c order : Trigger.new) {
                    Sales_Confirmation__c oldOrder = Trigger.oldMap.get(order.Id);
                    if (order.Approval_Status__c == 'Approved' && oldOrder.Approval_Status__c != 'Approved') {
                        approvedOrders.add(order);
                    }
                }
            }

            if (!approvedOrders.isEmpty()) {
                // Create SAP Orders
       //         SAPOrderService.createSAPOrders(approvedOrders);
                
                // Handle warehouse locked records
                List<Sales_Confirmation__c> warehouseLockedRecords = new List<Sales_Confirmation__c>();
                
                for (Sales_Confirmation__c order : approvedOrders) {
                    if (order.Sales_Order_Id__c == 'WAREHOUSE_LOCKED') {
                        warehouseLockedRecords.add(new Sales_Confirmation__c(
                            Id = order.Id,
                            Approval_Status__c = 'Pending'
                        ));
                    }
                }
                
                // Update warehouse locked records
                if (!warehouseLockedRecords.isEmpty()) {
                    update warehouseLockedRecords;
                }
            }
        } catch(Exception e) {
            // Log the error
            System.debug('Error in SalesOrderTrigger: ' + e.getMessage() + '\n' + e.getStackTraceString());
        }
    }
}