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
    Map<Id, Id> orderItemToOrderId = new Map<Id, Id>();
    Map<Id, Id> orderIdToOwnerId = new Map<Id, Id>();
    List<Id> deletedOrderItemIds = new List<Id>();
    if (Trigger.isDelete) {
        for (Delivery_Line_Item__c dli : Trigger.old) {
            if (dli.Sales_Order_Line_Item__c != null) {
                orderItemIds.add(dli.Sales_Order_Line_Item__c);
                deletedOrderItemIds.add(dli.Sales_Order_Line_Item__c);
            }
        }

        if (!deletedOrderItemIds.isEmpty()) {
            // Get OrderItem -> OrderId, Quantity, Product Name
            Map<Id, OrderItem> orderItemDetails = new Map<Id, OrderItem>();
            for (OrderItem oi : [SELECT Id, OrderId, Quantity, Product2Id, Product2.Name FROM OrderItem WHERE Id IN :deletedOrderItemIds]) {
                orderItemToOrderId.put(oi.Id, oi.OrderId);
                orderItemDetails.put(oi.Id, oi);
            }
            // Get OrderId -> OwnerId
            Set<Id> orderIds = new Set<Id>();
            for (Id oid : orderItemToOrderId.values()) {
                if (oid != null) orderIds.add(oid);
            }
            for (Order o : [SELECT Id, OwnerId FROM Order WHERE Id IN :orderIds]) {
                orderIdToOwnerId.put(o.Id, o.OwnerId);
            }
            // Get Notification Type Id
            Id notifTypeId = null;
            List<CustomNotificationType> notifTypes = [SELECT Id FROM CustomNotificationType WHERE DeveloperName = 'DeliveryPlan_Notification' LIMIT 1];
            if (!notifTypes.isEmpty()) {
                notifTypeId = notifTypes[0].Id;
            }
            // Send notification to each order owner and warehouse manager
            if (notifTypeId != null) {
                // Fetch Warehouse Manager for each Delivery_Line_Item__c
                Map<Id, Id> orderIdToWarehouseManagerId = new Map<Id, Id>();
                Set<Id> deliveryGroupIds = new Set<Id>();
                for (Delivery_Line_Item__c dli : Trigger.old) {
                    if (dli.Delivery_Group__c != null) {
                        deliveryGroupIds.add(dli.Delivery_Group__c);
                    }
                }
                if (!deliveryGroupIds.isEmpty()) {
                    for (Delivery_Group__c dg : [SELECT Id, Warehouse_Manager__c FROM Delivery_Group__c WHERE Id IN :deliveryGroupIds]) {
                        orderIdToWarehouseManagerId.put(dg.Id, dg.Warehouse_Manager__c);
                    }
                }
                for (Delivery_Line_Item__c dli : Trigger.old) {
                    Id orderItemId = dli.Sales_Order_Line_Item__c;
                    Id orderId = orderItemToOrderId.get(orderItemId);
                    Id ownerId = orderIdToOwnerId.get(orderId);
                    OrderItem oi = orderItemDetails.get(orderItemId);
                    String prodName = oi != null && oi.Product2 != null ? oi.Product2.Name : '';
                    String qty = oi != null && oi.Quantity != null ? String.valueOf(oi.Quantity) : '';
                    // Find warehouse manager
                    Id warehouseManagerId = null;
                    if (dli.Delivery_Group__c != null && orderIdToWarehouseManagerId.containsKey(dli.Delivery_Group__c)) {
                        warehouseManagerId = orderIdToWarehouseManagerId.get(dli.Delivery_Group__c);
                    }
                    Set<String> recipients = new Set<String>();
                    if (ownerId != null) recipients.add(ownerId);
                    if (warehouseManagerId != null) recipients.add(warehouseManagerId);
                    if (!recipients.isEmpty()) {
                        Messaging.CustomNotification notif = new Messaging.CustomNotification();
                        notif.setTitle('Delivery Line Item Removed');
                        notif.setBody('A Delivery Line Item was removed for Order: ' + orderId + '. Product: ' + prodName + ', Quantity: ' + qty);
                        notif.setNotificationTypeId(notifTypeId);
                        notif.setTargetId(orderId);
                        notif.send(recipients);
                    }
                }
            }
        }
    }

    // Call helper ONLY if we have data
    if (!orderItemIds.isEmpty()) {
        DeliveryLineItemHelper.updateOrderProductRollups(orderItemIds);
    }
}