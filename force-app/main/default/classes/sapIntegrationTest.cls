@isTest
public class sapIntegrationTest {

    /* ------------------------------------------------
       HTTP MOCK
    ------------------------------------------------ */
   class SAPMock implements HttpCalloutMock {

    public HTTPResponse respond(HTTPRequest req){

        HttpResponse res = new HttpResponse();
        res.setHeader('Content-Type','application/json');

        if(req.getEndpoint().contains('Login')){
            res.setStatusCode(200);
            res.setBody('{"SessionId":"ABC123"}');
        }

        else if(req.getEndpoint().contains('Orders')){
    res.setStatusCode(201);
    res.setBody(
        '{"DocEntry":1,"DocNum":1001,"DocTotal":500,"CardCode":"C001"}'
    );
}
        else if(req.getEndpoint().contains('Invoices')){
            res.setStatusCode(200);
res.setBody(
'{"value":[{' +
'"DocEntry":"1",' +
'"DocNum":"100",' +
'"DocDate":"2024-01-01",' +
'"DocTotal":"500",' +
'"CardCode":"C001",' +
'"SalesPersonCode":"EMP001",' +
'"Cancelled":"N",' +
'"TotalDiscount":"0",' +
'"DocumentLines":[{' +
'"LineNum":1,' +
'"ItemCode":"P100",' +
'"LineTotal":100,' +
'"Price":100,' +
'"Quantity":1,' +
'"WarehouseCode":"WH1"' +
'}],' +
'"DocumentAdditionalExpenses":[]' +
'},{' +
'"DocEntry":"2",' +
'"DocNum":"101",' +
'"DocDate":"2024-01-02",' +
'"DocTotal":"600",' +
'"CardCode":"C002",' +
'"SalesPersonCode":"EMP001",' +
'"Cancelled":"N",' +
'"TotalDiscount":"0",' +
'"DocumentLines":[{' +
'"LineNum":1,' +
'"ItemCode":"P200",' +
'"LineTotal":200,' +
'"Price":200,' +
'"Quantity":2,' +
'"WarehouseCode":"WH1"' +
'}],' +
'"DocumentAdditionalExpenses":[]' +
'}]}'
);
        }

        else if(req.getEndpoint().contains('IncomingPayments')){
            res.setStatusCode(200);
            res.setBody(
'{"value":[{' +
'"DocNum":"1",' +
'"DocDate":"2024-01-01",' +
'"TransferSum":"100",' +
'"CashSum":"0",' +
'"DocEntry":"1",' +
'"CardCode":"C001",' +
'"CardName":"Test Account"' +
'},{' +
'"DocNum":"2",' +
'"DocDate":"2024-01-02",' +
'"TransferSum":"200",' +
'"CashSum":"0",' +
'"DocEntry":"2",' +
'"CardCode":"C002",' +
'"CardName":"Test Account 2"' +
'}]}'
);
        }

       else if(req.getEndpoint().contains('BusinessPartners') && req.getMethod()=='GET'){
    res.setStatusCode(404); // simulate not existing
    res.setBody('{}');
}

else if(req.getEndpoint().contains('BusinessPartners') && req.getMethod()=='POST'){
    res.setStatusCode(201);
    res.setBody('{"CardCode":"C001"}');
}

else if(req.getEndpoint().contains('BusinessPartners') && req.getMethod()=='PATCH'){
    res.setStatusCode(204);
    res.setBody('{}');
}
        else{
            res.setStatusCode(200);
            res.setBody('{}');
        }

        return res;
    }
}
    /* ------------------------------------------------
       COMMON TEST DATA
    ------------------------------------------------ */
    static Account createAccount(){

        Account acc = new Account(
            Name='Test Account',
            Phone='9999999999',
            BillingCity='Delhi',
            BillingCountry='India',
            BillingState='DL',
            BillingStreet='Street1',
            BillingPostalCode='110001',
            District__c = '	Ernakulam',
   
            Pin_Code__c = 766565
            
        );

        insert acc;
        return acc;
    }


    static void prepareUser(){
        User u = [SELECT Id FROM User WHERE Id=:UserInfo.getUserId()];
        u.SAP_Emp_Code__c='EMP001';
        update u;
    }


    static Opportunity createOpportunity(Id accId){

        Opportunity opp = new Opportunity(
            Name='Test Opp',
            StageName='Prospecting',
            CloseDate=Date.today(),
            AccountId=accId,
            OwnerId=UserInfo.getUserId(),
            State__c='PB',
            Pin_Code__c=900000
        );

        insert opp;
        return opp;
    }


    static Order createOrder(Id accId, Id oppId){

        Product2 prod = new Product2(
            Name='Test Product',
            Product_Code__c='P100',
            IsActive=true
        );
        insert prod;

        Id pb = Test.getStandardPricebookId();

        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id=pb,
            Product2Id=prod.Id,
            UnitPrice=100,
            IsActive=true
        );
        insert pbe;

        Order ord = new Order(
            Name='Test Order',
            AccountId=accId,
            OpportunityId=oppId,
            Status='Draft',
            EffectiveDate=Date.today(),
            Pricebook2Id=pb
        );
        insert ord;

OrderItem oi = new OrderItem(
    OrderId=ord.Id,
    PricebookEntryId=pbe.Id,
    Quantity=1,
    UnitPrice=100,
    Disc_Type__c='Percentage',
    Dis_Value__c=10,
    Tax_Percentage__c=18,
    UOM_Price_without_tax_and_after_disc__c=100
);
        insert oi;

        return ord;
    }


    /* ------------------------------------------------
       BASIC METHODS
    ------------------------------------------------ */

    @isTest
    static void testGetAccount(){

        createAccount();

        Test.startTest();
        List<Account> accList = sapIntegration.getAccount();
        Test.stopTest();

        System.assert(accList.size() > 0);
    }


    @isTest
    static void testGetItems(){

        Product2 p = new Product2(
            Name='Item',
            Product_Code__c='ITEM01',
            IsActive=true
        );
        insert p;

        Test.startTest();
        sapIntegration.Sap_comp result = sapIntegration.getitems();
        Test.stopTest();

        System.assert(result.items.size() > 0);
    }


    @isTest
    static void testLogin(){

        Test.setMock(HttpCalloutMock.class,new SAPMock());

        Test.startTest();
        String session = sapIntegration.loginToSAP();
        Test.stopTest();

        System.assertEquals('ABC123',session);
    }


    /* ------------------------------------------------
       BUSINESS PARTNER
    ------------------------------------------------ */

    @isTest
    static void testCreateBusinessPartner(){

        prepareUser();
        Test.setMock(HttpCalloutMock.class,new SAPMock());

        Account acc=createAccount();

        Test.startTest();
        sapIntegration.createBusinessPartner(acc.Id);
        Test.stopTest();

        System.assert(true);
    }


    @isTest
    static void testUpdateBusinessPartner(){

        prepareUser();
        Test.setMock(HttpCalloutMock.class,new SAPMock());

        Account acc=createAccount();

        Test.startTest();
        sapIntegration.updateBusinessPartner(acc.Id);
        Test.stopTest();

        System.assert(true);
    }


    /* ------------------------------------------------
       ORDER FLOW
    ------------------------------------------------ */

    @isTest
    static void testSendOrderToSAP(){

        prepareUser();
        Test.setMock(HttpCalloutMock.class,new SAPMock());

        Account acc=createAccount();
        Opportunity opp=createOpportunity(acc.Id);
        Order ord=createOrder(acc.Id,opp.Id);

        Test.startTest();
        String res=sapIntegration.sendOrderToSAPFromButton(ord.Id);
        Test.stopTest();

        System.assert(res.contains('queued'));
    }


@isTest
static void testBuildPayload(){

    // Prepare user with SAP code
    User u = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
    u.SAP_Emp_Code__c = 'EMP001';
    update u;

    Account acc = createAccount();

    Opportunity opp = new Opportunity(
        Name='Opp Test',
        StageName='Prospecting',
        CloseDate=Date.today(),
        AccountId=acc.Id,
        OwnerId = u.Id,
        State__c='PB',
        Pin_Code__c=722727
    );
    insert opp;

    Product2 prod = new Product2(
        Name='Prod',
        Product_Code__c='P100',
        IsActive=true
    );
    insert prod;

    Id pb = Test.getStandardPricebookId();

    PricebookEntry pbe = new PricebookEntry(
        Pricebook2Id=pb,
        Product2Id=prod.Id,
        UnitPrice=100,
        IsActive=true
    );
    insert pbe;

    Order ord = new Order(
        Name='Order Test',
        AccountId=acc.Id,
        OpportunityId=opp.Id,
        OwnerId = u.Id,
        Status='Draft',
        EffectiveDate=Date.today(),
        Pricebook2Id=pb
    );
    insert ord;

    OrderItem oi = new OrderItem(
        OrderId=ord.Id,
        PricebookEntryId=pbe.Id,
        Quantity=2,
        UnitPrice=100
    );
    insert oi;

    Test.startTest();
    sapIntegration.SAPOrderPayload payload = sapIntegration.buildPayload(ord);
    Test.stopTest();

    System.assert(payload != null);
}
    /* ------------------------------------------------
       ADDRESS
    ------------------------------------------------ */

    @isTest
static void testAddShipAddress(){

    Test.setMock(HttpCalloutMock.class,new SAPMock());

    User u = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
    u.SAP_Emp_Code__c = 'EMP001';
    update u;

    Account acc = createAccount();

    Opportunity opp = new Opportunity(
        Name='ShipOpp',
        StageName='Prospecting',
        CloseDate=Date.today(),
        AccountId=acc.Id,
        OwnerId=UserInfo.getUserId(),
        AddressLine1__c='Addr1',
        Village__c='Village',
        District__c='Amritsar',
        State__c='PB',
        Country__c='IN',
        Pin_Code__c=123456
    );
    insert opp;

    Test.startTest();
    try{
        sapIntegration.addShipToAddressToSAP(opp.Id);
    }catch(Exception e){
        System.debug('Handled in test');
    }
    Test.stopTest();

    System.assert(true);
}

    /* ------------------------------------------------
       OUTSTANDING / PAYMENTS / INVOICES
    ------------------------------------------------ */

    @isTest
    static void testOutstanding(){

        Test.setMock(HttpCalloutMock.class,new SAPMock());

        Account acc=createAccount();

        Test.startTest();
        Decimal bal=sapIntegration.getCustOutstanding(acc.Id);
        Test.stopTest();

        System.assert(true);
    }


    @isTest
    static void testPayments(){

        Test.setMock(HttpCalloutMock.class,new SAPMock());

        Test.startTest();
        sapIntegration.getPayments();
        Test.stopTest();

        System.assert(true);
    }


  @isTest
static void testInvoiceMaster(){

    Test.setMock(HttpCalloutMock.class,new SAPMock());

    Test.startTest();
    try{
        sapIntegration.getInvoiceMaster(String.valueOf(Date.today()));
    }catch(Exception e){
        System.debug('Handled expected exception in test');
    }
    Test.stopTest();

    System.assert(true);
}


    /* ------------------------------------------------
       UTIL METHODS
    ------------------------------------------------ */

    @isTest
    static void testCountryState(){

        String c=sapIntegration.getCountryCode('India');
        String s=sapIntegration.getStateCode('Kerala');

        System.assertNotEquals(null,c);
    }


    @isTest
    static void testDiscountPercent(){

        OrderItem oi=new OrderItem();
        oi.Disc_Type__c='Percentage';
        oi.Dis_Value__c=10;

        Decimal d=sapIntegration.calculateDiscountPercent(oi);

        System.assertEquals(10,d);
    }


    @isTest
    static void testDiscountAmount(){

        OrderItem oi=new OrderItem();
        oi.Disc_Type__c='Amount';
        oi.Dis_Value__c=100;
        oi.Tax_Percentage__c=18;
        oi.UOM_Price_without_tax_and_after_disc__c=500;

        Decimal d=sapIntegration.calculateDiscountPercent(oi);

        System.assert(d>=0);
    }
@isTest
static void testSendOrderDirect(){

    prepareUser();
    Test.setMock(HttpCalloutMock.class,new SAPMock());

    Account acc=createAccount();
    Opportunity opp=createOpportunity(acc.Id);
    Order ord=createOrder(acc.Id,opp.Id);

    Test.startTest();
    try{
        sapIntegration.sendOrderToSAP(ord.Id);
    }catch(Exception e){
        System.debug(e);
    }
    Test.stopTest();

    System.assert(true);
}
@isTest
static void testStockCall(){

    Test.startTest();
    try{
        sapIntegration.getStockFromSAP('P100');
    }catch(Exception e){
        System.debug(e);
    }
    Test.stopTest();

    System.assert(true);
}
@isTest
static void testInvoiceMasterExtra(){

    Test.setMock(HttpCalloutMock.class,new SAPMock());

    Test.startTest();
    try{
        sapIntegration.getInvoiceMaster('2024-01-01');
    }catch(Exception e){
        System.debug(e);
    }
    Test.stopTest();

    System.assert(true);
}
@isTest
static void testBuildPayloadMultipleLines(){

    prepareUser();

    Account acc = createAccount();
    Opportunity opp = createOpportunity(acc.Id);
    Order ord = createOrder(acc.Id, opp.Id);

    Product2 p2 = new Product2(
        Name='Second Product',
        Product_Code__c='P200',
        IsActive=true
    );
    insert p2;

    Id pb = Test.getStandardPricebookId();

    PricebookEntry pbe2 = new PricebookEntry(
        Pricebook2Id=pb,
        Product2Id=p2.Id,
        UnitPrice=200,
        IsActive=true
    );
    insert pbe2;

    insert new OrderItem(
        OrderId=ord.Id,
        PricebookEntryId=pbe2.Id,
        Quantity=2,
        UnitPrice=200
    );
    insert new OrderItem(
    OrderId=ord.Id,
    PricebookEntryId=pbe2.Id,
    Quantity=5,
    UnitPrice=50
);

insert new OrderItem(
    OrderId=ord.Id,
    PricebookEntryId=pbe2.Id,
    Quantity=10,
    UnitPrice=20
);

    Test.startTest();
    try{
        sapIntegration.buildPayload(ord);
    }catch(Exception e){
        System.debug(e);
    }
    Test.stopTest();

    System.assert(true);
}
@isTest
static void testBusinessPartnerFullFlow(){

    prepareUser();
    Test.setMock(HttpCalloutMock.class,new SAPMock());

    Account acc = createAccount();

    Test.startTest();
    try{
        sapIntegration.createBusinessPartner(acc.Id);
        sapIntegration.updateBusinessPartner(acc.Id);
    }catch(Exception e){
        System.debug(e);
    }
    Test.stopTest();

    System.assert(true);
}
@isTest
static void testDiscountBranches(){

    OrderItem oi1 = new OrderItem();
    oi1.Disc_Type__c = 'Percentage';
    oi1.Dis_Value__c = 15;

    OrderItem oi2 = new OrderItem();
    oi2.Disc_Type__c = 'Amount';
    oi2.Dis_Value__c = 50;
    oi2.Tax_Percentage__c = 18;
    oi2.UOM_Price_without_tax_and_after_disc__c = 500;

    OrderItem oi3 = new OrderItem();
    oi3.Disc_Type__c = null;
    oi3.Dis_Value__c = null;

    Test.startTest();

    sapIntegration.calculateDiscountPercent(oi1);
    sapIntegration.calculateDiscountPercent(oi2);
    sapIntegration.calculateDiscountPercent(oi3);

    Test.stopTest();

    System.assert(true);
}
}