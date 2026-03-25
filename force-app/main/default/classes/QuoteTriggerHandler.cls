public class QuoteTriggerHandler {
    
    // Recursion control for Coordinator name update
    private static Boolean isUpdatingCoordinator = false;

    // 🔹 Existing task logic (unchanged)
    public static void handleAfterSave(List<Quote> newList,Map<Id, Quote> oldMap,Boolean isInsert) {
        Set<Id> acceptedQuoteIds = new Set<Id>();
        Set<Id> ownerIds = new Set<Id>();
        Map<Id, User> ownerMap = new Map<Id, User>();
        
        if(isInsert){
            for(Quote q : newList){
                if(q.OwnerId != null){
                    ownerIds.add(q.OwnerId);
                }
            }
        }  
        if(!ownerIds.isEmpty()){
            ownerMap = new Map<Id, User>(
                [SELECT Id, ManagerId FROM User WHERE Id IN :ownerIds AND ManagerId != null]
                
            );
        }
        
        for (Quote q : newList) {
            if(isInsert && q.OwnerId != null){
                User owner = ownerMap.get(q.OwnerId);
                if(q.Quote_Category__c != null){
                    
                    sendPublicGroupNotification(
                        q.Quote_Category__c,
                        'Quote Creation Notification',
                        'A new quote "' + q.Name + '" has been created.',
                        q.Id
                    );
                    
                }
                
                
                
                
                Quote oldQ = oldMap != null ? oldMap.get(q.Id) : null;
                
                if (oldQ != null && ( (oldQ.Status != q.Status && (q.Status == 'Accepted' || q.Status == 'Denied') ) || (oldQ.Customer_Accepted__c != q.Customer_Accepted__c && (q.Customer_Accepted__c == true))|| (oldQ.Approval_Status__c != q.Approval_Status__c && q.Approval_Status__c == 'Revised')))
                {
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
    }
    
    
    public static void sendNotification(Set<String> userIds,String title, String body, Id quoteId) {
            if (userIds.isEmpty()) return;
            
            // Filter to only active users
            Set<String> activeUserIds = new Set<String>();
            for (User u : [SELECT Id FROM User WHERE Id IN :userIds AND IsActive = true]) {
                activeUserIds.add(String.valueOf(u.Id));
            }
            
            if (activeUserIds.isEmpty()) return;
            
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
            
            notification.send(activeUserIds);
        }
    
    public static void sendManagerNotification( Set<String> userIds, String title,String body, Id quoteId) {
            
            if (userIds.isEmpty()) return;
            
            // Filter to only active users
            Set<String> activeUserIds = new Set<String>();
            for (User u : [SELECT Id FROM User WHERE Id IN :userIds AND IsActive = true]) {
                activeUserIds.add(String.valueOf(u.Id));
            }
            
            if (activeUserIds.isEmpty()) return;
            
            CustomNotificationType notificationType = [ SELECT Id FROM CustomNotificationType WHERE DeveloperName = 'Quote_Created_Manager_Notification' LIMIT 1];
            
            Messaging.CustomNotification notification =
                new Messaging.CustomNotification();
            
            notification.setNotificationTypeId(notificationType.Id);
            notification.setTitle(title);
            notification.setBody(body);
            notification.setTargetId(quoteId);
            
            notification.send(activeUserIds);
        }
    
    
    public static void handleStatusBasedNotifications( List<Quote> newList, Map<Id, Quote> oldMap) {
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
    
    public static void handleCustomerAcceptedNotification(List<Quote> newList,Map<Id, Quote> oldMap) {
        // Prevent recursion when updating Coordinator_name__c
        if (isUpdatingCoordinator) return;
        
        Set<Id> oppIds = new Set<Id>();
        Map<Id, Quote> acceptedQuotes = new Map<Id, Quote>();
        Set<Id> ownIds = new Set<Id>();
        // 1. Detect status change
        for (Quote q : newList) {
            Quote oldQ = oldMap.get(q.Id);
            
            if (oldQ != null && oldQ.Customer_Accepted__c == false && q.Customer_Accepted__c == true && q.OpportunityId != null) {
                acceptedQuotes.put(q.Id, q);
                oppIds.add(q.OpportunityId);
                ownIds.add(q.OwnerId);
            }
        }
        
        if (acceptedQuotes.isEmpty()) return;
        Map<Id, User> users = new Map<Id, User>([SELECT Id, ManagerId FROM User WHERE Id IN :ownIds  AND ManagerId != null]);
        
        
        Set<Id> managerIds = new Set<Id>();
        for (User u : users.values()) {
            managerIds.add(u.ManagerId);
        }
        
        if (managerIds.isEmpty()) return;
        
        Map<Id, List<User>> managerToCoordinators = new Map<Id, List<User>>();
        
        for (User u : [ SELECT Id, Name, ManagerId FROM User WHERE ManagerId IN :managerIds AND Profile.Name = 'Coordinator' AND IsActive = true ]) {
            if (!managerToCoordinators.containsKey(u.ManagerId)) {
                managerToCoordinators.put(u.ManagerId, new List<User>());
            }
            managerToCoordinators.get(u.ManagerId).add(u);
        }
        
        // 2. Fetch Opportunity → Account
        Map<Id, Opportunity> oppMap = new Map<Id, Opportunity>([SELECT Id, Account.Name FROM Opportunity WHERE Id IN :oppIds ]);
        
        // 3. Notify internal user (Quote Owner) and save Coordinator name
        List<Quote> quotesToUpdate = new List<Quote>();
        
        for (Quote q : acceptedQuotes.values()) {
            
            User owner = users.get(q.OwnerId);
            if (owner == null) continue;
            
            List<User> coordinators = managerToCoordinators.get(owner.ManagerId);
            if (coordinators == null || coordinators.isEmpty()) continue;
            
            // Get the first Coordinator's name and save to Quote
            String coordinatorName = coordinators[0].Name;
            Quote quoteToUpdate = new Quote(Id = q.Id, Coordinator_name__c = coordinatorName);
            quotesToUpdate.add(quoteToUpdate);
            
            Opportunity opp = oppMap.get(q.OpportunityId);
            String customerName =(opp != null && opp.Account != null)? opp.Account.Name: 'Customer';
            
            // Add Quote Owner and all Coordinators as notification recipients
            Set<String> recipientIds = new Set<String>();
            recipientIds.add(String.valueOf(q.OwnerId)); // Quote Owner
            for (User u : coordinators) {
                recipientIds.add(u.Id); // Coordinators
            }
            
            sendNotification( recipientIds,'Quote Accepted',customerName + ' has accepted the quote', q.Id );
        }
        
        // Update Quotes with Coordinator name
        if (!quotesToUpdate.isEmpty()) {
            isUpdatingCoordinator = true;
            try {
                update quotesToUpdate;
            } finally {
                isUpdatingCoordinator = false;
            }
        }
    }
    
    public static void handleApprovalOwnerNotification(List<Quote> newList,Map<Id, Quote> oldMap) {
        
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
    public static void sendPublicGroupNotification(
        String quoteCategory,
        String title,
        String body,
        Id quoteId
    ) {
        if (String.isBlank(quoteCategory)) return;
        
        // Get Public Group
        Group publicGroup;
        try {
            publicGroup = [
                SELECT Id, Name
                FROM Group
                WHERE Type = 'Regular'
                AND Name = :quoteCategory
                LIMIT 1
            ];
        } catch (Exception e) {
            return;
        }
        
        // Get Group Members AND their Managers
        Set<String> userIds = new Set<String>();
        Set<Id> usersToProcess = new Set<Id>();
        
        // Step 1: Get direct members
        for (GroupMember gm : [
            SELECT UserOrGroupId
            FROM GroupMember
            WHERE GroupId = :publicGroup.Id
        ]) {
            if (String.valueOf(gm.UserOrGroupId).startsWith('005')) {
                usersToProcess.add(gm.UserOrGroupId);
                userIds.add(String.valueOf(gm.UserOrGroupId));
            }
        }
        
        // Step 2: Get managers recursively
        while (!usersToProcess.isEmpty()) {
            
            Set<Id> nextManagers = new Set<Id>();
            
            for (User u : [
                SELECT Id, ManagerId
                FROM User
                WHERE Id IN :usersToProcess
            ]) {
                
                if (u.ManagerId != null &&
                    !userIds.contains(String.valueOf(u.ManagerId))) {
                        
                        userIds.add(String.valueOf(u.ManagerId));
                        nextManagers.add(u.ManagerId);
                    }
            }
            
            usersToProcess = nextManagers;
        }
        
        
        if (userIds.isEmpty()) return;
        
        // Get Notification Type
        CustomNotificationType notificationType = [
            SELECT Id
            FROM CustomNotificationType
            WHERE DeveloperName = 'Quote_Created_Manager_Notification'
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
    public static void syncQuoteToOpportunity(List<Quote> newList, Map<Id, Quote> oldMap) {
        Map<Id, Id> oppToQuoteMap = new Map<Id, Id>();

        for (Quote q : newList) {
            Quote oldQ = oldMap.get(q.Id);
            if (q.Status == 'Accepted' && oldQ.Status != 'Accepted'
                && q.OpportunityId != null && !q.IsSyncing) {
                oppToQuoteMap.put(q.OpportunityId, q.Id);
            }
        }

        if (!oppToQuoteMap.isEmpty()) {
            System.enqueueJob(new SyncQuoteToOppQueueable(oppToQuoteMap));
        }
    }

}