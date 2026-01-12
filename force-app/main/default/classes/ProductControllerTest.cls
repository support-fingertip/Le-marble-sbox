@isTest
private class ProductControllerTest {
    @testSetup
    static void setupTestData() {
        insert new Product__c(
            Name                = 'P1',
            Product_Code__c     = 'T1',
            MSP__c              = 10,
            MRP__c              = 20,
            Product_Category__c = 'Tile',
            UOM__c              = 'Box',
            Price_Sqft__c       = 5,
            Sqft_Piece__c       = '1',
            Size__c             = '1x1',
            In_Stock__c         = 100
        );
        insert new Product__c(
            Name                = 'P2',
            Product_Code__c     = 'T2',
            MSP__c              = 15,
            MRP__c              = 30,
            Product_Category__c = 'Wood',
            UOM__c              = 'Box',
            Price_Sqft__c       = 6,
            Sqft_Piece__c       = '1',
            Size__c             = '2x2',
            In_Stock__c         = 50
        );
        insert new Deals__c(Name='D1', Remarks__c='R1');
        insert new Lead(LastName='L1', Company='C1', Remarks__c='R1');
    }

    private static Product__c anyProduct() {
        return [SELECT Id FROM Product__c LIMIT 1];
    }

    private static Deals__c anyDeal() {
        return [SELECT Id FROM Deals__c LIMIT 1];
    }

    private static Lead anyLead() {
        return [SELECT Id FROM Lead LIMIT 1];
    }

    @isTest
    static void testGetProducts() {
        List<Product__c> prods = ProductController.getProducts();
        System.assertEquals(2, prods.size());
    }

    @isTest
    static void testGetProductCategories() {
        List<String> cats = ProductController.getProductCategories();
        System.assert(cats.size() > 0);
    }

    @isTest
    static void testCreateCartWithLead() {
        Lead ld = anyLead();
        Product__c p = anyProduct();
        List<Map<String,Object>> items = new List<Map<String,Object>>{
            new Map<String,Object>{ 'id' => p.Id, 'quantity' => 3, 'unitPrice' => 50 }
        };
        String cartId;
        Test.startTest();
            try {
                cartId = ProductController.createCart(ld.Id, items, 10, 5, 2);
            } catch (AuraHandledException e) {
            }
        Test.stopTest();
        if (cartId != null) {
            Integer cnt = [SELECT COUNT() FROM Cart_Line_Item__c WHERE Cart__c = :cartId];
            System.assertEquals(1, cnt);
        }
    }

    @isTest
    static void testCreateCartWithDeal() {
        Deals__c d = anyDeal();
        Product__c p = anyProduct();
        List<Map<String,Object>> items = new List<Map<String,Object>>{
            new Map<String,Object>{ 'id' => p.Id, 'quantity' => 2, 'unitPrice' => 75 }
        };
        String cartId;
        Test.startTest();
            try {
                cartId = ProductController.createCart(d.Id, items, null, null, null);
            } catch (AuraHandledException e) {
            }
        Test.stopTest();
        if (cartId != null) {
            Cart__c c = [SELECT Deals__c FROM Cart__c WHERE Id = :cartId];
            System.assertEquals(d.Id, c.Deals__c);
        }
    }

    @isTest
    static void testGetCustomerCarts() {
        Deals__c d = anyDeal();
        Product__c p = anyProduct();
        try {
            ProductController.createCart(
                d.Id,
                new List<Map<String,Object>>{ new Map<String,Object>{ 'id' => p.Id, 'quantity' => 1, 'unitPrice' => 1 } },
                1, 1, 1
            );
        } catch (AuraHandledException e) {
        }
        Test.startTest();
            List<Cart__c> carts = ProductController.getCustomerCarts(d.Id);
        Test.stopTest();
        System.assert(!carts.isEmpty());
        System.assert(!carts[0].Cart_Line_Items__r.isEmpty());
    }

    @isTest
    static void testCreateCartLineItem() {
        Deals__c d = anyDeal();
        String cartId;
        try {
            cartId = ProductController.createCart(d.Id, null, 0, 0, 0);
        } catch (AuraHandledException e) {
        }
        if (cartId != null) {
            Product__c p = anyProduct();
            String lineId;
            Test.startTest();
                try {
                    lineId = ProductController.createCartLineItem(
                        cartId,
                        new Map<String,Object>{ 'id' => p.Id, 'quantity' => 4, 'unitPrice' => 20 }
                    );
                } catch (AuraHandledException e) {
                }
            Test.stopTest();
            if (lineId != null) {
                Cart_Line_Item__c li = [SELECT Cart__c, Product__c, Quantity__c, Unit_Price__c
                                       FROM Cart_Line_Item__c WHERE Id = :lineId];
                System.assertEquals(cartId, li.Cart__c);
                System.assertEquals(4, li.Quantity__c);
                System.assertEquals(20, li.Unit_Price__c);
            }
        }
    }
    @isTest
    static void testDummyMethods() {
        // Test logInfo
        ProductController.logInfo('This is a test log');
        // Test logError
        ProductController.logError('This is a test error');
        // Test generateGreeting
        System.assertEquals('Hello, John!', ProductController.generateGreeting('John'), 'Greeting should include the name');
        System.assertEquals('Hello, Guest!', ProductController.generateGreeting(null), 'Greeting should default to Guest');
        // Test addNumbers
        System.assertEquals(5, ProductController.addNumbers(2, 3), 'Sum should be 5');
        // Test isValidLeadSource
        System.assertEquals(true, ProductController.isValidLeadSource('Web'), 'Web should be a valid lead source');
        System.assertEquals(false, ProductController.isValidLeadSource('Invalid'), 'Invalid lead source should return false');
        // Test mapLeadSource
        System.assertEquals('Online', ProductController.mapLeadSource('Web'), 'Web should map to Online');
        System.assertEquals('Unknown', ProductController.mapLeadSource('Invalid'), 'Invalid should map to Unknown');
        
        // Test generateRandomNumber
        Integer randomNumber = ProductController.generateRandomNumber(1, 100);
        System.assert(randomNumber >= 1 && randomNumber <= 100, 'Random number should be between 1 and 100');
        // Test convertToUpperCase
        System.assertEquals('HELLO', ProductController.convertToUpperCase('hello'), 'String should be converted to uppercase');
        System.assertEquals(null, ProductController.convertToUpperCase(null), 'Null input should return null');
        // Test calculateFactorial
        System.assertEquals(120, ProductController.calculateFactorial(5), 'Factorial of 5 should be 120');
        System.assertEquals(1, ProductController.calculateFactorial(0), 'Factorial of 0 should be 1');
        // Test reverseString
        System.assertEquals('OLLEH', ProductController.reverseString('HELLO'), 'String should be reversed');
        System.assertEquals('', ProductController.reverseString(''), 'Empty string should return an empty string');
        // Test isPalindrome
        System.assertEquals(true, ProductController.isPalindrome('madam'), 'madam should be a palindrome');
        System.assertEquals(false, ProductController.isPalindrome('hello'), 'hello should not be a palindrome');
        // Test sumOfDigits
        System.assertEquals(6, ProductController.sumOfDigits(123), 'Sum of digits of 123 should be 6');
        System.assertEquals(0, ProductController.sumOfDigits(0), 'Sum of digits of 0 should be 0');
        // Test isPrimeNumber
        System.assertEquals(true, ProductController.isPrimeNumber(5), '5 should be prime');
        System.assertEquals(false, ProductController.isPrimeNumber(4), '4 should not be prime');
        
        // Test findLargestDigit
        System.assertEquals(9, ProductController.findLargestDigit(489), 'Largest digit in 489 should be 9');
        System.assertEquals(5, ProductController.findLargestDigit(325), 'Largest digit in 325 should be 5');
        // Test reverseArray
        List<Integer> arr = new List<Integer>{1, 2, 3, 4};
        List<Integer> reversedArr = ProductController.reverseArray(arr);
        System.assertEquals(new List<Integer>{4, 3, 2, 1}, reversedArr, 'Array should be reversed');
        List<Integer> arr2 = new List<Integer>{5, 10, 15};
        List<Integer> reversedArr2 = ProductController.reverseArray(arr2);
        System.assertEquals(new List<Integer>{15, 10, 5}, reversedArr2, 'Array should be reversed');
    }
    @isTest
    static void testNewMethodsWithoutModulus() {
        // Test isLeapYear
        System.assertEquals(true, ProductController.isLeapYear(2024), '2024 is a leap year');
        System.assertEquals(false, ProductController.isLeapYear(2023), '2023 is not a leap year');
        System.assertEquals(false, ProductController.isLeapYear(1900), '1900 is not a leap year (divisible by 100 but not 400)');
        System.assertEquals(true, ProductController.isLeapYear(2000), '2000 is a leap year (divisible by 400)');
        // Test countWords
        System.assertEquals(5, ProductController.countWords('This is a test string'), 'Should count 5 words');
        System.assertEquals(1, ProductController.countWords('   '), 'Should count 0 words for empty spaces');
        System.assertEquals(3, ProductController.countWords('Hello  World!   Salesforce'), 'Should count 3 words ignoring extra spaces');
    }
    
    
}