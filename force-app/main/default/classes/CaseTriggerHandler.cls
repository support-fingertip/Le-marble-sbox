public class CaseTriggerHandler {

    private static final String NOTIFICATION_TYPE_NAME = 'Case_Notification';

    public static void handleAfterInsert(List<Case> newCases) {
        notifyAssignees(newCases, null);

        // Collect all related Lead__c IDs
        Set<Id> leadIds = new Set<Id>();
        for (Case c : newCases) {
            if (c.Lead__c != null) {
                leadIds.add(c.Lead__c);
            }
        }

        // Query all related leads and their phone numbers
        Map<Id, String> leadIdToPhone = new Map<Id, String>();
        if (!leadIds.isEmpty()) {
            for (Customer__c lead : [
                SELECT Id, Phone__c
                FROM Customer__c
                WHERE Id IN :leadIds
            ]) {
                leadIdToPhone.put(lead.Id, lead.Phone__c);
            }
        }

        // Now process each case
        for (Case newCase : newCases) {
            System.debug('Case Status: ' + newCase.Status);
            String phone = (newCase.Lead__c != null) ? leadIdToPhone.get(newCase.Lead__c) : null;
            System.debug('Fetched Lead Phone: ' + phone);

            if (newCase.Status == 'New' && phone != null) {
                String phoneNumber = phone.replaceAll('[^0-9]', '');
                System.debug('Formatted Phone Number: ' + phoneNumber);
                System.debug('Phone Number Length: ' + phoneNumber.length());

                // Ensure phone number starts with country code
                if (!phoneNumber.startsWith('91') && phoneNumber.length() == 10) {
                    phoneNumber = '91' + phoneNumber;
                    System.debug('Added country code. New number: ' + phoneNumber);
                }

                try {
                    WhatsAppMessageSender.sendDeliveryNotification(phoneNumber);
                    System.debug('WhatsApp message sent successfully to: ' + phoneNumber);
                } catch (Exception e) {
                    System.debug('Error sending WhatsApp message: ' + e.getMessage());
                }
            } else if (phone == null) {
                System.debug('Phone number is null for Case: ' + newCase.Id);
            } else {
                System.debug('Case status is not New. Current status: ' + newCase.Status);
            }
        }
    }

    public static void handleAfterUpdate(List<Case> newCases, Map<Id, Case> oldMap) {
        List<Case> reassignedCases = new List<Case>();
        List<Case> statusChangedCases = new List<Case>();

        for (Case c : newCases) {
            Case oldCase = oldMap.get(c.Id);
            if (oldCase == null) continue;

            if (c.OwnerId != oldCase.OwnerId) {
                reassignedCases.add(c);
            }
            if (c.Status != oldCase.Status) {
                statusChangedCases.add(c);
            }
        }

        if (!reassignedCases.isEmpty()) {
            notifyAssignees(reassignedCases, oldMap);
        }
        if (!statusChangedCases.isEmpty()) {
            notifyStatusChange(statusChangedCases, oldMap);
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

    private static void notifyAssignees(List<Case> cases, Map<Id, Case> oldMap) {
        Id typeId = getNotificationTypeId();
        if (typeId == null) return;

        for (Case c : cases) {
            if (c.OwnerId == null || String.valueOf(c.OwnerId).startsWith('00G')) {
                // skip queues; only notify users
                continue;
            }
            String subject = String.isBlank(c.Subject) ? c.CaseNumber : c.Subject;
            String body = (oldMap == null)
                ? 'A new case has been assigned to you: ' + subject
                : 'Case has been reassigned to you: ' + subject;
            sendNotification(typeId, c.Id, 'Case Assigned', body, new Set<String>{ String.valueOf(c.OwnerId) });
        }
    }

    private static void notifyStatusChange(List<Case> cases, Map<Id, Case> oldMap) {
        Id typeId = getNotificationTypeId();
        if (typeId == null) return;

        for (Case c : cases) {
            if (c.OwnerId == null || String.valueOf(c.OwnerId).startsWith('00G')) {
                continue;
            }
            String subject = String.isBlank(c.Subject) ? c.CaseNumber : c.Subject;
            String body = 'Case status changed to ' + c.Status + ': ' + subject;
            sendNotification(typeId, c.Id, 'Case Status Updated', body, new Set<String>{ String.valueOf(c.OwnerId) });
        }
    }

    private static void sendNotification(Id typeId, Id targetId, String title, String body, Set<String> recipientIds) {
        if (recipientIds == null || recipientIds.isEmpty()) return;
        try {
            Messaging.CustomNotification notification = new Messaging.CustomNotification();
            notification.setNotificationTypeId(typeId);
            notification.setTargetId(targetId);
            notification.setTitle(title);
            notification.setBody(body);
            notification.send(recipientIds);
        } catch (Exception e) {
            System.debug('Error sending case notification: ' + e.getMessage());
        }
    }
}