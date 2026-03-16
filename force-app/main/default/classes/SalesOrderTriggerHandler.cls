public class SalesOrderTriggerHandler {

  /*  public static void populateContactDetails(List<Order> orders) {

        Set<Id> contactIds = new Set<Id>();

        for (Order o : orders) {
            if (o.BillToContactId != null) {
                contactIds.add(o.BillToContactId);
            }
            if (o.ShipToContactId != null) {
                contactIds.add(o.ShipToContactId);
            }
        }

        if (contactIds.isEmpty()) {
            return;
        }

        Map<Id, Contact> contactMap = new Map<Id, Contact>(
            [
                SELECT Id, Name, Phone,
                       MailingStreet, MailingCity, MailingState,
                       MailingPostalCode, MailingCountry
                FROM Contact
                WHERE Id IN :contactIds
            ]
        );

        for (Order o : orders) {

            if (o.BillToContactId != null && contactMap.containsKey(o.BillToContactId)) {

                Contact c = contactMap.get(o.BillToContactId);

                // Contact Name
                o.Contact_Person_Name__c = c.Name;

                // Contact Phone (String → Number SAFE CONVERSION)
                if (c.Phone != null) {
                    String digitsOnly = c.Phone.replaceAll('[^0-9]', '');
                    if (digitsOnly != '') {
                        try {
                            o.Contact_Person_Number__c = Decimal.valueOf(digitsOnly);
                        } catch (Exception e) {
                            // ignore invalid phone number
                        }
                    }
                }

               
                o.BillingStreet     = c.MailingStreet;
                o.BillingCity       = c.MailingCity;
                o.BillingState      = c.MailingState;
                o.BillingPostalCode = c.MailingPostalCode;
                o.BillingCountry    = c.MailingCountry;
            }

            
            if (o.ShipToContactId != null && contactMap.containsKey(o.ShipToContactId)) {

                Contact sc = contactMap.get(o.ShipToContactId);

                // Shipping Address
                o.ShippingStreet     = sc.MailingStreet;
                o.ShippingCity       = sc.MailingCity;
                o.ShippingState      = sc.MailingState;
                o.ShippingPostalCode = sc.MailingPostalCode;
                o.ShippingCountry    = sc.MailingCountry;
            }
        }
    }*/
    
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
                    Sales_Order_Created__c = false
                ));
            }
            update quotesToUpdate;
        }
    }
}