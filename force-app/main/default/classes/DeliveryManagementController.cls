public with sharing class DeliveryManagementController {
    @AuraEnabled
    public static List<Sales_Confirmation__c> searchSalesConfirmations(String searchTerm) {
        try {
            String searchKey = '%' + searchTerm + '%';
            return [
                SELECT Id, Name, Opportunity__r.Name, Opportunity__r.Company__c, 
                       Opportunity__r.Customer__r.Name, Opportunity__r.Phone__c, 
                       Opportunity__r.Address__Street__s, Opportunity__r.Address__City__s, 
                       Opportunity__r.Address__StateCode__s, Opportunity__r.Address__PostalCode__s, 
                       Opportunity__r.Address__CountryCode__s, Opportunity__r.Stage__c, 
                       Opportunity__r.Type__c, Opportunity__r.Owner.Name, Total_Amount__c, Payment_Type__c,
                       Approval_Status__c, Product_Category__c,
                       Preferred_Delivery_Date__c,
                       (SELECT Id, Name, Product__r.Name, Quantity__c, Unit_Price__c,
                        After_Disc_Price_Piece__c, After_Disc_Price_Sqft__c,
                        Price__c, Price_Sqft__c, Product_Category__c, Product_Tax__c,
                        Sqft__c, Sqm__c, UOM__c, Moved_to_Delivery__c
                        FROM Cart_Line_Items__r)
                FROM Sales_Confirmation__c
                WHERE Name LIKE :searchKey
                LIMIT 10
            ];
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static List<Cart_Line_Item__c> getAvailableProducts(Id salesConfirmationId) {
        try {
            // Get all cart line items for this sales confirmation
            List<Cart_Line_Item__c> cartItems = [
                SELECT Id, Name, Product__r.Name, Quantity__c, Unit_Price__c,
                       Sales_Confirmation__r.Name, Sales_Confirmation__c, Moved_to_Delivery__c,
                       (SELECT Id, Status__c FROM Pending_Purchase_Line_Items__r),
                       (SELECT Id, Quantity__c FROM Delivery_Line_Items__r)
                FROM Cart_Line_Item__c
                WHERE Sales_Confirmation__c = :salesConfirmationId
                AND Id NOT IN (
                    SELECT Cart_Line_Item__c 
                    FROM Pending_Purchase_Line_Item__c 
                    WHERE Pending_Purchase__r.Status__c != 'Received'
                )
            ];

            // Calculate remaining quantities
            for(Cart_Line_Item__c item : cartItems) {
                Decimal deliveredQuantity = 0;
                for(Delivery_Line_Item__c deliveryItem : item.Delivery_Line_Items__r) {
                    deliveredQuantity += deliveryItem.Quantity__c;
                }
                item.Quantity__c = item.Quantity__c - deliveredQuantity;
            }

            // Filter out items with zero remaining quantity
            List<Cart_Line_Item__c> available = new List<Cart_Line_Item__c>();
            for (Cart_Line_Item__c item : cartItems) {
                if (item.Quantity__c > 0) {
                    available.add(item);
                }
            }
            return available;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    @AuraEnabled
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
        try {
            Map<String, Object> data = (Map<String, Object>)JSON.deserializeUntyped(deliveryGroupData);
            
            // Create Delivery Group
            Delivery_Group__c deliveryGroup = new Delivery_Group__c(
                Sales_Confirmation__c = (Id)data.get('salesConfirmationId'),
                Delivery_Date__c = Date.valueOf((String)data.get('deliveryDate')),
                Driver_Assigned__c = (String)data.get('driverId'),
                Choose_Vehicle__c = (String)data.get('vehicleId'),
                Remarks__c = (String)data.get('remarks'),
                Status__c = 'Scheduled',
                Delivery_Time__c = data.containsKey('deliveryTime') && String.isNotBlank((String)data.get('deliveryTime')) ? parseTimeString(data.get('deliveryTime')) : null,
                Vehicle_Number__c = data.containsKey('vehicleNumber') ? (String)data.get('vehicleNumber') : null,
                Freight_Amount__c = data.containsKey('freightAmount') && data.get('freightAmount') != null ? Decimal.valueOf(String.valueOf(data.get('freightAmount'))) : null
            );
            
            insert deliveryGroup;
            
            // Create Delivery Line Items and update Cart Line Items
            List<Delivery_Line_Item__c> lineItems = new List<Delivery_Line_Item__c>();
            List<Object> productData = (List<Object>)data.get('productData');
            
            for (Object productObj : productData) {
                Map<String, Object> product = (Map<String, Object>)productObj;
                String productId = (String)product.get('id');
                Decimal deliveryQuantity = (Decimal)product.get('deliveryQuantity');
                
                // Create Delivery Line Item
                lineItems.add(new Delivery_Line_Item__c(
                    Delivery_Group__c = deliveryGroup.Id,
                    Cart_Line_Item__c = Id.valueOf(productId),
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

    @AuraEnabled
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
}