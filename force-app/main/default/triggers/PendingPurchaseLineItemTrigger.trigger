trigger PendingPurchaseLineItemTrigger on Pending_Purchase_Line_Item__c (after insert, after update, after delete) {
    // Collect unique Pending_Purchase__c IDs from affected line items
    Set<Id> pendingPurchaseIds = new Set<Id>();
   
    // Handle insert and update events
    if (Trigger.isInsert || Trigger.isUpdate) {
        for (Pending_Purchase_Line_Item__c lineItem : Trigger.new) {
            if (lineItem.Pending_Purchase__c != null) {
                pendingPurchaseIds.add(lineItem.Pending_Purchase__c);
            }
        }
    }
   
    // Handle delete events
    if (Trigger.isDelete) {
        for (Pending_Purchase_Line_Item__c lineItem : Trigger.old) {
            if (lineItem.Pending_Purchase__c != null) {
                pendingPurchaseIds.add(lineItem.Pending_Purchase__c);
            }
        }
    }
   
    // Call the Apex class to create or update the PO in SAP
    if (!pendingPurchaseIds.isEmpty()) {
        try {
            for (Id purchaseId : pendingPurchaseIds) {
                CreatePurchaseOrderInSAP.createPO(purchaseId);
            }
        } catch (Exception e) {
            System.debug('Error in PendingPurchaseLineItemTrigger: ' + e.getMessage());
        }
    }
}