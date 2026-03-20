public class CustomerConversionController {
    @AuraEnabled
    public static Map<String, String> convertToOpportunity(Id customerId) {
        try {
            // Get the customer record with all necessary fields
            Customer__c customer = [
                SELECT Id, Status1__c, Company__c, CustomerEntryDate__c, Name, 
                       Email__c, LeadSource__c, NextFollowupDate__c, OwnerId, 
                       Phone__c, LeadPurpose__c, Remarks__c, SecondaryPhone__c,
                       Address__City__s, Address__CountryCode__s, Address__StateCode__s,
                       Address__Street__s, Address__PostalCode__s, Status__c, Type__c, BranchLocation__c, GST_No__c
                FROM Customer__c 
                WHERE Id = :customerId 
                LIMIT 1
            ];
            
            // Update the status to trigger the conversion
            customer.Status1__c = 'Converted';
            update customer;
            
            // Query for the newly created Deal
            Deals__c newDeal = [
                SELECT Id 
                FROM Deals__c 
                WHERE Customer__c = :customerId 
                ORDER BY CreatedDate DESC 
                LIMIT 1
            ];
            
            Map<String, String> result = new Map<String, String>();
            result.put('dealId', newDeal.Id);
            return result;
        } catch (Exception e) {
            // Log the error for debugging
            System.debug('Error in convertToOpportunity: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            throw new AuraHandledException('Error converting customer: ' + e.getMessage());
        }
    }
}