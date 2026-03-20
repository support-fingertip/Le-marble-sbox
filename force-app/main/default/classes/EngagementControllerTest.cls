@isTest
private class EngagementControllerTest {

    @testSetup
    static void setupTestData() {
        insert new Architect__c(
            Name            = 'Test Architect',
            Phone_Number__c = '1234567890'
        );
    }

    // --- searchArchitectsByPhone -----------------------------------------

    @isTest
    static void testSearchArchitectsByPhone_found() {
        Architect__c arch = [SELECT Id, Phone_Number__c FROM Architect__c LIMIT 1];
        String sub = arch.Phone_Number__c.substring(3, 6);

        Test.startTest();
        List<Architect__c> results = EngagementController.searchArchitectsByPhone(sub);
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Should return exactly one matching architect');
        System.assertEquals(arch.Id, results[0].Id, 'Returned record must be the inserted architect');
    }

    @isTest
    static void testSearchArchitectsByPhone_fullMatch() {
        Architect__c arch = [SELECT Id, Phone_Number__c FROM Architect__c LIMIT 1];

        Test.startTest();
        List<Architect__c> results = EngagementController.searchArchitectsByPhone(arch.Phone_Number__c);
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Full phone number should return one result');
        System.assertEquals(arch.Id, results[0].Id, 'Returned record should match inserted architect');
    }

    @isTest
    static void testSearchArchitectsByPhone_noResults() {
        Test.startTest();
        List<Architect__c> results = EngagementController.searchArchitectsByPhone('0000000000');
        Test.stopTest();

        System.assertEquals(0, results.size(), 'Non-matching phone should return empty list');
    }

    @isTest
    static void testSearchArchitectsByPhone_nullReturnsEmpty() {
        // null is coerced to '%null%' by string concat - no exception, empty results
        Test.startTest();
        List<Architect__c> results = EngagementController.searchArchitectsByPhone(null);
        Test.stopTest();

        System.assertNotEquals(null, results, 'Result list should never be null');
        System.assertEquals(0, results.size(), 'Null phone should return empty list');
    }

    // --- getInfluencerTypePicklistValues ---------------------------------

    @isTest
    static void testGetInfluencerTypePicklistValues_count() {
        Schema.DescribeFieldResult dr = Engagement__c.Influencer_Type__c.getDescribe();
        Integer activeCount = 0;
        for (Schema.PicklistEntry pe : dr.getPicklistValues()) {
            if (pe.isActive()) activeCount++;
        }

        Test.startTest();
        List<Map<String,String>> opts = EngagementController.getInfluencerTypePicklistValues();
        Test.stopTest();

        System.assertEquals(activeCount, opts.size(),
            'Should return exactly as many entries as active picklist values');
    }

    @isTest
    static void testGetInfluencerTypePicklistValues_shape() {
        Test.startTest();
        List<Map<String,String>> opts = EngagementController.getInfluencerTypePicklistValues();
        Test.stopTest();

        for (Map<String,String> entry : opts) {
            System.assert(entry.containsKey('label'), 'Every entry must have a label key');
            System.assert(entry.containsKey('value'), 'Every entry must have a value key');
            System.assertNotEquals('', entry.get('label'), 'Label should not be blank');
            System.assertNotEquals('', entry.get('value'), 'Value should not be blank');
        }
    }

    // --- getEngagementTypePicklistValues ---------------------------------

    @isTest
    static void testGetEngagementTypePicklistValues_count() {
        Schema.DescribeFieldResult dr = Engagement__c.Engagements_Type__c.getDescribe();
        Integer activeCount = 0;
        for (Schema.PicklistEntry pe : dr.getPicklistValues()) {
            if (pe.isActive()) activeCount++;
        }

        Test.startTest();
        List<Map<String,String>> opts = EngagementController.getEngagementTypePicklistValues();
        Test.stopTest();

        System.assertEquals(activeCount, opts.size(),
            'Should return exactly as many entries as active picklist values');
    }

    @isTest
    static void testGetEngagementTypePicklistValues_shape() {
        Test.startTest();
        List<Map<String,String>> opts = EngagementController.getEngagementTypePicklistValues();
        Test.stopTest();

        for (Map<String,String> entry : opts) {
            System.assert(entry.containsKey('label'), 'Every entry must have a label key');
            System.assert(entry.containsKey('value'), 'Every entry must have a value key');
        }
    }

    // --- createEngagement ------------------------------------------------

    @isTest
    static void testCreateEngagement_allFields() {
        Architect__c arch = [SELECT Id FROM Architect__c LIMIT 1];

        String inflValue = null;
        for (Schema.PicklistEntry pe : Engagement__c.Influencer_Type__c.getDescribe().getPicklistValues()) {
            if (pe.isActive()) { inflValue = pe.getValue(); break; }
        }
        String engValue = null;
        for (Schema.PicklistEntry pe : Engagement__c.Engagements_Type__c.getDescribe().getPicklistValues()) {
            if (pe.isActive()) { engValue = pe.getValue(); break; }
        }

        Datetime nowDt = System.now();
        String iso = nowDt.formatGMT('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'');

        Map<String,Object> data = new Map<String,Object>{
            'architectId'    => arch.Id,
            'dateTime'       => iso,
            'influencerType' => inflValue,
            'engagementType' => engValue,
            'notes'          => 'Test discussion summary'
        };

        Test.startTest();
        String newId = EngagementController.createEngagement(data);
        Test.stopTest();

        System.assertNotEquals(null, newId, 'Should return the new record Id');

        Engagement__c e = [
            SELECT Architect__c, Date_and_time__c, Influencer_Type__c,
                   Engagements_Type__c, Notes_Discussion_Summary__c
            FROM Engagement__c WHERE Id = :newId
        ];
        System.assertEquals(arch.Id,   e.Architect__c,                    'Architect should match');
        System.assertEquals(inflValue,  e.Influencer_Type__c,              'Influencer type should match');
        System.assertEquals(engValue,   e.Engagements_Type__c,             'Engagement type should match');
        System.assertEquals('Test discussion summary', e.Notes_Discussion_Summary__c, 'Notes should match');
        System.assertEquals(
            Math.floor(nowDt.getTime() / 1000),
            Math.floor(e.Date_and_time__c.getTime() / 1000),
            'Date_and_time__c should match the ISO datetime passed in'
        );
    }

    @isTest
    static void testCreateEngagement_nullDateTime() {
        // Verifies the null dateTime branch: dt stays null, record still inserts
        Architect__c arch = [SELECT Id FROM Architect__c LIMIT 1];

        Map<String,Object> data = new Map<String,Object>{
            'architectId' => arch.Id,
            'dateTime'    => null,
            'notes'       => 'No date test'
        };

        Test.startTest();
        String newId = EngagementController.createEngagement(data);
        Test.stopTest();

        System.assertNotEquals(null, newId, 'Should return a record Id even without a dateTime');

        Engagement__c e = [SELECT Date_and_time__c FROM Engagement__c WHERE Id = :newId];
        System.assertEquals(null, e.Date_and_time__c, 'Date_and_time__c should be null when not supplied');
    }

    @isTest
    static void testCreateEngagement_returnsRecordId() {
        Architect__c arch = [SELECT Id FROM Architect__c LIMIT 1];

        Map<String,Object> data = new Map<String,Object>{
            'architectId' => arch.Id,
            'dateTime'    => null,
            'notes'       => 'Id format check'
        };

        Test.startTest();
        String newId = EngagementController.createEngagement(data);
        Test.stopTest();

        System.assertNotEquals(null, newId, 'Returned Id must not be null');
        System.assertEquals(18, newId.length(), 'Salesforce Id should be 18 characters');
    }

    @isTest
    static void testCreateEngagement_invalidDateTimeThrows() {
        // An invalid ISO string causes JSON.deserialize to throw -> AuraHandledException
        Architect__c arch = [SELECT Id FROM Architect__c LIMIT 1];

        Map<String,Object> data = new Map<String,Object>{
            'architectId' => arch.Id,
            'dateTime'    => 'NOT-A-DATE',
            'notes'       => 'bad date test'
        };

        Boolean sawEx = false;
        Test.startTest();
        try {
            EngagementController.createEngagement(data);
        } catch (AuraHandledException ex) {
            sawEx = true;
            // AuraHandledException.getMessage() returns 'Script-thrown exception'
            // in test context, not the original message — so we only verify the type.
        }
        Test.stopTest();

        System.assert(sawEx, 'Expected AuraHandledException for an invalid date string');
    }
}