public with sharing class StockRequestToPOController {

    public class StockRequestData {
        @AuraEnabled public Stock_Request__c stockRequest;
        @AuraEnabled public List<Stock_Request_Line_Item__c> items;
    }

    @AuraEnabled(cacheable=true)
    public static StockRequestData getStockRequestDetails(Id stockRequestId) {
        StockRequestData result = new StockRequestData();
        result.stockRequest = [
            SELECT Id, Name, Product_Category__c, Status__c, OwnerId, Owner.Name,
                   CreatedDate, LastModifiedDate
            FROM Stock_Request__c
            WHERE Id = :stockRequestId
            LIMIT 1
        ];
        result.items = [
            SELECT Id, Name, Product__c, Product__r.Name, Quantity__c
            FROM Stock_Request_Line_Item__c
            WHERE Stock_Request__c = :stockRequestId
            ORDER BY CreatedDate ASC
        ];
        return result;
    }

    @AuraEnabled
    public static Id createPurchaseOrder(Id stockRequestId, List<Id> selectedItemIds) {
        if (selectedItemIds == null || selectedItemIds.isEmpty()) {
            throw new AuraHandledException('Please select at least one item to create a purchase order.');
        }

        Stock_Request__c sr = [
            SELECT Id, Product_Category__c
            FROM Stock_Request__c
            WHERE Id = :stockRequestId
            LIMIT 1
        ];

        List<Stock_Request_Line_Item__c> selectedItems = [
            SELECT Id, Product__c, Quantity__c
            FROM Stock_Request_Line_Item__c
            WHERE Id IN :selectedItemIds AND Stock_Request__c = :stockRequestId
        ];

        if (selectedItems.isEmpty()) {
            throw new AuraHandledException('No matching stock request items found.');
        }

        Purchase_Order__c po = new Purchase_Order__c(
            PO_Date__c = Date.today(),
            PO_Status__c = 'Draft',
            Approval_Status__c = 'Submitted'
        );
        if (String.isNotBlank(sr.Product_Category__c)) {
            po.Product_Category__c = sr.Product_Category__c;
        }
        insert po;

        List<Purchase_Order_Item__c> poItems = new List<Purchase_Order_Item__c>();
        for (Stock_Request_Line_Item__c item : selectedItems) {
            poItems.add(new Purchase_Order_Item__c(
                Purchase_Order__c = po.Id,
                Product__c = item.Product__c,
                Quantity__c = item.Quantity__c
            ));
        }
        insert poItems;

        return po.Id;
    }
}
