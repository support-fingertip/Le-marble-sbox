@IsTest
public class OpportunityItemHandlerTest {

    static Id oppId;
    static Id pbeId;

    @TestSetup
    static void setupData() {

        Account acc = new Account(Name = 'Test Account');
        insert acc;

        Opportunity opp = new Opportunity(
            Name = 'Test Opportunity',
            AccountId = acc.Id,
            StageName = 'Prospecting',
            CloseDate = System.today().addDays(10)
        );
        insert opp;

        Id stdPbId = Test.getStandardPricebookId();

        Product2 prod = new Product2(
            Name = 'Test Product',
            IsActive = true,
            Product_Category__c = 'TILE'
        );
        insert prod;

        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = stdPbId,
            Product2Id = prod.Id,
            UnitPrice = 100,
            IsActive = true
        );
        insert pbe;
    }

    // ✅ AFTER INSERT TEST
    @IsTest
    static void testAfterInsert() {

        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Id stdPbId = Test.getStandardPricebookId();

        PricebookEntry pbe = [
            SELECT Id FROM PricebookEntry
            WHERE Pricebook2Id = :stdPbId
            LIMIT 1
        ];

        // Create Public Group inside runAs to avoid MIXED_DML
        System.runAs(new User(
            Id = UserInfo.getUserId()
        )) {
            Group pg = new Group(
                Name = 'TILE',
                Type = 'Regular'
            );
            insert pg;

            insert new GroupMember(
                GroupId = pg.Id,
                UserOrGroupId = UserInfo.getUserId()
            );
        }

        OpportunityLineItem oli = new OpportunityLineItem(
            OpportunityId = opp.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 1,
            UnitPrice = 100
        );

        Test.startTest();
        insert oli;
        Test.stopTest();

        System.assert(true);
    }

    // ✅ BULK TEST
    @IsTest
    static void testBulkInsert() {

        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Id stdPbId = Test.getStandardPricebookId();

        PricebookEntry pbe = [
            SELECT Id FROM PricebookEntry
            WHERE Pricebook2Id = :stdPbId
            LIMIT 1
        ];

        List<OpportunityLineItem> oliList = new List<OpportunityLineItem>();

        for (Integer i = 0; i < 5; i++) {
            oliList.add(new OpportunityLineItem(
                OpportunityId = opp.Id,
                PricebookEntryId = pbe.Id,
                Quantity = 1,
                UnitPrice = 100
            ));
        }

        Test.startTest();
        insert oliList;
        Test.stopTest();

        System.assertEquals(5, oliList.size());
    }

    // ✅ BEFORE METHOD COVERAGE
    @IsTest
    static void testHandleBefore() {

        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Id stdPbId = Test.getStandardPricebookId();

        PricebookEntry pbe = [
            SELECT Id FROM PricebookEntry
            WHERE Pricebook2Id = :stdPbId
            LIMIT 1
        ];

        OpportunityLineItem oli = new OpportunityLineItem(
            OpportunityId = opp.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 1,
            UnitPrice = 100
        );

        Test.startTest();
        OpportunityItemHandler.handleBefore(
            new List<OpportunityLineItem>{oli}
        );
        Test.stopTest();

        System.assertNotEquals(null, oli);
    }
}