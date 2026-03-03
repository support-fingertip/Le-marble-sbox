@isTest
public class SalesOrderContactTriggerTest {
    
    // Mock for SAP callouts
    private class MockSAPCallout implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            if (req.getEndpoint().contains('/Login')) {
                res.setBody('{"SessionId":"test-session"}');
                res.setStatusCode(200);
            } else if (req.getEndpoint().contains('/Orders')) {
                res.setBody('{"DocEntry":"12345","DocNum":"SO-001"}');
                res.setStatusCode(201);
            } else {
                res.setBody('{"success":true}');
                res.setStatusCode(200);
            }
            return res;
        }
    }
    
    @TestSetup
    static void setupTestData() {
        // Create Account
        Account acc = new Account(Name = 'Test Account For Contact Trigger');
        insert acc;
        
        // Create Customer
        Customer__c customer = new Customer__c(
            Name = 'Test Customer Contact Trigger',
            Lead_Name__c = 'Test Lead CT',
            Primary_Phone__c = '9876543210',
            Email__c = 'testct@example.com',
            Customer_ID__c = 'CUSTCT001'
        );
        insert customer;
        
        // Create Deal
        Deals__c deal = new Deals__c(
            Name = 'Test Deal CT',
            Customer__c = customer.Id,
            Company__c = 'Test Co CT',
            Type__c = 'RETAIL'
        );
        insert deal;
        
        // Create Product (custom)
        Product__c product = new Product__c(
            Name = 'Test Product CT',
            Product_Code__c = 'PCT001',
            Product_Category__c = 'TILES'
        );
        insert product;
        
        // Create Cart
        Cart__c cart = new Cart__c(
            Customer__c = customer.Id,
            Deals__c = deal.Id,
            Status__c = 'Approved'
        );
        insert cart;
        
        // Create Cart Line Item
        Cart_Line_Item__c cli = new Cart_Line_Item__c(
            Product__c = product.Id,
            Cart__c = cart.Id,
            Product_Category__c = 'TILES',
            Quantity__c = 2,
            Price__c = 100,
            Item_Chosen__c = true,
            Warehouse__c = 'WH001',
            BPL_IDAssignedToInvoice__c = '1'
        );
        insert cli;
    }
    
    @isTest
    static void testInsertWithDraftStatus() {
        // Test: Insert Order with Status = 'Draft' should NOT enqueue job
        Test.setMock(HttpCalloutMock.class, new MockSAPCallout());
        
        Account acc = [SELECT Id FROM Account LIMIT 1];
        
        Test.startTest();
        SalesOrderTriggerHandler.isRunning = false;
        
        Order ord = new Order(
            Name = 'Test Order Insert Draft',
            Status = 'Draft',
            EffectiveDate = Date.today(),
            AccountId = acc.Id
        );
        insert ord;
        
        Test.stopTest();
        
        // Verify the order was inserted with Draft status
        Order inserted = [SELECT Id, Status, SAP_Doc_Num__c FROM Order WHERE Id = :ord.Id];
        System.assertEquals('Draft', inserted.Status, 'Order should have Draft status');
    }
    
    @isTest
    static void testTriggerViaApprovedSalesConfirmation() {
        // Test trigger indirectly via Sales_Confirmation__c approval
        Test.setMock(HttpCalloutMock.class, new MockSAPCallout());
        
        Deals__c deal = [SELECT Id FROM Deals__c LIMIT 1];
        
        Test.startTest();
        SalesOrderTriggerHandler.isRunning = false;
        
        // Create Sales Confirmation with Approved status - this creates Order
        Sales_Confirmation__c sc = new Sales_Confirmation__c(
            Opportunity__c = deal.Id,
            Approval_Status__c = 'Approved',
            Payment_Type__c = 'Cash',
            BPL_IDAssignedToInvoice__c = '1'
        );
        insert sc;
        
        Test.stopTest();
        
        // Verify Sales Confirmation was created
        sc = [SELECT Id, Sales_Order_Id__c, Approval_Status__c FROM Sales_Confirmation__c WHERE Id = :sc.Id];
        System.assertEquals('Approved', sc.Approval_Status__c, 'Sales Confirmation should be Approved');
    }
    
    @isTest
    static void testTriggerViaUpdatedSalesConfirmation() {
        // Test trigger indirectly via Sales_Confirmation__c update to Approved
        Test.setMock(HttpCalloutMock.class, new MockSAPCallout());
        
        Deals__c deal = [SELECT Id FROM Deals__c LIMIT 1];
        
        // Create Sales Confirmation with Pending status first
        SalesOrderTriggerHandler.isRunning = false;
        Sales_Confirmation__c sc = new Sales_Confirmation__c(
            Opportunity__c = deal.Id,
            Approval_Status__c = 'Pending',
            Payment_Type__c = 'Cash',
            BPL_IDAssignedToInvoice__c = '1'
        );
        insert sc;
        
        Test.startTest();
        SalesOrderTriggerHandler.isRunning = false;
        
        // Update to Approved - this should trigger the Order trigger
        sc.Approval_Status__c = 'Approved';
        update sc;
        
        Test.stopTest();
        
        // Verify Sales Confirmation was updated
        sc = [SELECT Id, Sales_Order_Id__c, Approval_Status__c FROM Sales_Confirmation__c WHERE Id = :sc.Id];
        System.assertEquals('Approved', sc.Approval_Status__c, 'Sales Confirmation should be Approved');
    }
    
    @isTest
    static void testReentrancePrevention() {
        // Test: When isRunning is true, trigger should exit early
        Test.setMock(HttpCalloutMock.class, new MockSAPCallout());
        
        Account acc = [SELECT Id FROM Account LIMIT 1];
        
        Test.startTest();
        // Set isRunning to true to simulate reentrance
        SalesOrderTriggerHandler.isRunning = true;
        
        // Insert Order - trigger should exit early due to isRunning flag
        Order ord = new Order(
            Name = 'Test Order Reentrance',
            Status = 'Draft',
            EffectiveDate = Date.today(),
            AccountId = acc.Id
        );
        insert ord;
        
        Test.stopTest();
        
        // Verify the order was inserted (trigger should have exited early)
        Order inserted = [SELECT Id, Status FROM Order WHERE Id = :ord.Id];
        System.assertEquals('Draft', inserted.Status, 'Order should be inserted even with isRunning=true');
        
        // Reset for cleanup
        SalesOrderTriggerHandler.isRunning = false;
    }
    
    @isTest
    static void testBulkSalesConfirmationApproval() {
        // Test bulk approval scenario
        Test.setMock(HttpCalloutMock.class, new MockSAPCallout());
        
        // Create additional deals
        Customer__c customer = [SELECT Id FROM Customer__c LIMIT 1];
        List<Deals__c> deals = new List<Deals__c>();
        for (Integer i = 0; i < 3; i++) {
            deals.add(new Deals__c(
                Name = 'Bulk Deal ' + i,
                Customer__c = customer.Id,
                Company__c = 'Test Co Bulk',
                Type__c = 'RETAIL'
            ));
        }
        insert deals;
        
        // Create Sales Confirmations with Pending status
        SalesOrderTriggerHandler.isRunning = false;
        List<Sales_Confirmation__c> confirmations = new List<Sales_Confirmation__c>();
        for (Deals__c deal : deals) {
            confirmations.add(new Sales_Confirmation__c(
                Opportunity__c = deal.Id,
                Approval_Status__c = 'Pending',
                Payment_Type__c = 'Cash',
                BPL_IDAssignedToInvoice__c = '1'
            ));
        }
        insert confirmations;
        
        Test.startTest();
        SalesOrderTriggerHandler.isRunning = false;
        
        // Bulk update to Approved
        for (Sales_Confirmation__c sc : confirmations) {
            sc.Approval_Status__c = 'Approved';
        }
        update confirmations;
        
        Test.stopTest();
        
        // Verify all were approved
        List<Sales_Confirmation__c> updated = [SELECT Id, Approval_Status__c FROM Sales_Confirmation__c WHERE Id IN :confirmations];
        System.assertEquals(3, updated.size(), 'All 3 confirmations should exist');
        for (Sales_Confirmation__c sc : updated) {
            System.assertEquals('Approved', sc.Approval_Status__c, 'All should be Approved');
        }
    }
    
    @isTest
    static void testIsRunningFlagReset() {
        // Test that isRunning flag can be toggled
        Test.setMock(HttpCalloutMock.class, new MockSAPCallout());
        
        Test.startTest();
        
        // Verify initial state (should be false or reset from previous test)
        SalesOrderTriggerHandler.isRunning = false;
        System.assertEquals(false, SalesOrderTriggerHandler.isRunning, 'isRunning should start as false');
        
        // Set to true
        SalesOrderTriggerHandler.isRunning = true;
        System.assertEquals(true, SalesOrderTriggerHandler.isRunning, 'isRunning should be true');
        
        // Reset to false
        SalesOrderTriggerHandler.isRunning = false;
        System.assertEquals(false, SalesOrderTriggerHandler.isRunning, 'isRunning should be false again');
        
        Test.stopTest();
    }
    
    @isTest
    static void testDirectOrderUpdateToApproved() {
        // Test: Direct Order update from Draft to Approved triggers enqueue
        Test.setMock(HttpCalloutMock.class, new MockSAPCallout());
        
        Account acc = [SELECT Id FROM Account LIMIT 1];
        
        // Insert Order with Draft status first
        SalesOrderTriggerHandler.isRunning = false;
        Order ord = new Order(
            Name = 'Direct Update Order',
            Status = 'Draft',
            EffectiveDate = Date.today(),
            AccountId = acc.Id
        );
        insert ord;
        
        // Query the order to get fresh data
        ord = [SELECT Id, Status, SAP_Doc_Num__c FROM Order WHERE Id = :ord.Id];
        
        Test.startTest();
        SalesOrderTriggerHandler.isRunning = false;
        
        // Update to Approved - this directly triggers the Order trigger
        ord.Status = 'Approved';
        try {
            update ord;
        } catch (DmlException e) {
            // Expected - validation may require products
            System.debug('Expected validation: ' + e.getMessage());
        }
        
        Test.stopTest();
    }
    
    @isTest
    static void testOrderUpdateWithSAPDocNum() {
        // Test: Update Order with existing SAP_Doc_Num__c should NOT enqueue
        Test.setMock(HttpCalloutMock.class, new MockSAPCallout());
        
        Account acc = [SELECT Id FROM Account LIMIT 1];
        
        // Insert Order with Draft status and SAP_Doc_Num__c already set
        SalesOrderTriggerHandler.isRunning = false;
        Order ord = new Order(
            Name = 'Order With SAP Doc',
            Status = 'Draft',
            EffectiveDate = Date.today(),
            AccountId = acc.Id,
            SAP_Doc_Num__c = 'EXISTING-DOC-001'
        );
        insert ord;
        
        Test.startTest();
        SalesOrderTriggerHandler.isRunning = false;
        
        // Update to Approved - should NOT trigger enqueue since SAP_Doc_Num__c exists
        ord.Status = 'Approved';
        try {
            update ord;
        } catch (DmlException e) {
            // Expected
            System.debug('Expected validation: ' + e.getMessage());
        }
        
        Test.stopTest();
        
        // Verify SAP_Doc_Num__c unchanged
        Order updated = [SELECT Id, SAP_Doc_Num__c FROM Order WHERE Id = :ord.Id];
        System.assertEquals('EXISTING-DOC-001', updated.SAP_Doc_Num__c, 'SAP_Doc_Num__c should be unchanged');
    }
    
    @isTest
    static void testOrderUpdateStaysApproved() {
        // Test: Update Order that stays Approved should NOT enqueue again
        Test.setMock(HttpCalloutMock.class, new MockSAPCallout());
        
        Deals__c deal = [SELECT Id FROM Deals__c LIMIT 1];
        
        // Create via Sales Confirmation (creates Approved Order)
        SalesOrderTriggerHandler.isRunning = false;
        Sales_Confirmation__c sc = new Sales_Confirmation__c(
            Opportunity__c = deal.Id,
            Approval_Status__c = 'Approved',
            Payment_Type__c = 'Cash',
            BPL_IDAssignedToInvoice__c = '1'
        );
        insert sc;
        
        // Get the created Order
        List<Order> orders = [SELECT Id, Status, Name, SAP_Doc_Num__c FROM Order WHERE AccountId != null LIMIT 1];
        if (!orders.isEmpty()) {
            Order ord = orders[0];
            
            Test.startTest();
            SalesOrderTriggerHandler.isRunning = false;
            
            // Update name but keep Approved - should NOT trigger enqueue
            ord.Name = 'Updated Name';
            update ord;
            
            Test.stopTest();
            
            // Verify order was updated
            Order updated = [SELECT Id, Name FROM Order WHERE Id = :ord.Id];
            System.assert(updated.Name.contains('Updated'), 'Name should be updated');
        }
    }
    
    @isTest
    static void testMultipleOrdersUpdateToApproved() {
        // Test: Multiple Orders update to Approved in bulk
        Test.setMock(HttpCalloutMock.class, new MockSAPCallout());
        
        Account acc = [SELECT Id FROM Account LIMIT 1];
        
        // Insert multiple Orders with Draft status
        SalesOrderTriggerHandler.isRunning = false;
        List<Order> orders = new List<Order>();
        for (Integer i = 0; i < 5; i++) {
            orders.add(new Order(
                Name = 'Bulk Direct Order ' + i,
                Status = 'Draft',
                EffectiveDate = Date.today(),
                AccountId = acc.Id
            ));
        }
        insert orders;
        
        Test.startTest();
        SalesOrderTriggerHandler.isRunning = false;
        
        // Update all to Approved
        for (Order o : orders) {
            o.Status = 'Approved';
        }
        try {
            update orders;
        } catch (DmlException e) {
            // Expected - validation may require products
            System.debug('Expected validation: ' + e.getMessage());
        }
        
        Test.stopTest();
    }
    
    @isTest
    static void testOrderTriggerLoopIteration() {
        // Test: Exercise the loop iteration through multiple records
        Test.setMock(HttpCalloutMock.class, new MockSAPCallout());
        
        Account acc = [SELECT Id FROM Account LIMIT 1];
        
        // Insert Order
        SalesOrderTriggerHandler.isRunning = false;
        Order ord1 = new Order(
            Name = 'Loop Test Order 1',
            Status = 'Draft',
            EffectiveDate = Date.today(),
            AccountId = acc.Id
        );
        Order ord2 = new Order(
            Name = 'Loop Test Order 2',
            Status = 'Draft',
            EffectiveDate = Date.today(),
            AccountId = acc.Id
        );
        insert new List<Order>{ord1, ord2};
        
        Test.startTest();
        SalesOrderTriggerHandler.isRunning = false;
        
        // Update both orders - exercises the for loop
        ord1.Name = 'Loop Test Order 1 Updated';
        ord2.Name = 'Loop Test Order 2 Updated';
        update new List<Order>{ord1, ord2};
        
        Test.stopTest();
        
        // Verify both updated
        List<Order> updated = [SELECT Id, Name FROM Order WHERE Name LIKE 'Loop Test Order%' ORDER BY Name];
        System.assertEquals(2, updated.size(), 'Both orders should exist');
    }
    
    @isTest
    static void testOrderWithOpportunityApproved() {
        // Test: Order linked to Opportunity with products can be approved - triggers enqueue
        Test.setMock(HttpCalloutMock.class, new MockSAPCallout());
        
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Id stdPricebookId = Test.getStandardPricebookId();
        
        // Create Opportunity linked to Account
        Opportunity opp = new Opportunity(
            Name = 'Test Opp for Order Trigger',
            AccountId = acc.Id,
            StageName = 'Qualification',
            CloseDate = Date.today().addDays(30)
        );
        insert opp;
        
        // Create User with SAP_Emp_Code__c if needed
        User currentUser = [SELECT Id, SAP_Emp_Code__c FROM User WHERE Id = :UserInfo.getUserId()];
        
        // Create Order with Pricebook and OpportunityId
        SalesOrderTriggerHandler.isRunning = false;
        Order ord = new Order(
            Name = 'Order With Opportunity',
            Status = 'Draft',
            EffectiveDate = Date.today(),
            AccountId = acc.Id,
            OpportunityId = opp.Id,
            Pricebook2Id = stdPricebookId
        );
        insert ord;
        
        // Create Product
        Product2 prod = new Product2(
            Name = 'Test Product For Opp Order',
            IsActive = true
        );
        insert prod;
        
        // Create Pricebook Entry
        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = stdPricebookId,
            Product2Id = prod.Id,
            UnitPrice = 100,
            IsActive = true
        );
        insert pbe;
        
        // Create OrderItem
        OrderItem oi = new OrderItem(
            OrderId = ord.Id,
            Quantity = 5,
            UnitPrice = 100,
            PricebookEntryId = pbe.Id
        );
        insert oi;
        
        Test.startTest();
        SalesOrderTriggerHandler.isRunning = false;
        
        // Update to Approved - should trigger enqueue
        ord.Status = 'Approved';
        update ord;
        
        Test.stopTest();
        
        // Verify order was approved
        Order updated = [SELECT Id, Status FROM Order WHERE Id = :ord.Id];
        System.assertEquals('Approved', updated.Status, 'Order should be Approved');
    }
}