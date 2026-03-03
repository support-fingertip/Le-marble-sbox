@isTest
private class OpportunityTriggerTest {

    // Helper to create unique account for each test
    private static Account createUniqueAccount(String suffix) {
        Account acc = new Account(Name = 'Test Account ' + suffix + ' ' + System.currentTimeMillis());
        insert acc;
        return acc;
    }

    // =====================
    // TEST: Auto-Name Generation on Insert
    // =====================
    @isTest
    static void testAutoNameGeneration_WithCategoryAndBranch() {
        Account acc = createUniqueAccount('CatBranch');
        String todayStr = String.valueOf(System.today());

        Test.startTest();
        Opportunity opp = new Opportunity(
            Name = 'Placeholder',
            AccountId = acc.Id,
            StageName = 'Prospecting',
            CloseDate = System.today().addDays(30),
            Product_Category__c = 'Tile',
            Branch_Location__c = 'HO'
        );
        insert opp;
        Test.stopTest();

        Opportunity inserted = [SELECT Id, Name, Product_Category__c, Branch_Location__c FROM Opportunity WHERE Id = :opp.Id];
        System.assert(inserted.Name.contains(acc.Name), 'Opportunity name should contain account name');
        System.assert(inserted.Name.contains(todayStr), 'Opportunity name should contain today date');
    }

    @isTest
    static void testAutoNameGeneration_WithCategoryOnly() {
        Account acc = createUniqueAccount('CatOnly');
        String todayStr = String.valueOf(System.today());

        Test.startTest();
        Opportunity opp = new Opportunity(
            Name = 'Placeholder',
            AccountId = acc.Id,
            StageName = 'Prospecting',
            CloseDate = System.today().addDays(30),
            Product_Category__c = 'Marble'
        );
        insert opp;
        Test.stopTest();

        Opportunity inserted = [SELECT Id, Name, Product_Category__c FROM Opportunity WHERE Id = :opp.Id];
        System.assert(inserted.Name.contains(acc.Name), 'Opportunity name should contain account name');
        System.assert(inserted.Name.contains(todayStr), 'Opportunity name should contain today date');
    }

    @isTest
    static void testAutoNameGeneration_WithBranchOnly() {
        Account acc = createUniqueAccount('BranchOnly');
        String todayStr = String.valueOf(System.today());

        Test.startTest();
        Opportunity opp = new Opportunity(
            Name = 'Placeholder',
            AccountId = acc.Id,
            StageName = 'Prospecting',
            CloseDate = System.today().addDays(30),
            Branch_Location__c = 'HO'
        );
        insert opp;
        Test.stopTest();

        Opportunity inserted = [SELECT Id, Name, Branch_Location__c FROM Opportunity WHERE Id = :opp.Id];
        System.assert(inserted.Name.contains(acc.Name), 'Opportunity name should contain account name');
        System.assert(inserted.Name.contains(todayStr), 'Opportunity name should contain today date');
    }

    @isTest
    static void testAutoNameGeneration_WithoutCategoryAndBranch() {
        Account acc = createUniqueAccount('NoCatBranch');
        String todayStr = String.valueOf(System.today());

        Test.startTest();
        Opportunity opp = new Opportunity(
            Name = 'Placeholder',
            AccountId = acc.Id,
            StageName = 'Prospecting',
            CloseDate = System.today().addDays(30)
        );
        insert opp;
        Test.stopTest();

        Opportunity inserted = [SELECT Id, Name FROM Opportunity WHERE Id = :opp.Id];
        System.assert(inserted.Name.contains(acc.Name), 'Opportunity name should contain account name');
        System.assert(inserted.Name.contains(todayStr), 'Opportunity name should contain today date');
    }

    // =====================
    // TEST: Duplicate Name Validation on Insert
    // =====================
    @isTest
    static void testDuplicateNameValidation_OnInsert() {
        Account acc = createUniqueAccount('DupInsert');

        // Create first opportunity
        Opportunity opp1 = new Opportunity(
            Name = 'Placeholder',
            AccountId = acc.Id,
            StageName = 'Prospecting',
            CloseDate = System.today().addDays(30),
            Product_Category__c = 'Tile',
            Branch_Location__c = 'HO'
        );
        insert opp1;

        Test.startTest();
        // Try to create duplicate opportunity (same Account, Category, Branch, Date)
        Opportunity opp2 = new Opportunity(
            Name = 'Placeholder',
            AccountId = acc.Id,
            StageName = 'Prospecting',
            CloseDate = System.today().addDays(30),
            Product_Category__c = 'Tile',
            Branch_Location__c = 'HO'
        );

        Boolean errorThrown = false;
        try {
            insert opp2;
        } catch (DmlException e) {
            errorThrown = true;
            System.assert(e.getMessage().contains('An Opportunity with the same Account, Branch, and Category already exists'), 
                'Error message should indicate duplicate opportunity');
        }
        Test.stopTest();

        System.assert(errorThrown, 'DmlException should be thrown for duplicate opportunity');
    }

    // =====================
    // TEST: Duplicate Name Validation on Update
    // =====================
    @isTest
    static void testDuplicateNameValidation_OnUpdate() {
        Account acc = createUniqueAccount('DupUpdate');

        // Create first opportunity with Tile category
        Opportunity opp1 = new Opportunity(
            Name = 'Placeholder',
            AccountId = acc.Id,
            StageName = 'Prospecting',
            CloseDate = System.today().addDays(30),
            Product_Category__c = 'Tile',
            Branch_Location__c = 'HO'
        );
        insert opp1;

        // Create second opportunity with Marble category
        Opportunity opp2 = new Opportunity(
            Name = 'Placeholder',
            AccountId = acc.Id,
            StageName = 'Prospecting',
            CloseDate = System.today().addDays(30),
            Product_Category__c = 'Marble',
            Branch_Location__c = 'HO'
        );
        insert opp2;

        // Get the name of opp1 to force opp2 to have the same name
        Opportunity opp1Refreshed = [SELECT Id, Name FROM Opportunity WHERE Id = :opp1.Id];
        
        Test.startTest();
        // Try to update opp2 name to match opp1 name
        opp2.Name = opp1Refreshed.Name;

        Boolean errorThrown = false;
        try {
            update opp2;
        } catch (DmlException e) {
            errorThrown = true;
            System.assert(e.getMessage().contains('An Opportunity with the same Account, Branch, and Category already exists'), 
                'Error message should indicate duplicate opportunity');
        }
        Test.stopTest();

        System.assert(errorThrown, 'DmlException should be thrown for duplicate opportunity name on update');
    }

    // =====================
    // TEST: Allow Update of Same Record (No False Positive)
    // =====================
    @isTest
    static void testUpdateSameRecord_NoError() {
        Account acc = createUniqueAccount('SameRecord');

        Opportunity opp = new Opportunity(
            Name = 'Placeholder',
            AccountId = acc.Id,
            StageName = 'Prospecting',
            CloseDate = System.today().addDays(30),
            Product_Category__c = 'Tile',
            Branch_Location__c = 'HO'
        );
        insert opp;

        Test.startTest();
        // Update the same record (should not throw error)
        opp.StageName = 'Qualification';
        update opp;
        Test.stopTest();

        Opportunity updated = [SELECT Id, StageName FROM Opportunity WHERE Id = :opp.Id];
        System.assertEquals('Qualification', updated.StageName, 'Opportunity should be updated without error');
    }

    // =====================
    // TEST: Opportunity Without Account
    // =====================
    @isTest
    static void testOpportunityWithoutAccount() {
        String todayStr = String.valueOf(System.today());
        String uniqueId = String.valueOf(System.currentTimeMillis());

        Test.startTest();
        Opportunity opp = new Opportunity(
            Name = 'Placeholder ' + uniqueId,
            StageName = 'Prospecting',
            CloseDate = System.today().addDays(30),
            Product_Category__c = 'Tile',
            Branch_Location__c = 'HO'
        );
        insert opp;
        Test.stopTest();

        Opportunity inserted = [SELECT Id, Name, Product_Category__c, Branch_Location__c FROM Opportunity WHERE Id = :opp.Id];
        System.assert(inserted.Name.contains(todayStr), 'Opportunity name should contain today date');
    }

    // =====================
    // TEST: Bulk Insert with different accounts
    // =====================
    @isTest
    static void testBulkInsert() {
        String todayStr = String.valueOf(System.today());

        // Create multiple accounts to avoid duplicate name conflicts
        List<Account> accounts = new List<Account>();
        for (Integer i = 0; i < 50; i++) {
            accounts.add(new Account(Name = 'Bulk Account ' + i + ' ' + System.currentTimeMillis()));
        }
        insert accounts;

        List<Opportunity> opps = new List<Opportunity>();
        for (Integer i = 0; i < 50; i++) {
            opps.add(new Opportunity(
                Name = 'Placeholder',
                AccountId = accounts[i].Id,
                StageName = 'Prospecting',
                CloseDate = System.today().addDays(30),
                Product_Category__c = 'Tile',
                Branch_Location__c = 'HO'
            ));
        }

        Test.startTest();
        insert opps;
        Test.stopTest();

        List<Opportunity> inserted = [SELECT Id, Name, AccountId FROM Opportunity WHERE AccountId IN :accounts];
        System.assertEquals(50, inserted.size(), '50 opportunities should be inserted');

        for (Opportunity o : inserted) {
            System.assert(o.Name.contains('Bulk Account'), 'Each opportunity name should contain account name');
            System.assert(o.Name.endsWith(todayStr), 'Each opportunity name should end with today date');
        }
    }

    // =====================
    // TEST: Different Accounts - No Duplicate Error
    // =====================
    @isTest
    static void testDifferentAccounts_NoDuplicateError() {
        Account acc1 = createUniqueAccount('DiffAcc1');
        Account acc2 = createUniqueAccount('DiffAcc2');

        // Create opportunity for first account
        Opportunity opp1 = new Opportunity(
            Name = 'Placeholder',
            AccountId = acc1.Id,
            StageName = 'Prospecting',
            CloseDate = System.today().addDays(30),
            Product_Category__c = 'Tile',
            Branch_Location__c = 'HO'
        );
        insert opp1;

        Test.startTest();
        // Create opportunity for second account with same category and branch
        Opportunity opp2 = new Opportunity(
            Name = 'Placeholder',
            AccountId = acc2.Id,
            StageName = 'Prospecting',
            CloseDate = System.today().addDays(30),
            Product_Category__c = 'Tile',
            Branch_Location__c = 'HO'
        );
        insert opp2; // Should not throw error as different account
        Test.stopTest();

        Opportunity inserted = [SELECT Id, Name FROM Opportunity WHERE Id = :opp2.Id];
        System.assertNotEquals(null, inserted, 'Opportunity should be inserted for different account');
    }
}