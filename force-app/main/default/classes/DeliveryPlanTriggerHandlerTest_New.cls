@IsTest
public class DeliveryPlanTriggerHandlerTest_New {


/* -----------------------
   COMMON TEST DATA METHOD
   ----------------------- */
private static Delivery_Group__c createDeliveryPlan(String approvalStatus){

    // Get admin user
    User adminUser = [
        SELECT Id
        FROM User
        WHERE Profile.Name = 'System Administrator'
        LIMIT 1
    ];

    // Warehouse
    Warehouse__c wh = new Warehouse__c(
        Name = 'Test Warehouse',
        Location__c = 'Location',
        Total_Capacity__c = 1000,
        Warehouse_Manager__c = adminUser.Id
    );
    insert wh;

    // Account
    Account acc = new Account(
        Name='Test Account',
        BillingCountry='India',
        BillingState='Maharashtra',
        BillingPostalCode='400001',
        BillingStreet='Street',
        District__c='Ernakulam',
        Pin_Code__c=400001
    );
    insert acc;
    
         // OPPORTUNITY
        Opportunity opp = new Opportunity(
            Name = 'Test Opportunity',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(10),
            AccountId = acc.Id,
            State__c = 'KL',
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

    // Sales Order
    Order ord = new Order(
        AccountId = acc.Id,
        QuoteId =q.id,
        Status = 'Draft',
        EffectiveDate = Date.today()
    );
    insert ord;

    // Delivery Plan
    Delivery_Group__c dp = new Delivery_Group__c(
        Warehouse__c = wh.Id,
        Sales_Order__c = ord.Id,
        Delivery_Status__c = 'Draft',
        Approval_Status__c = approvalStatus
    );
    insert dp;

    return dp;
}


/* -----------------------
   TEST 1: populate manager
   ----------------------- */
@IsTest
static void testPopulateWarehouseManager(){

    Delivery_Group__c dp = createDeliveryPlan('Draft');

    Test.startTest();
    DeliveryPlanTriggerHandler.populateWarehouseManager(
        new List<Delivery_Group__c>{dp},
        null
    );
    Test.stopTest();

    System.assertNotEquals(null, dp.Warehouse_Manager__c);
}


/* -----------------------
   TEST 2: block delivered
   ----------------------- */
@IsTest
static void testBlockDeliveredWithoutApproval(){

    Delivery_Group__c dp = createDeliveryPlan('Draft');
    dp.Delivery_Status__c = 'Delivered';

    Test.startTest();
    try{
        update dp;
        System.assert(false,'Should throw error');
    }
    catch(DmlException e){
        System.assert(e.getMessage().contains('approved'));
    }
    Test.stopTest();
}


/* -----------------------
   TEST 3: allow delivered
   ----------------------- */
@IsTest
static void testDeliveredWithApproval(){

    Delivery_Group__c dp = createDeliveryPlan('Approved');
    dp.Delivery_Status__c = 'Delivered';

    Test.startTest();
    update dp;
    Test.stopTest();

    Delivery_Group__c result=[
        SELECT Delivery_Status__c
        FROM Delivery_Group__c
        WHERE Id=:dp.Id
    ];

    System.assertEquals('Delivered',result.Delivery_Status__c);
}


/* -----------------------
   TEST 4: afterInsert
   ----------------------- */
@IsTest
static void testAfterInsertNotification(){

    Test.startTest();
    Delivery_Group__c dp = createDeliveryPlan('Draft');
    Test.stopTest();

    System.assertNotEquals(null, dp.Id);
}


/* -----------------------
   TEST 5: afterUpdate
   ----------------------- */
@IsTest
static void testAfterUpdateNotification(){

    Delivery_Group__c dp = createDeliveryPlan('Approved');

    dp.Delivery_Status__c='Delivered';

    Test.startTest();
    update dp;
    Test.stopTest();

    System.assertEquals('Delivered', dp.Delivery_Status__c);
}


/* -----------------------
   TEST 6: onCreate
   ----------------------- */
@IsTest
static void testOnCreateMethod(){

    Delivery_Group__c dp = createDeliveryPlan('Draft');

    Test.startTest();
    DeliveryPlanTriggerHandler.onCreate(
        new List<Delivery_Group__c>{dp}
    );
    Test.stopTest();

    System.assertNotEquals(null, dp.Id);
}


/* -----------------------
   TEST 7: onStatusChange
   ----------------------- */
@IsTest
static void testOnStatusChange(){

    Delivery_Group__c dp = createDeliveryPlan('Draft');

    Delivery_Group__c oldDp = dp.clone(false,true,false,false);

    dp.Approval_Status__c='Activated';

    Test.startTest();
    DeliveryPlanTriggerHandler.onStatusChange(
        new List<Delivery_Group__c>{dp},
        new Map<Id,Delivery_Group__c>{dp.Id=>oldDp}
    );
    Test.stopTest();

    System.assertEquals('Activated', dp.Approval_Status__c);
}
@IsTest
static void testWarehouseChange(){

    Delivery_Group__c dp = createDeliveryPlan('Draft');

    // Create second warehouse
    Warehouse__c wh2 = new Warehouse__c(
        Name = 'Second Warehouse',
        Location__c = 'New Location',
        Total_Capacity__c = 500,
        Warehouse_Manager__c = UserInfo.getUserId()
    );
    insert wh2;

    Delivery_Group__c oldDp = dp.clone(false,true,false,false);

    dp.Warehouse__c = wh2.Id;

    Test.startTest();
    DeliveryPlanTriggerHandler.populateWarehouseManager(
        new List<Delivery_Group__c>{dp},
        new Map<Id,Delivery_Group__c>{dp.Id => oldDp}
    );
    Test.stopTest();

    System.assertEquals(UserInfo.getUserId(), dp.Warehouse_Manager__c);
}


}