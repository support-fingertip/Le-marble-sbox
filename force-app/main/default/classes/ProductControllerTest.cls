@isTest
private class ProductControllerTest {

    static Id dealId;
    static Id productId;

    @testSetup
    static void setupData() {

        // Create Product
        Product__c prod = new Product__c(Name = 'Test Product');
        insert prod;
        productId = prod.Id;

        // Dynamically create parent for Deals__c
        Schema.DescribeFieldResult df =
            Cart__c.Deals__c.getDescribe();

        List<Schema.SObjectType> refTypes =
            df.getReferenceTo();

        if (!refTypes.isEmpty()) {

            Schema.SObjectType refType = refTypes[0];
            SObject parent = refType.newSObject();

            Map<String, Schema.SObjectField> fields =
                refType.getDescribe().fields.getMap();

            for (String fieldName : fields.keySet()) {

                Schema.DescribeFieldResult d =
                    fields.get(fieldName).getDescribe();

                if (!d.isNillable()
                    && !d.isDefaultedOnCreate()
                    && !d.isAutoNumber()) {

                    if (d.getType() == Schema.DisplayType.String) {
                        parent.put(fieldName, 'Test');
                    }
                    else if (d.getType() == Schema.DisplayType.Picklist) {
                        List<Schema.PicklistEntry> entries =
                            d.getPicklistValues();
                        if (!entries.isEmpty()) {
                            parent.put(fieldName,
                                entries[0].getValue());
                        }
                    }
                    else if (d.getType() == Schema.DisplayType.Date) {
                        parent.put(fieldName, Date.today());
                    }
                    else if (d.getType() == Schema.DisplayType.Boolean) {
                        parent.put(fieldName, true);
                    }
                    else if (d.getType() == Schema.DisplayType.Currency ||
                             d.getType() == Schema.DisplayType.Double ||
                             d.getType() == Schema.DisplayType.Percent) {
                        parent.put(fieldName, 1);
                    }
                }
            }

            insert parent;
            dealId = parent.Id;
        }
    }

    @isTest
    static void testCreateCart() {

        // 🔎 Fetch valid Status__c picklist value
        String validStatus;

        Schema.DescribeFieldResult statusDesc =
            Cart__c.Status__c.getDescribe();

        List<Schema.PicklistEntry> entries =
            statusDesc.getPicklistValues();

        if (!entries.isEmpty()) {
            validStatus = entries[0].getValue();
        }

        Map<String, Object> item = new Map<String, Object>{
            'id' => productId,
            'quantity' => 1,
            'unitPrice' => 100
        };

        List<Map<String, Object>> items =
            new List<Map<String, Object>>{ item };

        Test.startTest();
        String cartId = ProductController.createCart(
            dealId,
            items,
            0,
            0,
            0
        );
        Test.stopTest();

        System.assertNotEquals(null, cartId);
    }

    @isTest
    static void testCreateCartLineItem() {

        String cartId = ProductController.createCart(
            dealId,
            null,
            0,
            0,
            0
        );

        Map<String, Object> item = new Map<String, Object>{
            'id' => productId,
            'quantity' => 5,
            'unitPrice' => 200
        };

        Test.startTest();
        String lineItemId =
            ProductController.createCartLineItem(cartId, item);
        Test.stopTest();

        System.assertNotEquals(null, lineItemId);
    }

    @isTest
    static void testOtherMethods() {

        ProductController.getProducts();
        ProductController.getProductCategories();

        ProductController.logInfo('Test');
        ProductController.logError('Error');

        System.assertEquals('Hello, Guest!',
            ProductController.generateGreeting(''));

        System.assertEquals(5,
            ProductController.addNumbers(2, 3));

        System.assert(ProductController.isValidLeadSource('Web'));
        System.assertEquals('Online',
            ProductController.mapLeadSource('Web'));

        System.assertEquals('ABC',
            ProductController.convertToUpperCase('abc'));

        System.assertEquals(120,
            ProductController.calculateFactorial(5));

        System.assert(ProductController.isPalindrome('madam'));
        System.assert(ProductController.isPrimeNumber(7));
        System.assert(ProductController.isLeapYear(2024));
        System.assertEquals(3,
            ProductController.countWords('Hello World Test'));
    }
}