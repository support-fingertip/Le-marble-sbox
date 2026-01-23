public with sharing class NewDeliveryPlanController {
    @AuraEnabled
    public static List<Order> searchSalesOrders(String searchTerm) {
        try {
            system.debug(searchTerm);
            String searchKey = '%' + searchTerm + '%';
            return [
                SELECT Id, Name, account.name, orderNumber,
                       Phone__c, QuoteId,Quote_Name__c,Order_Owner__c,
                       BillingStreet, BillingCity, Product_Category__c,
                        BillingPostalCode, TotalAmount, BillingState,BillingCountry,Warehouse__c,
                       (SELECT Id, Product2.Name, Quantity, UnitPrice
                        FROM OrderItems)
                FROM Order
                WHERE Status='Approved' and orderNumber LIKE :searchKey
                LIMIT 10
            ];
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static List<OrderItem> getAvailableProducts(Id salesConfirmationId) {
        system.debug(salesConfirmationId);
        try {
            // Get all cart line items for this sales confirmation
            List<OrderItem> cartItems = [
                SELECT Id, Product2.Name, Quantity, UnitPrice,Pending_Quantity1__c,
                       order.Name, orderId,//, Moved_to_Delivery__c
                   //    (SELECT Id, Status__c FROM Pending_Purchase_Line_Items__r),
                       (SELECT Id, Quantity__c FROM Delivery_Line_Items__r)
                FROM OrderItem
                WHERE orderId = :salesConfirmationId 
                /*AND Id NOT IN (
                    SELECT OrderItem 
                    FROM Pending_Purchase_Line_Item__c 
                    WHERE Pending_Purchase__r.Status__c != 'Received'
                )*/
            ];

            // Calculate remaining quantities
            for(OrderItem item : cartItems) {
                Decimal deliveredQuantity = 0;
                for(Delivery_Line_Item__c deliveryItem : item.Delivery_Line_Items__r) {
                    deliveredQuantity += deliveryItem.Quantity__c;
                }
                item.Pending_Quantity__c = item.Quantity - deliveredQuantity;
            }

            // Filter out items with zero remaining quantity
            List<OrderItem> available = new List<OrderItem>();
            for (OrderItem item : cartItems) {
                if (item.Pending_Quantity__c > 0) {
                    available.add(item);
                }
            }
            system.debug(available);
            return available;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
 /*   @AuraEnabled
    public static List<Pending_Purchase__c> getPendingProducts(Id dealId) {
        try {
            // First get the Sales Confirmation IDs for this Deal
            List<Sales_Confirmation__c> salesConfirmations = [
                SELECT Id 
                FROM Sales_Confirmation__c 
                WHERE Opportunity__c = :dealId
            ];
            
            List<Id> salesConfirmationIds = new List<Id>();
            for(Sales_Confirmation__c sc : salesConfirmations) {
                salesConfirmationIds.add(sc.Id);
            }
            
            return [
                SELECT Id, Name, Status__c, Purchase_Request_Date__c, Received_Date__c,
                       Sales_Confirmation__r.Name,
                       (SELECT Id, Cart_Line_Item__r.Product__r.Name, Cart_Line_Item__r.Quantity__c
                        FROM Pending_Purchase_Line_Items__r)
                FROM Pending_Purchase__c
                WHERE Sales_Confirmation__c IN :salesConfirmationIds
            ];
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
  */  
    @AuraEnabled
    public static List<User> getDrivers() {
        try {
            return [
                SELECT Id, Name
                FROM User
                WHERE Profile.Name = 'Driver'
            ];
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    
    @AuraEnabled
    public static void createDeliveryGroup(String deliveryGroupData) {
        system.debug('deliveryGroupData>'+ deliveryGroupData);
        try {
            Map<String, Object> data = (Map<String, Object>)JSON.deserializeUntyped(deliveryGroupData);
            Id salesOrderId = (Id)data.get('salesConfirmationId');

           Order so = [
            SELECT 
                Id,
                AccountId,
                Warehouse__c,
                Warehouse_Manager__c,
                Contact_Person_Name__c,	
                Freight_Charge__c
            FROM Order
            WHERE Id = :salesOrderId
            LIMIT 1
        ];

            
            Decimal finalFreight;

        if (data.containsKey('freightAmount') && data.get('freightAmount') != null) {
            finalFreight = Decimal.valueOf(String.valueOf(data.get('freightAmount')));
        } else {
            finalFreight = so.Freight_Charge__c;
        }

                    // ===== Delivery Date + Time merge =====
            Date deliveryDate;
            Time deliveryTime;
            Datetime deliveryDateTime;

            // Date
            if (data.containsKey('deliveryDate') && data.get('deliveryDate') != null) {
                deliveryDate = Date.valueOf((String)data.get('deliveryDate'));
            }

            // Time
            if (data.containsKey('deliveryTime') && String.isNotBlank((String)data.get('deliveryTime'))) {
                deliveryTime = parseTimeString(data.get('deliveryTime'));
            }

            // Combine Date + Time → Datetime
            if (deliveryDate != null) {
                if (deliveryTime != null) {
                    deliveryDateTime = Datetime.newInstance(deliveryDate, deliveryTime);
                } else {
                    deliveryDateTime = Datetime.newInstance(
                        deliveryDate,
                        Time.newInstance(0, 0, 0, 0)
                    );
                }
            }
            // Create Delivery Group
            Delivery_Group__c deliveryGroup = new Delivery_Group__c(
                Sales_Order__c = salesOrderId,
                  Account__c  = so.AccountId,
                    Warehouse__c   = so.Warehouse__c,
                    Warehouse_Manager__c = so.Warehouse_Manager__c,
                    Contact_Person__c = so.Contact_Person_Name__c,
                   Delivery_Date_Time__c = deliveryDateTime,
                Driver_Assigned__c = (String)data.get('driverId'),
                Choose_Vehicle__c = (String)data.get('vehicleId'),
                Remarks__c = (String)data.get('remarks'),
                Status__c = 'Scheduled',
                 Delivery_Status__c = 'Scheduled',
                
                Vehicle_Number__c = data.containsKey('vehicleNumber') ? (String)data.get('vehicleNumber') : null,
               Freight_Amount__c = finalFreight


                
            );
            
 
            insert deliveryGroup;
            
            // Create Delivery Line Items and update Cart Line Items
            List<Delivery_Line_Item__c> lineItems = new List<Delivery_Line_Item__c>();
            List<Object> productData = (List<Object>)data.get('productData');
            
            for (Object productObj : productData) {
                system.debug('productObj>'+ productObj);
                Map<String, Object> product = (Map<String, Object>)productObj;
                String productId = (String)product.get('id');
                Decimal deliveryQuantity = (Decimal)product.get('deliveryQuantity');
                
                // Create Delivery Line Item
                lineItems.add(new Delivery_Line_Item__c(
                    Delivery_Group__c = deliveryGroup.Id,
                    Sales_Order_Line_Item__c = Id.valueOf(productId),
                    Quantity__c = deliveryQuantity
                ));
            }
            
            if (!lineItems.isEmpty()) {
                insert lineItems;
            }
            
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

/*    @AuraEnabled
    public static void updatePendingPurchaseStatus(Id pendingPurchaseId, String status) {
        try {
            // Update the Pending Purchase status
            Pending_Purchase__c purchase = new Pending_Purchase__c(
                Id = pendingPurchaseId,
                Status__c = status
            );
            
            if(status == 'Received') {
                purchase.Received_Date__c = Date.today();
            }
            
            update purchase;
            
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
*/
    @AuraEnabled
    public static List<String> getVehicleTypeOptions() {
        try {
            Schema.DescribeFieldResult fieldResult = Delivery_Group__c.Choose_Vehicle__c.getDescribe();
            List<Schema.PicklistEntry> ple = fieldResult.getPicklistValues();
            List<String> options = new List<String>();
            for(Schema.PicklistEntry p : ple) {
                options.add(p.getValue());
            }
            return options;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static List<String> getDriverPicklistOptions() {
        try {
            Schema.DescribeFieldResult fieldResult = Delivery_Group__c.Driver_Assigned__c.getDescribe();
            List<Schema.PicklistEntry> ple = fieldResult.getPicklistValues();
            List<String> options = new List<String>();
            for(Schema.PicklistEntry p : ple) {
                options.add(p.getValue());
            }
            return options;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static List<String> getVehicleNumberOptions() {
        try {
            Schema.DescribeFieldResult fieldResult = Delivery_Group__c.Vehicle_Number__c.getDescribe();
            List<Schema.PicklistEntry> ple = fieldResult.getPicklistValues();
            List<String> options = new List<String>();
            for(Schema.PicklistEntry p : ple) {
                options.add(p.getValue());
            }
            return options;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    private static Time parseTimeString(Object timeObj) {
        if (timeObj == null) return null;
        String timeStr = String.valueOf(timeObj);
        if (String.isBlank(timeStr)) return null;
        List<String> parts = timeStr.split(':');
        Integer hour = Integer.valueOf(parts[0]);
        Integer minute = parts.size() > 1 ? Integer.valueOf(parts[1]) : 0;
        Integer second = parts.size() > 2 ? Integer.valueOf(parts[2]) : 0;
        return Time.newInstance(hour, minute, second, 0);
    }

    @AuraEnabled(cacheable=true)
    public static Decimal getSalesOrderFreight(Id salesOrderId) {
    Order so = [
    SELECT Freight_Charge__c
    FROM Order
    WHERE Id = :salesOrderId
    LIMIT 1
];
    return so.Freight_Charge__c;
}

@AuraEnabled(cacheable=true)
public static String getSalesOrderRemarks(Id salesOrderId) {
    Order so = [
        SELECT Remarks__c
        FROM Order
        WHERE Id = :salesOrderId
        LIMIT 1
    ];
    return so.Remarks__c;
}
}