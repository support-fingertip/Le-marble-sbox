public with sharing class StockRequestTriggerHandler {

    private static final String NOTIFICATION_TYPE_NAME = 'Stock_Request_Notification';
    private static final String PURCHASE_MANAGER_PROFILE = 'Purchase Manager';

    public static void handleAfterInsert(List<Stock_Request__c> newRequests) {
        if (newRequests == null || newRequests.isEmpty()) {
            return;
        }

        Id typeId = getNotificationTypeId();
        if (typeId == null) {
            System.debug('Stock_Request_Notification CustomNotificationType not found; skipping notify.');
            return;
        }

        Set<String> recipientIds = getPurchaseManagerUserIds();
        if (recipientIds.isEmpty()) {
            System.debug('No active users with profile ' + PURCHASE_MANAGER_PROFILE + '; skipping notify.');
            return;
        }

        for (Stock_Request__c req : newRequests) {
            String body = 'A new Stock Request has been created'
                + (String.isBlank(req.Product_Category__c) ? '' : ' for ' + req.Product_Category__c)
                + '.';
            sendNotification(typeId, req.Id, 'New Stock Request', body, recipientIds);
        }
    }

    private static Id getNotificationTypeId() {
        List<CustomNotificationType> types = [
            SELECT Id FROM CustomNotificationType
            WHERE DeveloperName = :NOTIFICATION_TYPE_NAME
            LIMIT 1
        ];
        return types.isEmpty() ? null : types[0].Id;
    }

    private static Set<String> getPurchaseManagerUserIds() {
        Set<String> ids = new Set<String>();
        for (User u : [
            SELECT Id
            FROM User
            WHERE IsActive = true
              AND Profile.Name = :PURCHASE_MANAGER_PROFILE
        ]) {
            ids.add(String.valueOf(u.Id));
        }
        return ids;
    }

    private static void sendNotification(Id typeId, Id targetId, String title, String body, Set<String> recipientIds) {
        try {
            Messaging.CustomNotification notification = new Messaging.CustomNotification();
            notification.setNotificationTypeId(typeId);
            notification.setTargetId(targetId);
            notification.setTitle(title);
            notification.setBody(body);
            notification.send(recipientIds);
        } catch (Exception e) {
            System.debug('Error sending Stock Request notification: ' + e.getMessage());
        }
    }
}