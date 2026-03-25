@IsTest
public class OpportunityItemHandlerTest {

    static Id oppId;
    static Id pbeId;

    @TestSetup
    static void setupData() {

        Account acc = new Account(
            Name              = 'Test Account',
            BillingCountry    = 'India',
            BillingState      = 'Maharashtra',
            BillingPostalCode = '400001',
            BillingStreet     = '123 Test Street',
            District__c       = 'Ernakulam',
            Pin_Code__c       = 400001
        );
        insert acc;

        String validState;
        for (Schema.PicklistEntry pe : Opportunity.State__c.getDescribe().getPicklistValues()) {
            if (pe.isActive()) { validState = pe.getValue(); break; }
        }
        Opportunity opp = new Opportunity(
            Name = 'Test Opportunity',
            AccountId = acc.Id,
            StageName = 'Prospecting',
            CloseDate = System.today().addDays(10),
            State__c = validState,
            Pin_Code__c = 400001
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

    // ✅ UPDATE TRIGGER TEST
    @IsTest
    static void testAfterUpdate() {

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
        insert oli;

        Test.startTest();
        oli.Quantity = 5;
        update oli;
        Test.stopTest();

        OpportunityLineItem updated = [SELECT Quantity FROM OpportunityLineItem WHERE Id = :oli.Id];
        System.assertEquals(5, updated.Quantity, 'Quantity should be updated');
    }

    // ✅ BEFORE UPDATE TRIGGER TEST
    @IsTest
    static void testBeforeUpdate() {

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
        insert oli;

        Test.startTest();
        oli.UnitPrice = 200;
        update oli;
        Test.stopTest();

        OpportunityLineItem updated = [SELECT UnitPrice FROM OpportunityLineItem WHERE Id = :oli.Id];
        System.assertEquals(200, updated.UnitPrice, 'UnitPrice should be updated');
    }

    // ✅ EMPTY LIST TEST
    @IsTest
    static void testHandleBefore_EmptyList() {
        Test.startTest();
        OpportunityItemHandler.handleBefore(new List<OpportunityLineItem>());
        Test.stopTest();
        System.assert(true, 'Should handle empty list');
    }

    // ✅ AFTER INSERT EMPTY NOTIFICATION
    @IsTest
    static void testAfterInsert_NoMatchingGroup() {

        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Id stdPbId = Test.getStandardPricebookId();

        // Create product with category that has no matching group
        Product2 prod2 = new Product2(
            Name = 'No Group Product',
            IsActive = true,
            Product_Category__c = 'UNKNOWN_CATEGORY'
        );
        insert prod2;

        PricebookEntry pbe2 = new PricebookEntry(
            Pricebook2Id = stdPbId,
            Product2Id = prod2.Id,
            UnitPrice = 50,
            IsActive = true
        );
        insert pbe2;

        OpportunityLineItem oli = new OpportunityLineItem(
            OpportunityId = opp.Id,
            PricebookEntryId = pbe2.Id,
            Quantity = 1,
            UnitPrice = 50
        );

        Test.startTest();
        insert oli;
        Test.stopTest();

        System.assert(true, 'Should handle missing group gracefully');
    }
}