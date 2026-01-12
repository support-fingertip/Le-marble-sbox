public class DeliveryPlanQuantityHandler {

    public static void handleAfterUpdate(
        List<Delivery_Group__c> newList,
        Map<Id, Delivery_Group__c> oldMap
    ) {
        Set<Id> deliveredPlanIds = new Set<Id>();

        // STEP 1: Detect Delivery Plans newly marked Delivered
        for (Delivery_Group__c dp : newList) {
            Delivery_Group__c oldDp = oldMap.get(dp.Id);

            if (oldDp.Delivery_Status__c != 'Delivered' &&
                dp.Delivery_Status__c == 'Delivered') {
                deliveredPlanIds.add(dp.Id);
            }
        }

        if (deliveredPlanIds.isEmpty()) return;

        // STEP 2: Fetch Delivery Line Items
        List<Delivery_Line_Item__c> dliList = [
            SELECT Id,
                   Delivered_Quantity__c,
                   Sales_Order_Line_Item__c
            FROM Delivery_Line_Item__c
            WHERE Delivery_Group__c IN :deliveredPlanIds
              AND Sales_Order_Line_Item__c != null
        ];

        // STEP 3: Sum delivered qty per Order Product
        Map<Id, Decimal> orderItemToDeliveredQty = new Map<Id, Decimal>();

        for (Delivery_Line_Item__c dli : dliList) {
            Decimal qty = dli.Delivered_Quantity__c == null ? 0 : dli.Delivered_Quantity__c;

            orderItemToDeliveredQty.put(
                dli.Sales_Order_Line_Item__c,
                orderItemToDeliveredQty.get(dli.Sales_Order_Line_Item__c) == null
                    ? qty
                    : orderItemToDeliveredQty.get(dli.Sales_Order_Line_Item__c) + qty
            );
        }

        if (orderItemToDeliveredQty.isEmpty()) return;

        // STEP 4: Fetch Order Products
        List<OrderItem> orderItems = [
            SELECT Id,
                   Quantity,
                   Delivered_Quantity__c,
                   Pending_Quantity__c,
                   Delivery_Status__c
            FROM OrderItem
            WHERE Id IN :orderItemToDeliveredQty.keySet()
        ];

        // STEP 5: Update quantities & status
        for (OrderItem oi : orderItems) {

            Decimal delivered =
                (oi.Delivered_Quantity__c == null ? 0 : oi.Delivered_Quantity__c)
                + orderItemToDeliveredQty.get(oi.Id);

            Decimal ordered = oi.Quantity;
            Decimal pending = ordered - delivered;

            oi.Delivered_Quantity__c = delivered;
            oi.Pending_Quantity__c = pending;

            if (delivered == 0) {
                oi.Delivery_Status__c = 'Pending';
            } else if (delivered < ordered) {
                oi.Delivery_Status__c = 'Partially Delivered';
            } else {
                oi.Delivery_Status__c = 'Delivered';
            }
        }

    
        if (!orderItems.isEmpty()) {
            update orderItems;
        }
         rollupToSalesOrder(orderItemToDeliveredQty.keySet());
    }
    // STEP 6: Roll up Order Products to Sales Order
public static void rollupToSalesOrder(Set<Id> orderItemIds) {

    Map<Id, Decimal> orderToDeliveredQty = new Map<Id, Decimal>();

    for (OrderItem oi : [
        SELECT OrderId, Delivered_Quantity__c
        FROM OrderItem
        WHERE Id IN :orderItemIds
    ]) {
        orderToDeliveredQty.put(
            oi.OrderId,
            (orderToDeliveredQty.get(oi.OrderId) == null ? 0 : orderToDeliveredQty.get(oi.OrderId))
            + (oi.Delivered_Quantity__c == null ? 0 : oi.Delivered_Quantity__c)
        );
    }

    List<Order> ordersToUpdate = new List<Order>();

    for (Id orderId : orderToDeliveredQty.keySet()) {
        ordersToUpdate.add(new Order(
            Id = orderId,
            Delivered_Quantity__c = orderToDeliveredQty.get(orderId)
        ));
    }

    if (!ordersToUpdate.isEmpty()) {
        update ordersToUpdate;
    }

}
}