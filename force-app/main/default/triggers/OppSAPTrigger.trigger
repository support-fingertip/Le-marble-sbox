trigger OppSAPTrigger on Deals__c (after insert, after update) {

    // Create BP in SAP on insert
    if (Trigger.isInsert) {
        for (Deals__c deal : Trigger.new) {
            SAPBPCreation.createBusinessPartner(deal.Id);
        }
    }

    // Update BP in SAP on field changes
    if (Trigger.isUpdate) {
        for (Integer i = 0; i < Trigger.new.size(); i++) {
            Deals__c oldDeal = Trigger.old[i];
            Deals__c newDeal = Trigger.new[i];

            if (
                oldDeal.Email__c != newDeal.Email__c ||
                oldDeal.Phone__c != newDeal.Phone__c ||
                oldDeal.SecondaryPhone__c != newDeal.SecondaryPhone__c ||
                oldDeal.Company__c != newDeal.Company__c ||
                oldDeal.Remarks__c != newDeal.Remarks__c ||
                oldDeal.Address__Street__s != newDeal.Address__Street__s ||
                oldDeal.Address__City__s != newDeal.Address__City__s ||
                oldDeal.Address__PostalCode__s != newDeal.Address__PostalCode__s ||
                oldDeal.Address__StateCode__s != newDeal.Address__StateCode__s ||
                oldDeal.Address__CountryCode__s != newDeal.Address__CountryCode__s ||
                oldDeal.Billing_Address__Street__s != newDeal.Billing_Address__Street__s ||
                oldDeal.Billing_Address__City__s != newDeal.Billing_Address__City__s ||
                oldDeal.Billing_Address__PostalCode__s != newDeal.Billing_Address__PostalCode__s ||
                oldDeal.Billing_Address__StateCode__s != newDeal.Billing_Address__StateCode__s ||
                oldDeal.Billing_Address__CountryCode__s != newDeal.Billing_Address__CountryCode__s ||
                oldDeal.Billing_Address_Name__c != newDeal.Billing_Address_Name__c ||
                oldDeal.Billing_Address_Name_2__c != newDeal.Billing_Address_Name_2__c ||
                oldDeal.Billing_Address_Name_3__c != newDeal.Billing_Address_Name_3__c ||
                oldDeal.Shipping_Address_Name__c != newDeal.Shipping_Address_Name__c ||
                oldDeal.Shipping_Address_Name_2__c != newDeal.Shipping_Address_Name_2__c ||
                oldDeal.Shipping_Address_Name_3__c != newDeal.Shipping_Address_Name_3__c
            ) {
                SAPBPCreation.updateBusinessPartner(newDeal.Id);
            }
        }
    }
}