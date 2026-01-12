public with sharing class StandardLeadController {

    /*1.  FETCH STANDARD LEAD PICKLIST VALUES */

    @AuraEnabled(cacheable=true)
    public static List<String> getLeadTypes() {
        return getPicklistValues('Lead', 'Type__c');
    }

    @AuraEnabled(cacheable=true)
    public static List<String> getSalutations() {
        return getPicklistValues('Lead', 'Salutation');
    }

    @AuraEnabled(cacheable=true)
    public static List<String> getLeadSources() {
        return getPicklistValues('Lead', 'LeadSource');
    }

    @AuraEnabled(cacheable=true)
    public static List<String> getLeadCategories() {
        return getPicklistValues('Lead', 'Lead_Category__c');
    }

    @AuraEnabled(cacheable=true)
    public static List<String> getStates() {
        return getPicklistValues('Lead', 'State__c');
    }

    @AuraEnabled(cacheable=true)
    public static List<String> getCountries() {
        return getPicklistValues('Lead', 'Country__c');
    }

    @AuraEnabled(cacheable=true)
    public static List<String> getUnqualifiedReasons() {
        return getPicklistValues('Lead', 'Unqualified_Reason__c');
    }


    /* 2. CREATE A STANDARD LEAD RECORD */

    @AuraEnabled
    public static Id createLead(Map<String, Object> data) {

        Lead newLead = new Lead();

        // Basic fields
        if (data.containsKey('type')) newLead.Type__c = (String)data.get('type');
        if (data.containsKey('salutation')) newLead.Salutation = (String)data.get('salutation');
        if (data.containsKey('firstName')) newLead.FirstName = (String)data.get('firstName');
        if (data.containsKey('lastName')) newLead.LastName = (String)data.get('lastName');
        if (data.containsKey('company')) newLead.Company = (String)data.get('company');

        // Contact fields
        if (data.containsKey('primaryPhone')) newLead.Phone = (String)data.get('primaryPhone');
        if (data.containsKey('secondaryPhone')) newLead.Secondary_Phone__c = (String)data.get('secondaryPhone');
        if (data.containsKey('email')) newLead.Email = (String)data.get('email');

        // Address fields
        if (data.containsKey('country')) newLead.Country__c = (String)data.get('country');
        if (data.containsKey('state')) newLead.State__c = (String)data.get('state');

        // Additional info
        if (data.containsKey('remarks')) newLead.Remarks__c = (String)data.get('remarks');
        if (data.containsKey('leadCategory')) newLead.Lead_Category__c = (String)data.get('leadCategory');

        // Owner assignment
        if (data.containsKey('assignedExecutive')) {
            newLead.OwnerId = (String)data.get('assignedExecutive');
        }

        // INSERT WITH DUPLICATE HANDLING
        try {
            insert newLead;

        } catch (DmlException dmlEx) {
            if (dmlEx.getDmlType(0) == StatusCode.DUPLICATES_DETECTED) {
                throw new AuraHandledException(
                    'Duplicate Lead Found. Phone / Email / GST already exists.'
                );
            } else {
                throw dmlEx;
            }
        }

        return newLead.Id;
    }


    /* 3. REUSABLE HELPER FOR PICKLISTS */
    private static List<String> getPicklistValues(String objectName, String fieldName) {
        List<String> picklistValues = new List<String>();
        try {
            Schema.SObjectType sObj = Schema.getGlobalDescribe().get(objectName);
            Schema.DescribeFieldResult fieldResult = sObj.getDescribe().fields.getMap().get(fieldName).getDescribe();

            for (Schema.PicklistEntry entry : fieldResult.getPicklistValues()) {
                if (entry.isActive()) {
                    picklistValues.add(entry.getLabel());
                }
            }
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching picklist values: ' + e.getMessage());
        }
        return picklistValues;
    }
}