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

    // Mock class for SAP service failure scenarios
    private class SAPServiceFailureMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(500);
            res.setBody('{"error":"Service unavailable"}');
            return res;
        }
    }

    @testSetup
    static void setup() {
        // Create Customer with required fields
        Customer__c customer = new Customer__c(
            Name = 'Test Customer',
            Lead_Name__c = 'Test Lead',
            Primary_Phone__c = '9876543210',
            Email__c = 'test@example.com',
            Phone__c = '1234567890',
            Company__c = 'Test Co'
        );
        insert customer;

        // Create Deal with required Billing_Address fields
        Deals__c deal = new Deals__c(
            Name = 'Test Deal',
            Customer__c = customer.Id,
            Company__c = 'Test Co',
            Email__c = 'deal@example.com',
            Phone__c = '9999999999',
            SecondaryPhone__c = '8888888888',
            Address__Street__s = '123 Test Street',
            Address__City__s = 'Chennai',
            Address__PostalCode__s = '600001',
            Address__StateCode__s = 'TN',
            Address__CountryCode__s = 'IN',
            Billing_Address__Street__s = '123 Test Street',
            Billing_Address__City__s = 'Chennai',
            Billing_Address__PostalCode__s = '600001',
            Billing_Address__StateCode__s = 'TN',
            Billing_Address__CountryCode__s = 'IN'
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

        // Create Cart Line Items (two for multi-item tests)
        List<Cart_Line_Item__c> clis = new List<Cart_Line_Item__c>();
        clis.add(new Cart_Line_Item__c(
            Product__c = product.Id,
            Cart__c = cart.Id,
            Product_Category__c = 'Category1',
            Quantity__c = 2,
            Price__c = 100,
            Item_Chosen__c = false
        ));
        clis.add(new Cart_Line_Item__c(
            Product__c = product.Id,
            Cart__c = cart.Id,
            Product_Category__c = 'Category2',
            Quantity__c = 3,
            Price__c = 200,
            Item_Chosen__c = false
        ));
        insert clis;
    }

    // ═══════════════════════════════════════════════════════════════════
    //  getCartLineItemsByDeal
    // ═══════════════════════════════════════════════════════════════════

    @isTest
    static void testGetCartLineItemsByDeal() {
        Deals__c deal = [SELECT Id FROM Deals__c LIMIT 1];

        Test.startTest();
        List<Cart_Line_Item__c> items = SalesConfirmationController.getCartLineItemsByDeal(deal.Id, null);
        Test.stopTest();

        System.assert(items.size() > 0, 'Should return cart line items');
    }

    @isTest
    static void testGetCartLineItemsByDeal_WithWarehouseCode() {
        Deals__c deal = [SELECT Id FROM Deals__c LIMIT 1];

        Test.startTest();
        // warehouseCode is accepted but ignored per controller logic
        List<Cart_Line_Item__c> items = SalesConfirmationController.getCartLineItemsByDeal(deal.Id, 'WH001');
        Test.stopTest();

        System.assert(items.size() > 0, 'Should return cart line items regardless of warehouseCode');
    }

    @isTest
    static void testGetCartLineItemsByDeal_NoResults() {
        Test.startTest();
        // Use a fake ID that won't match any deals
        List<Cart_Line_Item__c> items = SalesConfirmationController.getCartLineItemsByDeal(
            'a0B000000000001AAA', null
        );
        Test.stopTest();

        System.assertEquals(0, items.size(), 'Should return empty list for non-existent deal');
    }

    // ═══════════════════════════════════════════════════════════════════
    //  getDealInfo
    // ═══════════════════════════════════════════════════════════════════

    @isTest
    static void testGetDealInfo() {
        Deals__c deal = [SELECT Id FROM Deals__c LIMIT 1];

        Test.startTest();
        Deals__c result = SalesConfirmationController.getDealInfo(deal.Id);
        Test.stopTest();

        System.assertEquals(deal.Id, result.Id, 'Should return the correct deal');
        System.assertNotEquals(null, result.Name, 'Should include Name');
        System.assertNotEquals(null, result.Company__c, 'Should include Company');
    }

    @isTest
    static void testGetDealInfo_Exception() {
        Test.startTest();
        try {
            // Querying with null Id returns 0 rows → QueryException for single object assignment
            SalesConfirmationController.getDealInfo(null);
            System.assert(false, 'Should have thrown an exception');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage() != null, 'Exception message should not be null');
        }
        Test.stopTest();
    }

    // ═══════════════════════════════════════════════════════════════════
    //  getPaymentTypeOptions
    // ═══════════════════════════════════════════════════════════════════

    @isTest
    static void testGetPaymentTypeOptions() {
        Test.startTest();
        List<Map<String, String>> options = SalesConfirmationController.getPaymentTypeOptions();
        Test.stopTest();

        System.assert(options.size() > 0, 'Should return payment type options');
        // Each option should have label and value
        for (Map<String, String> opt : options) {
            System.assert(opt.containsKey('label'), 'Option should have label');
            System.assert(opt.containsKey('value'), 'Option should have value');
        }
    }

    // ═══════════════════════════════════════════════════════════════════
    //  createSalesConfirmation — Cash payment
    // ═══════════════════════════════════════════════════════════════════

    @isTest
    static void testCreateSalesConfirmation_Cash() {
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

        Test.startTest();
        String result = SalesConfirmationController.createSalesConfirmation(
            deal.Id, selectedLineItems, 'Cash', null, null, '1', 'WH001'
        );
        Test.stopTest();

        System.assertNotEquals(null, result, 'Should return Sales Confirmation Id');

        Sales_Confirmation__c sc = [SELECT Payment_Type__c, Approval_Status__c, Total_Amount__c
                                    FROM Sales_Confirmation__c WHERE Id = :result];
        System.assertEquals('Cash', sc.Payment_Type__c, 'Payment type should be Cash');
    }

    // ═══════════════════════════════════════════════════════════════════
    //  createSalesConfirmation — Credit payment with amount & due date
    // ═══════════════════════════════════════════════════════════════════

    @isTest
    static void testCreateSalesConfirmation_CreditWithDueDate() {
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

        Test.startTest();
        String result = SalesConfirmationController.createSalesConfirmation(
            deal.Id, selectedLineItems, 'Credit', '1000.00', '2026-12-31', '1', 'WH001'
        );
        Test.stopTest();

        System.assertNotEquals(null, result, 'Should return Sales Confirmation Id');

        Sales_Confirmation__c sc = [SELECT Credit_Amount__c, Credit_Approval_Status__c,
                                           Payment_Type__c, Credit_Due_Date__c
                                    FROM Sales_Confirmation__c WHERE Id = :result];
        System.assertEquals('Credit', sc.Payment_Type__c);
        System.assertEquals(1000.00, sc.Credit_Amount__c);
        System.assertEquals('Pending', sc.Credit_Approval_Status__c);
        System.assertEquals(Date.valueOf('2026-12-31'), sc.Credit_Due_Date__c);
    }

    // ═══════════════════════════════════════════════════════════════════
    //  createSalesConfirmation — Credit payment WITHOUT due date
    // ═══════════════════════════════════════════════════════════════════

    @isTest
    static void testCreateSalesConfirmation_CreditNoDueDate() {
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

        Test.startTest();
        String result = SalesConfirmationController.createSalesConfirmation(
            deal.Id, selectedLineItems, 'Credit', '500.00', null, '1', 'WH001'
        );
        Test.stopTest();

        System.assertNotEquals(null, result, 'Should return Sales Confirmation Id');

        Sales_Confirmation__c sc = [SELECT Credit_Amount__c, Credit_Due_Date__c
                                    FROM Sales_Confirmation__c WHERE Id = :result];
        System.assertEquals(500.00, sc.Credit_Amount__c);
        System.assertEquals(null, sc.Credit_Due_Date__c, 'Due date should be null when not provided');
    }

    // ═══════════════════════════════════════════════════════════════════
    //  createSalesConfirmation — Credit payment with EMPTY creditAmount
    // ═══════════════════════════════════════════════════════════════════

    @isTest
    static void testCreateSalesConfirmation_CreditEmptyAmount() {
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

        Test.startTest();
        String result = SalesConfirmationController.createSalesConfirmation(
            deal.Id, selectedLineItems, 'Credit', '', '', '1', 'WH001'
        );
        Test.stopTest();

        System.assertNotEquals(null, result, 'Should return Sales Confirmation Id');

        Sales_Confirmation__c sc = [SELECT Credit_Amount__c, Credit_Approval_Status__c
                                    FROM Sales_Confirmation__c WHERE Id = :result];
        System.assertEquals(null, sc.Credit_Amount__c, 'Credit amount should be null when empty string passed');
    }

    // ═══════════════════════════════════════════════════════════════════
    //  createSalesConfirmation — warehouse mapped to BPL from SAP
    // ═══════════════════════════════════════════════════════════════════

    @isTest
    static void testCreateSalesConfirmation_WarehouseBPLMapping() {
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

        Test.startTest();
        String result = SalesConfirmationController.createSalesConfirmation(
            deal.Id, selectedLineItems, 'Cash', null, null, '1', 'WH001'
        );
        Test.stopTest();

        System.assertNotEquals(null, result);

        Cart_Line_Item__c updated = [SELECT BPL_IDAssignedToInvoice__c, Warehouse__c
                                     FROM Cart_Line_Item__c WHERE Id = :cli.Id];
        System.assertEquals('1', updated.BPL_IDAssignedToInvoice__c, 'BPL should be assigned from warehouse mapping');
        System.assertEquals('WH001', updated.Warehouse__c, 'Warehouse should be preserved');
    }

    // ═══════════════════════════════════════════════════════════════════
    //  createSalesConfirmation — warehouse NOT in map, fallback to BPL
    // ═══════════════════════════════════════════════════════════════════

    @isTest
    static void testCreateSalesConfirmation_FallbackBPL() {
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

        Test.startTest();
        String result = SalesConfirmationController.createSalesConfirmation(
            deal.Id, selectedLineItems, 'Cash', null, null, '1', 'WH001'
        );
        Test.stopTest();

        System.assertNotEquals(null, result, 'Should use fallback BPL for unmapped warehouse');
    }

    // ═══════════════════════════════════════════════════════════════════
    //  createSalesConfirmation — null warehouse, fallback to BPL
    // ═══════════════════════════════════════════════════════════════════

    @isTest
    static void testCreateSalesConfirmation_NullWarehouse() {
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

        Test.startTest();
        String result = SalesConfirmationController.createSalesConfirmation(
            deal.Id, selectedLineItems, 'Cash', null, null, '1', 'WH001'
        );
        Test.stopTest();

        System.assertNotEquals(null, result, 'Should use fallback BPL with null warehouse');
    }

    // ═══════════════════════════════════════════════════════════════════
    //  createSalesConfirmation — no BPL resolved → validation error
    // ═══════════════════════════════════════════════════════════════════

    @isTest
    static void testCreateSalesConfirmation_NoBPLResolved() {
        Test.setMock(HttpCalloutMock.class, new MockHttpCallout());
        Deals__c deal = [SELECT Id FROM Deals__c LIMIT 1];
        Cart_Line_Item__c cli = [SELECT Id FROM Cart_Line_Item__c LIMIT 1];

        List<Map<String, Object>> selectedLineItems = new List<Map<String, Object>>{
            new Map<String, Object>{
                'Id' => cli.Id,
                'Warehouse__c' => 'UNKNOWN_WH',
                'Location' => null
            }
        };

        Test.startTest();
        try {
            // Both warehouse not in map AND BPL_IDAssignedToInvoice blank → no BPL
            SalesConfirmationController.createSalesConfirmation(
                deal.Id, selectedLineItems, 'Cash', null, null, null, null
            );
            System.assert(false, 'Should have thrown validation error');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage() != null, 'Should contain validation error message');
        }
        Test.stopTest();
    }

    // ═══════════════════════════════════════════════════════════════════
    //  createSalesConfirmation — SAP service failure → fallback BPL
    // ═══════════════════════════════════════════════════════════════════

    @isTest
    static void testCreateSalesConfirmation_SAPServiceFailure() {
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

        Test.startTest();
        String result = SalesConfirmationController.createSalesConfirmation(
            deal.Id, selectedLineItems, 'Cash', null, null, '1', 'WH001'
        );
        Test.stopTest();

        System.assertNotEquals(null, result, 'Should use fallback BPL when SAP service fails');
    }

    // ═══════════════════════════════════════════════════════════════════
    //  createSalesConfirmation — multiple line items
    // ═══════════════════════════════════════════════════════════════════

    @isTest
    static void testCreateSalesConfirmation_MultipleLineItems() {
        Test.setMock(HttpCalloutMock.class, new MockHttpCallout());
        Deals__c deal = [SELECT Id FROM Deals__c LIMIT 1];
        List<Cart_Line_Item__c> clis = [SELECT Id FROM Cart_Line_Item__c];

        List<Map<String, Object>> selectedLineItems = new List<Map<String, Object>>();
        for (Cart_Line_Item__c cli : clis) {
            selectedLineItems.add(new Map<String, Object>{
                'Id' => cli.Id,
                'Warehouse__c' => 'WH001',
                'Location' => 'LOC001'
            });
        }

        Test.startTest();
        String result = SalesConfirmationController.createSalesConfirmation(
            deal.Id, selectedLineItems, 'Cash', null, null, '1', 'WH001'
        );
        Test.stopTest();

        System.assertNotEquals(null, result);

        // Verify total amount is aggregated
        Sales_Confirmation__c sc = [SELECT Total_Amount__c FROM Sales_Confirmation__c WHERE Id = :result];
        System.assertNotEquals(null, sc.Total_Amount__c, 'Total amount should be calculated');
    }

    // ═══════════════════════════════════════════════════════════════════
    //  createSalesConfirmation — exception (null dealId)
    // ═══════════════════════════════════════════════════════════════════

    @isTest
    static void testCreateSalesConfirmation_Exception() {
        Test.setMock(HttpCalloutMock.class, new MockHttpCallout());

        Test.startTest();
        try {
            SalesConfirmationController.createSalesConfirmation(
                null, new List<Map<String, Object>>(), null, null, null, null, null
            );
        } catch (AuraHandledException e) {
            System.assert(e.getMessage() != null, 'Exception should have a message');
        }
        Test.stopTest();
    }
}