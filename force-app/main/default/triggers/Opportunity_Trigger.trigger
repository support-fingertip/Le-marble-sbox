trigger Opportunity_Trigger on Opportunity (before insert,before update) {

    Set<Id> accountIds = new Set<Id>();
    for (Opportunity opp : Trigger.new) {
        if (opp.AccountId != null) {
            accountIds.add(opp.AccountId);
        }
    }
      Map<Id, Account> accMap = new Map<Id, Account>(
        [SELECT Id, Name FROM Account WHERE Id IN :accountIds]
    );
    
    for (Opportunity opp : Trigger.new) {
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
        
    }
}