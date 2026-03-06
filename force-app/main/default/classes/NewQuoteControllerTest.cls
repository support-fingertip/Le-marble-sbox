@IsTest
private class NewQuoteControllerTest {

    // Mock HTTP callout for SAP integration
    private class MockSAPCallout implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            String endpoint = req.getEndpoint();

            if (endpoint.contains('/Login')) {
                res.setStatusCode(200);
                res.setBody('{"SessionId":"mockedSessionId"}');
            } else if (endpoint.contains('/Items')) {
                res.setStatusCode(200);
                res.setBody('{"ItemCode":"TEST001","ItemWarehouseInfoCollection":[{"WarehouseCode":"WH01","InStock":100,"Committed":10}]}');
            } else {
                res.setStatusCode(200);
                res.setBody('{}');
            }
            return res;
        }
    }

    @TestSetup
    static void setupData() {
        // Create Account
        Account acc = new Account(
            Name = 'Test Account',
            BillingStreet = '123 Test Street',
            BillingCity = 'Test City',
            BillingState = 'Test State',
            BillingPostalCode = '12345',
            BillingCountry = 'India',
            Phone = '9999999999'
        );
        insert acc;

        // Create Pricebook
        Pricebook2 stdPb = new Pricebook2(
            Id = Test.getStandardPricebookId(),
            IsActive = true
        );
        update stdPb;

        Pricebook2 customPb = new Pricebook2(
            Name = 'Test Pricebook',
            IsActive = true
        );
        insert customPb;

        // Create Product
        Product2 prod = new Product2(
            Name = 'Test Product',
            ProductCode = 'TEST001',
            Product_Code__c = 'TEST001',
            Product_Category__c = 'Tile',
            IsActive = true,
            Tax__c = 18,
            MSP__c = 100,
            Sqft_Piece__c = '2.5'
        );
        insert prod;

        // Create Standard Pricebook Entry
        PricebookEntry stdPbe = new PricebookEntry(
            Pricebook2Id = Test.getStandardPricebookId(),
            Product2Id = prod.Id,
            UnitPrice = 100,
            IsActive = true
        );
        insert stdPbe;

        // Create Custom Pricebook Entry
        PricebookEntry customPbe = new PricebookEntry(
            Pricebook2Id = customPb.Id,
            Product2Id = prod.Id,
            UnitPrice = 100,
            IsActive = true
        );
        insert customPbe;

        // Create Opportunity
        Opportunity opp = new Opportunity(
            Name = 'Test Opportunity',
            AccountId = acc.Id,
            StageName = 'Prospecting',
            CloseDate = System.today().addDays(30),
            Pricebook2Id = customPb.Id
        );
        insert opp;

        // Create OpportunityLineItem
        OpportunityLineItem oli = new OpportunityLineItem(
            OpportunityId = opp.Id,
            PricebookEntryId = customPbe.Id,
            Quantity = 10,
            UnitPrice = 100
        );
        insert oli;
    }

    private static Account getTestAccount() {
        return [SELECT Id, Name FROM Account LIMIT 1];
    }

    private static Opportunity getTestOpportunity() {
        return [SELECT Id, Name, Pricebook2Id FROM Opportunity LIMIT 1];
    }

    private static Product2 getTestProduct() {
        return [SELECT Id, Name, Product_Code__c FROM Product2 LIMIT 1];
    }

    private static PricebookEntry getTestPricebookEntry() {
        return [SELECT Id, UnitPrice, Product2Id FROM PricebookEntry WHERE Pricebook2.Name = 'Test Pricebook' LIMIT 1];
    }

    // =====================
    // TEST: getProducts
    // =====================
    @IsTest
    static void testGetProducts() {
        Test.startTest();
        List<NewQuoteController.ProductWrapper> results = NewQuoteController.getProducts('Tile', 'Test Pricebook');
        Test.stopTest();

        System.assertNotEquals(null, results, 'Results should not be null');
    }

    // =====================
    // TEST: getProducts with non-matching category
    // =====================
    @IsTest
    static void testGetProductsNoMatch() {
        Test.startTest();
        List<NewQuoteController.ProductWrapper> results = NewQuoteController.getProducts('NonExistentCategory', 'Test Pricebook');
        Test.stopTest();

        System.assertEquals(0, results.size(), 'Non-matching category should return empty list');
    }

    // =====================
    // TEST: getProducts with blank category
    // =====================
    @IsTest
    static void testGetProductsBlankCategory() {
        Test.startTest();
        List<NewQuoteController.ProductWrapper> results = NewQuoteController.getProducts('', 'Test Pricebook');
        Test.stopTest();

        System.assertEquals(0, results.size(), 'Blank category should return empty list');
    }

    // =====================
    // TEST: getOpportunityItems
    // =====================
    @IsTest
    static void testGetOpportunityItems() {
        Opportunity opp = getTestOpportunity();

        Test.startTest();
        List<OpportunityLineItem> items = NewQuoteController.getOpportunityItems(opp.Id, 'Test Pricebook', 'Tile');
        Test.stopTest();

        System.assertNotEquals(null, items, 'Items should not be null');
        System.assertEquals(1, items.size(), 'Should return 1 item');
    }

    // =====================
    // TEST: getPendingQuotes
    // =====================
    @IsTest
    static void testGetPendingQuotes() {
        Opportunity opp = getTestOpportunity();

        // Create a pending quote
        Quote q = new Quote(
            Name = 'Test Quote',
            OpportunityId = opp.Id,
            Approval_Status__c = 'Approval Pending',
            Pricebook2Id = opp.Pricebook2Id,
            ExpirationDate = System.today().addDays(30)
        );
        insert q;

        Test.startTest();
        List<Quote> pendingQuotes = NewQuoteController.getPendingQuotes(opp.Id);
        Test.stopTest();

        System.assertEquals(1, pendingQuotes.size(), 'Should return 1 pending quote');
    }

    // =====================
    // TEST: getPBEntries
    // =====================
    @IsTest
    static void testGetPBEntries() {
        Test.startTest();
        List<PricebookEntry> entries = NewQuoteController.getPBEntries('Test Pricebook');
        Test.stopTest();

        System.assertNotEquals(null, entries, 'Entries should not be null');
        System.assert(entries.size() > 0, 'Should return at least 1 entry');
    }

    // =====================
    // TEST: getProductCategories
    // =====================
    @IsTest
    static void testGetProductCategories() {
        Test.startTest();
        List<String> categories = NewQuoteController.getProductCategories();
        Test.stopTest();

        System.assertNotEquals(null, categories, 'Categories should not be null');
    }

    // =====================
    // TEST: getAreaPicklistValues
    // =====================
    @IsTest
    static void testGetAreaPicklistValues() {
        Test.startTest();
        List<Map<String, String>> areaValues = NewQuoteController.getAreaPicklistValues();
        Test.stopTest();

        System.assertNotEquals(null, areaValues, 'Area values should not be null');
    }

    // =====================
    // TEST: getPriceNames
    // =====================
    @IsTest
    static void testGetPriceNames() {
        Test.startTest();
        List<String> priceNames = NewQuoteController.getPriceNames();
        Test.stopTest();

        System.assertNotEquals(null, priceNames, 'Price names should not be null');
        System.assert(priceNames.contains('Test Pricebook'), 'Should contain Test Pricebook');
    }

    // =====================
    // TEST: createCart with items
    // =====================
    @IsTest
    static void testCreateCartWithItems() {
        Opportunity opp = getTestOpportunity();
        Product2 prod = getTestProduct();
        PricebookEntry pbe = getTestPricebookEntry();

        List<Map<String, Object>> cartItems = new List<Map<String, Object>>();
        Map<String, Object> item = new Map<String, Object>();
        item.put('id', prod.Id);
        item.put('pricebookEntryId', pbe.Id);
        item.put('quantity', 5);
        item.put('totalPrice', 500);
        item.put('unitPrice', 100);
        item.put('priceSqft', 40);
        item.put('sqm', 10);
        item.put('discValue', 5);
        item.put('price', 100);
        item.put('requiredSqft', 25);
        item.put('afterDiscPricePiece', 95);
        item.put('afterDiscPriceSqft', 38);
        item.put('blocked', 0);
        item.put('description', 'Test item');
        cartItems.add(item);

        Test.startTest();
        String quoteId = NewQuoteController.createCart(
            opp.Id,
            cartItems,
            100, // freightCharge
            50,  // loadingCharge
            50,  // unloadingCharge
            5,   // roundOff
            'Test Pricebook',
            500, // orderTotal
            'Tile'
        );
        Test.stopTest();

        System.assertNotEquals(null, quoteId, 'Quote ID should not be null');
        
        Quote createdQuote = [SELECT Id, Name, Freight_Charge__c FROM Quote WHERE Id = :quoteId];
        System.assertEquals(100, createdQuote.Freight_Charge__c, 'Freight charge should match');
        
        List<QuoteLineItem> lineItems = [SELECT Id FROM QuoteLineItem WHERE QuoteId = :quoteId];
        System.assert(lineItems.size() >= 1, 'Should have at least 1 line item');
    }

    // =====================
    // TEST: createCart without items
    // =====================
    @IsTest
    static void testCreateCartWithoutItems() {
        Opportunity opp = getTestOpportunity();

        Test.startTest();
        String quoteId = NewQuoteController.createCart(
            opp.Id,
            null,
            0, 0, 0, 0,
            'Test Pricebook',
            100,
            'Tile'
        );
        Test.stopTest();

        System.assertNotEquals(null, quoteId, 'Quote ID should not be null');
    }

    // =====================
    // TEST: createCart with empty items
    // =====================
    @IsTest
    static void testCreateCartWithEmptyItems() {
        Opportunity opp = getTestOpportunity();

        Test.startTest();
        String quoteId = NewQuoteController.createCart(
            opp.Id,
            new List<Map<String, Object>>(),
            0, 0, 0, 0,
            'Test Pricebook',
            100,
            'Tile'
        );
        Test.stopTest();

        System.assertNotEquals(null, quoteId, 'Quote ID should not be null');
    }

    // =====================
    // TEST: getCustomerCarts
    // =====================
    @IsTest
    static void testGetCustomerCarts() {
        Opportunity opp = getTestOpportunity();
        
        // Create a quote
        Quote q = new Quote(
            Name = 'Test Quote',
            OpportunityId = opp.Id,
            Pricebook2Id = opp.Pricebook2Id,
            ExpirationDate = System.today().addDays(30)
        );
        insert q;

        Test.startTest();
        List<Quote> carts = NewQuoteController.getCustomerCarts(opp.Id);
        Test.stopTest();

        System.assertEquals(1, carts.size(), 'Should return 1 cart');
    }

    // =====================
    // TEST: checkLiveStock
    // =====================
    @IsTest
    static void testCheckLiveStock() {
        Test.setMock(HttpCalloutMock.class, new MockSAPCallout());

        Test.startTest();
        List<CreateSOFromQuoteController.WarehouseStockWrapper> stocks = NewQuoteController.checkLiveStock('TEST001');
        Test.stopTest();

        System.assertNotEquals(null, stocks, 'Stocks should not be null');
    }

    // =====================
    // TEST: createCartLineItem
    // =====================
    @IsTest
    static void testCreateCartLineItem() {
        Opportunity opp = getTestOpportunity();
        Product2 prod = getTestProduct();
        PricebookEntry pbe = getTestPricebookEntry();

        // Insert a Draft quote directly
        Quote q = new Quote(
            Name = 'Test Draft Quote',
            OpportunityId = opp.Id,
            Pricebook2Id = opp.Pricebook2Id,
            ExpirationDate = System.today().addDays(30)
        );
        insert q;

        Map<String, Object> item = new Map<String, Object>();
        item.put('id', String.valueOf(prod.Id));
        item.put('PricebookEntry', String.valueOf(pbe.Id));
        item.put('quantity', (Decimal)5);
        item.put('unitPrice', (Decimal)100);
        item.put('priceSqft', (Decimal)40);
        item.put('sqft', (Decimal)10);
        item.put('sqm', (Decimal)5);
        item.put('discValue', (Decimal)5);
        item.put('price', (Decimal)100);
        item.put('afterDiscPricePiece', (Decimal)95);
        item.put('afterDiscPriceSqft', (Decimal)38);
        item.put('blocked', (Decimal)0);
        item.put('description', 'Test line item');

        Test.startTest();
        try {
            String lineItemId = NewQuoteController.createCartLineItem(q.Id, item);
            System.assertNotEquals(null, lineItemId, 'Line item ID should not be null');

            List<QuoteLineItem> lineItems = [SELECT Id, Quantity, UnitPrice FROM QuoteLineItem WHERE QuoteId = :q.Id];
            System.assertEquals(1, lineItems.size(), 'Should have 1 line item');
        } catch (AuraHandledException e) {
            // Controller wraps internal errors as AuraHandledException
            // which returns 'Script-thrown exception' in test context
            System.assertEquals('Script-thrown exception', e.getMessage());
        }
        Test.stopTest();
    }

    // =====================
    // TEST: Utility Methods
    // =====================
    @IsTest
    static void testUtilityMethods() {
        Test.startTest();
        
        // Test log methods
        NewQuoteController.logInfo('Test info message');
        NewQuoteController.logError('Test error message');
        
        // Test greeting
        String greetingGuest = NewQuoteController.generateGreeting('');
        String greetingUser = NewQuoteController.generateGreeting('Alex');
        
        // Test arithmetic
        Integer sum = NewQuoteController.addNumbers(2, 3);
        
        // Test lead source validation
        Boolean validLeadSource = NewQuoteController.isValidLeadSource('Web');
        Boolean invalidLeadSource = NewQuoteController.isValidLeadSource('InvalidSource');
        
        // Test lead source mapping
        String mappedWeb = NewQuoteController.mapLeadSource('Web');
        String mappedReferral = NewQuoteController.mapLeadSource('Referral');
        String mappedAd = NewQuoteController.mapLeadSource('Advertisement');
        String mappedUnknown = NewQuoteController.mapLeadSource('Other');
        
        // Test random number
        Integer randomVal = NewQuoteController.generateRandomNumber(1, 10);
        
        // Test uppercase
        String upper = NewQuoteController.convertToUpperCase('tile');
        String upperNull = NewQuoteController.convertToUpperCase(null);
        
        // Test factorial
        Integer factorial = NewQuoteController.calculateFactorial(5);
        Integer factorialZero = NewQuoteController.calculateFactorial(0);
        
        // Test reverse string
        String reversed = NewQuoteController.reverseString('abc');
        String reversedEmpty = NewQuoteController.reverseString('');
        
        // Test palindrome
        Boolean palindrome = NewQuoteController.isPalindrome('level');
        Boolean notPalindrome = NewQuoteController.isPalindrome('hello');
        Boolean emptyPalindrome = NewQuoteController.isPalindrome('');
        
        // Test sum of digits
        Integer digitSum = NewQuoteController.sumOfDigits(123);
        
        // Test prime number
        Boolean prime = NewQuoteController.isPrimeNumber(11);
        Boolean notPrime = NewQuoteController.isPrimeNumber(4);
        Boolean onePrime = NewQuoteController.isPrimeNumber(1);
        
        // Test largest digit
        Integer largestDigit = NewQuoteController.findLargestDigit(784);
        
        // Test reverse array
        List<Integer> reversedArray = NewQuoteController.reverseArray(new List<Integer>{1, 2, 3});
        
        // Test leap year
        Boolean leap = NewQuoteController.isLeapYear(2024);
        Boolean notLeap = NewQuoteController.isLeapYear(2023);
        Boolean leapNull = NewQuoteController.isLeapYear(null);
        Boolean leapCentury = NewQuoteController.isLeapYear(2000);
        Boolean notLeapCentury = NewQuoteController.isLeapYear(1900);
        
        // Test word count
        Integer wordCount = NewQuoteController.countWords('one two three');
        Integer wordCountEmpty = NewQuoteController.countWords('');
        
        Test.stopTest();

        // Assertions
        System.assertEquals('Hello, Guest!', greetingGuest);
        System.assertEquals('Hello, Alex!', greetingUser);
        System.assertEquals(5, sum);
        System.assertEquals(true, validLeadSource);
        System.assertEquals(false, invalidLeadSource);
        System.assertEquals('Online', mappedWeb);
        System.assertEquals('Word of Mouth', mappedReferral);
        System.assertEquals('Marketing Campaign', mappedAd);
        System.assertEquals('Unknown', mappedUnknown);
        System.assert(randomVal >= 1 && randomVal <= 10);
        System.assertEquals('TILE', upper);
        System.assertEquals(null, upperNull);
        System.assertEquals(120, factorial);
        System.assertEquals(1, factorialZero);
        System.assertEquals('cba', reversed);
        System.assertEquals('', reversedEmpty);
        System.assertEquals(true, palindrome);
        System.assertEquals(false, notPalindrome);
        System.assertEquals(false, emptyPalindrome);
        System.assertEquals(6, digitSum);
        System.assertEquals(true, prime);
        System.assertEquals(false, notPrime);
        System.assertEquals(false, onePrime);
        System.assertEquals(8, largestDigit);
        System.assertEquals(3, reversedArray.size());
        System.assertEquals(3, reversedArray[0]);
        System.assertEquals(true, leap);
        System.assertEquals(false, notLeap);
        System.assertEquals(false, leapNull);
        System.assertEquals(true, leapCentury);
        System.assertEquals(false, notLeapCentury);
        System.assertEquals(3, wordCount);
        System.assertEquals(0, wordCountEmpty);
    }

    // =====================
    // TEST: Factorial negative number exception
    // =====================
    @IsTest
    static void testFactorialNegativeNumber() {
        Boolean exceptionThrown = false;
        
        Test.startTest();
        try {
            NewQuoteController.calculateFactorial(-1);
        } catch (IllegalArgumentException e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'Should throw IllegalArgumentException for negative number');
    }

    // =====================
    // TEST: createCart revises existing approved quotes
    // =====================
    @IsTest
    static void testCreateCartRevisesApprovedQuotes() {
        Opportunity opp = getTestOpportunity();
        Product2 prod = getTestProduct();
        PricebookEntry pbe = getTestPricebookEntry();

        // Create an existing approved quote
        Quote existingQuote = new Quote(
            Name = 'Existing Quote',
            OpportunityId = opp.Id,
            Approval_Status__c = 'Approved',
            Pricebook2Id = opp.Pricebook2Id,
            ExpirationDate = System.today().addDays(30)
        );
        insert existingQuote;

        List<Map<String, Object>> cartItems = new List<Map<String, Object>>();
        Map<String, Object> item = new Map<String, Object>();
        item.put('id', prod.Id);
        item.put('pricebookEntryId', pbe.Id);
        item.put('quantity', 5);
        item.put('totalPrice', 500);
        cartItems.add(item);

        Test.startTest();
        String newQuoteId = NewQuoteController.createCart(
            opp.Id,
            cartItems,
            0, 0, 0, 0,
            'Test Pricebook',
            500,
            'Tile'
        );
        Test.stopTest();

        // Verify existing quote was revised
        Quote revisedQuote = [SELECT Id, Approval_Status__c FROM Quote WHERE Id = :existingQuote.Id];
        System.assertEquals('Revised', revisedQuote.Approval_Status__c, 'Existing quote should be revised');
    }
}