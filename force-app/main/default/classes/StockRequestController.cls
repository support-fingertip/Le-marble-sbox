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
    public static Id createStockRequestWithItems(String category, List<LineItemInput> items) {
        if (String.isBlank(category)) {
            throw new AuraHandledException('Product Category is required.');
        }
        if (items == null || items.isEmpty()) {
            throw new AuraHandledException('At least one product item is required.');
        }

        Set<Id> seen = new Set<Id>();
        for (LineItemInput li : items) {
            if (String.isBlank(li.productId)) {
                throw new AuraHandledException('Each row must have a Product selected.');
            }
            if (li.quantity == null || li.quantity <= 0) {
                throw new AuraHandledException('Quantity must be greater than 0 on every row.');
            }
            Id productId = (Id) li.productId;
            if (seen.contains(productId)) {
                throw new AuraHandledException('A product can only appear once. Please remove duplicates.');
            }
            seen.add(productId);
        }

        Savepoint sp = Database.setSavepoint();
        try {
            Stock_Request__c req = new Stock_Request__c(
                Product_Category__c = category
            );
            insert req;

            List<Stock_Request_Line_Item__c> lineItems = new List<Stock_Request_Line_Item__c>();
            for (LineItemInput li : items) {
                lineItems.add(new Stock_Request_Line_Item__c(
                    Stock_Request__c = req.Id,
                    Product__c       = li.productId,
                    Quantity__c      = li.quantity,
                    Status__c        = 'Open',
                    Request_Date__c  = Date.today()
                ));
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

    public class LineItemInput {
        @AuraEnabled public String productId;
        @AuraEnabled public Decimal quantity;
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
