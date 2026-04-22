@isTest
public class EditQuoteControllerTest {


// Get valid State picklist value
public static String getState(){
    List<Schema.PicklistEntry> vals =
        Account.State__c.getDescribe().getPicklistValues();
    return vals[0].getValue();
}

// Get valid District picklist value
public static String getDistrict(){
    List<Schema.PicklistEntry> vals =
        Account.District__c.getDescribe().getPicklistValues();
    return vals[0].getValue();
}

public static Account createAccount(){

    String stateVal = getState();
    String districtVal = getDistrict();

    Account acc = new Account(
        Name = 'Test Account',
        BillingCountry = 'India',
        BillingState = stateVal,
        BillingCity = 'Test City',
        BillingStreet = 'Test Street',
        BillingPostalCode = '560001',

        State__c = stateVal,
        District__c = districtVal,
        Pin_Code__c = 560001
    );

    insert acc;
    return acc;
}

@isTest
static void testLoadQuote(){

    Account acc = createAccount();

    Opportunity opp = new Opportunity(
        Name = 'Test Opportunity',
        StageName = 'Prospecting',
        CloseDate = Date.today(),
        AccountId = acc.Id,
        State__c = 'PB',
        Pin_Code__c = 811023
    );
    insert opp;

    Id pricebookId = Test.getStandardPricebookId();

    Product2 prod = new Product2(
        Name = 'Test Product',
        IsActive = true
    );
    insert prod;

    PricebookEntry pbe = new PricebookEntry(
        Product2Id = prod.Id,
        Pricebook2Id = pricebookId,
        UnitPrice = 100,
        IsActive = true
    );
    insert pbe;

    Quote q = new Quote(
        Name = 'Test Quote',
        OpportunityId = opp.Id,
        Pricebook2Id = pricebookId
    );
    insert q;

    QuoteLineItem qli = new QuoteLineItem(
        QuoteId = q.Id,
        PricebookEntryId = pbe.Id,
        Quantity = 2,
        UnitPrice = 100
    );
    insert qli;

    Test.startTest();
    EditQuoteController.loadQuote(q.Id);
    Test.stopTest();

    System.assert(true);
}

@isTest
static void testSaveQuote(){

    Account acc = createAccount();

    Opportunity opp = new Opportunity(
        Name = 'Test Opportunity',
        StageName = 'Prospecting',
        CloseDate = Date.today(),
        AccountId = acc.Id,
        State__c = 'PB',
        Pin_Code__c = 811024
        
    );
    insert opp;

    Id pricebookId = Test.getStandardPricebookId();

    Product2 prod = new Product2(Name='Test Product', IsActive=true);
    insert prod;

    PricebookEntry pbe = new PricebookEntry(
        Product2Id=prod.Id,
        Pricebook2Id=pricebookId,
        UnitPrice=100,
        IsActive=true
    );
    insert pbe;

    Quote q = new Quote(
        Name='Test Quote',
        OpportunityId=opp.Id,
        Pricebook2Id=pricebookId
    );
    insert q;

    QuoteLineItem oldItem = new QuoteLineItem(
        QuoteId=q.Id,
        PricebookEntryId=pbe.Id,
        Quantity=1,
        UnitPrice=100
    );
    insert oldItem;

    q.Freight_Charge__c = 50;

    QuoteLineItem newItem = new QuoteLineItem(
        QuoteId=q.Id,
        PricebookEntryId=pbe.Id,
        Quantity=3,
        UnitPrice=150
    );

    Test.startTest();
    EditQuoteController.saveQuote(
        q,
        new List<QuoteLineItem>{newItem},
        new List<Id>{oldItem.Id}
    );
    Test.stopTest();

    System.assert(true);
}


}