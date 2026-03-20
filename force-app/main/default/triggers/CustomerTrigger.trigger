trigger CustomerTrigger on Customer__c (after update) {
    // List to store all new deals to be created
    List<Deals__c> dealsToInsert = new List<Deals__c>();
    // Map to store Customer Id to new Deal Id for cart updates
    Map<Id, Id> customerToDealMap = new Map<Id, Id>();
    
    try {
        // Process all records in the trigger
        for (Customer__c customer : Trigger.new) {
            // Check if the status is converted
            if (customer.Status1__c == 'Converted') {
                // Create a new Deal record
                Deals__c newDeal = new Deals__c();
                newDeal.Company__c = customer.Company__c;
                newDeal.CustomerEntryDate__c = customer.CustomerEntryDate__c;
                newDeal.Name = customer.Name;
                newDeal.Email__c = customer.Email__c;
                newDeal.LeadSource__c = customer.LeadSource__c;
                newDeal.NextFollowupDate__c = customer.NextFollowupDate__c;

                newDeal.Phone__c = customer.Phone__c;
                newDeal.Purpose__c = customer.LeadPurpose__c;
                newDeal.Remarks__c = customer.Remarks__c;
                newDeal.SecondaryPhone__c = customer.SecondaryPhone__c;
                
                // Copy address fields individually
                newDeal.Address__City__s = customer.Address__City__s;
                newDeal.Address__CountryCode__s = customer.Address__CountryCode__s;
                newDeal.Address__StateCode__s = customer.Address__StateCode__s;
                newDeal.Address__Street__s = customer.Address__Street__s;
                newDeal.Address__PostalCode__s = customer.Address__PostalCode__s;
                newDeal.Billing_Address__City__s = customer.Billing_Address__City__s;
                newDeal.Billing_Address__CountryCode__s = customer.Billing_Address__CountryCode__s;
                newDeal.Billing_Address__StateCode__s = customer.Billing_Address__StateCode__s;
                newDeal.Billing_Address__Street__s = customer.Billing_Address__Street__s;
                newDeal.Billing_Address__PostalCode__s = customer.Billing_Address__PostalCode__s;
                
                newDeal.Stage__c = customer.Status__c;
                newDeal.Type__c = customer.Type__c;
                newDeal.Customer__c = customer.Id; // Link to; customer
                newDeal.BranchLocation__c = customer.BranchLocation__c;
                newDeal.Opp_BE_Name__c = customer.Name;
                newDeal.GST_No__c = customer.GST_No__c;
                
                dealsToInsert.add(newDeal);
            }
        }
        
        // Insert all new deals
        if (!dealsToInsert.isEmpty()) {
            insert dealsToInsert;
            
            // Create map of Customer Id to new Deal Id
            for (Deals__c deal : dealsToInsert) {
                customerToDealMap.put(deal.Customer__c, deal.Id);
            }
            
            // Query all carts for the converted customers
            List<Cart__c> cartsToUpdate = [
                SELECT Id, Deals__c, Customer__c 
                FROM Cart__c 
                WHERE Customer__c IN :customerToDealMap.keySet()
            ];
            
            // Update carts with new Deal IDs
            if (!cartsToUpdate.isEmpty()) {
                for (Cart__c cart : cartsToUpdate) {
                    cart.Deals__c = customerToDealMap.get(cart.Customer__c);
                }
                update cartsToUpdate;
            }
        }
    } catch (Exception e) {
        // Log the error
        System.debug('Error in CustomerTrigger: ' + e.getMessage());
        System.debug('Stack trace: ' + e.getStackTraceString());
        
        // Throw a custom exception to be handled by the calling code
        throw new AuraHandledException('Error converting customer to opportunity: ' + e.getMessage());
    }
}