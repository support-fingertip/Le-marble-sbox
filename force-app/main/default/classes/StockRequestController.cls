public with sharing class StockRequestController {

    @AuraEnabled(cacheable=true)
    public static List<PicklistOption> getProductCategories() {
        List<PicklistOption> options = new List<PicklistOption>();
        Schema.DescribeFieldResult fieldResult =
            Stock_Request__c.Product_Category__c.getDescribe();
        for (Schema.PicklistEntry entry : fieldResult.getPicklistValues()) {
            if (entry.isActive()) {
                options.add(new PicklistOption(entry.getLabel(), entry.getValue()));
            }
        }
        return options;
    }

    @AuraEnabled(cacheable=true)
    public static List<Product2> searchProducts(String category, String searchTerm) {
        if (String.isBlank(category)) {
            return new List<Product2>();
        }
        String term = String.isBlank(searchTerm) ? '' : searchTerm.trim();
        String key = '%' + term + '%';
        return [
            SELECT Id, Name, ProductCode, Product_Category__c
            FROM Product2
            WHERE Product_Category__c = :category
              AND IsActive = true
              AND (Name LIKE :key OR ProductCode LIKE :key)
            ORDER BY Name
            LIMIT 25
        ];
    }

    @AuraEnabled
    public static Id createStockRequestWithItems(String category, String itemsJson) {
        if (String.isBlank(category)) {
            throw new AuraHandledException('Product Category is required.');
        }
        if (String.isBlank(itemsJson)) {
            throw new AuraHandledException('At least one product item is required.');
        }

        List<Object> rawItems;
        try {
            rawItems = (List<Object>) JSON.deserializeUntyped(itemsJson);
        } catch (Exception e) {
            throw new AuraHandledException('Could not read item list: ' + e.getMessage());
        }
        if (rawItems == null || rawItems.isEmpty()) {
            throw new AuraHandledException('At least one product item is required.');
        }

        Set<Id> seen = new Set<Id>();
        List<Stock_Request_Line_Item__c> lineItems = new List<Stock_Request_Line_Item__c>();
        for (Integer i = 0; i < rawItems.size(); i++) {
            Map<String, Object> li = (Map<String, Object>) rawItems[i];
            String productIdStr = (String) li.get('productId');
            Object qtyObj = li.get('quantity');

            if (String.isBlank(productIdStr)) {
                throw new AuraHandledException('Row ' + (i + 1) + ': Product is required.');
            }
            if (qtyObj == null) {
                throw new AuraHandledException('Row ' + (i + 1) + ': Quantity is required.');
            }
            Decimal qty;
            try {
                qty = Decimal.valueOf(String.valueOf(qtyObj));
            } catch (Exception e) {
                throw new AuraHandledException('Row ' + (i + 1) + ': Quantity must be a number.');
            }
            if (qty <= 0) {
                throw new AuraHandledException('Row ' + (i + 1) + ': Quantity must be greater than 0.');
            }

            Id productId = (Id) productIdStr;
            if (seen.contains(productId)) {
                throw new AuraHandledException('A product can only appear once. Please remove duplicates.');
            }
            seen.add(productId);

            lineItems.add(new Stock_Request_Line_Item__c(
                Product__c      = productId,
                Quantity__c     = qty,
                Status__c       = 'Open',
                Request_Date__c = Date.today()
            ));
        }

        Savepoint sp = Database.setSavepoint();
        try {
            Stock_Request__c req = new Stock_Request__c(
                Product_Category__c = category
            );
            insert req;
            for (Stock_Request_Line_Item__c sri : lineItems) {
                sri.Stock_Request__c = req.Id;
            }
            insert lineItems;
            return req.Id;
        } catch (DmlException dmlEx) {
            Database.rollback(sp);
            throw new AuraHandledException(dmlEx.getDmlMessage(0));
        } catch (Exception e) {
            Database.rollback(sp);
            throw new AuraHandledException(e.getMessage());
        }
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
