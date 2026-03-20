public class OpportunityTriggerHandler {

 /*   public static void preventDuplicateOppAccountName( List<Opportunity> newList,Map<Id, Opportunity> oldMap) {

        Set<Id> accountIds = new Set<Id>();
        Set<String> oppNames = new Set<String>();

        // Collect AccountIds + Names from trigger records
        for (Opportunity opp : newList) {
            if (opp.AccountId != null && String.isNotBlank(opp.Name)) {
                accountIds.add(opp.AccountId);
                oppNames.add(opp.Name.trim());
            }
        }

        if (accountIds.isEmpty() || oppNames.isEmpty()) return;

        // Query existing Opportunities with same AccountId + Name
        Map<String, Id> existingMap = new Map<String, Id>();

        for (Opportunity existingOpp : [
            SELECT Id, AccountId, Name
            FROM Opportunity
            WHERE AccountId IN :accountIds
            AND Name IN :oppNames
        ]) {
            String key = existingOpp.AccountId + '|' + existingOpp.Name.trim();
            existingMap.put(key, existingOpp.Id);
        }

        // Validate duplicates
        for (Opportunity opp : newList) {

            if (opp.AccountId == null || String.isBlank(opp.Name)) continue;

            // On update: skip check if AccountId + Name not changed
            if (Trigger.isUpdate && oldMap != null && oldMap.containsKey(opp.Id)) {
                Opportunity oldOpp = oldMap.get(opp.Id);

                Boolean isSame =
                    opp.AccountId == oldOpp.AccountId &&
                    String.valueOf(opp.Name).trim() == String.valueOf(oldOpp.Name).trim();

                if (isSame) continue;
            }

            String key = opp.AccountId + '|' + opp.Name.trim();

            if (existingMap.containsKey(key)) {
                // For update: allow same record
                if (Trigger.isInsert || (Trigger.isUpdate && existingMap.get(key) != opp.Id)) {
                    opp.Name.addError('Duplicate Opportunity not allowed for same Account and Name.');
                }
            }
        }
    }*/
    
    
}