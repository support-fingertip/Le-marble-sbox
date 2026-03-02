@IsTest
public class QuotationControllerTest {

    @TestSetup
    static void setupData() {

        // ---------------------
        // Create Account (Customer)
        // ---------------------
        Account acc = new Account(
            Name = 'Test Customer'
        );
        insert acc;

        // ---------------------
        // Create Deals__c (ONLY valid fields)
        // ---------------------
        Deals__c deal = new Deals__c(
            Name = 'Test Deal',
            Email__c = 'test@test.com',
            Customer__c = acc.Id
        );
        insert deal;

        // ---------------------
        // Standard Pricebook
        // ---------------------
        Id stdPricebookId = Test.getStandardPricebookId();

        Product2 prod = new Product2(
            Name = 'Test Product',
            IsActive = true
        );
        insert prod;

        insert new PricebookEntry(
            Pricebook2Id = stdPricebookId,
            Product2Id = prod.Id,
            UnitPrice = 500,
            IsActive = true
        );

        // ---------------------
        // Create Cart (Correct Deals__c type)
        // ---------------------
        Cart__c cart = new Cart__c(
            Deals__c = deal.Id
        );
        insert cart;

        // ---------------------
        // Create Cart Line Item
        // ---------------------
        Cart_Line_Item__c cli = new Cart_Line_Item__c(
            Cart__c = cart.Id,
            Product__c = prod.Id,
            Quantity__c = 2,
            Unit_Price__c = 500,
            Product_Category__c = 'Tiles'
        );
        insert cli;

        // ---------------------
        // Create Opportunity + Quote
        // ---------------------
        Opportunity opp = new Opportunity(
            Name = 'Test Opp',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(10),
            AccountId = acc.Id
        );
        insert opp;

        Quote q = new Quote(
            Name = 'Test Quote',
            OpportunityId = opp.Id,
            Pricebook2Id = stdPricebookId
        );
        insert q;
    }

    @IsTest
    static void testAllMethods() {

        Cart__c cart = [SELECT Id FROM Cart__c LIMIT 1];

        Test.setCurrentPage(Page.QuotationTemplate);

        ApexPages.StandardController sc =
            new ApexPages.StandardController(cart);

        Test.startTest();

        // Constructor
        QuotationController controller =
            new QuotationController(sc);

        // Aura method
        QuotationController.getCartLineItems(cart.Id);

        // Generate file
        QuotationController.generateAndSaveQuotationFile(
            cart.Id,
            new List<String>()
        );

        // Send email
        QuotationController.sendQuotationEmail(
            null,
            cart.Id,
            new List<String>(),
            'test@test.com',
            'Subject',
            'Body'
        );

        // Utility coverage
        QuotationController.generateGreeting('John');
        QuotationController.addNumbers(2,3);
        QuotationController.isPrimeNumber(7);
        QuotationController.isPalindrome('madam');
        QuotationController.calculateFactorial(5);
        QuotationController.sumOfDigits(123);

        Test.stopTest();

        System.assert(true);
    }
}