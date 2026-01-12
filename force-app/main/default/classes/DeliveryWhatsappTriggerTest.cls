@isTest
public with sharing class DeliveryWhatsappTriggerTest {
    
    @TestSetup
    static void setupTestData() {
        // Set mock before any operations
        Test.setMock(HttpCalloutMock.class, new WhatsAppCalloutMock());
        
        // Create test Customer
        Customer__c customer = new Customer__c(
            Name = 'Test Project - Vishwa',
            LeadSource__c = 'Web',
            Email__c = 'testcustomer@example.com',
            Status__c = 'Tamil Nadu',
            Phone__c = '9876543210',
            CustomerEntryDate__c = Date.newInstance(2025, 6, 11)
        );
        insert customer;

        // Create test Deal
        Deals__c deal = new Deals__c(
            Name = 'Test Deal',
            Customer__c = customer.Id,
            Email__c = 'test@example.com',
            Phone__c = '9999999999',
            SecondaryPhone__c = '8888888888',
            Company__c = 'Test Company',
            Remarks__c = 'Important customer',
            Address__Street__s = '123 Road',
            Address__City__s = 'Chennai',
            Address__PostalCode__s = '600001',
            Address__StateCode__s = 'TN',
            Address__CountryCode__s = 'IN'
        );
        insert deal;

        // Create Sales Confirmation
        Sales_Confirmation__c sc = new Sales_Confirmation__c(
            Opportunity__c = deal.Id
        );
        insert sc;
    }

    @isTest
    static void testDeliveryInsertWithValidPhone() {
        Test.setMock(HttpCalloutMock.class, new WhatsAppCalloutMock());
        
        Test.startTest();
        Sales_Confirmation__c sc = [SELECT Id, Opportunity__c FROM Sales_Confirmation__c LIMIT 1];
        Deals__c deal = [SELECT Id FROM Deals__c WHERE Id = :sc.Opportunity__c];
        deal.Phone__c = '9876543210';
        update deal;

        Delivery_Group__c delivery = new Delivery_Group__c(
            Sales_Confirmation__c = sc.Id,
            Delivery_Date__c = Date.today().addDays(7)
        );
        insert delivery;
        Test.stopTest();
    }

    @isTest
    static void testDeliveryUpdateWithDateChange() {
        Test.setMock(HttpCalloutMock.class, new WhatsAppCalloutMock());
        
        Test.startTest();
        Sales_Confirmation__c sc = [SELECT Id, Opportunity__c FROM Sales_Confirmation__c LIMIT 1];
        Deals__c deal = [SELECT Id FROM Deals__c WHERE Id = :sc.Opportunity__c];
        deal.Phone__c = '6379486144';
        update deal;

        Delivery_Group__c delivery = new Delivery_Group__c(
            Sales_Confirmation__c = sc.Id,
            Delivery_Date__c = Date.today().addDays(7)
        );
        insert delivery;

        delivery.Delivery_Date__c = Date.today().addDays(14);
        update delivery;
        Test.stopTest();
    }

    @isTest
    static void testDeliveryUpdateWithoutDateChange() {
        Test.setMock(HttpCalloutMock.class, new WhatsAppCalloutMock());
        
        Test.startTest();
        Sales_Confirmation__c sc = [SELECT Id, Opportunity__c FROM Sales_Confirmation__c LIMIT 1];
        Deals__c deal = [SELECT Id FROM Deals__c WHERE Id = :sc.Opportunity__c];
        deal.Phone__c = '9876543210';
        update deal;

        Delivery_Group__c delivery = new Delivery_Group__c(
            Sales_Confirmation__c = sc.Id,
            Delivery_Date__c = Date.today().addDays(7)
        );
        insert delivery;

        delivery.Remarks__c = 'Test Remarks';
        update delivery;
        Test.stopTest();
    }

    @isTest
    static void testDeliveryWithNullPhone() {
        Test.setMock(HttpCalloutMock.class, new WhatsAppCalloutMock());
        
        Test.startTest();
        Sales_Confirmation__c sc = [SELECT Id, Opportunity__c FROM Sales_Confirmation__c LIMIT 1];
        Deals__c deal = [SELECT Id FROM Deals__c WHERE Id = :sc.Opportunity__c];
        deal.Phone__c = null;
        update deal;

        Delivery_Group__c delivery = new Delivery_Group__c(
            Sales_Confirmation__c = sc.Id,
            Delivery_Date__c = Date.today().addDays(7)
        );
        insert delivery;
        Test.stopTest();
    }

    @isTest
    static void testDeliveryWithPhoneHavingCountryCode() {
        Test.setMock(HttpCalloutMock.class, new WhatsAppCalloutMock());
        
        Test.startTest();
        Sales_Confirmation__c sc = [SELECT Id, Opportunity__c FROM Sales_Confirmation__c LIMIT 1];
        Deals__c deal = [SELECT Id FROM Deals__c WHERE Id = :sc.Opportunity__c];
        deal.Phone__c = '919876543210';
        update deal;

        Delivery_Group__c delivery = new Delivery_Group__c(
            Sales_Confirmation__c = sc.Id,
            Delivery_Date__c = Date.today().addDays(7)
        );
        insert delivery;
        Test.stopTest();
    }

    // Mock HTTP Callout class
    private class WhatsAppCalloutMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"status":"success"}');
            res.setStatusCode(200);
            return res;
        }
    }
}