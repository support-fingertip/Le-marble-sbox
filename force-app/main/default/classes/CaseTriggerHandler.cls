public class CaseTriggerHandler {
    public static void handleAfterInsert(List<Case> newCases) {
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
}