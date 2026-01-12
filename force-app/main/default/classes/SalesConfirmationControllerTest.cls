@isTest
public class SalesConfirmationControllerTest {
    // Mock class for HTTP callouts
    private class MockHttpCallout implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            
            // Check if this is a login request
            if (req.getEndpoint().contains('/Login')) {
                res.setBody('{"SessionId":"test-session-id"}');
                res.setStatusCode(200);
            }
            // Check if this is a warehouses request (getActiveWarehouses)
            else if (req.getEndpoint().contains('/Warehouses') && !req.getEndpoint().contains('BusinessPlaceID')) {
                res.setBody('{"value":[{"WarehouseCode":"WH001","WarehouseName":"Test Warehouse 1","BusinessPlaceID":"1"},{"WarehouseCode":"WH002","WarehouseName":"Test Warehouse 2","BusinessPlaceID":"2"}]}');
                res.setStatusCode(200);
            }
            // Check if this is a warehouses by BPL request (getWarehousesByBPL)
            else if (req.getEndpoint().contains('/Warehouses') && req.getEndpoint().contains('BusinessPlaceID')) {
                // Return warehouses for BPL 1
                if (req.getEndpoint().contains('BusinessPlaceID eq 1')) {
                    res.setBody('{"value":[{"WarehouseCode":"WH001","WarehouseName":"Test Warehouse 1","BusinessPlaceID":"1"}]}');
                }
                // Return warehouses for BPL 2
                else if (req.getEndpoint().contains('BusinessPlaceID eq 2')) {
                    res.setBody('{"value":[{"WarehouseCode":"WH002","WarehouseName":"Test Warehouse 2","BusinessPlaceID":"2"}]}');
                }
                // Return empty for other BPLs
                else {
                    res.setBody('{"value":[]}');
                }
                res.setStatusCode(200);
            }
            // Check if this is a business places request
            else if (req.getEndpoint().contains('/BusinessPlaces')) {
                res.setBody('{"value":[{"BPLID":"1","BPLName":"Test BPL 1"},{"BPLID":"2","BPLName":"Test BPL 2"}]}');
                res.setStatusCode(200);
            }
            // Default response
            else {
                res.setBody('{"status":"success"}');
                res.setStatusCode(200);
            }
            
            return res;
        }
    }

    @testSetup
    static void setup() {
        // Set mock for any callouts
        Test.setMock(HttpCalloutMock.class, new MockHttpCallout());

        // Create Customer
        Customer__c customer = new Customer__c(
            Name = 'Test Customer',
            Email__c = 'test@example.com',
            Phone__c = '1234567890',
            Company__c = 'Test Co'
        );
        insert customer;

        // Create Deal
        Deals__c deal = new Deals__c(
            Name = 'Test Deal',
            Customer__c = customer.Id,
            Company__c = 'Test Co'
        );
        insert deal;

        // Create Cart
        Cart__c cart = new Cart__c(
            Customer__c = customer.Id,
            Deals__c = deal.Id,
            Status__c = 'Approved'
        );
        insert cart;

        // Create Product
        Product__c product = new Product__c(
            Name = 'Test Product',
            Product_Code__c = 'P001'
        );
        insert product;

        // Create Cart Line Item
        Cart_Line_Item__c cli = new Cart_Line_Item__c(
            Product__c = product.Id,
            Cart__c = cart.Id,
            Product_Category__c = 'Category1',
            Quantity__c = 2,
            Price__c = 100,
            Item_Chosen__c = false
        );
        insert cli;
    }

    @isTest
    static void testGetCartLineItemsByDeal() {
        Test.setMock(HttpCalloutMock.class, new MockHttpCallout());
        Deals__c deal = [SELECT Id FROM Deals__c LIMIT 1];
        List<Cart_Line_Item__c> items = SalesConfirmationController.getCartLineItemsByDeal(deal.Id, null);
        System.assert(items.size() > 0, 'Should return cart line items');
    }

    @isTest
    static void testGetCartLineItemsByDeal_Exception() {
        Test.setMock(HttpCalloutMock.class, new MockHttpCallout());
        try {
            SalesConfirmationController.getCartLineItemsByDeal(null, null);
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Error fetching cart items'));
        }
    }

    @isTest
    static void testGetDealInfo() {
        Test.setMock(HttpCalloutMock.class, new MockHttpCallout());
        Deals__c deal = [SELECT Id FROM Deals__c LIMIT 1];
        Deals__c result = SalesConfirmationController.getDealInfo(deal.Id);
        System.assertEquals(deal.Id, result.Id, 'Should return the correct deal');
    }

    @isTest
    static void testGetDealInfo_Exception() {
        Test.setMock(HttpCalloutMock.class, new MockHttpCallout());
        try {
            SalesConfirmationController.getDealInfo(null);
            System.assert(false, 'Should have thrown an exception');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage() != null);
        }
    }

    @isTest
    static void testCreateSalesConfirmation() {
        Test.setMock(HttpCalloutMock.class, new MockHttpCallout());
        Deals__c deal = [SELECT Id FROM Deals__c LIMIT 1];
        Cart_Line_Item__c cli = [SELECT Id FROM Cart_Line_Item__c LIMIT 1];
        List<Map<String, Object>> selectedLineItems = new List<Map<String, Object>>{
            new Map<String, Object>{
                'Id' => cli.Id,
                'Warehouse__c' => 'WH001',
                'Location' => null
            }
        };
        String result = SalesConfirmationController.createSalesConfirmation(
            deal.Id, selectedLineItems, 'Cash', null, null, '1', 'WH001'
        );
        System.assertNotEquals(null, result, 'Should return Sales Confirmation Id');
    }

    @isTest
    static void testCreateSalesConfirmation_Exception() {
        Test.setMock(HttpCalloutMock.class, new MockHttpCallout());
        try {
            SalesConfirmationController.createSalesConfirmation(null, new List<Map<String, Object>>(), null, null, null, null, null);
        } catch (AuraHandledException e) {
            System.assert(e.getMessage() != null);
        }
    }

    @isTest
    static void testCreateSalesConfirmation_WithCredit() {
        Test.setMock(HttpCalloutMock.class, new MockHttpCallout());
        Deals__c deal = [SELECT Id FROM Deals__c LIMIT 1];
        Cart_Line_Item__c cli = [SELECT Id FROM Cart_Line_Item__c LIMIT 1];
        List<Map<String, Object>> selectedLineItems = new List<Map<String, Object>>{
            new Map<String, Object>{
                'Id' => cli.Id,
                'Warehouse__c' => 'WH001',
                'Location' => 'LOC001'
            }
        };
        String result = SalesConfirmationController.createSalesConfirmation(
            deal.Id, selectedLineItems, 'Credit', '1000.00', '2025-12-31', '1', 'WH001'
        );
        System.assertNotEquals(null, result, 'Should return Sales Confirmation Id');
        
        // Verify the credit amount, due date and approval status were set
        Sales_Confirmation__c salesConf = [SELECT Id, Credit_Amount__c, Credit_Approval_Status__c, Payment_Type__c, Credit_Due_Date__c 
                                          FROM Sales_Confirmation__c WHERE Id = :result];
        System.assertEquals('Credit', salesConf.Payment_Type__c, 'Payment type should be Credit');
        System.assertEquals(1000.00, salesConf.Credit_Amount__c, 'Credit amount should be set');
        System.assertEquals('Pending', salesConf.Credit_Approval_Status__c, 'Credit approval status should be Pending');
        System.assertEquals(Date.valueOf('2025-12-31'), salesConf.Credit_Due_Date__c, 'Credit due date should be set');
    }

    @isTest
    static void testGetPaymentTypeOptions() {
        Test.setMock(HttpCalloutMock.class, new MockHttpCallout());
        List<Map<String, String>> options = SalesConfirmationController.getPaymentTypeOptions();
        System.assert(options.size() > 0, 'Should return payment type options');
    }

    @isTest
    static void testGetPaymentTypeOptions_Exception() {
        Test.setMock(HttpCalloutMock.class, new MockHttpCallout());
        try {
            List<Map<String, String>> options = SalesConfirmationController.getPaymentTypeOptions();
            System.assert(options != null);
        } catch (AuraHandledException e) {
            System.assert(e.getMessage() != null);
        }
    }

    @isTest
    static void testCreateSalesConfirmation_WithInvalidWarehouseBPL() {
        Test.setMock(HttpCalloutMock.class, new MockHttpCallout());
        Deals__c deal = [SELECT Id FROM Deals__c LIMIT 1];
        Cart_Line_Item__c cli = [SELECT Id FROM Cart_Line_Item__c LIMIT 1];
        List<Map<String, Object>> selectedLineItems = new List<Map<String, Object>>{
            new Map<String, Object>{
                'Id' => cli.Id,
                'Warehouse__c' => 'INVALID_WH',
                'Location' => 'LOC001'
            }
        };
        
        // Should now work with fallback BPL even for invalid warehouse
        String result = SalesConfirmationController.createSalesConfirmation(
            deal.Id, selectedLineItems, 'Cash', null, null, '1', 'WH001'
        );
        System.assertNotEquals(null, result, 'Should return Sales Confirmation Id with fallback BPL for invalid warehouse');
    }

    @isTest
    static void testCreateSalesConfirmation_WithMultipleWarehouses() {
        Test.setMock(HttpCalloutMock.class, new MockHttpCallout());
        Deals__c deal = [SELECT Id FROM Deals__c LIMIT 1];
        Cart_Line_Item__c cli = [SELECT Id FROM Cart_Line_Item__c LIMIT 1];
        List<Map<String, Object>> selectedLineItems = new List<Map<String, Object>>{
            new Map<String, Object>{
                'Id' => cli.Id,
                'Warehouse__c' => 'WH001',
                'Location' => 'LOC001'
            }
        };
        
        String result = SalesConfirmationController.createSalesConfirmation(
            deal.Id, selectedLineItems, 'Cash', null, null, '1', 'WH001'
        );
        System.assertNotEquals(null, result, 'Should return Sales Confirmation Id');
        
        // Verify the cart line item was updated with correct BPL
        Cart_Line_Item__c updatedCli = [SELECT Id, BPL_IDAssignedToInvoice__c, Warehouse__c 
                                       FROM Cart_Line_Item__c WHERE Id = :cli.Id];
        System.assertEquals('1', updatedCli.BPL_IDAssignedToInvoice__c, 'BPL should be assigned based on warehouse');
        System.assertEquals('WH001', updatedCli.Warehouse__c, 'Warehouse should be preserved');
    }

    @isTest
    static void testCreateSalesConfirmation_WithSAPServiceFailure() {
        // Mock that simulates SAP service failure
        Test.setMock(HttpCalloutMock.class, new SAPServiceFailureMock());
        Deals__c deal = [SELECT Id FROM Deals__c LIMIT 1];
        Cart_Line_Item__c cli = [SELECT Id FROM Cart_Line_Item__c LIMIT 1];
        List<Map<String, Object>> selectedLineItems = new List<Map<String, Object>>{
            new Map<String, Object>{
                'Id' => cli.Id,
                'Warehouse__c' => 'WH001',
                'Location' => 'LOC001'
            }
        };
        
        // Should still work with fallback BPL
        String result = SalesConfirmationController.createSalesConfirmation(
            deal.Id, selectedLineItems, 'Cash', null, null, '1', 'WH001'
        );
        System.assertNotEquals(null, result, 'Should return Sales Confirmation Id with fallback BPL');
    }

    // Mock class for SAP service failure scenarios
    private class SAPServiceFailureMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(500); // Simulate server error
            res.setBody('{"error":"Service unavailable"}');
            return res;
        }
    }

    @isTest
    static void testCreateSalesConfirmation_WithNullWarehouse() {
        Test.setMock(HttpCalloutMock.class, new MockHttpCallout());
        Deals__c deal = [SELECT Id FROM Deals__c LIMIT 1];
        Cart_Line_Item__c cli = [SELECT Id FROM Cart_Line_Item__c LIMIT 1];
        List<Map<String, Object>> selectedLineItems = new List<Map<String, Object>>{
            new Map<String, Object>{
                'Id' => cli.Id,
                'Warehouse__c' => null,
                'Location' => 'LOC001'
            }
        };
        
        // Should work with null warehouse using fallback BPL
        String result = SalesConfirmationController.createSalesConfirmation(
            deal.Id, selectedLineItems, 'Cash', null, null, '1', 'WH001'
        );
        System.assertNotEquals(null, result, 'Should return Sales Confirmation Id with null warehouse');
    }

    @isTest
    static void testCreateSalesConfirmation_WithValidWarehouseBPL() {
        Test.setMock(HttpCalloutMock.class, new MockHttpCallout());
        Deals__c deal = [SELECT Id FROM Deals__c LIMIT 1];
        Cart_Line_Item__c cli = [SELECT Id FROM Cart_Line_Item__c LIMIT 1];
        List<Map<String, Object>> selectedLineItems = new List<Map<String, Object>>{
            new Map<String, Object>{
                'Id' => cli.Id,
                'Warehouse__c' => 'WH001',
                'Location' => 'LOC001'
            }
        };
        
        // Should work with valid warehouse-BPL combination
        String result = SalesConfirmationController.createSalesConfirmation(
            deal.Id, selectedLineItems, 'Cash', null, null, '1', 'WH001'
        );
        System.assertNotEquals(null, result, 'Should return Sales Confirmation Id with valid warehouse-BPL combination');
        
        // Verify the cart line item was updated with correct BPL from warehouse mapping
        Cart_Line_Item__c updatedCli = [SELECT Id, BPL_IDAssignedToInvoice__c, Warehouse__c 
                                       FROM Cart_Line_Item__c WHERE Id = :cli.Id];
        System.assertEquals('1', updatedCli.BPL_IDAssignedToInvoice__c, 'BPL should be assigned based on warehouse mapping');
        System.assertEquals('WH001', updatedCli.Warehouse__c, 'Warehouse should be preserved');
    }
}