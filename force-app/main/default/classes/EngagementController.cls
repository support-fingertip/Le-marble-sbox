public with sharing class EngagementController {
    @AuraEnabled
    public static List<Architect__c> searchArchitectsByPhone(String phoneNumber) {
        try {
            String searchKey = '%' + phoneNumber + '%';
            return [
                SELECT Id, Name, Phone_Number__c
                FROM Architect__c
                WHERE Phone_Number__c LIKE :searchKey
                LIMIT 5
            ];
        } catch (Exception e) {
            throw new AuraHandledException('Error searching architects: ' + e.getMessage());
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getInfluencerTypePicklistValues() {
        try {
            List<Map<String, String>> options = new List<Map<String, String>>();
            
            // Get the describe result for the Engagement__c object
            Schema.DescribeFieldResult fieldResult = Engagement__c.Influencer_Type__c.getDescribe();
            
            // Get the picklist values
            List<Schema.PicklistEntry> picklistValues = fieldResult.getPicklistValues();
            
            // Convert to a format suitable for LWC
            for(Schema.PicklistEntry entry : picklistValues) {
                if(entry.isActive()) {
                    options.add(new Map<String, String>{
                        'label' => entry.getLabel(),
                        'value' => entry.getValue()
                    });
                }
            }
            
            return options;
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching Influencer Type values: ' + e.getMessage());
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getEngagementTypePicklistValues() {
        try {
            List<Map<String, String>> options = new List<Map<String, String>>();
            
            // Get the describe result for the Engagement__c object
            Schema.DescribeFieldResult fieldResult = Engagement__c.Engagements_Type__c.getDescribe();
            
            // Get the picklist values
            List<Schema.PicklistEntry> picklistValues = fieldResult.getPicklistValues();
            
            // Convert to a format suitable for LWC
            for(Schema.PicklistEntry entry : picklistValues) {
                if(entry.isActive()) {
                    options.add(new Map<String, String>{
                        'label' => entry.getLabel(),
                        'value' => entry.getValue()
                    });
                }
            }
            
            return options;
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching Engagement Type values: ' + e.getMessage());
        }
    }
    
    @AuraEnabled
    public static String createEngagement(Map<String, Object> engagementData) {
        try {
            String dateTimeStr = (String)engagementData.get('dateTime');
            Datetime dt = dateTimeStr != null ? (Datetime)JSON.deserialize('"' + dateTimeStr + '"', Datetime.class) : null;
            
            Engagement__c newEngagement = new Engagement__c(
                Architect__c = (String)engagementData.get('architectId'),
                Date_and_time__c = dt,
                Influencer_Type__c = (String)engagementData.get('influencerType'),
                Engagements_Type__c = (String)engagementData.get('engagementType'),
                Notes_Discussion_Summary__c = (String)engagementData.get('notes')
            );
            
            insert newEngagement;
            return newEngagement.Id;
        } catch (Exception e) {
            throw new AuraHandledException('Error creating engagement: ' + e.getMessage());
        }
    }
}