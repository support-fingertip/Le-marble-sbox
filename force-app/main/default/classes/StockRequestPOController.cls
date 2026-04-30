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

    @AuraEnabled(cacheable=true)
    public static List<PicklistOption> getBranchOptions() {
        List<PicklistOption> options = new List<PicklistOption>();
        Schema.DescribeFieldResult fieldResult =
            Purchase_Order__c.Branch__c.getDescribe();
        for (Schema.PicklistEntry entry : fieldResult.getPicklistValues()) {
            if (entry.isActive()) {
                options.add(new PicklistOption(entry.getLabel(), entry.getValue()));
            }
        }
        return options;
    }

    @AuraEnabled(cacheable=true)
    public static List<Account> searchVendorAccounts(String searchTerm) {
        String term = String.isBlank(searchTerm) ? '' : searchTerm.trim();
        String key = '%' + term + '%';
        return [
            SELECT Id, Name, AccountNumber
            FROM Account
            WHERE Name LIKE :key
            ORDER BY Name
            LIMIT 25
        ];
    }

    @AuraEnabled
    public static Id createPurchaseOrderFromItems(
        Id stockRequestId,
        String branch,
        Id vendorId,
        Decimal totalAmount,
        String itemsJson
    ) {
        if (stockRequestId == null) {
            throw new AuraHandledException('Stock Request Id is required.');
        }
        if (String.isBlank(branch)) {
            throw new AuraHandledException('Branch is required.');
        }
        if (String.isBlank(itemsJson)) {
            throw new AuraHandledException('Please select at least one item.');
        }

        List<Object> rawItems;
        try {
            rawItems = (List<Object>) JSON.deserializeUntyped(itemsJson);
        } catch (Exception e) {
            throw new AuraHandledException('Could not read item list: ' + e.getMessage());
        }
        if (rawItems == null || rawItems.isEmpty()) {
            throw new AuraHandledException('Please select at least one item.');
        }

        Stock_Request__c req = [
            SELECT Id, Product_Category__c
            FROM Stock_Request__c
            WHERE Id = :stockRequestId
            LIMIT 1
        ];

        Set<Id> selectedItemIds = new Set<Id>();
        Map<Id, Decimal> priceByItemId = new Map<Id, Decimal>();
        for (Integer i = 0; i < rawItems.size(); i++) {
            Map<String, Object> row = (Map<String, Object>) rawItems[i];
            String itemIdStr = (String) row.get('id');
            Object priceObj = row.get('price');
            if (String.isBlank(itemIdStr)) {
                throw new AuraHandledException('Row ' + (i + 1) + ': Stock Request Item Id is missing.');
            }
            Decimal price = 0;
            if (priceObj != null && String.valueOf(priceObj) != '') {
                try {
                    price = Decimal.valueOf(String.valueOf(priceObj));
                } catch (Exception e) {
                    throw new AuraHandledException('Row ' + (i + 1) + ': Price must be a number.');
                }
                if (price < 0) {
                    throw new AuraHandledException('Row ' + (i + 1) + ': Price cannot be negative.');
                }
            }
            Id liId = (Id) itemIdStr;
            selectedItemIds.add(liId);
            priceByItemId.put(liId, price);
        }

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
                Branch__c           = branch,
                Vendor__c           = vendorId,
                Total_Amount__c     = totalAmount,
                PO_Date__c          = Date.today()
            );
            insert po;

            List<Purchase_Order_Item__c> poItems = new List<Purchase_Order_Item__c>();
            for (Stock_Request_Line_Item__c li : lines) {
                poItems.add(new Purchase_Order_Item__c(
                    Purchase_Order__c = po.Id,
                    Product__c        = li.Product__c,
                    Quantity__c       = li.Quantity__c,
                    Price__c          = priceByItemId.get(li.Id)
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

    public class PicklistOption {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
        public PicklistOption(String l, String v) {
            this.label = l;
            this.value = v;
        }
    }
}
