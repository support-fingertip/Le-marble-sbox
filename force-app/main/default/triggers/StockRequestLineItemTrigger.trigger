trigger StockRequestLineItemTrigger on Stock_Request_Line_Item__c (before insert) {
    if (Trigger.isBefore && Trigger.isInsert) {
        Id runningUserId = UserInfo.getUserId();
        for (Stock_Request_Line_Item__c sri : Trigger.new) {
            if (sri.Requested_By__c == null) {
                sri.Requested_By__c = runningUserId;
            }
        }
    }
}
