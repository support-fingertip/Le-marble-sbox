trigger CustomerWhatsappTrigger on Customer__c (after insert) {
    for (Customer__c cust : Trigger.new) {
        if (cust.Phone__c != null) {
            String phoneNumber = cust.Phone__c.replaceAll('[^0-9]', '');
            if (!phoneNumber.startsWith('91') && phoneNumber.length() == 10) {
                phoneNumber = '91' + phoneNumber;
            }
            // Use 'thanks' as the name parameter
            WhatsAppMessageSender.sendThanksMessage(phoneNumber);
        }
    }
}