trigger Opportunity_Trigger on Opportunity (before insert, before update) {
    if (Trigger.isBefore) {
  //      OpportunityTriggerHandler.preventDuplicateOppAccountName(Trigger.new, Trigger.oldMap);
 
    }
    
    // VALIDATE PIN CODE AND STATE ARE MANDATORY ON INSERT
     
    if(trigger.isinsert){   
        Set<Id> accountId = new Set<Id>();
        for (Opportunity opp : Trigger.new) {

            if (opp.Pin_Code__c == null && !opp.Same_as_Account_Ship_Address__c) {
                opp.addError('Pin Code is required.');
            }
            if (String.isBlank(opp.State__c) && !opp.Same_as_Account_Ship_Address__c) {
                opp.addError('State is required.');
            }
            
            if (opp.AccountId != null) {
                accountId.add(opp.AccountId);
            }
        }
        Map<Id, Account> accMap = new Map<Id, Account>([
            SELECT Id, Name, GST_Number__c,
                Address_Line1__c, Address_Line2__c, Address_Line3__c, Corporation__c, Country__c, District__c, Municipality__c, Panchayath__c, State__c, Village__c, pin_code__c
            FROM Account WHERE Id IN :accountId
        ]);

        for (Opportunity opp : Trigger.new) {
            // Copy address fields if checkbox is checked
            if (opp.Same_as_Account_Ship_Address__c && opp.AccountId != null && accMap.containsKey(opp.AccountId)) {
                Account acc = accMap.get(opp.AccountId);
                opp.AddressLine1__c = acc.Address_Line1__c;
                opp.AddressLine2__c = acc.Address_Line2__c;
                opp.AddressLine3__c = acc.Address_Line3__c;
                opp.Corporation__c = acc.Corporation__c;
                opp.Country__c = acc.Country__c;
                opp.District__c = acc.District__c;
                opp.Municipality__c = acc.Municipality__c;
                opp.Panchayath__c = acc.Panchayath__c;
                opp.State__c = acc.State__c;
                opp.Village__c = acc.Village__c;
                opp.pin_code__c = acc.pin_code__c;
            }
            // ...existing code for naming and GST...
            string dt;
            if(opp.createddate!=null){
                dt=string.valueof(opp.createddate.date());     
            }
            else{
                dt= string.valueof(system.today());
            }
            String accName = (opp.AccountId != null && accMap.containsKey(opp.AccountId)) 
                ? accMap.get(opp.AccountId).Name 
                : '';
            String newName = accName;
            
            if (opp.Product_Category__c != null && opp.Product_Category__c != '') {
                newName += ' - ' + opp.Product_Category__c;
            }
            if (opp.Branch_Location__c != null && opp.Branch_Location__c != '') {
                newName += ' - ' + opp.Branch_Location__c;
            }
            newName += ' - ' + dt;
            opp.Name = newName;
            // Map GST Number from Account to Opportunity on insert
            if (opp.AccountId != null && accMap.containsKey(opp.AccountId)) {
                opp.GST_Number__c = accMap.get(opp.AccountId).GST_Number__c;
            }
        }
    }
    
    Set<Id> accountIds = new Set<Id>();
    for (Opportunity opp : Trigger.new) {
        if (opp.AccountId != null) {
            accountIds.add(opp.AccountId);
        }
    }
    
    // Map GST Number from Account to Opportunity on update (when AccountId changes)
    if (Trigger.isUpdate) {
        Map<Id, Account> accountGstMap = new Map<Id, Account>([SELECT Id, GST_Number__c FROM Account WHERE Id IN :accountIds]);
        for (Opportunity opp : Trigger.new) {
            Opportunity oldOpp = Trigger.oldMap.get(opp.Id);
            // Update GST if AccountId changed
            if (opp.AccountId != null && opp.AccountId != oldOpp.AccountId) {
                if (accountGstMap.containsKey(opp.AccountId)) {
                    opp.GST_Number__c = accountGstMap.get(opp.AccountId).GST_Number__c;
                }
            }
        }
    }
    
    // Collect all existing Opportunity names for the related Accounts
    Set<String> existingOppNames = new Set<String>();
    
    for (Opportunity opp : [SELECT Id, AccountId, Name FROM Opportunity WHERE AccountId IN :accountIds]) { 
        existingOppNames.add(opp.Name);
    }
    
    // Auto-version: If name exists, append version number (v2, v3, etc.)
    for (Opportunity opp : Trigger.new) {
        
        String baseName = opp.Name;
        String finalName = baseName;
        Integer version = 1;
        
        // Check if name exists and increment version until unique
        while (existingOppNames.contains(finalName)) {
            // Skip if updating the same record with same name
            if (Trigger.isUpdate && existingOppNames.contains(finalName)) {
                Opportunity oldOpp = Trigger.oldMap.get(opp.Id);
                if (oldOpp != null && oldOpp.Name == finalName) {
                    break;
                }
            }
            version++;
            finalName = baseName + ' v' + version;
        }
        
        opp.Name = finalName;
        existingOppNames.add(finalName); // Track for batch inserts
    }
    
}