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
                Sales_Order_Created__c
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
    public static Id createOrderFromQuote(Id quoteId , Id warehouseId,List<Id> selectedQuoteLineItemIds, Map<Id, Decimal> blockQtyMap, Date deliveryCommittedDate, String remarks) {
        try {
             // 1️⃣ Validate warehouse
        if (warehouseId == null) {
            throw new AuraHandledException('Please select a Warehouse');
        }
            // Fetch Quote
         Quote q = [
    SELECT Id,
           AccountId,
           OpportunityId,
           Pricebook2Id,
           Sales_Order_Created__c,

           Freight_Charge__c,
           Loading_Charge__c,
           Unloading_Charge__c,

           ContactId,
           Contact.Name,
           Contact.Phone,

           BillingStreet,
           BillingCity,
           BillingState,
           BillingPostalCode,
           BillingCountry,

           ShippingStreet,
           ShippingCity,
           ShippingState,
           ShippingPostalCode,
             ShippingCountry,
             
             AddressLine1__c,                                     
             AddressLine2__c,                               
             AddressLine3__c,                              
             District__c,                             
             State__c,                          
             country__c                            
                                     
    FROM Quote
    WHERE Id = :quoteId
    LIMIT 1
];



        Warehouse__c wh = [SELECT Id, Warehouse_Manager__c FROM Warehouse__c WHERE Id = :warehouseId LIMIT 1];

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

    if (deliveryCommittedDate == null) {
    throw new AuraHandledException(
        'Delivery Committed Date is mandatory'
    );
}

if (deliveryCommittedDate < Date.today()) {
    throw new AuraHandledException(
        'Delivery Committed Date cannot be in the past'
    );
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
            ord.Warehouse__c  = warehouseId; 
            ord.Delivery_Committed_Date__c = deliveryCommittedDate;   
            ord.Remarks__c = remarks;   

            ord.EffectiveDate = Date.today();
            ord.Status        = 'Draft';

            ord.Product_Category__c = category;

            // ================= CONTACT PERSON =================
            if (q.ContactId != null && q.Contact.Phone != null) {

                // Remove all non-numeric characters
                String phoneDigits = q.Contact.Phone.replaceAll('[^0-9]', '');

                // Only assign if digits exist
                if (!String.isBlank(phoneDigits)) {
                    ord.Contact_Person_Number__c = Decimal.valueOf(phoneDigits);
                }

                ord.Contact_Person_Name__c = q.Contact.Name;
            }

            ord.BillingStreet     = q.BillingStreet;
            ord.BillingCity       = q.BillingCity;
            ord.BillingState      = q.BillingState;
            ord.BillingPostalCode = q.BillingPostalCode;
            ord.BillingCountry    = q.BillingCountry;

    /*        if (String.isBlank(q.ShippingStreet)) {
                Account acc = [
                    SELECT ShippingStreet, ShippingCity, ShippingState,
                        ShippingPostalCode, ShippingCountry
                    FROM Account
                    WHERE Id = :q.AccountId
                    LIMIT 1
                ];

                ord.ShippingStreet     = acc.ShippingStreet;
                ord.ShippingCity       = acc.ShippingCity;
                ord.ShippingState      = acc.ShippingState;
                ord.ShippingPostalCode = acc.ShippingPostalCode;
                ord.ShippingCountry    = acc.ShippingCountry;
            }*/
            
            
            
            ord.AddressLine1__c= q.AddressLine1__c;
            ord.AddressLine2__c= q.AddressLine2__c;
            ord.AddressLine3__c= q.AddressLine3__c;
            ord.District__c= q.District__c;
            ord.State__c= q.State__c;
            ord.Country__c= q.country__c;
            

            ord.Freight_Charge__c     = q.Freight_Charge__c;
            ord.Loading_Charges__c   = q.Loading_Charge__c;
            ord.Unloading_Charges__c = q.Unloading_Charge__c;

            
            ord.Warehouse_Manager__c = wh.Warehouse_Manager__c;
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
                oi.Block_Quantity__c = blockQtyMap.containsKey(qli.Id)
                    ? blockQtyMap.get(qli.Id)
                    : 0;
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