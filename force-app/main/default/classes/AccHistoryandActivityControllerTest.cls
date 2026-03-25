@isTest
public class AccHistoryandActivityControllerTest {

    @isTest
    static void testGetData_AllFilters() {

        // Create Account with required picklist fields
        String district = Account.District__c.getDescribe().getPicklistValues()[0].getValue();
        String state = Account.State__c.getDescribe().getPicklistValues()[0].getValue();
        String country = Account.Country__c.getDescribe().getPicklistValues()[0].getValue();
        Account acc = new Account(
            Name = 'Test Account',
            District__c = district,
            State__c = state,
            Country__c = country,
            BillingCountry = 'India',
            BillingState = 'KA',
            BillingPostalCode = '560001',
            BillingCity = 'Bangalore',
            BillingStreet = '123 Test Street',
            Pin_Code__c = 560001
        );
        insert acc;

        // Create Contact
        Contact con = new Contact(
            LastName = 'Test Contact',
            AccountId = acc.Id
        );
        insert con;

        // Create Opportunity
        String oppState = Opportunity.State__c.getDescribe().getPicklistValues()[0].getValue();
        String oppDistrict = Opportunity.District__c.getDescribe().getPicklistValues()[0].getValue();
        Opportunity opp = new Opportunity(
            Name = 'Test Opportunity',
            AccountId = acc.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today(),
            State__c = oppState,
            District__c = oppDistrict,
            Pin_Code__c = 560001
        );
        insert opp;

        // Create Quote
        Quote qt = new Quote(
            Name = 'Test Quote',
            OpportunityId = opp.Id
        );
        insert qt;

        // Create Order (Keep Draft)
        Order ord = new Order(
            Name = 'Test Order',
            AccountId = acc.Id,
            EffectiveDate = Date.today(),
            Status = 'Draft'
        );
        insert ord;

        // Create Invoice__c
        Invoice__c inv = new Invoice__c(
            Account__c = acc.Id,
            Invoice_Amount__c = 500,
            Invoice_Date__c = Date.today()
        );
        insert inv;

        // 🔥 Get valid picklist value dynamically
        String validDeliveryStatus;
        List<Schema.PicklistEntry> picklistValues =
            Delivery_Group__c.Delivery_Status__c.getDescribe().getPicklistValues();

        if (!picklistValues.isEmpty()) {
            validDeliveryStatus = picklistValues[0].getValue();
        }

        // ✅ Create Delivery_Group__c with required Sales_Order__c
        Delivery_Group__c dg = new Delivery_Group__c(
            Account__c = acc.Id,
            Sales_Order__c = ord.Id,   // REQUIRED FIELD FIXED
            Delivery_Status__c = validDeliveryStatus
        );
        insert dg;

        // Create Completed Task
        Task t = new Task(
            WhatId = acc.Id,
            Subject = 'Test Task',
            ActivityDate = Date.today(),
            Status = 'Completed',
            Priority = 'Normal'
        );
        insert t;

        Test.startTest();

        List<AccHistoryandActivityController.WrapSObject> result =
            AccHistoryandActivityController.GetData(acc.Id, 'All');

        AccHistoryandActivityController.GetData(acc.Id, 'Activities');
        AccHistoryandActivityController.GetData(acc.Id, 'Quotes');
        AccHistoryandActivityController.GetData(acc.Id, 'Contacts');
        AccHistoryandActivityController.GetData(acc.Id, 'Invoices');
        AccHistoryandActivityController.GetData(acc.Id, 'Opportunities');
        AccHistoryandActivityController.GetData(acc.Id, 'SalesOrder');
        AccHistoryandActivityController.GetData(acc.Id, 'DeliveryPlans');
        AccHistoryandActivityController.GetData(acc.Id, 'Field Updates');

        Test.stopTest();

        System.assert(result != null);
        System.assert(result.size() > 0);
    }
}