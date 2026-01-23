public class QuoteTriggerHandler {

/*    public static void beforeInsert(List<Quote> newQuotes) {
        populateEmailFromPrimaryContact(newQuotes);
    }

   private static void populateEmailFromPrimaryContact(List<Quote> newQuotes) {

    Set<Id> oppIds = new Set<Id>();

    for (Quote q : newQuotes) {
        if (q.OpportunityId != null && q.Email == null) {
            oppIds.add(q.OpportunityId);
        }
    }

    if (oppIds.isEmpty()) return;

    // Get Primary Contact Email per Opportunity
    Map<Id, String> oppToEmail = new Map<Id, String>();

    for (OpportunityContactRole ocr : [
        SELECT OpportunityId, Contact.Email
        FROM OpportunityContactRole
        WHERE IsPrimary = true
        AND OpportunityId IN :oppIds
        AND Contact.Email != null
    ]) {
        oppToEmail.put(ocr.OpportunityId, ocr.Contact.Email);
    }

    // Populate Quote Email
    for (Quote q : newQuotes) {
        if (oppToEmail.containsKey(q.OpportunityId)) {
            q.Email = oppToEmail.get(q.OpportunityId);
        }
    }
}*/

    // 🔹 Existing task logic (unchanged)
    public static void handleAfterSave(
        List<Quote> newList,
        Map<Id, Quote> oldMap,
        Boolean isInsert
    ) {
        Set<Id> acceptedQuoteIds = new Set<Id>();

        for (Quote q : newList) {
            Quote oldQ = oldMap != null ? oldMap.get(q.Id) : null;

            if (oldQ != null &&
                oldQ.Status != q.Status &&
                (q.Status == 'Accepted' || q.Status == 'Denied')) {

                acceptedQuoteIds.add(q.Id);
            }
        }

        if (acceptedQuoteIds.isEmpty()) return;

        List<Task> tasksToClose = new List<Task>();

        for (Task t : [
            SELECT Id, WhatId
            FROM Task
            WHERE WhatId IN :acceptedQuoteIds
            AND Subject = 'Customer acceptance Follow up'
            AND Status != 'Completed'
        ]) {
            t.Status = 'Completed';
            tasksToClose.add(t);
        }

        if (!tasksToClose.isEmpty()) {
            update tasksToClose;
        }
    }

 
    public static void sendNotification(
        Set<String> userIds,
        String title,
        String body,
        Id quoteId
    ) {
        if (userIds.isEmpty()) return;

        CustomNotificationType notificationType = [
            SELECT Id
            FROM CustomNotificationType
            WHERE DeveloperName = 'Quote_Accepted'
            LIMIT 1
        ];

        Messaging.CustomNotification notification =
            new Messaging.CustomNotification();

        notification.setNotificationTypeId(notificationType.Id);
        notification.setTitle(title);
        notification.setBody(body);
        notification.setTargetId(quoteId);

        notification.send(userIds);
    }

public static void handleStatusBasedNotifications(
    List<Quote> newList,
    Map<Id, Quote> oldMap
) {
    // 1. Find Quotes where approval status changed
    Set<Id> quoteIds = new Set<Id>();

    for (Quote q : newList) {
        Quote oldQ = oldMap.get(q.Id);
        if (oldQ != null &&
            oldQ.Approval_Status__c != q.Approval_Status__c) {
            quoteIds.add(q.Id);
        }
    }

    if (quoteIds.isEmpty()) return;

    // 2. Get latest approval step per Quote
    Map<Id, ProcessInstanceStep> latestStepByQuote = new Map<Id, ProcessInstanceStep>();
    Set<Id> processNodeIds = new Set<Id>();

    for (ProcessInstanceStep step : [
        SELECT
            ProcessInstance.TargetObjectId,
            StepStatus,
            StepNodeId
        FROM ProcessInstanceStep
        WHERE ProcessInstance.TargetObjectId IN :quoteIds
        ORDER BY CreatedDate DESC
    ]) {
        Id qId = step.ProcessInstance.TargetObjectId;
        if (!latestStepByQuote.containsKey(qId)) {
            latestStepByQuote.put(qId, step);
            if (step.StepNodeId != null) {
                processNodeIds.add(step.StepNodeId);
            }
        }
    }

    if (processNodeIds.isEmpty()) return;

    // 3. Query ProcessNode to get step names (Checker / Manager)
    Map<Id, ProcessNode> processNodeMap = new Map<Id, ProcessNode>([
        SELECT Id, Name
        FROM ProcessNode
        WHERE Id IN :processNodeIds
    ]);

    // 4. Send notifications
    for (Quote q : newList) {

        if (!latestStepByQuote.containsKey(q.Id)) continue;

        ProcessInstanceStep step = latestStepByQuote.get(q.Id);
        ProcessNode node = processNodeMap.get(step.StepNodeId);

        if (node == null || node.Name == null) continue;

        String title;
        String body;

        // Approved
        if (step.StepStatus == 'Approved') {

            if (node.Name.toLowerCase().contains('checker')) {
                title = 'Checker Approved';
                body  = 'Checker has approved your quote';
            }
            else if (node.Name.toLowerCase().contains('manager')) {
                title = 'Manager Approved';
                body  = 'Manager has approved your quote';
            }

        }
        // Rejected
        else if (step.StepStatus == 'Rejected') {

            if (node.Name.toLowerCase().contains('checker')) {
                title = 'Checker Rejected';
                body  = 'Checker has rejected your quote';
            }
            else if (node.Name.toLowerCase().contains('manager')) {
                title = 'Manager Rejected';
                body  = 'Manager has rejected your quote';
            }
        }

        if (String.isBlank(title) || String.isBlank(body)) continue;

        Set<String> userIds = new Set<String>();
        userIds.add(String.valueOf(q.OwnerId));

        sendNotification(
            userIds,
            title,
            body,
            q.Id
        );
    }
}
    
    public static void handleCustomerAcceptedNotification(
    List<Quote> newList,
    Map<Id, Quote> oldMap
) {
    Set<Id> oppIds = new Set<Id>();
    Map<Id, Quote> acceptedQuotes = new Map<Id, Quote>();

    // 1. Detect status change
    for (Quote q : newList) {
        Quote oldQ = oldMap.get(q.Id);

        if (oldQ != null &&
            oldQ.Status != 'Accepted' &&
            q.Status == 'Accepted' &&
            q.OpportunityId != null) {

            acceptedQuotes.put(q.Id, q);
            oppIds.add(q.OpportunityId);
        }
    }

    if (acceptedQuotes.isEmpty()) return;

    // 2. Fetch Opportunity → Account
    Map<Id, Opportunity> oppMap = new Map<Id, Opportunity>([
        SELECT Id, Account.Name
        FROM Opportunity
        WHERE Id IN :oppIds
    ]);

    // 3. Notify internal user (Quote Owner)
    for (Quote q : acceptedQuotes.values()) {

        Opportunity opp = oppMap.get(q.OpportunityId);
        String customerName =
            (opp != null && opp.Account != null)
            ? opp.Account.Name
            : 'Customer';

        sendNotification(
            new Set<String>{ String.valueOf(q.OwnerId) },
            'Quote Accepted',
            customerName + ' has accepted the quote',
            q.Id
        );
    }
}

public static void handleApprovalOwnerNotification(
    List<Quote> newList,
    Map<Id, Quote> oldMap
) {
   
    Set<Id> quoteIds = new Set<Id>();

    for (Quote q : newList) {
        Quote oldQ = oldMap.get(q.Id);

        if (oldQ != null &&
            oldQ.Approval_Status__c != q.Approval_Status__c) {
            quoteIds.add(q.Id);
        }
    }

    if (quoteIds.isEmpty()) return;

    // 🔹 Ge
    Map<Id, ProcessInstance> latestProcessByQuote =
        new Map<Id, ProcessInstance>();

    for (ProcessInstance pi : [
        SELECT Id, TargetObjectId, Status
        FROM ProcessInstance
        WHERE TargetObjectId IN :quoteIds
        ORDER BY CreatedDate DESC
    ]) {
        if (!latestProcessByQuote.containsKey(pi.TargetObjectId)) {
            latestProcessByQuote.put(pi.TargetObjectId, pi);
        }
    }

    // 🔹 Send notification ONLY on FINAL approval
    for (Quote q : newList) {

        ProcessInstance pi = latestProcessByQuote.get(q.Id);
        if (pi == null) continue;

        if (pi.Status == 'Approved') {

            Set<String> userIds = new Set<String>{
                String.valueOf(q.OwnerId)
            };

            sendNotification(
                userIds,
                'Quote Approved',
                'Your quote has been approved',
                q.Id
            );
        }
    }
}
}