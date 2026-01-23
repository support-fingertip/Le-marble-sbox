trigger Account_Trigger on Account (before insert, before update,after insert, after update) {
    
    if (Trigger.isBefore && Trigger.isInsert) {
        AccountTriggerHandler.beforeInsert(Trigger.new);
    }

    if (Trigger.isBefore && Trigger.isUpdate) {
        AccountTriggerHandler.beforeUpdate(Trigger.new, Trigger.oldMap);
    }
    if(Trigger.isAfter && Trigger.isInsert){
        for (Account deal : Trigger.new) {
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
                oldDeal.ShippingStreet != newDeal.ShippingStreet ||
                oldDeal.ShippingCity != newDeal.BillingCity ||
                oldDeal.ShippingPostalCode != newDeal.BillingPostalCode ||
                oldDeal.ShippingState != newDeal.ShippingState ||
                oldDeal.ShippingCountry != newDeal.ShippingCountry ||
                oldDeal.Address_Line1__c != newDeal.Address_Line1__c ||
                oldDeal.Address_Line2__c != newDeal.Address_Line2__c ||
                oldDeal.Address_Line3__c != newDeal.Address_Line3__c 
            ) {
             System.enqueueJob(new SAPAccountSyncQueue(newDeal.Id));
        //             sapIntegration.updateBusinessPartner(newDeal.Id);
            }
            
       //    sapIntegration.createBusinessPartner(deal.Id);
        }
    }
}