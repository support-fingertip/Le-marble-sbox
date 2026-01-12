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
}