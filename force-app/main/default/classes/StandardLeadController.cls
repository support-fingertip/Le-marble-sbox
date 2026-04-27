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
    public static List<PicklistOption> getStates() {
        return getPicklistEntries('Lead', 'State__c');
    }

    @AuraEnabled(cacheable=true)
    public static List<String> getDistricts() {
        return getPicklistValues('Lead', 'District__c');
    }

    @AuraEnabled(cacheable=true)
    public static List<String> getPanchayaths() {
        return getPicklistValues('Lead', 'Panchayath__c');
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
 system.debug('data> '+data);
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
        if (data.containsKey('country')) newLead.Country__c = resolvePicklistApiName('Lead', 'Country__c', (String)data.get('country'));
        if (data.containsKey('state')) newLead.State__c = resolvePicklistApiName('Lead', 'State__c', (String)data.get('state'));
        if (data.containsKey('district')) newLead.District__c = resolvePicklistApiName('Lead', 'District__c', (String)data.get('district'));
        if (data.containsKey('panchayat')) newLead.Panchayath__c = resolvePicklistApiName('Lead', 'Panchayath__c', (String)data.get('panchayat'));
          // Default Country to India when the form left it blank
        if (String.isBlank(newLead.Country__c)) {
            newLead.Country__c = resolvePicklistApiName('Lead', 'Country__c', 'India');
        }
        if (data.containsKey('pinCode') && data.get('pinCode') != null) {
            String pinCode = String.valueOf(data.get('pinCode')).trim();
            if (!String.isBlank(pinCode)) {
                if (!Pattern.matches('^[0-9]{6}$', pinCode)) {
                    throw new AuraHandledException('Pin Code must be exactly 6 digits.');
                }
                newLead.Pin_Code__c = Decimal.valueOf(pinCode);
            }
        }

        // Additional info
        if (data.containsKey('remarks')) newLead.Remarks__c = (String)data.get('remarks');
        if (data.containsKey('leadCategory')) newLead.Lead_Category__c = (String)data.get('leadCategory');

        // Owner assignment
        if (data.containsKey('assignedExecutive')) {
            newLead.OwnerId = (String)data.get('assignedExecutive');
        }

        // INSERT WITH DUPLICATE HANDLING
        try {
            system.debug('newLead> '+newLead);
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

    private static List<PicklistOption> getPicklistEntries(String objectName, String fieldName) {
        List<PicklistOption> options = new List<PicklistOption>();
        try {
            Schema.SObjectType sObj = Schema.getGlobalDescribe().get(objectName);
            Schema.DescribeFieldResult fieldResult = sObj.getDescribe().fields.getMap().get(fieldName).getDescribe();

            for (Schema.PicklistEntry entry : fieldResult.getPicklistValues()) {
                if (entry.isActive()) {
                    options.add(new PicklistOption(entry.getLabel(), entry.getValue()));
                }
            }
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching picklist values: ' + e.getMessage());
        }
        return options;
    }

    public class PicklistOption {
        @AuraEnabled public String label;
        @AuraEnabled public String value;

        public PicklistOption(String label, String value) {
            this.label = label;
            this.value = value;
        }
    }

    /*
     * Translates a picklist input (label or API name) to the field's API name.
     * The LWC sometimes sends the label (e.g. for District, Panchayath where
     * label and API name diverge); Salesforce DML rejects label as an invalid
     * picklist value, so we resolve here before assigning.
     */
    private static String resolvePicklistApiName(String objectName, String fieldName, String input) {
        if (String.isBlank(input)) return null;
        try {
            Schema.SObjectType sObj = Schema.getGlobalDescribe().get(objectName);
            Schema.DescribeFieldResult fieldResult = sObj.getDescribe().fields.getMap().get(fieldName).getDescribe();
            for (Schema.PicklistEntry entry : fieldResult.getPicklistValues()) {
                if (!entry.isActive()) continue;
                if (entry.getValue() == input) return entry.getValue();   // already API
                if (entry.getLabel() == input) return entry.getValue();   // label -> API
            }
        } catch (Exception e) {
            // fall through and return raw input
        }
        return input;
    }
}