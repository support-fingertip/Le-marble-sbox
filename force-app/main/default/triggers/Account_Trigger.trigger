trigger Account_Trigger on Account (before insert, before update,after insert, after update) {
    
    if (Trigger.isBefore && Trigger.isInsert) {
        AccountTriggerHandler.beforeInsert(Trigger.new);
    }

    if (Trigger.isBefore && Trigger.isUpdate) {
        AccountTriggerHandler.beforeUpdate(Trigger.new, Trigger.oldMap);
    }
    if(Trigger.isAfter && Trigger.isInsert){
        for (Account deal : Trigger.new) {
            //stopped creating in prod
            sapIntegration.createBusinessPartner(deal.Id);
        }
    }
      if(Trigger.isAfter && Trigger.isUpdate){
        for (Account deal : Trigger.new) {
              Account oldDeal = Trigger.oldMap.get(deal.id);
            Account newDeal = deal;

            if (
                oldDeal.Email__c != newDeal.Email__c ||
                oldDeal.Phone != newDeal.Phone ||
                oldDeal.Secondary_Phone__c != newDeal.Secondary_Phone__c ||
                oldDeal.BillingStreet != newDeal.BillingStreet ||
                oldDeal.BillingCity != newDeal.BillingCity ||
                oldDeal.BillingPostalCode != newDeal.BillingPostalCode ||
                oldDeal.BillingState != newDeal.BillingState ||
                oldDeal.BillingCountry != newDeal.BillingCountry ||
                oldDeal.BillingPostalCode != newDeal.BillingPostalCode ||
                
                oldDeal.GST_Type__c != newDeal.GST_Type__c ||
                oldDeal.GST_Number__c != newDeal.GST_Number__c ||
                
                oldDeal.Address_Line1__c != newDeal.Address_Line1__c ||
                oldDeal.Address_Line2__c != newDeal.Address_Line2__c ||
                oldDeal.Address_Line3__c != newDeal.Address_Line3__c ||
                
                oldDeal.corporation__c != newDeal.corporation__c ||
                oldDeal.State__c != newDeal.State__c ||
                oldDeal.State__c != newDeal.State__c ||
                oldDeal.country__c != newDeal.country__c ||
                 oldDeal.POC_Name__c != newDeal.POC_Name__c 
                

                
            ) {
                //stopped creating in prod
             System.enqueueJob(new SAPAccountSyncQueue(newDeal.Id));
            }
            
        }
    }
}