public with sharing class DeliveryLineItemHelper {

    public static void updateOrderProductRollups(Set<Id> orderItemIds) {

        if (orderItemIds == null || orderItemIds.isEmpty()) {
            return;
        }

        
         //* 1. Aggregate Delivered Quantity from Delivery Line Items
        
        Map<Id, Decimal> deliveredQtyMap = new Map<Id, Decimal>();

        for (AggregateResult ar : [
    SELECT
        Sales_Order_Line_Item__c orderItemId,
        SUM(Quantity__c) totalDelivered
    FROM Delivery_Line_Item__c
    WHERE Sales_Order_Line_Item__c IN :orderItemIds
    GROUP BY Sales_Order_Line_Item__c
]) {

            deliveredQtyMap.put(
                (Id) ar.get('orderItemId'),
                (Decimal) ar.get('totalDelivered')
            );
        }

       
         //* 2. Fetch OrderItem Records
         
        Map<Id, OrderItem> orderItemMap = new Map<Id, OrderItem>();

        for (OrderItem oi : [
            SELECT
                Id,
                OrderId,
                Quantity,
                Delivered_Quantity__c,
                Pending_Quantity__c,
                Delivery_Status__c
            FROM OrderItem
            WHERE Id IN :orderItemIds
        ]) {
            orderItemMap.put(oi.Id, oi);
        }

        List<OrderItem> orderItemsToUpdate = new List<OrderItem>();

       
         //* 3. Update Rollup Fields on OrderItem
       
        for (OrderItem oi : orderItemMap.values()) {

            Decimal delivered = deliveredQtyMap.containsKey(oi.Id)
                ? deliveredQtyMap.get(oi.Id)
                : 0;

            Decimal totalQty = (oi.Quantity == null ? 0 : oi.Quantity);
            Decimal pending  = totalQty - delivered;

            if (pending < 0) {
                pending = 0;
            }

            Boolean needsUpdate = false;

            // Delivered Quantity
            if (oi.Delivered_Quantity__c == null || oi.Delivered_Quantity__c != delivered) {
                oi.Delivered_Quantity__c = delivered;
                needsUpdate = true;
            }

            // Pending Quantity
            if (oi.Pending_Quantity__c == null || oi.Pending_Quantity__c != pending) {
                oi.Pending_Quantity__c = pending;
                needsUpdate = true;
            }

            // Delivery Status
            String newStatus;
            if (delivered == 0) {
                newStatus = 'Pending';
            } else if (delivered < totalQty) {
                newStatus = 'Partial';
            } else {
                newStatus = 'Delivered';
            }

            if (oi.Delivery_Status__c == null || oi.Delivery_Status__c != newStatus) {
                oi.Delivery_Status__c = newStatus;
                needsUpdate = true;
            }

            if (needsUpdate) {
                orderItemsToUpdate.add(oi);
            }
        }

         // 4. Update OrderItem Records
        
        if (!orderItemsToUpdate.isEmpty()) {
            try {
                update orderItemsToUpdate;
            } catch (DmlException e) {
                System.debug('DeliveryLineItemHelper update error: ' + e.getMessage());
            }
        }
    }
}