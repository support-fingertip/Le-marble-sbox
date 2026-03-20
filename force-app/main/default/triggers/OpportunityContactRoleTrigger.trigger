trigger OpportunityContactRoleTrigger on OpportunityContactRole (after insert) {
    Set<Id> oppIds = new Set<Id>();
    Set<Id> conIds = new Set<Id>();
    
    for (OpportunityContactRole ocr : Trigger.new) {
        if (ocr.IsPrimary && ocr.OpportunityId != null) {
            oppIds.add(ocr.OpportunityId);
            conIds.add(ocr.ContactId);
        }
    }
    system.debug('oppIds>>>'+oppIds);
    if (oppIds.isEmpty()) return;
    
    Map<Id, Opportunity> oppMap = new Map<Id, Opportunity>([SELECT Id,createddate,account.name,Product_Category__c,Branch_Location__c, Contact_Person_Name__c,Contact_Number__c FROM Opportunity WHERE Id IN :oppIds ]);
    Map<Id, contact> conMap = new Map<Id, contact>([SELECT Id, name,phone FROM contact WHERE Id IN :conIds ]);
    
    List<Opportunity> oppsToUpdate = new List<Opportunity>();
    system.debug('oppMap>>>'+oppMap);
    for (OpportunityContactRole ocr : Trigger.new) {
        if (ocr.IsPrimary && oppMap.containsKey(ocr.OpportunityId)) {
            Opportunity opp = oppMap.get(ocr.OpportunityId);
            system.debug('Contact_Person_Name__c>>>'+opp.Contact_Person_Name__c);
            if (opp.Contact_Person_Name__c == null) {
                
                
                string dt;
                if(opp.createddate!=null){
                    dt=string.valueof(opp.createddate.date());     
                }
                else{
                    dt= string.valueof(system.today());
                }
                String accName = (conMap.get(ocr.ContactId).name != null) 
                    ? conMap.get(ocr.ContactId).name 
                    : opp.account.name;
                String newName = accName;
                
                if (opp.Product_Category__c != null && opp.Product_Category__c != '') {
                    newName += ' - ' + opp.Product_Category__c;
                }
                if (opp.Branch_Location__c != null && opp.Branch_Location__c != '') {
                    newName += ' - ' + opp.Branch_Location__c;
                }
                newName += ' - ' + dt;
                opp.Name = newName;
                
                
                oppsToUpdate.add(new Opportunity(
                    Id = opp.Id,
                    name=opp.Name,
                    Contact_Person_Name__c = conMap.get(ocr.ContactId).name,
                    Contact_Number__c = conMap.get(ocr.ContactId).phone
                ));
            }
        }
    }
    system.debug('oppsToUpdate>>>'+oppsToUpdate);
    if (!oppsToUpdate.isEmpty()) {
        update oppsToUpdate;
    }
}