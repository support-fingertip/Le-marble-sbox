trigger SalesPromotion_Trigger on Sales_Promotion__c (after insert) {
List<Approval.ProcessSubmitRequest> requests = new List<Approval.ProcessSubmitRequest>();
    for (Sales_Promotion__c sp : Trigger.new) {
        Approval.ProcessSubmitRequest req = new Approval.ProcessSubmitRequest();
        req.setObjectId(sp.Id);
        req.setSubmitterId(UserInfo.getUserId());
        req.setComments('Auto-submitted on record creation.');
        requests.add(req);
    }
    if (!requests.isEmpty()) {
        // allOrNone=false: log failures (e.g. user has no manager assigned)
        // without rolling back the insert
        Approval.process(requests, false);
    }
}