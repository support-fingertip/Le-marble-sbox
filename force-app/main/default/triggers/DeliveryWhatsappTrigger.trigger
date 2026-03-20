trigger DeliveryWhatsappTrigger on Delivery_Group__c (after insert, after update) {
    for (Delivery_Group__c delivery : Trigger.new) {
        // Get phone number from related Opportunity
        String phone = null;
        if (delivery.Sales_Confirmation__c != null) {
            // Query the related Opportunity's Phone
            Sales_Confirmation__c sc = [
                SELECT Opportunity__r.Phone__c
                FROM Sales_Confirmation__c
                WHERE Id = :delivery.Sales_Confirmation__c
                LIMIT 1
            ];
            if (sc.Opportunity__r != null) {
                phone = sc.Opportunity__r.Phone__c;
            }
        }
        // Get delivery date
        String deliveryDate = (delivery.Delivery_Date__c != null) ? String.valueOf(delivery.Delivery_Date__c) : null;

        // Format phone number
        if (phone != null) {
            String phoneNumber = phone.replaceAll('[^0-9]', '');
            if (!phoneNumber.startsWith('91') && phoneNumber.length() == 10) {
                phoneNumber = '91' + phoneNumber;
            }
            // Only send if both phone and date are present
            Boolean sendMsg = false;
            if (Trigger.isInsert && deliveryDate != null) {
                sendMsg = true;
            }
            if (Trigger.isUpdate && deliveryDate != null) {
                Delivery_Group__c oldDelivery = Trigger.oldMap.get(delivery.Id);
                if (oldDelivery.Delivery_Date__c != delivery.Delivery_Date__c) {
                    sendMsg = true;
                }
            }
            if (sendMsg) {
                WhatsAppMessageSender.sendDeliveryNotificationWithDate(phoneNumber, deliveryDate);
            }
        }
    }
}