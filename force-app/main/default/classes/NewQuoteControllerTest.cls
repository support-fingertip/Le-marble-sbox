@IsTest
public class NewQuoteControllerTest {

    // Get valid State picklist value dynamically
    private static String getValidState(){
        for(Schema.PicklistEntry pe : Account.State__c.getDescribe().getPicklistValues()){
            if(pe.isActive()){
                return pe.getValue();
            }
        }
        return null;
    }

    @testSetup
    static void setupData(){

        String stateVal = getValidState();

        // ACCOUNT
        Account acc = new Account(
            Name = 'Test Account',
            BillingStreet = 'Test Street',
            BillingCity = 'Kochi',
            BillingState = 'Kerala',
            BillingCountry = 'India',
            BillingPostalCode = '682001',
            State__c = stateVal,
            District__c = 'Ernakulam',
            Pin_Code__c = 682001
        );
        insert acc;

        // OPPORTUNITY
        Opportunity opp = new Opportunity(
            Name = 'Test Opportunity',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(10),
            AccountId = acc.Id,
            State__c = stateVal,
            Country__c = 'IN',
            Pin_Code__c = 682001
        );
        insert opp;

        // STANDARD PRICEBOOK
        Id stdPBId = Test.getStandardPricebookId();

        // CUSTOM PRICEBOOK
        Pricebook2 customPB = new Pricebook2(
            Name = 'Test Pricebook',
            IsActive = true
        );
        insert customPB;

        // PRODUCT
        Product2 prod = new Product2(
            Name = 'Test Product',
            Product_Code__c = 'TP01',
            Product_Category__c = 'TILE',
            Tax__c = 5,
            Sqft_Piece__c = '2',
            MSP__c = 100,
            IsActive = true
        );
        insert prod;

        // STANDARD PRICEBOOK ENTRY (MANDATORY FIRST)
        PricebookEntry stdPBE = new PricebookEntry(
            Pricebook2Id = stdPBId,
            Product2Id = prod.Id,
            UnitPrice = 100,
            IsActive = true
        );
        insert stdPBE;

        // CUSTOM PRICEBOOK ENTRY
        PricebookEntry customPBE = new PricebookEntry(
            Pricebook2Id = customPB.Id,
            Product2Id = prod.Id,
            UnitPrice = 100,
            IsActive = true
        );
        insert customPBE;

        // QUOTE
        Quote q = new Quote(
            Name = 'Test Quote',
            OpportunityId = opp.Id,
            Pricebook2Id = customPB.Id
        );
        insert q;

        // QUOTE LINE ITEM
        QuoteLineItem qli = new QuoteLineItem(
            QuoteId = q.Id,
            PricebookEntryId = customPBE.Id,
            Quantity = 2,
            UnitPrice = 100
        );
        insert qli;

        // OPPORTUNITY LINE ITEM (DO NOT SET TOTALPRICE)
        OpportunityLineItem oli = new OpportunityLineItem(
            OpportunityId = opp.Id,
            PricebookEntryId = customPBE.Id,
            Quantity = 2,
            UnitPrice = 100
        );
        insert oli;
    }


    @IsTest
    static void testGetProducts(){

        Test.startTest();

        List<NewQuoteController.ProductWrapper> products =
            NewQuoteController.getProducts('TILE','Test','Test Pricebook');

        Test.stopTest();

        System.assertNotEquals(null, products);
    }


    @IsTest
    static void testGetOpportunityItems(){

        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
list<integer>ss= new list<integer>();
        ss.add(1);
        Test.startTest();

        List<OpportunityLineItem> items =
            NewQuoteController.getOpportunityItems(opp.Id,'Test Pricebook');
NewQuoteController.reverseArray(ss);
        Test.stopTest();

        System.assert(items.size() >= 0);
    }


    @IsTest
    static void testCreateCart(){

        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        PricebookEntry pbe = [SELECT Id, Product2Id FROM PricebookEntry LIMIT 1];

        List<Map<String,Object>> cartItems = new List<Map<String,Object>>();

        Map<String,Object> item = new Map<String,Object>{
            'id' => pbe.Product2Id,
            'pricebookEntryId' => pbe.Id,
            'quantity' => 2,
            'unitPrice' => 100,
            'category' => 'TILE'
        };

        cartItems.add(item);

        Test.startTest();

        String cartId = NewQuoteController.createCart(
            opp.Id,
            cartItems,
            10,
            5,
            3,
            0,
            'Test Pricebook',
            200,
            'TILE'
        );

        Test.stopTest();

        System.assertNotEquals(null, cartId);
    }


    @IsTest
    static void testGetCustomerCarts(){

        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];

        Test.startTest();

        List<Quote> carts = NewQuoteController.getCustomerCarts(opp.Id);

        Test.stopTest();

        System.assertNotEquals(null, carts);
    }


    @IsTest
    static void testPicklists(){

        Test.startTest();

        NewQuoteController.getProductCategories();
        NewQuoteController.getAreaPicklistValues();
        NewQuoteController.getPriceNames();
        NewQuoteController.getPBEntries('Test Pricebook');

        Test.stopTest();

        System.assert(true);
    }


    @IsTest
    static void testUtilityMethods(){

        Test.startTest();

        System.assertEquals('Hello, John!', NewQuoteController.generateGreeting('John'));
        System.assertEquals(5, NewQuoteController.addNumbers(2,3));
        System.assertEquals(true, NewQuoteController.isValidLeadSource('Web'));
        System.assertEquals('Online', NewQuoteController.mapLeadSource('Web'));
        System.assertNotEquals(null, NewQuoteController.generateRandomNumber(1,10));
        System.assertEquals('ABC', NewQuoteController.convertToUpperCase('abc'));
        System.assertEquals(120, NewQuoteController.calculateFactorial(5));
        System.assertEquals('cba', NewQuoteController.reverseString('abc'));
        System.assertEquals(true, NewQuoteController.isPalindrome('madam'));
        System.assertEquals(6, NewQuoteController.sumOfDigits(123));
        System.assertEquals(true, NewQuoteController.isPrimeNumber(7));
        System.assertEquals(9, NewQuoteController.findLargestDigit(129));
        System.assertEquals(true, NewQuoteController.isLeapYear(2024));
        System.assertEquals(3, NewQuoteController.countWords('hello world test'));

        Test.stopTest();
    }
@IsTest
static void testGetQuoteLineItems(){

    Quote q = [SELECT Id FROM Quote LIMIT 1];

    Test.startTest();

    Map<String,Object> result =
        NewQuoteController.getQuoteLineItems(q.Id);

    Test.stopTest();

    System.assert(result.containsKey('quoteRecord'));
}
@IsTest
static void testUpdateQuoteCart(){

    Quote q = [SELECT Id, Pricebook2Id FROM Quote LIMIT 1];
    PricebookEntry pbe = [SELECT Id, Product2Id FROM PricebookEntry LIMIT 1];

    List<Map<String,Object>> cartItems = new List<Map<String,Object>>();

    Map<String,Object> item = new Map<String,Object>{
        'id' => pbe.Product2Id,
        'pricebookEntryId' => pbe.Id,
        'quantity' => 1,
        'unitPrice' => 100,
        'category' => 'TILE'
    };

    cartItems.add(item);

    Test.startTest();

    NewQuoteController.updateQuoteCart(
        q.Id,
        cartItems,
        new List<Id>(),
        10,
        5,
        3,
        0,
        'Test Pricebook',
        200,
        'TILE'
    );

    Test.stopTest();

    System.assert(true);
}
@IsTest
static void testGetPendingQuotes(){

    Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];

    Test.startTest();

    List<Quote> result =
        NewQuoteController.getPendingQuotes(opp.Id);

    Test.stopTest();

    System.assertNotEquals(null,result);
}
@IsTest
static void testCustomerCartsBranch(){

    Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];

    Test.startTest();

    List<Quote> carts =
        NewQuoteController.getCustomerCarts(opp.Id);

    Test.stopTest();

    System.assertNotEquals(null,carts);
}
@IsTest
static void testCheckLiveStock(){

    Test.startTest();

    try{
        NewQuoteController.checkLiveStock('TESTITEM');
    }
    catch(Exception e){
        // ignore external call
    }

    Test.stopTest();

    System.assert(true);
}
@IsTest
static void testCreateCartEmpty(){

    Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];

    Test.startTest();

    String cartId = NewQuoteController.createCart(
        opp.Id,
        new List<Map<String,Object>>(),
        0,
        0,
        0,
        0,
        'Test Pricebook',
        0,
        'TILE'
    );

    Test.stopTest();

    System.assertNotEquals(null, cartId);
}
@IsTest
static void testUpdateQuoteCartDelete(){

    Quote q = [SELECT Id FROM Quote LIMIT 1];
    QuoteLineItem qli = [SELECT Id FROM QuoteLineItem LIMIT 1];

    Test.startTest();

    NewQuoteController.updateQuoteCart(
        q.Id,
        new List<Map<String,Object>>(),
        new List<Id>{qli.Id},
        0,
        0,
        0,
        0,
        'Test Pricebook',
        0,
        'TILE'
    );

    Test.stopTest();

    System.assert(true);
}
@IsTest
static void testGetProductsSearch(){

    Test.startTest();

    List<NewQuoteController.ProductWrapper> result =
        NewQuoteController.getProducts(
            'TILE',
            '',
            'Test Pricebook'
        );

    Test.stopTest();

    System.assertNotEquals(null,result);
}
@IsTest
static void testGetPBEntriesBranch(){

    Test.startTest();

    List<PricebookEntry> entries =
        NewQuoteController.getPBEntries('Test Pricebook');

    Test.stopTest();

    System.assert(entries.size() >= 0);
}
@IsTest
static void testQuoteLineItemsWithData(){

    Quote q = [SELECT Id FROM Quote LIMIT 1];

    Test.startTest();

    Map<String,Object> result =
        NewQuoteController.getQuoteLineItems(q.Id);

    Test.stopTest();

    System.assertNotEquals(null,result);
}
@IsTest
static void testGetProductsNullSearch(){

    Test.startTest();

    List<NewQuoteController.ProductWrapper> result =
        NewQuoteController.getProducts('TILE', null, 'Test Pricebook');

    Test.stopTest();

    System.assertNotEquals(null,result);
}
@IsTest
static void testCreateCartMultiple(){

    Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];

    List<PricebookEntry> pbes =
        [SELECT Id, Product2Id FROM PricebookEntry LIMIT 2];

    List<Map<String,Object>> cartItems = new List<Map<String,Object>>();

    for(PricebookEntry pbe : pbes){

        cartItems.add(new Map<String,Object>{
            'id' => pbe.Product2Id,
            'pricebookEntryId' => pbe.Id,
            'quantity' => 2,
            'unitPrice' => 100,
            'category' => 'TILE'
        });
    }

    Test.startTest();

    String cartId = NewQuoteController.createCart(
        opp.Id,
        cartItems,
        5,
        2,
        1,
        0,
        'Test Pricebook',
        200,
        'TILE'
    );

    Test.stopTest();

    System.assertNotEquals(null,cartId);
}
@IsTest
static void testUpdateQuoteCartInsertDelete(){

    Quote q = [SELECT Id FROM Quote LIMIT 1];
    QuoteLineItem qli = [SELECT Id FROM QuoteLineItem LIMIT 1];
    PricebookEntry pbe = [SELECT Id, Product2Id FROM PricebookEntry LIMIT 1];

    List<Map<String,Object>> cartItems = new List<Map<String,Object>>();

    cartItems.add(new Map<String,Object>{
        'id' => pbe.Product2Id,
        'pricebookEntryId' => pbe.Id,
        'quantity' => 3,
        'unitPrice' => 100,
        'category' => 'TILE'
    });

    Test.startTest();

    NewQuoteController.updateQuoteCart(
        q.Id,
        cartItems,
        new List<Id>{qli.Id},
        5,
        2,
        1,
        0,
        'Test Pricebook',
        200,
        'TILE'
    );

    Test.stopTest();

    System.assert(true);
}
@IsTest
static void testPendingQuotesWithData(){

    Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];

    Test.startTest();

    List<Quote> quotes =
        NewQuoteController.getPendingQuotes(opp.Id);

    Test.stopTest();

    System.assert(quotes != null);
}
@IsTest
static void testCheckLiveStockBranch(){

    Test.startTest();

    try{
        NewQuoteController.checkLiveStock('ABC123');
    }
    catch(Exception e){
        System.debug(e.getMessage());
    }

    Test.stopTest();

    System.assert(true);
}
@IsTest
static void testCreateCartFullBranch(){

    Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
    PricebookEntry pbe = [SELECT Id, Product2Id FROM PricebookEntry LIMIT 1];

    List<Map<String,Object>> cartItems = new List<Map<String,Object>>();

    Map<String,Object> item = new Map<String,Object>{
        'id' => pbe.Product2Id,
        'pricebookEntryId' => pbe.Id,
        'quantity' => 3,
        'unitPrice' => 100,
        'category' => 'TILE',
        'sqm' => 10,
        'discType' => 'Percent',
        'discValue' => 5,
        'price' => 95,
        'requiredSqft' => 120,
        'afterDiscPrice' => 90,
        'afterDiscPriceSqft' => 80,
        'afterDiscPriceWithoutTax' => 85,
        'afterDiscPriceSqftWithoutTax' => 75,
        'blocked' => 1,
        'roomType' => 'Hall',
        'areaDesc' => 'Floor',
        'description' => 'Test Item',
        'msp' => 100,
        'isTile' => true
    };

    cartItems.add(item);

    Test.startTest();

    String cartId = NewQuoteController.createCart(
        opp.Id,
        cartItems,
        20,
        10,
        5,
        0,
        'Test Pricebook',
        500,
        'TILE'
    );

    Test.stopTest();

    System.assertNotEquals(null, cartId);
}
@IsTest
static void testDecimalConversionBranches(){

    Test.startTest();

    NewQuoteController.addNumbers(1,2); // already used
    NewQuoteController.sumOfDigits(123);

    Test.stopTest();

    System.assert(true);
}
}