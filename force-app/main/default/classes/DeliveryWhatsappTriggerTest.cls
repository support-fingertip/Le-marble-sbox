@isTest
public with sharing class DeliveryWhatsappTriggerTest {

    @TestSetup
    static void setupTestData() {
        Customer__c customer = new Customer__c(
            Name             = 'Test Project - Vishwa',
            Lead_Name__c     = 'Test Lead',
            Primary_Phone__c = '9876543210',
            Phone__c         = '9876543210',
            Email__c         = 'testcustomer@example.com'
        );
        insert customer;

        Deals__c deal = new Deals__c(
            Name        = 'Test Deal',
            Customer__c = customer.Id,
            Company__c  = 'Test Company',
            Type__c     = 'RETAIL',
            Phone__c    = '9999999999'
        );
        insert deal;

        Sales_Confirmation__c sc = new Sales_Confirmation__c(
            Opportunity__c = deal.Id
        );
        insert sc;

        // Delivery_Group__c requires Sales_Order__c (Order) + Delivery_Status__c
        Account acc = new Account(
            Name              = 'Test Account',
            BillingCountry    = 'India',
            BillingState      = 'Maharashtra',
            BillingPostalCode = '400001',
            BillingStreet     = '123 Test Street',
            District__c       = 'Ernakulam',
            Pin_Code__c       = 400001
        );
        insert acc;

        Order ord = new Order(
            AccountId     = acc.Id,
            EffectiveDate = Date.today(),
            Status        = 'Draft',
            Pricebook2Id  = Test.getStandardPricebookId()
        );
        SalesOrderTriggerHandler.isRunning = true;
        insert ord;
        SalesOrderTriggerHandler.isRunning = false;
    }

    // Helper to get Order Id
    private static Id getOrderId() {
        return [SELECT Id FROM Order LIMIT 1].Id;
    }

    // -----------------------------------------------------------------------
    // AFTER INSERT — sends WhatsApp when phone + date are present
    // -----------------------------------------------------------------------

    @isTest
    static void testDeliveryInsertWithValidPhone() {
        Test.setMock(HttpCalloutMock.class, new WhatsAppCalloutMock());

        Sales_Confirmation__c sc = [SELECT Id, Opportunity__c FROM Sales_Confirmation__c LIMIT 1];
        Deals__c deal = [SELECT Id FROM Deals__c WHERE Id = :sc.Opportunity__c];
        deal.Phone__c = '9876543210';
        update deal;

        Test.startTest();
        Delivery_Group__c delivery = new Delivery_Group__c(
            Sales_Confirmation__c = sc.Id,
            Sales_Order__c        = getOrderId(),
            Delivery_Status__c    = 'Draft',
            Delivery_Date__c      = Date.today().addDays(7)
        );
        insert delivery;
        Test.stopTest();

        System.assertNotEquals(null, delivery.Id, 'Delivery record should be inserted');
    }

    // -----------------------------------------------------------------------
    // AFTER INSERT — no send when delivery date is null (sendMsg stays false)
    // -----------------------------------------------------------------------

    @isTest
    static void testDeliveryInsertWithNullDate() {
        Test.setMock(HttpCalloutMock.class, new WhatsAppCalloutMock());

        Sales_Confirmation__c sc = [SELECT Id, Opportunity__c FROM Sales_Confirmation__c LIMIT 1];
        Deals__c deal = [SELECT Id FROM Deals__c WHERE Id = :sc.Opportunity__c];
        deal.Phone__c = '9876543210';
        update deal;

        Test.startTest();
        Delivery_Group__c delivery = new Delivery_Group__c(
            Sales_Confirmation__c = sc.Id,
            Sales_Order__c        = getOrderId(),
            Delivery_Status__c    = 'Draft',
            Delivery_Date__c      = null
        );
        insert delivery;
        Test.stopTest();

        System.assertNotEquals(null, delivery.Id, 'Delivery record should still insert without a date');
    }

    // -----------------------------------------------------------------------
    // AFTER INSERT — no send when Sales_Confirmation__c is null (phone = null)
    // -----------------------------------------------------------------------

    @isTest
    static void testDeliveryInsertWithNoSalesConfirmation() {
        Test.setMock(HttpCalloutMock.class, new WhatsAppCalloutMock());

        Test.startTest();
        Delivery_Group__c delivery = new Delivery_Group__c(
            Sales_Confirmation__c = null,
            Sales_Order__c        = getOrderId(),
            Delivery_Status__c    = 'Draft',
            Delivery_Date__c      = Date.today().addDays(7)
        );
        insert delivery;
        Test.stopTest();

        System.assertNotEquals(null, delivery.Id, 'Delivery record should insert even with no Sales Confirmation');
    }

    // -----------------------------------------------------------------------
    // AFTER INSERT — no send when phone is null on the related Opportunity
    // -----------------------------------------------------------------------

    @isTest
    static void testDeliveryInsertWithNullPhone() {
        Test.setMock(HttpCalloutMock.class, new WhatsAppCalloutMock());

        Sales_Confirmation__c sc = [SELECT Id, Opportunity__c FROM Sales_Confirmation__c LIMIT 1];
        Deals__c deal = [SELECT Id FROM Deals__c WHERE Id = :sc.Opportunity__c];
        deal.Phone__c = null;
        update deal;

        Test.startTest();
        Delivery_Group__c delivery = new Delivery_Group__c(
            Sales_Confirmation__c = sc.Id,
            Sales_Order__c        = getOrderId(),
            Delivery_Status__c    = 'Draft',
            Delivery_Date__c      = Date.today().addDays(7)
        );
        insert delivery;
        Test.stopTest();

        System.assertNotEquals(null, delivery.Id, 'Delivery record should insert even with null phone');
    }

    // -----------------------------------------------------------------------
    // AFTER INSERT — phone already has country code (91xxxxxxxxxx, 12 digits)
    // -----------------------------------------------------------------------

    @isTest
    static void testDeliveryInsertPhoneAlreadyHasCountryCode() {
        Test.setMock(HttpCalloutMock.class, new WhatsAppCalloutMock());

        Sales_Confirmation__c sc = [SELECT Id, Opportunity__c FROM Sales_Confirmation__c LIMIT 1];
        Deals__c deal = [SELECT Id FROM Deals__c WHERE Id = :sc.Opportunity__c];
        deal.Phone__c = '919876543210';
        update deal;

        Test.startTest();
        Delivery_Group__c delivery = new Delivery_Group__c(
            Sales_Confirmation__c = sc.Id,
            Sales_Order__c        = getOrderId(),
            Delivery_Status__c    = 'Draft',
            Delivery_Date__c      = Date.today().addDays(7)
        );
        insert delivery;
        Test.stopTest();

        System.assertNotEquals(null, delivery.Id, 'Delivery record should insert with pre-formatted phone');
    }

    // -----------------------------------------------------------------------
    // AFTER INSERT — phone with special characters (+91-9876543210)
    // -----------------------------------------------------------------------

    @isTest
    static void testDeliveryInsertPhoneWithSpecialChars() {
        Test.setMock(HttpCalloutMock.class, new WhatsAppCalloutMock());

        Sales_Confirmation__c sc = [SELECT Id, Opportunity__c FROM Sales_Confirmation__c LIMIT 1];
        Deals__c deal = [SELECT Id FROM Deals__c WHERE Id = :sc.Opportunity__c];
        deal.Phone__c = '+91-9876543210';
        update deal;

        Test.startTest();
        Delivery_Group__c delivery = new Delivery_Group__c(
            Sales_Confirmation__c = sc.Id,
            Sales_Order__c        = getOrderId(),
            Delivery_Status__c    = 'Draft',
            Delivery_Date__c      = Date.today().addDays(7)
        );
        insert delivery;
        Test.stopTest();

        System.assertNotEquals(null, delivery.Id, 'Delivery record should insert with special-char phone');
    }

    // -----------------------------------------------------------------------
    // AFTER UPDATE — date changed → WhatsApp should be sent
    // -----------------------------------------------------------------------

    @isTest
    static void testDeliveryUpdateWithDateChange() {
        Test.setMock(HttpCalloutMock.class, new WhatsAppCalloutMock());

        Sales_Confirmation__c sc = [SELECT Id, Opportunity__c FROM Sales_Confirmation__c LIMIT 1];
        Deals__c deal = [SELECT Id FROM Deals__c WHERE Id = :sc.Opportunity__c];
        deal.Phone__c = '6379486144';
        update deal;

        Delivery_Group__c delivery = new Delivery_Group__c(
            Sales_Confirmation__c = sc.Id,
            Sales_Order__c        = getOrderId(),
            Delivery_Status__c    = 'Draft',
            Delivery_Date__c      = Date.today().addDays(7)
        );
        insert delivery;

        Test.startTest();
        delivery.Delivery_Date__c = Date.today().addDays(14);
        update delivery;
        Test.stopTest();

        Delivery_Group__c updated = [SELECT Delivery_Date__c FROM Delivery_Group__c WHERE Id = :delivery.Id];
        System.assertEquals(Date.today().addDays(14), updated.Delivery_Date__c, 'Delivery date should be updated');
    }

    // -----------------------------------------------------------------------
    // AFTER UPDATE — date unchanged → no WhatsApp sent
    // -----------------------------------------------------------------------

    @isTest
    static void testDeliveryUpdateWithoutDateChange() {
        Test.setMock(HttpCalloutMock.class, new WhatsAppCalloutMock());

        Sales_Confirmation__c sc = [SELECT Id, Opportunity__c FROM Sales_Confirmation__c LIMIT 1];
        Deals__c deal = [SELECT Id FROM Deals__c WHERE Id = :sc.Opportunity__c];
        deal.Phone__c = '9876543210';
        update deal;

        Delivery_Group__c delivery = new Delivery_Group__c(
            Sales_Confirmation__c = sc.Id,
            Sales_Order__c        = getOrderId(),
            Delivery_Status__c    = 'Draft',
            Delivery_Date__c      = Date.today().addDays(7)
        );
        insert delivery;

        Test.startTest();
        delivery.Remarks__c = 'Updated remarks only';
        update delivery;
        Test.stopTest();

        Delivery_Group__c updated = [SELECT Delivery_Date__c FROM Delivery_Group__c WHERE Id = :delivery.Id];
        System.assertEquals(Date.today().addDays(7), updated.Delivery_Date__c, 'Delivery date should remain unchanged');
    }

    // -----------------------------------------------------------------------
    // AFTER UPDATE — date cleared to null → no send
    // -----------------------------------------------------------------------

    @isTest
    static void testDeliveryUpdateDateClearedToNull() {
        Test.setMock(HttpCalloutMock.class, new WhatsAppCalloutMock());

        Sales_Confirmation__c sc = [SELECT Id, Opportunity__c FROM Sales_Confirmation__c LIMIT 1];
        Deals__c deal = [SELECT Id FROM Deals__c WHERE Id = :sc.Opportunity__c];
        deal.Phone__c = '9876543210';
        update deal;

        Delivery_Group__c delivery = new Delivery_Group__c(
            Sales_Confirmation__c = sc.Id,
            Sales_Order__c        = getOrderId(),
            Delivery_Status__c    = 'Draft',
            Delivery_Date__c      = Date.today().addDays(7)
        );
        insert delivery;

        Test.startTest();
        delivery.Delivery_Date__c = null;
        update delivery;
        Test.stopTest();

        Delivery_Group__c updated = [SELECT Delivery_Date__c FROM Delivery_Group__c WHERE Id = :delivery.Id];
        System.assertEquals(null, updated.Delivery_Date__c, 'Delivery date should be null after clearing');
    }

    // -----------------------------------------------------------------------
    // Mock HTTP callout
    // -----------------------------------------------------------------------

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