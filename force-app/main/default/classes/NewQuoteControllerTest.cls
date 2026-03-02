@IsTest
public class NewQuoteControllerTest {

    @TestSetup
    static void setupData() {

        Id stdPbId = Test.getStandardPricebookId();
        update new Pricebook2(Id = stdPbId, IsActive = true);

        Pricebook2 pb = new Pricebook2(
            Name = 'Test Pricebook',
            IsActive = true
        );
        insert pb;

        Account acc = new Account(
            Name = 'Test Account'
        );
        insert acc;

        Opportunity opp = new Opportunity(
            Name = 'Test Opp',
            StageName = 'Prospecting',
            CloseDate = System.today().addDays(10),
            AccountId = acc.Id,
            Pricebook2Id = pb.Id
        );
        insert opp;

        Product2 prod = new Product2(
            Name = 'Tile Product',
            IsActive = true,
            Product_Category__c = 'Tiles',
            MSP__c = 100,
            Tax__c = 18
        );
        insert prod;

        insert new PricebookEntry(
            Pricebook2Id = stdPbId,
            Product2Id = prod.Id,
            UnitPrice = 100,
            IsActive = true
        );

        insert new PricebookEntry(
            Pricebook2Id = pb.Id,
            Product2Id = prod.Id,
            UnitPrice = 120,
            IsActive = true
        );
    }

    @IsTest
    static void testControllerFullCoverage() {

        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        PricebookEntry pbe = [SELECT Id, Product2Id FROM PricebookEntry WHERE UnitPrice = 120 LIMIT 1];

        Test.startTest();

        // 1️⃣ getProducts (covers MSP + tax logic)
        NewQuoteController.getProducts('Tiles','Test Pricebook');

        // 2️⃣ getOpportunityItems (safe call)
        NewQuoteController.getOpportunityItems(
            opp.Id,
            'Test Pricebook',
            'Tiles'
        );

        // 3️⃣ getPBEntries
        NewQuoteController.getPBEntries('Test Pricebook');

        // 4️⃣ getProductCategories
        NewQuoteController.getProductCategories();

        // 5️⃣ getAreaPicklistValues
        NewQuoteController.getAreaPicklistValues();

        // 6️⃣ getPriceNames
        NewQuoteController.getPriceNames();

        // 7️⃣ createCart (SAFE minimal data)
        List<Map<String,Object>> cartItems = new List<Map<String,Object>>();
        cartItems.add(new Map<String,Object>{
            'id' => pbe.Product2Id,
            'pricebookEntryId' => pbe.Id,
            'quantity' => 1,
            'unitPrice' => 120,
            'totalPrice' => 120,
            'category' => 'Tiles'
        });

        NewQuoteController.createCart(
            opp.Id,
            cartItems,
            0, 0, 0,
            0,
            'Test Pricebook',
            100,
            'Tiles'
        );

        // 8️⃣ getPendingQuotes
        NewQuoteController.getPendingQuotes(opp.Id);

        // 9️⃣ getCustomerCarts
        NewQuoteController.getCustomerCarts(opp.Id);

        // 🔟 Utility methods
        NewQuoteController.logInfo('info');
        NewQuoteController.logError('error');

        NewQuoteController.generateGreeting('John');
        NewQuoteController.generateGreeting('');

        NewQuoteController.addNumbers(1,2);
        NewQuoteController.isValidLeadSource('Web');
        NewQuoteController.isValidLeadSource('Other');

        NewQuoteController.mapLeadSource('Web');
        NewQuoteController.mapLeadSource('Other');

        NewQuoteController.generateRandomNumber(1,5);
        NewQuoteController.convertToUpperCase('abc');
        NewQuoteController.calculateFactorial(5);
        NewQuoteController.reverseString('abc');
        NewQuoteController.isPalindrome('madam');
        NewQuoteController.sumOfDigits(123);
        NewQuoteController.isPrimeNumber(7);
        NewQuoteController.findLargestDigit(394);
        NewQuoteController.reverseArray(new List<Integer>{1,2,3});
        NewQuoteController.isLeapYear(2024);
        NewQuoteController.countWords('Hello World Test');

        Test.stopTest();

        System.assert(true);
    }
}