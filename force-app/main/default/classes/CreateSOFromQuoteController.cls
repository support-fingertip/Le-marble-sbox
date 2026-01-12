public with sharing class CreateSOFromQuoteController {

    // ================================
    // 1. Get Quote Header Information
    // ================================
  @AuraEnabled(cacheable=true)
public static Map<String, Object> getQuoteInfo(Id quoteId) {
    try {
        Quote q = [
            SELECT
                Id,
                Name,
                AccountId,
                Account.Name,
                Account.Phone,
                Account.BillingStreet,
                Account.BillingCity,
                Account.BillingState,
                Account.BillingPostalCode,
                Account.BillingCountry,
                Owner.Name,
                OpportunityId,
                Pricebook2Id,
                Email,
                Sales_Order_Created__c,
                Discount,
                Freight_Charge__c,
                Loading_Charge__c,
                Unloading_Charge__c,
                GrandTotal
            FROM Quote
            WHERE Id = :quoteId
            LIMIT 1
        ];
         return new Map<String, Object>{
            'quote' => q,
           'email' => q.Email
        };

    } catch (Exception e) {
        throw new AuraHandledException('Error fetching quote info: ' + e.getMessage());
    }
}

    // =================================
    // 2. Get Quote Line Items for UI
    // =================================
    @AuraEnabled(cacheable=true)
    public static List<QuoteLineItem> getQuoteLineItems(Id quoteId) {
    try {
        return [
            SELECT
                Id,
                Quantity,
                UnitPrice,
                Product2.Name,
                Product2.ProductCode,
                Product2.Family,
                PricebookEntry.Product2.Product_Category__c
            FROM QuoteLineItem
            WHERE QuoteId = :quoteId
            ORDER BY CreatedDate ASC
        ];
    } catch (Exception e) {
        throw new AuraHandledException(
            'Error fetching quote line items: ' + e.getMessage()
        );
    }
}

    
    // 3. Create Order from Quote
    
    @AuraEnabled
    public static Id createOrderFromQuote(Id quoteId , Id warehouseId,List<Id> selectedQuoteLineItemIds) {
        try {
            // Fetch Quote
            Quote q = [
            SELECT Id,Name,
            AccountId,
           OpportunityId,
           Pricebook2Id,
           Sales_Order_Created__c,
           Discount,
          Freight_Charge__c,
          Loading_Charge__c,
           Unloading_Charge__c,
          GrandTotal
              FROM Quote
            WHERE Id = :quoteId
            LIMIT 1
          ];

            if (q.Sales_Order_Created__c == true) {
    throw new AuraHandledException(
        'Sales Order is already created for this Quote.'
    );
    }
    if (warehouseId == null) {
    throw new AuraHandledException('Please select a Warehouse');
}


        if (selectedQuoteLineItemIds == null || selectedQuoteLineItemIds.isEmpty()) {
    throw new AuraHandledException('Please select at least one product');
    }
            
              // Fetch Quote Line Items
           List<QuoteLineItem> qlis = [
    SELECT
        Quantity,
        UnitPrice,
        PricebookEntryId,
        PricebookEntry.Product2.Product_Category__c
    FROM QuoteLineItem
    WHERE Id IN :selectedQuoteLineItemIds
    ];


        String category = qlis[0].PricebookEntry.Product2.Product_Category__c;

        for (QuoteLineItem qli : qlis) {
            if (qli.PricebookEntry.Product2.Product_Category__c != category) {
                throw new AuraHandledException(
                    'Selected products must belong to the same category'
                );
            }
        }


            // Create Order
            Order ord = new Order();
            ord.AccountId     = q.AccountId;
            ord.Customer__c   = q.AccountId;
            ord.OpportunityId = q.OpportunityId;
            ord.Pricebook2Id  = q.Pricebook2Id;

            ord.QuoteId           = q.Id;          // standard
            ord.Standard_Quote__c = q.Id;   
            ord.Warehouse__c  = warehouseId;       // custom

            ord.EffectiveDate = Date.today();
            ord.Status        = 'Draft';

            ord.Product_Category__c = category;
            ord.Discount__c = q.Discount;           
            ord.Freight_Charge__c     = q.Freight_Charge__c;
            ord.Loading_Charges__c    = q.Loading_Charge__c;    
            ord.Unloading_Charges__c  = q.Unloading_Charge__c;   
            ord.Grand_Total__c        = q.GrandTotal;  
            
            insert ord;
            q.Sales_Order_Created__c = true;
            update q;

           

            // Create Order Items
            List<OrderItem> orderItems = new List<OrderItem>();
            for (QuoteLineItem qli : qlis) {
                OrderItem oi = new OrderItem();
                oi.OrderId          = ord.Id;
                oi.PricebookEntryId = qli.PricebookEntryId;
                oi.Quantity         = qli.Quantity;
                oi.UnitPrice        = qli.UnitPrice;
                orderItems.add(oi);
            }

            if (!orderItems.isEmpty()) {
                insert orderItems;
            }

            return ord.Id;

        } catch (Exception e) {
            throw new AuraHandledException(
                'Error creating order from quote: ' + e.getMessage()
            );
        }
    }
     // 4. Get Payment Type Options
    
    @AuraEnabled(cacheable=true)
    public static List<String> getPaymentTypeOptions() {
        return new List<String>{ 'Cash', 'Credit' };
    }
   @AuraEnabled(cacheable=true)
    public static List<Warehouse__c> getActiveWarehouses() {
    return [
        SELECT Id, Name
        FROM Warehouse__c
        ORDER BY Name
    ];
}
}