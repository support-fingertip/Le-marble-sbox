public class SalesOrderTriggerHandler {

   public static Boolean isRunning = false;

    public static void resetQuoteLineItemsOnOrderDelete(List<Order> deletedOrders) {
        Set<Id> orderIds = new Set<Id>();
        Set<Id> quoteIds = new Set<Id>();

        for (Order ord : deletedOrders) {
            orderIds.add(ord.Id);
            if (ord.QuoteId != null) {
                quoteIds.add(ord.QuoteId);
            }
        }

        // Find QuoteLineItemIds from the OrderItems being deleted
        List<OrderItem> orderItems = [
            SELECT Id, QuoteLineItemId
            FROM OrderItem
            WHERE OrderId IN :orderIds
            AND QuoteLineItemId != null
        ];

        if (!orderItems.isEmpty()) {
            List<QuoteLineItem> qlisToUpdate = new List<QuoteLineItem>();
            for (OrderItem oi : orderItems) {
                qlisToUpdate.add(new QuoteLineItem(
                    Id = oi.QuoteLineItemId,
                    Order_Created__c = false
                ));
            }
            update qlisToUpdate;
        }

        // Reset Quote.Sales_Order_Created__c so new orders can be created
        if (!quoteIds.isEmpty()) {
            List<Quote> quotesToUpdate = new List<Quote>();
            for (Id qId : quoteIds) {
                quotesToUpdate.add(new Quote(
                    Id = qId,
                    Sales_Order_Created__c = false,
                    Status='Presented'
                ));
            }
            update quotesToUpdate;
        }
    }
}