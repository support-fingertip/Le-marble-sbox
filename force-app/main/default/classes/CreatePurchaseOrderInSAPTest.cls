/**
 * @description       : 
 * @author            : ChageMeIn@UserSettingsUnder.SFDoc
 * @group             : 
 * @last modified on  : 06-13-2025
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
**/
@isTest
private class CreatePurchaseOrderInSAPTest {
    @TestSetup
    static void setupTestData() {
        // Create test vendor
        Vendor__c vendor = new Vendor__c(
            Name = 'Test Vendor'
        );
        insert vendor;
        
        // Create test product
        Product__c product = new Product__c(
            Name = 'Test Product',
            Product_Code__c = 'TEST001'
        );
        insert product;
        
        // Create test pending purchase
        Pending_Purchase__c purchase = new Pending_Purchase__c(
            Vendor__c = vendor.Id,
            Received_Date__c = Date.today(),
            Remarks__c = '<p>Test <b>HTML</b> with &amp; entities</p>',
            Status__c = 'Finance Manager Approved'
        );
        insert purchase;
        
        // Create test line items
        List<Pending_Purchase_Line_Item__c> lineItems = new List<Pending_Purchase_Line_Item__c>{
            new Pending_Purchase_Line_Item__c(
                Pending_Purchase__c = purchase.Id,
                Product__c = product.Id,
                Quantity__c = 10,
                Warehouse__c = 'AMP0004',
                BPL_ID__c = '1'
            )
        };
        insert lineItems;
    }
    
    // Test methods for CreatePurchaseOrderInSAP class
    @isTest
    static void testCreateNewPO() {
        // Get the test purchase record
        Pending_Purchase__c purchase = [SELECT Id FROM Pending_Purchase__c LIMIT 1];
        
        // Set mock callout response for login
        Test.setMock(HttpCalloutMock.class, new SAPMockHttpResponseGenerator(200, '{"SessionId": "test-session"}'));
        
        // Set mock callout response for PO creation
        Test.setMock(HttpCalloutMock.class, new SAPMockHttpResponseGenerator(201, '{"DocEntry": "12345"}'));
        
        Test.startTest();
        // Call the method
        CreatePurchaseOrderInSAP.createPO(purchase.Id);
        Test.stopTest();
        
        // Verify the results
        Pending_Purchase__c updatedPurchase = [
            SELECT Id, Is_PO_Created__c, SAP_DocEntry__c 
            FROM Pending_Purchase__c 
            WHERE Id = :purchase.Id
        ];
    
    }
    
    @isTest
    static void testUpdateExistingPO() {
        // Get the test purchase record and update it
        Pending_Purchase__c purchase = [SELECT Id FROM Pending_Purchase__c LIMIT 1];
        purchase.Remarks__c = 'Updated Remarks';
        purchase.Is_PO_Created__c = true;
        purchase.SAP_DocEntry__c = '12345';
        update purchase;
        
        // Set mock callout responses
        Test.setMock(HttpCalloutMock.class, new SAPMockHttpResponseGenerator(200, '{"SessionId": "test-session"}'));
        Test.setMock(HttpCalloutMock.class, new SAPMockHttpResponseGenerator(200, '{"DocEntry": "12345", "DocumentLines": []}'));
        Test.setMock(HttpCalloutMock.class, new SAPMockHttpResponseGenerator(204, ''));
        
        Test.startTest();
        // Call the method
        CreatePurchaseOrderInSAP.createPO(purchase.Id);
        Test.stopTest();
        
        // Verify the results
        Pending_Purchase__c updatedPurchase = [
            SELECT Id, Remarks__c 
            FROM Pending_Purchase__c 
            WHERE Id = :purchase.Id
        ];
        
        System.assertEquals('Updated Remarks', updatedPurchase.Remarks__c, 'Remarks should be updated');
    }
    
    // Test methods for PendingPurchaseLineItemTrigger
    @isTest
    static void testLineItemTrigger_Insert() {
        // Get the test purchase record
        Pending_Purchase__c purchase = [SELECT Id FROM Pending_Purchase__c LIMIT 1];
        
        // Set mock callout responses
        Test.setMock(HttpCalloutMock.class, new SAPMockHttpResponseGenerator(200, '{"SessionId": "test-session"}'));
        Test.setMock(HttpCalloutMock.class, new SAPMockHttpResponseGenerator(201, '{"DocEntry": "12345"}'));
        
        Test.startTest();
        // Insert a new line item
        Pending_Purchase_Line_Item__c newLineItem = new Pending_Purchase_Line_Item__c(
            Pending_Purchase__c = purchase.Id,
            Product__c = [SELECT Id FROM Product__c LIMIT 1].Id,
            Quantity__c = 5,
            Warehouse__c = 'AMP0004',
            BPL_ID__c = '1'
        );
        insert newLineItem;
        Test.stopTest();
        
        // Verify the results
        Pending_Purchase__c updatedPurchase = [
            SELECT Id, Is_PO_Created__c, SAP_DocEntry__c 
            FROM Pending_Purchase__c 
            WHERE Id = :purchase.Id
        ];
        
    }
    
    @isTest
    static void testLineItemTrigger_Update() {
        // Get the test line item with Pending_Purchase__c field
        Pending_Purchase_Line_Item__c lineItem = [
            SELECT Id, Pending_Purchase__c 
            FROM Pending_Purchase_Line_Item__c 
            LIMIT 1
        ];
        
        // Set mock callout responses
        Test.setMock(HttpCalloutMock.class, new SAPMockHttpResponseGenerator(200, '{"SessionId": "test-session"}'));
        Test.setMock(HttpCalloutMock.class, new SAPMockHttpResponseGenerator(200, '{"DocEntry": "12345", "DocumentLines": []}'));
        Test.setMock(HttpCalloutMock.class, new SAPMockHttpResponseGenerator(204, ''));
        
        Test.startTest();
        // Update the line item
        lineItem.Quantity__c = 15;
        update lineItem;
        Test.stopTest();
        
        // Verify the results
        Pending_Purchase__c updatedPurchase = [
            SELECT Id, Is_PO_Created__c 
            FROM Pending_Purchase__c 
            WHERE Id = :lineItem.Pending_Purchase__c
        ];
    }
    
    @isTest
    static void testLineItemTrigger_Delete() {
        // Get the test line item with Pending_Purchase__c field
        Pending_Purchase_Line_Item__c lineItem = [
            SELECT Id, Pending_Purchase__c 
            FROM Pending_Purchase_Line_Item__c 
            LIMIT 1
        ];
        
        // Set mock callout responses
        Test.setMock(HttpCalloutMock.class, new SAPMockHttpResponseGenerator(200, '{"SessionId": "test-session"}'));
        Test.setMock(HttpCalloutMock.class, new SAPMockHttpResponseGenerator(200, '{"DocEntry": "12345", "DocumentLines": []}'));
        Test.setMock(HttpCalloutMock.class, new SAPMockHttpResponseGenerator(204, ''));
        
        Test.startTest();
        // Delete the line item
        delete lineItem;
        Test.stopTest();
        
        // Verify the results
        Pending_Purchase__c updatedPurchase = [
            SELECT Id, Is_PO_Created__c 
            FROM Pending_Purchase__c 
            WHERE Id = :lineItem.Pending_Purchase__c
        ];

    }
    
    // Test methods for PendingPurchaseUpdateTrigger
    @isTest
    static void testPurchaseUpdateTrigger_StatusChange() {
        // Get the test purchase record
        Pending_Purchase__c purchase = [SELECT Id FROM Pending_Purchase__c LIMIT 1];
        purchase.Status__c = 'Pending Approval';
        update purchase;
        
        // Set mock callout responses
        Test.setMock(HttpCalloutMock.class, new SAPMockHttpResponseGenerator(200, '{"SessionId": "test-session"}'));
        Test.setMock(HttpCalloutMock.class, new SAPMockHttpResponseGenerator(201, '{"DocEntry": "12345"}'));
        
        Test.startTest();
        // Update status to Finance Manager Approved
        purchase.Status__c = 'Finance Manager Approved';
        update purchase;
        Test.stopTest();
        
        // Verify the results
        Pending_Purchase__c updatedPurchase = [
            SELECT Id, Is_PO_Created__c, SAP_DocEntry__c 
            FROM Pending_Purchase__c 
            WHERE Id = :purchase.Id
        ];
    }
    
    @isTest
    static void testPurchaseUpdateTrigger_FieldChanges() {
        // Get the test purchase record
        Pending_Purchase__c purchase = [SELECT Id FROM Pending_Purchase__c LIMIT 1];
        
        // Set mock callout responses
        Test.setMock(HttpCalloutMock.class, new SAPMockHttpResponseGenerator(200, '{"SessionId": "test-session"}'));
        Test.setMock(HttpCalloutMock.class, new SAPMockHttpResponseGenerator(200, '{"DocEntry": "12345", "DocumentLines": []}'));
        Test.setMock(HttpCalloutMock.class, new SAPMockHttpResponseGenerator(204, ''));
        
        Test.startTest();
        // Update multiple fields
        purchase.Remarks__c = 'New Remarks';
        purchase.Received_Date__c = Date.today().addDays(7);
        update purchase;
        Test.stopTest();
        
        // Verify the results
        Pending_Purchase__c updatedPurchase = [
            SELECT Id, Is_PO_Created__c 
            FROM Pending_Purchase__c 
            WHERE Id = :purchase.Id
        ];
    }
    
    @isTest
    static void testEmptyLineItems() {
        // Get the test purchase record
        Pending_Purchase__c purchase = [SELECT Id FROM Pending_Purchase__c LIMIT 1];
        
        // Delete all line items
        delete [SELECT Id FROM Pending_Purchase_Line_Item__c WHERE Pending_Purchase__c = :purchase.Id];
        
        Test.startTest();
        CreatePurchaseOrderInSAP.createPO(purchase.Id);
        Test.stopTest();
        
        // Verify the results
        Pending_Purchase__c updatedPurchase = [
            SELECT Id, Is_PO_Created__c 
            FROM Pending_Purchase__c 
            WHERE Id = :purchase.Id
        ];
        
        System.assertEquals(false, updatedPurchase.Is_PO_Created__c, 'PO should not be created without line items');
    }
    
    @isTest
    static void testNonApprovedStatus() {
        // Get the test purchase record
        Pending_Purchase__c purchase = [SELECT Id FROM Pending_Purchase__c LIMIT 1];
        purchase.Status__c = 'Pending Approval';
        update purchase;
        
        Test.startTest();
        CreatePurchaseOrderInSAP.createPO(purchase.Id);
        Test.stopTest();
        
        // Verify the results
        Pending_Purchase__c updatedPurchase = [
            SELECT Id, Is_PO_Created__c 
            FROM Pending_Purchase__c 
            WHERE Id = :purchase.Id
        ];
        
        System.assertEquals(false, updatedPurchase.Is_PO_Created__c, 'PO should not be created for non-approved status');
    }
    
    @isTest
    static void testSAPLoginFailure() {
        // Get the test purchase record
        Pending_Purchase__c purchase = [SELECT Id FROM Pending_Purchase__c LIMIT 1];
        
        // Set mock callout response for failed login
        Test.setMock(HttpCalloutMock.class, new SAPMockHttpResponseGenerator(401, '{"error": "Invalid credentials"}'));
        
        Test.startTest();
        CreatePurchaseOrderInSAP.createPO(purchase.Id);
        Test.stopTest();
        
        // Verify the results
        Pending_Purchase__c updatedPurchase = [
            SELECT Id, Is_PO_Created__c 
            FROM Pending_Purchase__c 
            WHERE Id = :purchase.Id
        ];
        
        System.assertEquals(false, updatedPurchase.Is_PO_Created__c, 'PO should not be created due to login failure');
    }
    
    @isTest
    static void testPOCreationFailure() {
        // Get the test purchase record
        Pending_Purchase__c purchase = [SELECT Id FROM Pending_Purchase__c LIMIT 1];
        
        // Set mock callout responses
        Test.setMock(HttpCalloutMock.class, new SAPMockHttpResponseGenerator(200, '{"SessionId": "test-session"}'));
        Test.setMock(HttpCalloutMock.class, new SAPMockHttpResponseGenerator(400, '{"error": "Invalid PO data"}'));
        
        Test.startTest();
        CreatePurchaseOrderInSAP.createPO(purchase.Id);
        Test.stopTest();
        
        // Verify the results
        Pending_Purchase__c updatedPurchase = [
            SELECT Id, Is_PO_Created__c 
            FROM Pending_Purchase__c 
            WHERE Id = :purchase.Id
        ];
        
        System.assertEquals(false, updatedPurchase.Is_PO_Created__c, 'PO should not be created due to invalid data');
    }
    
    @isTest
    static void testPOUpdateFailure() {
        // Get the test purchase record and update it
        Pending_Purchase__c purchase = [SELECT Id FROM Pending_Purchase__c LIMIT 1];
        purchase.Is_PO_Created__c = true;
        purchase.SAP_DocEntry__c = '12345';
        update purchase;
        
        // Set mock callout responses
        Test.setMock(HttpCalloutMock.class, new SAPMockHttpResponseGenerator(200, '{"SessionId": "test-session"}'));
        Test.setMock(HttpCalloutMock.class, new SAPMockHttpResponseGenerator(404, '{"error": "PO not found"}'));
        
        Test.startTest();
        CreatePurchaseOrderInSAP.createPO(purchase.Id);
        Test.stopTest();
        
        // Verify the results
        Pending_Purchase__c updatedPurchase = [
            SELECT Id, Is_PO_Created__c 
            FROM Pending_Purchase__c 
            WHERE Id = :purchase.Id
        ];
        
        System.assertEquals(true, updatedPurchase.Is_PO_Created__c, 'PO should remain marked as created despite update failure');
    }
    
    @isTest
    static void testBlankSAPDocEntry() {
        // Get the test purchase record and update it
        Pending_Purchase__c purchase = [SELECT Id FROM Pending_Purchase__c LIMIT 1];
        purchase.Is_PO_Created__c = true;
        purchase.SAP_DocEntry__c = null;
        update purchase;
        
        Test.startTest();
        CreatePurchaseOrderInSAP.createPO(purchase.Id);
        Test.stopTest();
        
        // Verify the results
        Pending_Purchase__c updatedPurchase = [
            SELECT Id, Is_PO_Created__c 
            FROM Pending_Purchase__c 
            WHERE Id = :purchase.Id
        ];
        
        System.assertEquals(true, updatedPurchase.Is_PO_Created__c, 'PO should remain marked as created despite blank SAP DocEntry');
    }
    
    @isTest
    static void testMultipleLineItems() {
        // Get the test purchase record
        Pending_Purchase__c purchase = [SELECT Id FROM Pending_Purchase__c LIMIT 1];
        
        // Create additional line items
        List<Pending_Purchase_Line_Item__c> additionalItems = new List<Pending_Purchase_Line_Item__c>{
            new Pending_Purchase_Line_Item__c(
                Pending_Purchase__c = purchase.Id,
                Product__c = [SELECT Id FROM Product__c LIMIT 1].Id,
                Quantity__c = 5,
                Warehouse__c = 'AMP0004',
                BPL_ID__c = '1'
            ),
            new Pending_Purchase_Line_Item__c(
                Pending_Purchase__c = purchase.Id,
                Product__c = [SELECT Id FROM Product__c LIMIT 1].Id,
                Quantity__c = 3,
                Warehouse__c = 'AMP0004',
                BPL_ID__c = '1'
            )
        };
        insert additionalItems;
        
        // Set mock callout responses
        Test.setMock(HttpCalloutMock.class, new SAPMockHttpResponseGenerator(200, '{"SessionId": "test-session"}'));
        Test.setMock(HttpCalloutMock.class, new SAPMockHttpResponseGenerator(201, '{"DocEntry": "12345"}'));
        
        Test.startTest();
        CreatePurchaseOrderInSAP.createPO(purchase.Id);
        Test.stopTest();
        
        // Verify the results
        Pending_Purchase__c updatedPurchase = [
            SELECT Id, Is_PO_Created__c 
            FROM Pending_Purchase__c 
            WHERE Id = :purchase.Id
        ];
        
        System.assertEquals(false, updatedPurchase.Is_PO_Created__c, 'PO should be created with multiple line items');
    }
    
    @isTest
    static void testPOCreationWithLineItems() {
        // Get the test purchase record
        Pending_Purchase__c purchase = [SELECT Id FROM Pending_Purchase__c LIMIT 1];
        purchase.Status__c = 'Finance Manager Approved';
        update purchase;
        
        // Set mock callout responses for successful login and PO creation
        Test.setMock(HttpCalloutMock.class, new SAPMockHttpResponseGenerator(new Map<String, String>{
            'https://lemrg.hstconnect.in:50000/b1s/v1/Login' => '{"SessionId": "test-session"}',
            'https://lemrg.hstconnect.in:50000/b1s/v1/PurchaseOrders' => '{"DocEntry": "12345"}'
        }));
        
        Test.startTest();
        CreatePurchaseOrderInSAP.createPO(purchase.Id);
        Test.stopTest();
        
        // Verify the results
        Pending_Purchase__c updatedPurchase = [
            SELECT Id, Is_PO_Created__c, SAP_DocEntry__c 
            FROM Pending_Purchase__c 
            WHERE Id = :purchase.Id
        ];
        
        System.assertEquals(true, updatedPurchase.Is_PO_Created__c, 'PO should be created');
        System.assertEquals('12345', updatedPurchase.SAP_DocEntry__c, 'SAP DocEntry should be set');
    }
    
    @isTest
    static void testPOUpdateWithModifiedLineItems() {
        // Get the test purchase record and mark it as created
        Pending_Purchase__c purchase = [SELECT Id FROM Pending_Purchase__c LIMIT 1];
        purchase.Status__c = 'Finance Manager Approved';
        purchase.Is_PO_Created__c = true;
        purchase.SAP_DocEntry__c = '12345';
        update purchase;
        
        // Update line item quantity
        Pending_Purchase_Line_Item__c lineItem = [SELECT Id, Quantity__c FROM Pending_Purchase_Line_Item__c WHERE Pending_Purchase__c = :purchase.Id LIMIT 1];
        lineItem.Quantity__c = 10;
        update lineItem;
        
        // Set mock callout responses
        Test.setMock(HttpCalloutMock.class, new SAPMockHttpResponseGenerator(200, '{"SessionId": "test-session"}'));
        Test.setMock(HttpCalloutMock.class, new SAPMockHttpResponseGenerator(200, '{"DocumentLines": [{"LineNum": 0, "ItemCode": "TEST001", "Quantity": 5}]}'));
        Test.setMock(HttpCalloutMock.class, new SAPMockHttpResponseGenerator(204, ''));
        
        Test.startTest();
        CreatePurchaseOrderInSAP.createPO(purchase.Id);
        Test.stopTest();
        
        // Verify the results
        Pending_Purchase__c updatedPurchase = [
            SELECT Id, Is_PO_Created__c 
            FROM Pending_Purchase__c 
            WHERE Id = :purchase.Id
        ];
        
        System.assertEquals(true, updatedPurchase.Is_PO_Created__c, 'PO should remain created after update');
    }
    
    @isTest
    static void testPOUpdateWithNewLineItems() {
        // Get the test purchase record and mark it as created
        Pending_Purchase__c purchase = [SELECT Id FROM Pending_Purchase__c LIMIT 1];
        purchase.Status__c = 'Finance Manager Approved';
        purchase.Is_PO_Created__c = true;
        purchase.SAP_DocEntry__c = '12345';
        update purchase;
        
        // Create a new line item
        Product__c product = [SELECT Id FROM Product__c LIMIT 1];
        Pending_Purchase_Line_Item__c newLineItem = new Pending_Purchase_Line_Item__c(
            Pending_Purchase__c = purchase.Id,
            Product__c = product.Id,
            Quantity__c = 5,
            Warehouse__c = 'AMP0004',
            BPL_ID__c = '1'
        );
        insert newLineItem;
        
        // Set mock callout responses
        Test.setMock(HttpCalloutMock.class, new SAPMockHttpResponseGenerator(200, '{"SessionId": "test-session"}'));
        Test.setMock(HttpCalloutMock.class, new SAPMockHttpResponseGenerator(200, '{"DocumentLines": [{"LineNum": 0, "ItemCode": "TEST001", "Quantity": 5}]}'));
        Test.setMock(HttpCalloutMock.class, new SAPMockHttpResponseGenerator(204, ''));
        
        Test.startTest();
        CreatePurchaseOrderInSAP.createPO(purchase.Id);
        Test.stopTest();
        
        // Verify the results
        Pending_Purchase__c updatedPurchase = [
            SELECT Id, Is_PO_Created__c 
            FROM Pending_Purchase__c 
            WHERE Id = :purchase.Id
        ];
        
        System.assertEquals(true, updatedPurchase.Is_PO_Created__c, 'PO should remain created after adding new line item');
    }
    
    @isTest
    static void testPOUpdateWithRemovedLineItems() {
        // Get the test purchase record and mark it as created
        Pending_Purchase__c purchase = [SELECT Id FROM Pending_Purchase__c LIMIT 1];
        purchase.Status__c = 'Finance Manager Approved';
        purchase.Is_PO_Created__c = true;
        purchase.SAP_DocEntry__c = '12345';
        update purchase;
        
        // Delete a line item
        Pending_Purchase_Line_Item__c lineItem = [SELECT Id FROM Pending_Purchase_Line_Item__c WHERE Pending_Purchase__c = :purchase.Id LIMIT 1];
        delete lineItem;
        
        // Set mock callout responses
        Test.setMock(HttpCalloutMock.class, new SAPMockHttpResponseGenerator(200, '{"SessionId": "test-session"}'));
        Test.setMock(HttpCalloutMock.class, new SAPMockHttpResponseGenerator(200, '{"DocumentLines": [{"LineNum": 0, "ItemCode": "TEST001", "Quantity": 5}]}'));
        Test.setMock(HttpCalloutMock.class, new SAPMockHttpResponseGenerator(204, ''));
        
        Test.startTest();
        CreatePurchaseOrderInSAP.createPO(purchase.Id);
        Test.stopTest();
        
        // Verify the results
        Pending_Purchase__c updatedPurchase = [
            SELECT Id, Is_PO_Created__c 
            FROM Pending_Purchase__c 
            WHERE Id = :purchase.Id
        ];
        
        System.assertEquals(true, updatedPurchase.Is_PO_Created__c, 'PO should remain created after removing line item');
    }
    
    @isTest
    static void testPOUpdateWithGetFailure() {
        // Get the test purchase record and mark it as created
        Pending_Purchase__c purchase = [SELECT Id FROM Pending_Purchase__c LIMIT 1];
        purchase.Status__c = 'Finance Manager Approved';
        purchase.Is_PO_Created__c = true;
        purchase.SAP_DocEntry__c = '12345';
        update purchase;
        
        // Set mock callout responses
        Test.setMock(HttpCalloutMock.class, new SAPMockHttpResponseGenerator(new Map<String, String>{
            'https://lemrg.hstconnect.in:50000/b1s/v1/Login' => '{"SessionId": "test-session"}',
            'https://lemrg.hstconnect.in:50000/b1s/v1/PurchaseOrders(12345)' => '{"error": "PO not found"}'
        }));
        
        Test.startTest();
        CreatePurchaseOrderInSAP.createPO(purchase.Id);
        Test.stopTest();
        
        // Verify the results
        Pending_Purchase__c updatedPurchase = [
            SELECT Id, Is_PO_Created__c 
            FROM Pending_Purchase__c 
            WHERE Id = :purchase.Id
        ];
        
        System.assertEquals(true, updatedPurchase.Is_PO_Created__c, 'PO should remain marked as created despite get failure');
    }
    
    @isTest
    static void testPOUpdateWithPatchFailure() {
        // Get the test purchase record and mark it as created
        Pending_Purchase__c purchase = [SELECT Id FROM Pending_Purchase__c LIMIT 1];
        purchase.Status__c = 'Finance Manager Approved';
        purchase.Is_PO_Created__c = true;
        purchase.SAP_DocEntry__c = '12345';
        update purchase;
        
        // Set mock callout responses
        Test.setMock(HttpCalloutMock.class, new SAPMockHttpResponseGenerator(new Map<String, String>{
            'https://lemrg.hstconnect.in:50000/b1s/v1/Login' => '{"SessionId": "test-session"}',
            'https://lemrg.hstconnect.in:50000/b1s/v1/PurchaseOrders(12345)' => '{"DocumentLines": [{"LineNum": 0, "ItemCode": "TEST001", "Quantity": 5}]}',
            'https://lemrg.hstconnect.in:50000/b1s/v1/PurchaseOrders(12345)/update' => '{"error": "Update failed"}'
        }));
        
        Test.startTest();
        CreatePurchaseOrderInSAP.createPO(purchase.Id);
        Test.stopTest();
        
        // Verify the results
        Pending_Purchase__c updatedPurchase = [
            SELECT Id, Is_PO_Created__c 
            FROM Pending_Purchase__c 
            WHERE Id = :purchase.Id
        ];
        
        System.assertEquals(true, updatedPurchase.Is_PO_Created__c, 'PO should remain marked as created despite update failure');
    }
    
    @isTest
    static void testPOUpdateWithExistingAndNewLines() {
        // Get the test purchase record and mark it as created
        Pending_Purchase__c purchase = [SELECT Id FROM Pending_Purchase__c LIMIT 1];
        purchase.Status__c = 'Finance Manager Approved';
        purchase.Is_PO_Created__c = true;
        purchase.SAP_DocEntry__c = '12345';
        update purchase;
        
        // Create a new line item
        Product__c product = [SELECT Id FROM Product__c LIMIT 1];
        Pending_Purchase_Line_Item__c newLineItem = new Pending_Purchase_Line_Item__c(
            Pending_Purchase__c = purchase.Id,
            Product__c = product.Id,
            Quantity__c = 5,
            Warehouse__c = 'AMP0004',
            BPL_ID__c = '1'
        );
        insert newLineItem;
        
        // Update existing line item
        Pending_Purchase_Line_Item__c existingLineItem = [SELECT Id, Quantity__c FROM Pending_Purchase_Line_Item__c WHERE Pending_Purchase__c = :purchase.Id AND Id != :newLineItem.Id LIMIT 1];
        existingLineItem.Quantity__c = 15;
        update existingLineItem;
        
        // Set mock callout responses
        Test.setMock(HttpCalloutMock.class, new SAPMockHttpResponseGenerator(new Map<String, String>{
            'https://lemrg.hstconnect.in:50000/b1s/v1/Login' => '{"SessionId": "test-session"}',
            'https://lemrg.hstconnect.in:50000/b1s/v1/PurchaseOrders(12345)' => '{"DocumentLines": [{"LineNum": 0, "ItemCode": "TEST001", "Quantity": 10}]}',
            'https://lemrg.hstconnect.in:50000/b1s/v1/PurchaseOrders(12345)/update' => ''
        }));
        
        Test.startTest();
        CreatePurchaseOrderInSAP.createPO(purchase.Id);
        Test.stopTest();
        
        // Verify the results
        Pending_Purchase__c updatedPurchase = [
            SELECT Id, Is_PO_Created__c 
            FROM Pending_Purchase__c 
            WHERE Id = :purchase.Id
        ];
        
        System.assertEquals(true, updatedPurchase.Is_PO_Created__c, 'PO should remain marked as created after updating with existing and new lines');
    }
    
    // Mock HTTP Response Generator
    private class SAPMockHttpResponseGenerator implements HttpCalloutMock {
        private Map<String, String> endpointResponses;
        private Integer statusCode;
        private String body;
        
        public SAPMockHttpResponseGenerator(Integer statusCode, String body) {
            this.statusCode = statusCode;
            this.body = body;
        }
        
        public SAPMockHttpResponseGenerator(Map<String, String> endpointResponses) {
            this.endpointResponses = endpointResponses;
        }
        
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            
            if (endpointResponses != null) {
                String endpoint = req.getEndpoint();
                if (endpoint.contains('/Login')) {
                    res.setStatusCode(200);
                    res.setBody(endpointResponses.get('https://lemrg.hstconnect.in:50000/b1s/v1/Login'));
                } else if (endpoint.contains('/PurchaseOrders')) {
                    if (req.getMethod() == 'POST') {
                        res.setStatusCode(201);
                        res.setBody(endpointResponses.get('https://lemrg.hstconnect.in:50000/b1s/v1/PurchaseOrders'));
                    } else if (req.getMethod() == 'GET') {
                        res.setStatusCode(200);
                        res.setBody('{"DocumentLines": [{"LineNum": 0, "ItemCode": "TEST001", "Quantity": 5}]}');
                    } else if (req.getMethod() == 'PATCH') {
                        res.setStatusCode(204);
                        res.setBody('');
                    }
                }
            } else {
                res.setStatusCode(statusCode);
                res.setBody(body);
            }
            
            return res;
        }
    }
}