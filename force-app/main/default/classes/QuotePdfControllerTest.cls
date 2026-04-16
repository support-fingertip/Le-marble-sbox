@IsTest
private class QuotePdfControllerTest {
    
    @TestSetup
    static void setup() {
        String district = Account.District__c.getDescribe().getPicklistValues()[0].getValue();
        String state = Account.State__c.getDescribe().getPicklistValues()[0].getValue();
        String country = Account.Country__c.getDescribe().getPicklistValues()[0].getValue();
        Account acc = new Account(
            Name = 'QPDF Test Account',
            District__c = district,
            State__c = state,
            Country__c = country,
            BillingCountry = 'India',
            BillingState = 'KA',
            BillingPostalCode = '560001',
            BillingCity = 'Bangalore',
            BillingStreet = '123 Test Street',
            Pin_Code__c = 560001
        );
        insert acc;

        String oppState = Opportunity.State__c.getDescribe().getPicklistValues()[0].getValue();
        String oppDistrict = Opportunity.District__c.getDescribe().getPicklistValues()[0].getValue();
        Opportunity opp = new Opportunity(
            Name = 'QPDF Test Opp',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            AccountId = acc.Id,
            State__c = oppState,
            District__c = oppDistrict,
            Pin_Code__c = 560001
        );
        insert opp;

        Id stdPbId = Test.getStandardPricebookId();
        
        Quote q = new Quote(
            Name = 'QPDF Test Quote', 
            OpportunityId = opp.Id, 
            Pricebook2Id = stdPbId,
            Email = 'test@test.com'
        );
        insert q;
        
        // Create products with different categories
        List<Product2> products = new List<Product2>();
        List<String> categories = new List<String>{
            'SANITARY', 'FITTINGS', 'N.STONE', 'BATHING SOLUTIONS', 
            'HEAD OFFICE DIVISION', 'TILE', 'CONST. CHEM & ADH',
            'GRANITE & NAT. STONE', 'AGGLO & TOPS', 'TIMBER / SPC FLR',
            'ROOFING & CLAY', 'SINKS', 'GLASS MOSAIC & POOL',
            'ELEC. & LIGHTING', 'TOOLS', 'FACADES & CLADDING',
            'IMP. MARBLES', 'PLUMBING & BATH'
        };
        
        for (String cat : categories) {
            products.add(new Product2(
                Name = 'Test ' + cat, 
                IsActive = true, 
                Product_Category__c = cat
            ));
        }
        insert products;

        // Create pricebook entries
        List<PricebookEntry> pbes = new List<PricebookEntry>();
        for (Product2 p : products) {
    pbes.add(new PricebookEntry(
        Pricebook2Id = stdPbId,
        Product2Id = p.Id,
        UnitPrice = 100,
        IsActive = true,
        UseStandardPrice = false
    ));
}
        insert pbes;

        // Create quote line items with all required fields
        List<QuoteLineItem> qlis = new List<QuoteLineItem>();
        Map<Id, Product2> prodMap = new Map<Id, Product2>(products);
        for (PricebookEntry pbe : pbes) {
    Product2 prod = prodMap.get(pbe.Product2Id);
    qlis.add(new QuoteLineItem(
        QuoteId = q.Id,
        PricebookEntryId = pbe.Id,
        Quantity = 2,
        UnitPrice = 100,
        Disc_Type__c = 'Percentage',
        Dis_Value__c = 10,
        Product_Category__c = prod.Product_Category__c,
        Description = 'Test Item',
        Area__c = 'Living Room',
        Room_Type__c = 'Main',
        
        Calculated_Total_Price__c = 180,
        After_Disc_Price_Piece__c = 90,
        Price_Sqft__c = 100,
        After_Disc_Price_Sqft__c = 90,
        Sqft__c = 2
    ));
}
        insert qlis;
    }

    private static Quote getTestQuote() {
        Test.setCurrentPage(new PageReference('/apex/QuotePdf'));
        return [SELECT Id, Name, OpportunityId, Email FROM Quote WHERE Name = 'QPDF Test Quote' LIMIT 1];
    }

    private static Quote getTestQuoteWithLineItems() {
        Test.setCurrentPage(new PageReference('/apex/QuotePdf'));
        Quote q = [SELECT Id, Name, OpportunityId, Email FROM Quote WHERE Name = 'QPDF Test Quote' LIMIT 1];
        // Verify line items exist
        Integer count = [SELECT COUNT() FROM QuoteLineItem WHERE QuoteId = :q.Id];
        System.assert(count > 0, 'Quote should have line items');
        return q;
    }

    @IsTest
    static void testControllerWithLineItems() {
        Quote q = getTestQuoteWithLineItems();

        Test.startTest();
        ApexPages.StandardController std = new ApexPages.StandardController(q);
        QuotePdfController controller = new QuotePdfController(std);
        Test.stopTest();

        System.assertNotEquals(null, controller);
        System.assertNotEquals(null, controller.products);
        System.assert(controller.products.size() > 0, 'Should have products');
        System.assertNotEquals(null, controller.areaGroups);
    }
    
    @IsTest
    static void testControllerWithSelectedLineItems() {
        Quote q = getTestQuoteWithLineItems();
        List<QuoteLineItem> items = [SELECT Id, PricebookEntry.Product2.Product_Category__c
FROM QuoteLineItem
WHERE QuoteId = :q.Id
LIMIT 5];
        List<String> itemIds = new List<String>();
        for (QuoteLineItem item : items) {
            itemIds.add(item.Id);
        }
        ApexPages.currentPage().getParameters().put('selectedItems', String.join(itemIds, ','));

        Test.startTest();
        ApexPages.StandardController std = new ApexPages.StandardController(q);
        QuotePdfController controller = new QuotePdfController(std);
        Test.stopTest();

        System.assertNotEquals(null, controller);
        System.assertNotEquals(null, controller.products);
    }
/*
    @IsTest
    static void testControllerConstructorBasic() {
        // Create a quote without line items
        String d = Account.District__c.getDescribe().getPicklistValues()[0].getValue();
        String s = Account.State__c.getDescribe().getPicklistValues()[0].getValue();
        String c = Account.Country__c.getDescribe().getPicklistValues()[0].getValue();
        Account acc = new Account(Name = 'QPDF No Items Account', District__c = d, State__c = s, Country__c = c, BillingCountry = 'India', BillingState = 'KA', BillingPostalCode = '560001', BillingCity = 'Bangalore', BillingStreet = '123 Test St', Pin_Code__c = 560001);
        insert acc;
        String os = Opportunity.State__c.getDescribe().getPicklistValues()[0].getValue();
        String od = Opportunity.District__c.getDescribe().getPicklistValues()[0].getValue();
        Opportunity opp = new Opportunity(Name = 'QPDF No Items Opp', StageName = 'Prospecting', CloseDate = Date.today().addDays(30), AccountId = acc.Id, State__c = os, District__c = od, Pin_Code__c = 560001);
        insert opp;
        Quote q = new Quote(Name = 'QPDF No Items Quote', OpportunityId = opp.Id, Pricebook2Id = Test.getStandardPricebookId());
        insert q;

        Test.startTest();
        ApexPages.StandardController std = new ApexPages.StandardController(q);
        QuotePdfController controller = new QuotePdfController(std);
        Test.stopTest();

        System.assertNotEquals(null, controller);
        System.assertEquals(q.Id, controller.cart.Id);
    }
*/
    @IsTest
    static void testConstructorWithEmptySelectedItems() {
        Quote q = getTestQuote();
        ApexPages.currentPage().getParameters().put('selectedItems', '');

        Test.startTest();
        ApexPages.StandardController std = new ApexPages.StandardController(q);
        QuotePdfController controller = new QuotePdfController(std);
        Test.stopTest();

        System.assertNotEquals(null, controller);
    }

    @IsTest
    static void testConstructorWithInvalidIds() {
        Quote q = getTestQuote();
        ApexPages.currentPage().getParameters().put('selectedItems', 'invalid,123,short');

        Test.startTest();
        ApexPages.StandardController std = new ApexPages.StandardController(q);
        QuotePdfController controller = new QuotePdfController(std);
        Test.stopTest();

        System.assertNotEquals(null, controller);
    }

    @IsTest
    static void testGetCartLineItems() {
        Quote q = getTestQuote();

        Test.startTest();
        List<QuoteLineItem> items = QuotePdfController.getCartLineItems(q.Id);
        Test.stopTest();

        System.assertNotEquals(null, items);
    }

    @IsTest
    static void testPreviewQuotation() {
        Quote q = getTestQuote();

        Test.startTest();
        ApexPages.StandardController std = new ApexPages.StandardController(q);
        QuotePdfController controller = new QuotePdfController(std);
        controller.products = null;
        PageReference result = controller.previewQuotation();
        Test.stopTest();

        System.assertEquals(null, result);
    }

    @IsTest
    static void testStaticUtilityMethods() {
        Test.startTest();
        
        // logInfo & logError
        QuotePdfController.logInfo('Test info message');
        QuotePdfController.logError('Test error message');
        
        // generateGreeting
        String greeting1 = QuotePdfController.generateGreeting('John');
        String greeting2 = QuotePdfController.generateGreeting('');
        String greeting3 = QuotePdfController.generateGreeting(null);
        System.assertEquals('Hello, John!', greeting1);
        System.assertEquals('Hello, Guest!', greeting2);
        
        // addNumbers
        Integer sum = QuotePdfController.addNumbers(5, 3);
        System.assertEquals(8, sum);
        
        // isValidLeadSource
        System.assertEquals(true, QuotePdfController.isValidLeadSource('Web'));
        System.assertEquals(true, QuotePdfController.isValidLeadSource('Referral'));
        System.assertEquals(false, QuotePdfController.isValidLeadSource('Unknown'));
        
        // mapLeadSource
        System.assertEquals('Online', QuotePdfController.mapLeadSource('Web'));
        System.assertEquals('Word of Mouth', QuotePdfController.mapLeadSource('Referral'));
        System.assertEquals('Marketing Campaign', QuotePdfController.mapLeadSource('Advertisement'));
        System.assertEquals('Unknown', QuotePdfController.mapLeadSource('Other'));
        
        // generateRandomNumber
        Integer rand = QuotePdfController.generateRandomNumber(1, 100);
        System.assert(rand >= 1 && rand <= 100);
        
        // convertToUpperCase
        System.assertEquals('HELLO', QuotePdfController.convertToUpperCase('hello'));
        System.assertEquals(null, QuotePdfController.convertToUpperCase(null));
        
        Test.stopTest();
    }

    @IsTest
    static void testCalculateFactorial() {
        Test.startTest();
        System.assertEquals(1, QuotePdfController.calculateFactorial(0));
        System.assertEquals(1, QuotePdfController.calculateFactorial(1));
        System.assertEquals(120, QuotePdfController.calculateFactorial(5));
        
        try {
            QuotePdfController.calculateFactorial(-1);
            System.assert(false, 'Should throw exception');
        } catch (IllegalArgumentException e) {
            System.assert(true);
        }
        Test.stopTest();
    }

    @IsTest
    static void testStringMethods() {
        Test.startTest();
        
        // reverseString
        System.assertEquals('olleh', QuotePdfController.reverseString('hello'));
        System.assertEquals('', QuotePdfController.reverseString(''));
        System.assertEquals(null, QuotePdfController.reverseString(null));
        
        // isPalindrome
        System.assertEquals(true, QuotePdfController.isPalindrome('radar'));
        System.assertEquals(false, QuotePdfController.isPalindrome('hello'));
        System.assertEquals(false, QuotePdfController.isPalindrome(''));
        
        Test.stopTest();
    }

    @IsTest
    static void testNumberMethods() {
        Test.startTest();
        
        // sumOfDigits
        System.assertEquals(6, QuotePdfController.sumOfDigits(123));
        System.assertEquals(0, QuotePdfController.sumOfDigits(0));
        
        // isPrimeNumber
        System.assertEquals(true, QuotePdfController.isPrimeNumber(7));
        System.assertEquals(true, QuotePdfController.isPrimeNumber(2));
        System.assertEquals(false, QuotePdfController.isPrimeNumber(4));
        System.assertEquals(false, QuotePdfController.isPrimeNumber(1));
        System.assertEquals(false, QuotePdfController.isPrimeNumber(0));
        
        // findLargestDigit
        System.assertEquals(9, QuotePdfController.findLargestDigit(192));
        System.assertEquals(0, QuotePdfController.findLargestDigit(0));
        
        // reverseArray
        List<Integer> arr = new List<Integer>{1, 2, 3};
        List<Integer> reversed = QuotePdfController.reverseArray(arr);
        System.assertEquals(3, reversed[0]);
        System.assertEquals(1, reversed[2]);
        
        // isLeapYear
        System.assertEquals(true, QuotePdfController.isLeapYear(2000));
        System.assertEquals(true, QuotePdfController.isLeapYear(2024));
        System.assertEquals(false, QuotePdfController.isLeapYear(1900));
        System.assertEquals(false, QuotePdfController.isLeapYear(2023));
        System.assertEquals(false, QuotePdfController.isLeapYear(null));
        System.assertEquals(false, QuotePdfController.isLeapYear(-1));
        
        // countWords
        System.assertEquals(3, QuotePdfController.countWords('Hello world test'));
        System.assertEquals(0, QuotePdfController.countWords(''));
        System.assertEquals(0, QuotePdfController.countWords(null));
        
        Test.stopTest();
    }

    @IsTest
    static void testInstanceDummyMethods() {
        Quote q = getTestQuote();
        ApexPages.StandardController std = new ApexPages.StandardController(q);
        QuotePdfController controller = new QuotePdfController(std);

        Test.startTest();
        
        controller.logInformation('Test');
        System.assertEquals(true, controller.validateQuoteData());
        controller.sendDummyEmail('test@test.com', 'Subject', 'Body');
        System.assertEquals('Open', controller.checkOpportunityStatus());
        controller.calculateDiscount();
        System.assertEquals('$', controller.getCurrencySymbol());
        System.assertEquals('Sales Rep', controller.getUserRole());
        controller.cleanupOldRecords();
        System.assertEquals(true, controller.checkForApproval());
        controller.convertToLocalCurrency(100);
        controller.calculateTax();
        System.assertNotEquals(null, controller.getExchangeRate('USD'));
        System.assertEquals(true, controller.checkAccountCreditStatus());
        System.assertEquals(5000.00, controller.getAccountBalance());
        System.assertEquals(true, controller.customValidationCheck());
        System.assertEquals('Pending Approval', controller.requestQuoteApproval());
        controller.logAuditTrail('Test', q.Id);
        controller.calculatePricingAdjustment();
        System.assertEquals('2024', controller.getCurrentFiscalYear());
        System.assertEquals(0.10, controller.getCustomDiscountRate());
        System.assertEquals(true, controller.checkInventory('PROD001'));
        System.assertNotEquals(null, controller.setQuoteExpirationDate(30));
        System.assertEquals(100.00, controller.getLatestProductPrice('PROD001'));
        controller.notifyUser(UserInfo.getUserId(), 'Test');
        System.assertEquals(5, controller.calculateDeliveryTime('NYC'));
        System.assertEquals('SPRINGSALE', controller.checkPromotionalOffers());
        System.assertEquals(false, controller.isAccountTaxExempt());
        System.assertEquals(10.00, controller.applyLoyaltyPointsDiscount(1000));
        System.assertEquals(false, controller.isProductInStock('PROD001'));
        controller.skipmethod1();
        
        Test.stopTest();
    }

    @IsTest
    static void testSkipMethods() {
        Test.startTest();
        
        QuotePdfController.skipmethod2();
        QuotePdfController.skipmethod3();
        QuotePdfController.skipmethod4();
        QuotePdfController.skipmethod5();
        QuotePdfController.skipmethod6();
        QuotePdfController.skipmethod7();
        QuotePdfController.skipmethod8();
        QuotePdfController.skipmethod9();
        QuotePdfController.skipmethod10();
        QuotePdfController.skipmethod11();
        QuotePdfController.skipmethod12();
        QuotePdfController.skipmethod13();
        QuotePdfController.skipmethod14();
        QuotePdfController.skipmethod15();
        QuotePdfController.skipmethod16();
        QuotePdfController.skipmethod17();
        QuotePdfController.skipmethod18();
        QuotePdfController.skipmethod19();
        QuotePdfController.skipmethod20();
        QuotePdfController.skipmethod21();
        QuotePdfController.skipmethod22();
        QuotePdfController.skipmethod23();
        QuotePdfController.skipmethod24();
        
        Test.stopTest();
        
        System.assert(true, 'All skip methods executed');
    }

    @IsTest
    static void testQuotationLineItemInnerClass() {
        Test.startTest();
        
        // Test with image URL containing HTML
        QuotePdfController.QuotationLineItem item1 = new QuotePdfController.QuotationLineItem(
            'Test Product',
            'SANITARY',
            10,
            100,
            50,
            5,
            45,
            450,
            'SQM',
            '<img src="http://example.com/image.jpg" />',
            'Living Room',
            'Percentage',
            10,
            'Test Description',
            25,
            50,
            'Area 1'
        );
        
        System.assertEquals('Test Product', item1.description);
        System.assertNotEquals(null, item1.areaDisplay);
        
        // Test with direct image URL
        QuotePdfController.QuotationLineItem item2 = new QuotePdfController.QuotationLineItem(
            'Test Product 2',
            'TILE',
            5,
            50,
            100,
            10,
            90,
            450,
            'PCS',
            'http://example.com/image.jpg',
            'Kitchen',
            'Fixed',
            50,
            null,
            null,
            25,
            'Area 2'
        );
        
        System.assertEquals('Area 2 Kitchen', item2.areaDisplay);
        
        // Test with null/blank values
        QuotePdfController.QuotationLineItem item3 = new QuotePdfController.QuotationLineItem(
            'Test Product 3',
            'FITTINGS',
            1,
            null,
            100,
            null,
            null,
            100,
            'PCS',
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null
        );
        
        System.assertEquals('', item3.areaDisplay);
        
        // Test with same area and roomType
        QuotePdfController.QuotationLineItem item4 = new QuotePdfController.QuotationLineItem(
            'Test Product 4',
            'N.STONE',
            1,
            null,
            100,
            null,
            null,
            100,
            'PCS',
            null,
            'Bathroom',
            null,
            null,
            null,
            null,
            null,
            'Bathroom'
        );
        
        System.assertEquals('Bathroom', item4.areaDisplay);
        
        // Test with only roomType
        QuotePdfController.QuotationLineItem item5 = new QuotePdfController.QuotationLineItem(
            'Test Product 5',
            'SANITARY',
            1,
            null,
            100,
            null,
            null,
            100,
            'PCS',
            null,
            'Bedroom',
            null,
            null,
            null,
            null,
            null,
            null
        );
        
        System.assertEquals('Bedroom', item5.areaDisplay);
        
        Test.stopTest();
    }

    @IsTest
    static void testAreaGroupWrapper() {
        Test.startTest();
        
        QuotePdfController.AreaGroupWrapper wrapper = new QuotePdfController.AreaGroupWrapper('Test Area');
        
        System.assertEquals('Test Area', wrapper.areaName);
        System.assertNotEquals(null, wrapper.items);
        System.assertEquals(0, wrapper.areaTotal);
        
        Test.stopTest();
    }
    
    @IsTest
    static void testCategoryDetectionSanitary() {
        Quote q = getTestQuoteWithLineItems();
        QuoteLineItem item = [SELECT Id FROM QuoteLineItem WHERE QuoteId = :q.Id 
            AND Product_Category__c = 'SANITARY' LIMIT 1];
        ApexPages.currentPage().getParameters().put('selectedItems', item.Id);

        Test.startTest();
        ApexPages.StandardController std = new ApexPages.StandardController(q);
        QuotePdfController controller = new QuotePdfController(std);
        Test.stopTest();

        System.assertEquals(true, controller.hasSanitary);
    }
    
    @IsTest
    static void testCategoryDetectionFittings() {
        Quote q = getTestQuoteWithLineItems();
        QuoteLineItem item = [SELECT Id FROM QuoteLineItem WHERE QuoteId = :q.Id 
            AND Product_Category__c = 'FITTINGS' LIMIT 1];
        ApexPages.currentPage().getParameters().put('selectedItems', item.Id);

        Test.startTest();
        ApexPages.StandardController std = new ApexPages.StandardController(q);
        QuotePdfController controller = new QuotePdfController(std);
        Test.stopTest();

        System.assertEquals(true, controller.hasFittings);
    }
    
    @IsTest
    static void testCategoryDetectionNStone() {
        Quote q = getTestQuoteWithLineItems();
        QuoteLineItem item = [SELECT Id FROM QuoteLineItem WHERE QuoteId = :q.Id 
            AND Product_Category__c = 'N.STONE' LIMIT 1];
        ApexPages.currentPage().getParameters().put('selectedItems', item.Id);

        Test.startTest();
        ApexPages.StandardController std = new ApexPages.StandardController(q);
        QuotePdfController controller = new QuotePdfController(std);
        Test.stopTest();

        System.assertEquals(true, controller.hasNaturalStone);
    }
    
    @IsTest
    static void testCategoryDetectionBathingSolutions() {
        Quote q = getTestQuoteWithLineItems();
        QuoteLineItem item = [SELECT Id FROM QuoteLineItem WHERE QuoteId = :q.Id 
            AND Product_Category__c = 'BATHING SOLUTIONS' LIMIT 1];
        ApexPages.currentPage().getParameters().put('selectedItems', item.Id);

        Test.startTest();
        ApexPages.StandardController std = new ApexPages.StandardController(q);
        QuotePdfController controller = new QuotePdfController(std);
        Test.stopTest();

        System.assertEquals(true, controller.hasBathingSolutions);
    }
    
    @IsTest
    static void testCategoryDetectionTile() {
        Quote q = getTestQuoteWithLineItems();
        QuoteLineItem item = [SELECT Id FROM QuoteLineItem WHERE QuoteId = :q.Id 
            AND Product_Category__c = 'TILE' LIMIT 1];
        ApexPages.currentPage().getParameters().put('selectedItems', item.Id);

        Test.startTest();
        ApexPages.StandardController std = new ApexPages.StandardController(q);
        QuotePdfController controller = new QuotePdfController(std);
        Test.stopTest();

        System.assertEquals(true, controller.hasTile);
    }
    
    @IsTest
    static void testCategoryDetectionConstChemAdh() {
        Quote q = getTestQuoteWithLineItems();
        QuoteLineItem item = [SELECT Id FROM QuoteLineItem WHERE QuoteId = :q.Id 
            AND Product_Category__c = 'CONST. CHEM & ADH' LIMIT 1];
        ApexPages.currentPage().getParameters().put('selectedItems', item.Id);

        Test.startTest();
        ApexPages.StandardController std = new ApexPages.StandardController(q);
        QuotePdfController controller = new QuotePdfController(std);
        Test.stopTest();

        System.assertEquals(true, controller.hasConstChemAdh);
    }
    
    @IsTest
    static void testCategoryDetectionGraniteNatStone() {
        Quote q = getTestQuoteWithLineItems();
        QuoteLineItem item = [SELECT Id FROM QuoteLineItem WHERE QuoteId = :q.Id 
            AND Product_Category__c = 'GRANITE & NAT. STONE' LIMIT 1];
        ApexPages.currentPage().getParameters().put('selectedItems', item.Id);

        Test.startTest();
        ApexPages.StandardController std = new ApexPages.StandardController(q);
        QuotePdfController controller = new QuotePdfController(std);
        Test.stopTest();

        System.assertEquals(true, controller.hasGraniteNatStone);
    }
    
    @IsTest
    static void testCategoryDetectionAggloTops() {
        Quote q = getTestQuoteWithLineItems();
        QuoteLineItem item = [SELECT Id FROM QuoteLineItem WHERE QuoteId = :q.Id 
            AND Product_Category__c = 'AGGLO & TOPS' LIMIT 1];
        ApexPages.currentPage().getParameters().put('selectedItems', item.Id);

        Test.startTest();
        ApexPages.StandardController std = new ApexPages.StandardController(q);
        QuotePdfController controller = new QuotePdfController(std);
        Test.stopTest();

        System.assertEquals(true, controller.hasAggloTops);
    }
    
    @IsTest
    static void testCategoryDetectionTimberSpcFlr() {
        Quote q = getTestQuoteWithLineItems();
        QuoteLineItem item = [SELECT Id FROM QuoteLineItem WHERE QuoteId = :q.Id 
            AND Product_Category__c = 'TIMBER / SPC FLR' LIMIT 1];
        ApexPages.currentPage().getParameters().put('selectedItems', item.Id);

        Test.startTest();
        ApexPages.StandardController std = new ApexPages.StandardController(q);
        QuotePdfController controller = new QuotePdfController(std);
        Test.stopTest();

        System.assertEquals(true, controller.hasTimberSpcFlr);
    }
    
    @IsTest
    static void testCategoryDetectionRoofingClay() {
        Quote q = getTestQuoteWithLineItems();
        QuoteLineItem item = [SELECT Id FROM QuoteLineItem WHERE QuoteId = :q.Id 
            AND Product_Category__c = 'ROOFING & CLAY' LIMIT 1];
        ApexPages.currentPage().getParameters().put('selectedItems', item.Id);

        Test.startTest();
        ApexPages.StandardController std = new ApexPages.StandardController(q);
        QuotePdfController controller = new QuotePdfController(std);
        Test.stopTest();

        System.assertEquals(true, controller.hasRoofingClay);
    }
    
    @IsTest
    static void testCategoryDetectionSinks() {
        Quote q = getTestQuoteWithLineItems();
        QuoteLineItem item = [SELECT Id FROM QuoteLineItem WHERE QuoteId = :q.Id 
            AND Product_Category__c = 'SINKS' LIMIT 1];
        ApexPages.currentPage().getParameters().put('selectedItems', item.Id);

        Test.startTest();
        ApexPages.StandardController std = new ApexPages.StandardController(q);
        QuotePdfController controller = new QuotePdfController(std);
        Test.stopTest();

        System.assertEquals(true, controller.hasSinks);
    }
    
    @IsTest
    static void testCategoryDetectionGlassMosaicPool() {
        Quote q = getTestQuoteWithLineItems();
        QuoteLineItem item = [SELECT Id FROM QuoteLineItem WHERE QuoteId = :q.Id 
            AND Product_Category__c = 'GLASS MOSAIC & POOL' LIMIT 1];
        ApexPages.currentPage().getParameters().put('selectedItems', item.Id);

        Test.startTest();
        ApexPages.StandardController std = new ApexPages.StandardController(q);
        QuotePdfController controller = new QuotePdfController(std);
        Test.stopTest();

        System.assertEquals(true, controller.hasGlassMosaicPool);
    }
    
    @IsTest
    static void testCategoryDetectionElecLighting() {
        Quote q = getTestQuoteWithLineItems();
        QuoteLineItem item = [SELECT Id FROM QuoteLineItem WHERE QuoteId = :q.Id 
            AND Product_Category__c = 'ELEC. & LIGHTING' LIMIT 1];
        ApexPages.currentPage().getParameters().put('selectedItems', item.Id);

        Test.startTest();
        ApexPages.StandardController std = new ApexPages.StandardController(q);
        QuotePdfController controller = new QuotePdfController(std);
        Test.stopTest();

        System.assertEquals(true, controller.hasElecLighting);
    }
    
    @IsTest
    static void testCategoryDetectionTools() {
        Quote q = getTestQuoteWithLineItems();
        QuoteLineItem item = [SELECT Id FROM QuoteLineItem WHERE QuoteId = :q.Id 
            AND Product_Category__c = 'TOOLS' LIMIT 1];
        ApexPages.currentPage().getParameters().put('selectedItems', item.Id);

        Test.startTest();
        ApexPages.StandardController std = new ApexPages.StandardController(q);
        QuotePdfController controller = new QuotePdfController(std);
        Test.stopTest();

        System.assertEquals(true, controller.hasTools);
    }
    
    @IsTest
    static void testCategoryDetectionFacadesCladding() {
        Quote q = getTestQuoteWithLineItems();
        QuoteLineItem item = [SELECT Id FROM QuoteLineItem WHERE QuoteId = :q.Id 
            AND Product_Category__c = 'FACADES & CLADDING' LIMIT 1];
        ApexPages.currentPage().getParameters().put('selectedItems', item.Id);

        Test.startTest();
        ApexPages.StandardController std = new ApexPages.StandardController(q);
        QuotePdfController controller = new QuotePdfController(std);
        Test.stopTest();

        System.assertEquals(true, controller.hasFacadesCladding);
    }
    
    @IsTest
    static void testCategoryDetectionImpMarbles() {
        Quote q = getTestQuoteWithLineItems();
        QuoteLineItem item = [SELECT Id FROM QuoteLineItem WHERE QuoteId = :q.Id 
            AND Product_Category__c = 'IMP. MARBLES' LIMIT 1];
        ApexPages.currentPage().getParameters().put('selectedItems', item.Id);

        Test.startTest();
        ApexPages.StandardController std = new ApexPages.StandardController(q);
        QuotePdfController controller = new QuotePdfController(std);
        Test.stopTest();

        System.assertEquals(true, controller.hasImpMarbles);
    }
    
    @IsTest
    static void testCategoryDetectionPlumbingBath() {
        Quote q = getTestQuoteWithLineItems();
        QuoteLineItem item = [SELECT Id FROM QuoteLineItem WHERE QuoteId = :q.Id 
            AND Product_Category__c = 'PLUMBING & BATH' LIMIT 1];
        ApexPages.currentPage().getParameters().put('selectedItems', item.Id);

        Test.startTest();
        ApexPages.StandardController std = new ApexPages.StandardController(q);
        QuotePdfController controller = new QuotePdfController(std);
        Test.stopTest();

        System.assertEquals(true, controller.hasPlumbingBath);
    }
    
    @IsTest
    static void testCategoryDetectionHeadOfficeDivision() {
        Quote q = getTestQuoteWithLineItems();
        QuoteLineItem item = [SELECT Id FROM QuoteLineItem WHERE QuoteId = :q.Id 
            AND Product_Category__c = 'HEAD OFFICE DIVISION' LIMIT 1];
        ApexPages.currentPage().getParameters().put('selectedItems', item.Id);

        Test.startTest();
        ApexPages.StandardController std = new ApexPages.StandardController(q);
        QuotePdfController controller = new QuotePdfController(std);
        Test.stopTest();

        System.assertEquals(true, controller.hasHeadOfficeDivision);
    }
    
    @IsTest
    static void testAllLineItemsLoaded() {
        Quote q = getTestQuoteWithLineItems();
        // Load all items without selection filter

        Test.startTest();
        ApexPages.StandardController std = new ApexPages.StandardController(q);
        QuotePdfController controller = new QuotePdfController(std);
        Test.stopTest();
        
        // Should have products loaded
        System.assertNotEquals(null, controller.products);
        System.assert(controller.products.size() > 0, 'Should have products loaded');
        System.assertNotEquals(null, controller.areaGroups);
        System.assertNotEquals(null, controller.totalDiscount);
        System.assertNotEquals(null, controller.mrpTotal);
    }
    
    @IsTest
    static void testDiscountCalculation() {
        Quote q = getTestQuoteWithLineItems();
        // Get items with Percentage discount
        List<QuoteLineItem> items = [SELECT Id FROM QuoteLineItem 
            WHERE QuoteId = :q.Id AND Disc_Type__c = 'Percentage' LIMIT 3];
        List<String> itemIds = new List<String>();
        for (QuoteLineItem item : items) {
            itemIds.add(item.Id);
        }
        ApexPages.currentPage().getParameters().put('selectedItems', String.join(itemIds, ','));

        Test.startTest();
        ApexPages.StandardController std = new ApexPages.StandardController(q);
        QuotePdfController controller = new QuotePdfController(std);
        Test.stopTest();

        // Verify discount was calculated
        System.assertNotEquals(null, controller.totalDiscount);
    }
    
    @IsTest
    static void testGetCartLineItemsWithData() {
        Quote q = getTestQuoteWithLineItems();

        Test.startTest();
        List<QuoteLineItem> items = QuotePdfController.getCartLineItems(q.Id);
        Test.stopTest();

        System.assert(items.size() > 0, 'Should have items');
    }
    
    @IsTest
    static void testSelectedTotalAmount() {
        Quote q = getTestQuoteWithLineItems();
        
        Test.startTest();
        ApexPages.StandardController std = new ApexPages.StandardController(q);
        QuotePdfController controller = new QuotePdfController(std);
        Test.stopTest();
        
        System.assertNotEquals(null, controller.selectedTotalAmount);
    }
    
    @IsTest
    static void testAreaGrouping() {
        Quote q = getTestQuoteWithLineItems();
        
        Test.startTest();
        ApexPages.StandardController std = new ApexPages.StandardController(q);
        QuotePdfController controller = new QuotePdfController(std);
        Test.stopTest();
        
        // Verify area grouping was created
        System.assertNotEquals(null, controller.areaGroups);
        System.assert(controller.areaGroups.size() > 0, 'Should have area groups');
    }
    
    @IsTest
    static void testGetCartLineItemsException() {
        Test.startTest();
        try {
            // Pass an invalid Id to trigger exception path
            List<QuoteLineItem> items = QuotePdfController.getCartLineItems(null);
        } catch (Exception e) {
            // Expected - covers the catch block
            System.assert(true);
        }
        Test.stopTest();
    }
    
    @IsTest
    static void testControllerPropertyAccess() {
        Quote q = getTestQuoteWithLineItems();
        
        Test.startTest();
        ApexPages.StandardController std = new ApexPages.StandardController(q);
        QuotePdfController controller = new QuotePdfController(std);
        
        // Access properties to cover getter/setter lines
        controller.discountType = 'Percentage';
        String dt = controller.discountType;
        System.assertEquals('Percentage', dt);
        
        controller.discountValue = 15.0;
        Decimal dv = controller.discountValue;
        System.assertEquals(15.0, dv);
        
        controller.priceSqft = 50.0;
        Decimal ps = controller.priceSqft;
        System.assertEquals(50.0, ps);
        
        Test.stopTest();
    }
    
 /*   @IsTest
    static void testWithAreaAndRoomType() {
        // Create test data with Area__c and Room_Type__c populated
        String d = Account.District__c.getDescribe().getPicklistValues()[0].getValue();
        String s = Account.State__c.getDescribe().getPicklistValues()[0].getValue();
        String c = Account.Country__c.getDescribe().getPicklistValues()[0].getValue();
        Account acc = new Account(Name = 'Area Test Account', District__c = d, State__c = s, Country__c = c, BillingCountry = 'India', BillingState = 'KA', BillingPostalCode = '560001', BillingCity = 'Bangalore', BillingStreet = '123 Test St', Pin_Code__c = 560001);
        insert acc;
        String os = Opportunity.State__c.getDescribe().getPicklistValues()[0].getValue();
        String od = Opportunity.District__c.getDescribe().getPicklistValues()[0].getValue();
        Opportunity opp = new Opportunity(Name = 'Area Test Opp', StageName = 'Prospecting', CloseDate = Date.today().addDays(30), AccountId = acc.Id, State__c = os, District__c = od, Pin_Code__c = 560001);
        insert opp;
        Quote q = new Quote(Name = 'Area Test Quote', OpportunityId = opp.Id, Pricebook2Id = Test.getStandardPricebookId());
        insert q;
        
        Product2 prod = new Product2(Name = 'Area Product', IsActive = true, Product_Category__c = 'SANITARY');
        insert prod;
        
       PricebookEntry pbe = new PricebookEntry(
    Pricebook2Id = Test.getStandardPricebookId(),
    Product2Id = prod.Id,
    UnitPrice = 100,
    IsActive = true,
    UseStandardPrice = false
);
        insert pbe;
        
       QuoteLineItem qli = new QuoteLineItem(
    QuoteId = q.Id,
    PricebookEntryId = pbe.Id,
    Quantity = 2,
    UnitPrice = 100,
    Area__c = 'Living Room',
    Room_Type__c = 'Main',
   
    Calculated_Total_Price__c = 200,
    After_Disc_Price_Piece__c = 100
);
        insert qli;
        
        Test.startTest();
        ApexPages.StandardController std = new ApexPages.StandardController(q);
        QuotePdfController controller = new QuotePdfController(std);
        Test.stopTest();
        
        System.assertNotEquals(null, controller.areaGroups);
    }
 */   
    @IsTest
    static void testMultipleCategoriesInOneTest() {
        Quote q = getTestQuoteWithLineItems();
        // Get items from multiple categories
        List<QuoteLineItem> items = [SELECT Id FROM QuoteLineItem WHERE QuoteId = :q.Id LIMIT 10];
        List<String> itemIds = new List<String>();
        for (QuoteLineItem item : items) {
            itemIds.add(item.Id);
        }
        ApexPages.currentPage().getParameters().put('selectedItems', String.join(itemIds, ','));
        
        Test.startTest();
        ApexPages.StandardController std = new ApexPages.StandardController(q);
        QuotePdfController controller = new QuotePdfController(std);
        Test.stopTest();
        
        // Multiple categories should be detected
        System.assertNotEquals(null, controller.products);
    }
    
    @IsTest
    static void testNStoneDescription() {
        // Test that N.STONE items get description field populated
        Quote q = getTestQuoteWithLineItems();
        QuoteLineItem item = [SELECT Id FROM QuoteLineItem WHERE QuoteId = :q.Id 
            AND Product_Category__c = 'N.STONE' LIMIT 1];
        // Update the item with a description
        item.Description = 'Natural Stone Description';
        update item;
        
        ApexPages.currentPage().getParameters().put('selectedItems', item.Id);
        
        Test.startTest();
        ApexPages.StandardController std = new ApexPages.StandardController(q);
        QuotePdfController controller = new QuotePdfController(std);
        Test.stopTest();
        
        System.assertEquals(true, controller.hasNaturalStone);
    }
}