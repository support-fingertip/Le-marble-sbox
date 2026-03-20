public with sharing class DeliverySchedulingController {
    @AuraEnabled
    public static List<Delivery_Group__c> getDeliveryGroups(String searchTerm) {
        try {
            String searchKey = '%' + String.escapeSingleQuotes(searchTerm) + '%';
            
            return [
                SELECT Id, Name, Status__c, Delivery_Date__c,
                       Choose_Vehicle__c, 
                       Sales_Confirmation__c, Sales_Confirmation__r.Name,
                       Remarks__c,
                       (SELECT Id, Cart_Line_Item__c, 
                               Cart_Line_Item__r.Product__r.Name,
                               Cart_Line_Item__r.Quantity__c
                        FROM Delivery_Line_Items__r)
                FROM Delivery_Group__c
                WHERE Name LIKE :searchKey
                   OR Sales_Confirmation__r.Name LIKE :searchKey
                ORDER BY Delivery_Date__c DESC
                LIMIT 50
            ];
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static void markDeliveryAsCompleted(Id deliveryGroupId) {
        try {
            Delivery_Group__c delivery = new Delivery_Group__c(
                Id = deliveryGroupId,
                Status__c = 'Delivered'
            );
            
            update delivery;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}