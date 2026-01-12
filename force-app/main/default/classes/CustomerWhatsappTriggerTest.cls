/**
 * @description       : 
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : 
 * @last modified on  : 06-12-2025
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
**/
@isTest
public with sharing class CustomerWhatsappTriggerTest {
    @isTest
    static void testCustomerTriggerWithValidPhone() {
        // Set mock callout class
        Test.setMock(HttpCalloutMock.class, new WhatsAppCalloutMock());
        
        // Create test data
        Customer__c customer = new Customer__c(
            Name = 'Test Customer',
            Phone__c = '9876543210' // 10-digit number without country code
        );
        
        // Start the test
        Test.startTest();
        insert customer;
        Test.stopTest();
        
        // The verification is handled by the mock class
        // The trigger should have called WhatsAppMessageSender.sendThanksMessage
        // which internally uses HTTP callout that we mocked
    }
    
    @isTest
    static void testCustomerTriggerWithPhoneHavingCountryCode() {
        // Set mock callout class
        Test.setMock(HttpCalloutMock.class, new WhatsAppCalloutMock());
        
        // Create test data with phone number that already has country code
        Customer__c customer = new Customer__c(
            Name = 'Test Customer',
            Phone__c = '919876543210'
        );
        
        // Start the test
        Test.startTest();
        insert customer;
        Test.stopTest();
        
        // The verification is handled by the mock class
        // The trigger should have called WhatsAppMessageSender.sendThanksMessage
        // which internally uses HTTP callout that we mocked
    }
    
    @isTest
    static void testCustomerTriggerWithNullPhone() {
        // Set mock callout class
        Test.setMock(HttpCalloutMock.class, new WhatsAppCalloutMock());
        
        // Create test data with null phone
        Customer__c customer = new Customer__c(
            Name = 'Test Customer',
            Phone__c = null
        );
        
        // Start the test
        Test.startTest();
        insert customer;
        Test.stopTest();
        
        // No verification needed as no callout should occur
    }
    
    @isTest
    static void testWhatsAppMessageSenderDeliveryNotification() {
        // Set mock callout class
        Test.setMock(HttpCalloutMock.class, new WhatsAppCalloutMock());
        
        String testPhone = '919876543210';
        
        // Start the test
        Test.startTest();
        WhatsAppMessageSender.sendDeliveryNotification(testPhone);
        Test.stopTest();
        
        // Verification is handled by the mock class
    }
    
    @isTest
    static void testWhatsAppMessageSenderDeliveryNotificationWithDate() {
        // Set mock callout class
        Test.setMock(HttpCalloutMock.class, new WhatsAppCalloutMock());
        
        String testPhone = '919876543210';
        String testDate = '2024-06-12';
        
        // Start the test
        Test.startTest();
        WhatsAppMessageSender.sendDeliveryNotificationWithDate(testPhone, testDate);
        Test.stopTest();
        
        // Verification is handled by the mock class
    }
    
    // Mock HTTP Callout class that verifies the request parameters
    private class WhatsAppCalloutMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            // Verify that the request URL contains expected parameters
            String url = req.getEndpoint();
            System.assert(url.contains('username=mgg'), 'Username parameter is incorrect');
            System.assert(url.contains('api_password='), 'API password parameter is missing');
            System.assert(url.contains('sender=917994931996'), 'Sender parameter is incorrect');
            System.assert(url.contains('priority=21'), 'Priority parameter is incorrect');
            
            // Create and return a mock response
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"status":"success"}');
            res.setStatusCode(200);
            return res;
        }
    }
}