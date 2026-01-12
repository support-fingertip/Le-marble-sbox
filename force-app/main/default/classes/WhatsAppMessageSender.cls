public class WhatsAppMessageSender {
    @future(callout=true)
    public static void sendDeliveryNotification(String phoneNumber) {
        System.debug('Starting WhatsApp message send to: ' + phoneNumber);
        
        // Build the URL
        String baseUrl = 'https://panel.sangamamonline.in/pushwhatsapp.php';
        String username = 'mgg';
        String apiPassword = 'e62f7eppsshq15osz';
        String sender = '917994931996';
        String priority = '21';
        String name = 'complaints';

        String finalUrl = baseUrl +
            '?username=' + EncodingUtil.urlEncode(username, 'UTF-8') +
            '&api_password=' + EncodingUtil.urlEncode(apiPassword, 'UTF-8') +
            '&sender=' + EncodingUtil.urlEncode(sender, 'UTF-8') +
            '&priority=' + priority +
            '&name=' + EncodingUtil.urlEncode(name, 'UTF-8') +
            '&to=' + EncodingUtil.urlEncode(phoneNumber, 'UTF-8');
            
        System.debug('Final URL: ' + finalUrl);

        Http http = new Http();
        HttpRequest request = new HttpRequest();
        request.setEndpoint(finalUrl);
        request.setMethod('GET');
        request.setTimeout(120000); // Set timeout to 2 minutes

        try {
            System.debug('Sending HTTP request...');
            HttpResponse response = http.send(request);
            System.debug('Response Status Code: ' + response.getStatusCode());
            System.debug('WhatsApp response: ' + response.getBody());
            
            if(response.getStatusCode() != 200) {
                throw new WhatsAppException('HTTP Error: ' + response.getStatusCode() + ' - ' + response.getBody());
            }
        } catch (Exception e) {
            System.debug('WhatsApp callout error: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            throw new WhatsAppException('Failed to send WhatsApp message: ' + e.getMessage());
        }
    }
    
    @future(callout=true)
    public static void sendThanksMessage(String phoneNumber) {
        String baseUrl = 'https://panel.sangamamonline.in/pushwhatsapp.php';
        String username = 'mgg';
        String apiPassword = 'e62f7eppsshq15osz';
        String sender = '917994931996';
        String priority = '21';
        String name = 'thanks';

        String finalUrl = baseUrl +
            '?username=' + EncodingUtil.urlEncode(username, 'UTF-8') +
            '&api_password=' + EncodingUtil.urlEncode(apiPassword, 'UTF-8') +
            '&sender=' + EncodingUtil.urlEncode(sender, 'UTF-8') +
            '&priority=' + priority +
            '&name=' + EncodingUtil.urlEncode(name, 'UTF-8') +
            '&to=' + EncodingUtil.urlEncode(phoneNumber, 'UTF-8');

        Http http = new Http();
        HttpRequest request = new HttpRequest();
        request.setEndpoint(finalUrl);
        request.setMethod('GET');
        request.setTimeout(120000);

        HttpResponse response = http.send(request);
        System.debug('Response: ' + response.getBody());
    }
    
    @future(callout=true)
    public static void sendDeliveryNotificationWithDate(String phoneNumber, String deliveryDate) {
        String baseUrl = 'https://panel.sangamamonline.in/pushwhatsapp.php';
        String username = 'mgg';
        String apiPassword = 'e62f7eppsshq15osz';
        String sender = '917994931996';
        String priority = '21';
        String name = 'deliverymsg1';

        String finalUrl = baseUrl +
            '?username=' + EncodingUtil.urlEncode(username, 'UTF-8') +
            '&api_password=' + EncodingUtil.urlEncode(apiPassword, 'UTF-8') +
            '&sender=' + EncodingUtil.urlEncode(sender, 'UTF-8') +
            '&priority=' + priority +
            '&name=' + EncodingUtil.urlEncode(name, 'UTF-8') +
            '&to=' + EncodingUtil.urlEncode(phoneNumber, 'UTF-8') +
            '&value1=' + EncodingUtil.urlEncode(deliveryDate, 'UTF-8');

        Http http = new Http();
        HttpRequest request = new HttpRequest();
        request.setEndpoint(finalUrl);
        request.setMethod('GET');
        request.setTimeout(120000);

        HttpResponse response = http.send(request);
        System.debug('Response: ' + response.getBody());
    }
    
    public class WhatsAppException extends Exception {}
}