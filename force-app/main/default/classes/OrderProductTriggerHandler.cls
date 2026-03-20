public class OrderProductTriggerHandler {

    public static void updateDeliveryStatus(List<OrderItem> orderItems) {

        for (OrderItem oi : orderItems) {

       
            if (oi.Quantity == null) {
                continue;
            }

            Decimal deliveredQty = oi.Delivered_Quantity__c == null
                ? 0
                : oi.Delivered_Quantity__c;

            if (deliveredQty == 0) {
                oi.Delivery_Status__c = 'Pending';
            }
            else if (deliveredQty < oi.Quantity) {
                oi.Delivery_Status__c = 'Partial';
            }
            else {
                oi.Delivery_Status__c = 'Delivered';
            }
        }
    }
    
    
    /* updated the SO Status as per the pending quantity value
   	Added Roopesh: 23:01:2026*/
    public static void updateSalesOrderStatus(List<OrderItem> soItems) {

        Set<Id> salesOrderIds = new Set<Id>();

        for (OrderItem soi : soItems) {
            if (soi.OrderId != null) {
                salesOrderIds.add(soi.OrderId);
            }
        }

        if (salesOrderIds.isEmpty()) return;

        Map<Id, Decimal> pendingQtyBySO = new Map<Id, Decimal>();

        for (AggregateResult ar : [
            SELECT OrderId soId,
                   SUM(Pending_Quantity1__c) totalPending
            FROM OrderItem
            WHERE OrderId IN :salesOrderIds
            GROUP BY OrderId
        ]) {
            pendingQtyBySO.put(
                (Id) ar.get('soId'),
                (Decimal) ar.get('totalPending')
            );
        }

        List<order> ordersToUpdate = [
            SELECT Id, Status
            FROM order
            WHERE Id IN :salesOrderIds
        ];

        for (order so : ordersToUpdate) {

            Decimal totalPending =
                pendingQtyBySO.containsKey(so.Id)
                ? pendingQtyBySO.get(so.Id)
                : 0;

            if (totalPending == 0) {
                if (so.Status != 'Completed') {
                    so.Status = 'Completed';
                }
            }
            else {
                if (so.Status == 'Completed') {
                    so.Status = 'Approved';
                }
            }
        }

        update ordersToUpdate;
    }
}