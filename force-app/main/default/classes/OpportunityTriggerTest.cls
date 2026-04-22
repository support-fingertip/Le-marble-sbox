@isTest
private class OpportunityTriggerTest {

    static String validState;

    // Get valid State picklist dynamically
    static String getValidState(){
        if(validState == null){
            for(Schema.PicklistEntry pe : Opportunity.State__c.getDescribe().getPicklistValues()){
                if(pe.isActive()){
                    validState = pe.getValue();
                    break;
                }
            }
        }
        return validState;
    }

    // Generate VALID GST number
    static String generateGST(Integer i){

        String num = String.valueOf(i).leftPad(4,'0');

        return '22ABCDE' + num + 'F1Z5';
    }

    // Create account with valid GST
    static Account createAccount(String name, Integer i){

        Account acc = new Account(
            Name = name,
            BillingCountry = 'India',
            BillingState = 'Maharashtra',
            BillingPostalCode = '400001',
            BillingStreet = 'Street',
            District__c = 'Ernakulam',
            Pin_Code__c = 400001,
            GST_Number__c = generateGST(i)
        );

        insert acc;
        return acc;
    }

    // AUTO NAME GENERATION
    @isTest
    static void testAutoNameGeneration(){

        Account acc = createAccount('AutoAcc',1);

        Opportunity opp = new Opportunity(
            Name='Test',
            AccountId=acc.Id,
            StageName='Prospecting',
            CloseDate=System.today().addDays(5),
            Product_Category__c='Tile',
            Branch_Location__c='HO',
            State__c=getValidState(),
            Pin_Code__c=400001
        );

        Test.startTest();
        insert opp;
        Test.stopTest();

        Opportunity inserted=[SELECT Name FROM Opportunity WHERE Id=:opp.Id];

        System.assert(inserted.Name.contains(acc.Name));
    }

    // VERSIONING LOGIC
    @isTest
    static void testDuplicateVersioning(){

        Account acc = createAccount('VersionAcc',2);

        Opportunity opp1 = new Opportunity(
            Name='Test',
            AccountId=acc.Id,
            StageName='Prospecting',
            CloseDate=System.today().addDays(5),
            Product_Category__c='Tile',
            Branch_Location__c='HO',
            State__c=getValidState(),
            Pin_Code__c=400001
        );

        insert opp1;

        Opportunity opp2 = new Opportunity(
            Name='Test',
            AccountId=acc.Id,
            StageName='Prospecting',
            CloseDate=System.today().addDays(5),
            Product_Category__c='Tile',
            Branch_Location__c='HO',
            State__c=getValidState(),
            Pin_Code__c=400001
        );

        insert opp2;

        Opportunity second=[SELECT Name FROM Opportunity WHERE Id=:opp2.Id];

        System.assert(second.Name.contains('v2'));
    }

    // UPDATE SAME RECORD
    @isTest
    static void testUpdateSameRecord(){

        Account acc = createAccount('UpdateAcc',3);

        Opportunity opp = new Opportunity(
            Name='Test',
            AccountId=acc.Id,
            StageName='Prospecting',
            CloseDate=System.today().addDays(5),
            Product_Category__c='Tile',
            Branch_Location__c='HO',
            State__c=getValidState(),
            Pin_Code__c=400001
        );

        insert opp;

        Test.startTest();
        opp.StageName='Qualification';
        update opp;
        Test.stopTest();

        Opportunity updated=[SELECT StageName FROM Opportunity WHERE Id=:opp.Id];

        System.assertEquals('Qualification',updated.StageName);
    }

    // GST MAPPING
    @isTest
    static void testGSTMapping(){

        Account acc = createAccount('GSTAcc',4);

        Opportunity opp = new Opportunity(
            Name='Test',
            AccountId=acc.Id,
            StageName='Prospecting',
            CloseDate=System.today().addDays(5),
            State__c=getValidState(),
            Pin_Code__c=400001
        );

        insert opp;

        Opportunity inserted=[SELECT GST_Number__c FROM Opportunity WHERE Id=:opp.Id];

        System.assertEquals(acc.GST_Number__c,inserted.GST_Number__c);
    }

    // ACCOUNT CHANGE UPDATE
    @isTest
    static void testAccountChangeUpdate(){

        Account acc1 = createAccount('Acc1',5);
        Account acc2 = createAccount('Acc2',6);

        Opportunity opp = new Opportunity(
            Name='Test',
            AccountId=acc1.Id,
            StageName='Prospecting',
            CloseDate=System.today().addDays(5),
            State__c=getValidState(),
            Pin_Code__c=400001
        );

        insert opp;

        Test.startTest();
        opp.AccountId = acc2.Id;
        update opp;
        Test.stopTest();

        Opportunity updated=[SELECT GST_Number__c FROM Opportunity WHERE Id=:opp.Id];

        System.assertEquals(acc2.GST_Number__c,updated.GST_Number__c);
    }

    // BULK INSERT
    @isTest
    static void testBulkInsert(){

        List<Account> accs=new List<Account>();

        for(Integer i=0;i<50;i++){
            accs.add(new Account(
                Name='Bulk'+i,
                BillingCountry='India',
                BillingState='Maharashtra',
                BillingPostalCode='400001',
                BillingStreet='Street',
                District__c='Ernakulam',
                Pin_Code__c=400001,
                GST_Number__c=generateGST(100+i)
            ));
        }

        insert accs;

        List<Opportunity> opps=new List<Opportunity>();

        for(Account a:accs){
            opps.add(new Opportunity(
                Name='Test',
                AccountId=a.Id,
                StageName='Prospecting',
                CloseDate=System.today().addDays(5),
                Product_Category__c='Tile',
                Branch_Location__c='HO',
                State__c=getValidState(),
                Pin_Code__c=400001
            ));
        }

        Test.startTest();
        insert opps;
        Test.stopTest();

        List<Opportunity> inserted=[SELECT Id FROM Opportunity WHERE AccountId IN :accs];

        System.assertEquals(50,inserted.size());
    }
@isTest
static void testAddressCopy(){

    Account acc = new Account(
        Name='AddressAcc',
        BillingCountry='India',
        BillingState='Maharashtra',
        BillingPostalCode='400001',
        BillingStreet='Street',
        District__c='Ernakulam',

        Address_Line1__c='Line1',
        Address_Line2__c='Line2',
        Address_Line3__c='Line3',
        State__c = getValidState(),
        pin_code__c=400001,
        GST_Number__c='22ABCDE1234F1Z5'
    );

    insert acc;

    Opportunity opp = new Opportunity(
        Name='Test',
        AccountId=acc.Id,
        StageName='Prospecting',
        CloseDate=System.today().addDays(5),
        Same_as_Account_Ship_Address__c=true
    );

    insert opp;

    Opportunity inserted=[SELECT AddressLine1__c FROM Opportunity WHERE Id=:opp.Id];

    System.assertEquals('Line1',inserted.AddressLine1__c);
}

}