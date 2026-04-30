public with sharing class StockRequestPOController {

    @AuraEnabled(cacheable=true)
    public static StockRequestData getStockRequestDetails(Id stockRequestId) {
        if (stockRequestId == null) {
            throw new AuraHandledException('Stock Request Id is required.');
        }

        List<Stock_Request__c> reqs = [
            SELECT Id, Name, Product_Category__c, Status__c, OwnerId, Owner.Name,
                   CreatedDate, LastModifiedDate
            FROM Stock_Request__c
            WHERE Id = :stockRequestId
            LIMIT 1
        ];
        if (reqs.isEmpty()) {
            throw new AuraHandledException('Stock Request not found.');
        }

        List<Stock_Request_Line_Item__c> lines = [
            SELECT Id, Name, Product__c, Product__r.Name, Product__r.ProductCode,
                   Quantity__c, Status__c
            FROM Stock_Request_Line_Item__c
            WHERE Stock_Request__c = :stockRequestId
            ORDER BY CreatedDate ASC
        ];

        StockRequestData data = new StockRequestData();
        data.stockRequest = reqs[0];
        data.items = new List<LineItem>();
        for (Stock_Request_Line_Item__c li : lines) {
            LineItem w = new LineItem();
            w.id = li.Id;
            w.productId = li.Product__c;
            w.productName = li.Product__r != null ? li.Product__r.Name : null;
            w.productCode = li.Product__r != null ? li.Product__r.ProductCode : null;
            w.quantity = li.Quantity__c;
            w.status = li.Status__c;
            data.items.add(w);
        }
        return data;
    }

    @AuraEnabled
    public static Id createPurchaseOrderFromItems(Id stockRequestId, List<Id> selectedItemIds) {
        if (stockRequestId == null) {
            throw new AuraHandledException('Stock Request Id is required.');
        }
        if (selectedItemIds == null || selectedItemIds.isEmpty()) {
            throw new AuraHandledException('Please select at least one item.');
        }

        Stock_Request__c req = [
            SELECT Id, Product_Category__c
            FROM Stock_Request__c
            WHERE Id = :stockRequestId
            LIMIT 1
        ];

        List<Stock_Request_Line_Item__c> lines = [
            SELECT Id, Product__c, Quantity__c
            FROM Stock_Request_Line_Item__c
            WHERE Id IN :selectedItemIds
              AND Stock_Request__c = :stockRequestId
        ];
        if (lines.isEmpty()) {
            throw new AuraHandledException('Selected items could not be found on this Stock Request.');
        }

        Savepoint sp = Database.setSavepoint();
        try {
            Purchase_Order__c po = new Purchase_Order__c(
                Stock_Request__c    = req.Id,
                Product_Category__c = req.Product_Category__c,
                PO_Date__c          = Date.today()
            );
            insert po;

            List<Purchase_Order_Item__c> poItems = new List<Purchase_Order_Item__c>();
            for (Stock_Request_Line_Item__c li : lines) {
                poItems.add(new Purchase_Order_Item__c(
                    Purchase_Order__c = po.Id,
                    Product__c        = li.Product__c,
                    Quantity__c       = li.Quantity__c
                ));
            }
            insert poItems;
            return po.Id;
        } catch (DmlException dmlEx) {
            Database.rollback(sp);
            throw new AuraHandledException(dmlEx.getDmlMessage(0));
        } catch (Exception e) {
            Database.rollback(sp);
            throw new AuraHandledException(e.getMessage());
        }
    }

    public class StockRequestData {
        @AuraEnabled public Stock_Request__c stockRequest;
        @AuraEnabled public List<LineItem> items;
    }

    public class LineItem {
        @AuraEnabled public Id id;
        @AuraEnabled public Id productId;
        @AuraEnabled public String productName;
        @AuraEnabled public String productCode;
        @AuraEnabled public Decimal quantity;
        @AuraEnabled public String status;
    }
}
