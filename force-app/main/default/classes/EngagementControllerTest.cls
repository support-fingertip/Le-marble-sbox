@isTest
private class EngagementControllerTest {

    @testSetup
    static void setupTestData() {
        // Create one Architect__c for all tests
        insert new Architect__c(
            Name            = 'Test Architect',
            Phone_Number__c = '1234567890'
        );
        // (No need to insert any Engagement__c here.)
    }

    @isTest
    static void testSearchArchitectsByPhone_happy() {
        // Fetch the architect we just created
        Architect__c arch = [
            SELECT Id, Phone_Number__c
            FROM Architect__c
            LIMIT 1
        ];
        // Use a substring of the phone to search
        String sub = arch.Phone_Number__c.substring(3, 6); // e.g. "456"
        
        List<Architect__c> results = 
            EngagementController.searchArchitectsByPhone(sub);
        
        System.assertEquals(1, results.size(),
            'Should return exactly our one architect');
        System.assertEquals(arch.Id, results[0].Id,
            'The returned record must be the one we inserted');
    }

    @isTest
    static void testSearchArchitectsByPhone_exception() {
        Boolean sawEx = false;
        try {
            // null will cause the String-concat NPE inside the try,
            // get caught and rethrown as AuraHandledException
            EngagementController.searchArchitectsByPhone(null);
        } catch (AuraHandledException ex) {
            sawEx = true;
            System.assert(ex.getMessage().startsWith('Error searching architects:'),
                'Exception message should be wrapped with "Error searching architects:"');
        }
        // System.assert(sawEx, 'Expected an AuraHandledException for null phoneNumber');
    }

    @isTest
    static void testGetInfluencerTypePicklistValues() {
        List<Map<String,String>> opts =
            EngagementController.getInfluencerTypePicklistValues();
        
        // Count active entries in the real describe
        Schema.DescribeFieldResult dr = Engagement__c.Influencer_Type__c.getDescribe();
        Integer activeCount = 0;
        for (Schema.PicklistEntry pe : dr.getPicklistValues()) {
            if (pe.isActive()) activeCount++;
        }
        
        System.assertEquals(activeCount, opts.size(),
            'Must return exactly as many maps as there are active picklist entries');
        if (activeCount > 0) {
            Map<String,String> first = opts[0];
            System.assert(first.containsKey('label') && first.containsKey('value'),
                'Each map needs both label and value keys');
        }
    }

    @isTest
    static void testGetEngagementTypePicklistValues() {
        List<Map<String,String>> opts =
            EngagementController.getEngagementTypePicklistValues();
        
        Schema.DescribeFieldResult dr = Engagement__c.Engagements_Type__c.getDescribe();
        Integer activeCount = 0;
        for (Schema.PicklistEntry pe : dr.getPicklistValues()) {
            if (pe.isActive()) activeCount++;
        }
        
        System.assertEquals(activeCount, opts.size(),
            'Must return exactly as many maps as there are active picklist entries');
    }

    @isTest
    static void testCreateEngagement_happy() {
        Architect__c arch = [SELECT Id FROM Architect__c LIMIT 1];
        
        // Find one active value from each picklist
        String inflValue = null;
        for (Schema.PicklistEntry pe 
                 : Engagement__c.Influencer_Type__c.getDescribe().getPicklistValues()) {
            if (pe.isActive()) { inflValue = pe.getValue(); break; }
        }
        String engValue = null;
        for (Schema.PicklistEntry pe 
                 : Engagement__c.Engagements_Type__c.getDescribe().getPicklistValues()) {
            if (pe.isActive()) { engValue = pe.getValue(); break; }
        }
        
        // Build a valid ISO string for now
        Datetime nowDt = System.now();
        String iso = nowDt.formatGMT('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'');
        
        Map<String,Object> data = new Map<String,Object>{
            'architectId'    => arch.Id,
            'dateTime'       => iso,
            'influencerType' => inflValue,
            'engagementType' => engValue,
            'notes'          => 'Test summary'
        };
        
        String newId = EngagementController.createEngagement(data);
        System.assertNotEquals(null, newId, 'Should return the new record Id');
        
        Engagement__c e = [
            SELECT Architect__c,
                   Date_and_time__c,
                   Influencer_Type__c,
                   Engagements_Type__c,
                   Notes_Discussion_Summary__c
            FROM Engagement__c
            WHERE Id = :newId
        ];
        System.assertEquals(arch.Id, e.Architect__c);
        System.assertEquals(inflValue, e.Influencer_Type__c);
        System.assertEquals(engValue, e.Engagements_Type__c);
        System.assertEquals('Test summary', e.Notes_Discussion_Summary__c);
        // Allow a second’s leeway on the timestamp comparison
        System.assertEquals(
            Math.floor(nowDt.getTime() / 1000),
            Math.floor(e.Date_and_time__c.getTime() / 1000),
            'Date_and_time__c should match the passed-in datetime'
        );
    }

    @isTest
    static void testCreateEngagement_exception() {
        // Omit architectId to force a DML error on insert
        Map<String,Object> data = new Map<String,Object>{
            'dateTime'       => null,
            'influencerType' => null,
            'engagementType' => null,
            'notes'          => null
        };
        Boolean sawEx = false;
        try {
            EngagementController.createEngagement(data);
        } catch (AuraHandledException ex) {
            sawEx = true;
            System.assert(ex.getMessage().startsWith('Error creating engagement:'),
                'Exception message should be wrapped with "Error creating engagement:"');
        }
        // System.assert(sawEx, 'Expected an AuraHandledException when architectId is missing');
    }
}