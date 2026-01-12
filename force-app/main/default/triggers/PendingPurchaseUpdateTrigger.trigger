trigger PendingPurchaseUpdateTrigger on Pending_Purchase__c (after update) {
    // Collect IDs of Pending_Purchase__c records to update in SAP
    Set<Id> pendingPurchaseIds = new Set<Id>();
   
    for (Integer i = 0; i < Trigger.new.size(); i++) {
        Pending_Purchase__c newPurchase = Trigger.new[i];
        Pending_Purchase__c oldPurchase = Trigger.old[i];
       
        // Check if relevant fields have changed
        if (newPurchase.Remarks__c != oldPurchase.Remarks__c ||
            newPurchase.Vendor__c != oldPurchase.Vendor__c ||
            newPurchase.Received_Date__c != oldPurchase.Received_Date__c ||
            (newPurchase.Status__c == 'Finance Manager Approved' && oldPurchase.Status__c != 'Finance Manager Approved')) {
            pendingPurchaseIds.add(newPurchase.Id);
        }
    }
   
    // Call the Apex class to update the PO in SAP
    if (!pendingPurchaseIds.isEmpty()) {
        try {
            for (Id purchaseId : pendingPurchaseIds) {
                CreatePurchaseOrderInSAP.createPO(purchaseId);
            }
        } catch (Exception e) {
            System.debug('Error in PendingPurchaseUpdateTrigger: ' + e.getMessage());
        }
    }
}