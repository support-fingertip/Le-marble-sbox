@IsTest
public class EngagementControllerTest {

    @TestSetup
    static void setupData() {
        // Create Architect test data
        Architect__c architect1 = new Architect__c(
            Name = 'Test Architect 1',
            Phone_Number__c = '9876543210'
        );
        
        Architect__c architect2 = new Architect__c(
            Name = 'Test Architect 2',
            Phone_Number__c = '9876500000'
        );
        
        insert new List<Architect__c>{ architect1, architect2 };
    }

    // --------------------------------------------
    // Test searchArchitectsByPhone
    // --------------------------------------------
    @IsTest
    static void testSearchArchitectsByPhone() {
        Test.startTest();
        
        List<Architect__c> results =
            EngagementController.searchArchitectsByPhone('9876');
        
        Test.stopTest();
        
        System.assertNotEquals(null, results);
        System.assert(results.size() > 0, 'Should return matching architects');
        System.assertEquals('9876543210', results[0].Phone_Number__c);
    }

    // --------------------------------------------
    // Test getInfluencerTypePicklistValues
    // --------------------------------------------
    @IsTest
    static void testGetInfluencerTypePicklistValues() {
        Test.startTest();
        
        List<Map<String, String>> values =
            EngagementController.getInfluencerTypePicklistValues();
        
        Test.stopTest();
        
        System.assertNotEquals(null, values);
        System.assert(values.size() > 0,
            'Influencer Type picklist should return active values');
        
        System.assert(values[0].containsKey('label'));
        System.assert(values[0].containsKey('value'));
    }

    // --------------------------------------------
    // Test getEngagementTypePicklistValues
    // --------------------------------------------
    @IsTest
    static void testGetEngagementTypePicklistValues() {
        Test.startTest();
        
        List<Map<String, String>> values =
            EngagementController.getEngagementTypePicklistValues();
        
        Test.stopTest();
        
        System.assertNotEquals(null, values);
        System.assert(values.size() > 0,
            'Engagement Type picklist should return active values');
        
        System.assert(values[0].containsKey('label'));
        System.assert(values[0].containsKey('value'));
    }

    // --------------------------------------------
    // Test createEngagement
    // --------------------------------------------
    @IsTest
    static void testCreateEngagement() {
        // Get architect
        Architect__c arch = [
            SELECT Id FROM Architect__c LIMIT 1
        ];
        
        // Get valid picklist values dynamically
        String influencerValue = 
            Engagement__c.Influencer_Type__c.getDescribe()
            .getPicklistValues()[0].getValue();
        
        String engagementValue = 
            Engagement__c.Engagements_Type__c.getDescribe()
            .getPicklistValues()[0].getValue();
        
        Map<String, Object> engagementData = new Map<String, Object>{
            'architectId' => arch.Id,
            'dateTime' => String.valueOf(System.now()),
            'influencerType' => influencerValue,
            'engagementType' => engagementValue,
            'notes' => 'Test discussion summary'
        };
        
        Test.startTest();
        
        String engagementId =
            EngagementController.createEngagement(engagementData);
        
        Test.stopTest();
        
        System.assertNotEquals(null, engagementId,
            'Engagement Id should not be null');
        
        Engagement__c created = [
            SELECT Architect__c,
                   Influencer_Type__c,
                   Engagements_Type__c,
                   Notes_Discussion_Summary__c
            FROM Engagement__c
            WHERE Id = :engagementId
        ];
        
        System.assertEquals(arch.Id, created.Architect__c);
        System.assertEquals('Test discussion summary',
                            created.Notes_Discussion_Summary__c);
    }

    // --------------------------------------------
    // Test createEngagement with null datetime
    // --------------------------------------------
    @IsTest
    static void testCreateEngagement_NullDate() {
        Architect__c arch = [
            SELECT Id FROM Architect__c LIMIT 1
        ];
        
        String influencerValue = 
            Engagement__c.Influencer_Type__c.getDescribe()
            .getPicklistValues()[0].getValue();
        
        String engagementValue = 
            Engagement__c.Engagements_Type__c.getDescribe()
            .getPicklistValues()[0].getValue();
        
        Map<String, Object> engagementData = new Map<String, Object>{
            'architectId' => arch.Id,
            'dateTime' => null,
            'influencerType' => influencerValue,
            'engagementType' => engagementValue,
            'notes' => 'Test without date'
        };
        
        Test.startTest();
        
        String engagementId =
            EngagementController.createEngagement(engagementData);
        
        Test.stopTest();
        
        System.assertNotEquals(null, engagementId);
    }
}