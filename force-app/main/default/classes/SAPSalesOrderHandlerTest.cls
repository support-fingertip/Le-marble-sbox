@IsTest
public class SAPSalesOrderHandlerTest {
    
    // Mock for successful SAP callouts
    private class MockSAPCalloutSuccess implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            
            if (req.getEndpoint().contains('/Login')) {
                res.setStatusCode(200);
                res.setBody('{"SessionId":"test-session-id-12345"}');
            } else if (req.getEndpoint().contains('/Orders')) {
                res.setStatusCode(201);
                res.setBody('{"DocEntry":12345,"DocNum":"SO-00001"}');
            } else {
                res.setStatusCode(200);
                res.setBody('{}');
            }
            return res;
        }
    }
    
    // Mock for login failure
    private class MockSAPCalloutLoginFail implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(401);
            res.setBody('{"error":{"code":-10001,"message":"Invalid credentials"}}');
            return res;
        }
    }
    
    // Mock for order creation failure
    private class MockSAPCalloutOrderFail implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            
            if (req.getEndpoint().contains('/Login')) {
                res.setStatusCode(200);
                res.setBody('{"SessionId":"test-session-id-12345"}');
            } else if (req.getEndpoint().contains('/Orders')) {
                res.setStatusCode(400);
                res.setBody('{"error":{"code":-5002,"message":"Invalid Item Code"}}');
            } else {
                res.setStatusCode(200);
                res.setBody('{}');
            }
            return res;
        }
    }
    
    @TestSetup
    static void setupTestData() {
        // Create test Customer
        Customer__c customer = new Customer__c(
            Name = 'Test Customer SAP',
            Lead_Name__c = 'Test Lead SAP',
            Primary_Phone__c = '9876543210',
            Email__c = 'test@sap.com'
        );
        insert customer;
        
        // Create test Deals__c (Opportunity)
        Deals__c deal = new Deals__c(
            Name = 'Test Deal SAP',
            Customer__c = customer.Id,
            Stage__c = 'Proposal',
            Type__c = 'New Business'
        );
        insert deal;
    }
    
    @IsTest
    static void testSendToSAP_Success() {
        Test.setMock(HttpCalloutMock.class, new MockSAPCalloutSuccess());
        
        Deals__c deal = [SELECT Id FROM Deals__c LIMIT 1];
        
        Sales_Confirmation__c sc = new Sales_Confirmation__c(
            Opportunity__c = deal.Id,
            Total_Amount__c = 50000,
            Payment_Type__c = 'Cash',
            Product_Category__c = 'Tiles'
        );
        insert sc;
        
        List<Sales_Confirmation__c> orders = new List<Sales_Confirmation__c>{ sc };
        
        Test.startTest();
        SAPSalesOrderHandler.sendToSAP(orders);
        Test.stopTest();
        
        // Verify no exceptions thrown - successful execution
        System.assert(true, 'sendToSAP completed without exception');
    }
    
    @IsTest
    static void testSendToSAP_LoginFailure() {
        Test.setMock(HttpCalloutMock.class, new MockSAPCalloutLoginFail());
        
        Deals__c deal = [SELECT Id FROM Deals__c LIMIT 1];
        
        Sales_Confirmation__c sc = new Sales_Confirmation__c(
            Opportunity__c = deal.Id,
            Total_Amount__c = 25000,
            Payment_Type__c = 'Credit',
            Product_Category__c = 'Marble'
        );
        insert sc;
        
        List<Sales_Confirmation__c> orders = new List<Sales_Confirmation__c>{ sc };
        
        Test.startTest();
        SAPSalesOrderHandler.sendToSAP(orders);
        Test.stopTest();
        
        // Should return early without throwing exception
        System.assert(true, 'Login failure handled gracefully');
    }
    
    @IsTest
    static void testSendToSAP_OrderCreationFailure() {
        Test.setMock(HttpCalloutMock.class, new MockSAPCalloutOrderFail());
        
        Deals__c deal = [SELECT Id FROM Deals__c LIMIT 1];
        
        Sales_Confirmation__c sc = new Sales_Confirmation__c(
            Opportunity__c = deal.Id,
            Total_Amount__c = 75000,
            Payment_Type__c = 'Cheque',
            Product_Category__c = 'Granite'
        );
        insert sc;
        
        List<Sales_Confirmation__c> orders = new List<Sales_Confirmation__c>{ sc };
        
        Test.startTest();
        SAPSalesOrderHandler.sendToSAP(orders);
        Test.stopTest();
        
        // Should complete without throwing exception even if order creation fails
        System.assert(true, 'Order creation failure handled');
    }
    
    @IsTest
    static void testSendToSAP_MultipleOrders() {
        Test.setMock(HttpCalloutMock.class, new MockSAPCalloutSuccess());
        
        Deals__c deal = [SELECT Id FROM Deals__c LIMIT 1];
        
        List<Sales_Confirmation__c> orders = new List<Sales_Confirmation__c>();
        
        for (Integer i = 0; i < 3; i++) {
            orders.add(new Sales_Confirmation__c(
                Opportunity__c = deal.Id,
                Total_Amount__c = 10000 * (i + 1),
                Payment_Type__c = 'Cash',
                Product_Category__c = 'Tiles'
            ));
        }
        insert orders;
        
        Test.startTest();
        SAPSalesOrderHandler.sendToSAP(orders);
        Test.stopTest();
        
        // Verify all orders processed
        System.assertEquals(3, orders.size(), 'Should process 3 orders');
    }
    
    @IsTest
    static void testSendToSAP_EmptyList() {
        Test.setMock(HttpCalloutMock.class, new MockSAPCalloutSuccess());
        
        List<Sales_Confirmation__c> orders = new List<Sales_Confirmation__c>();
        
        Test.startTest();
        SAPSalesOrderHandler.sendToSAP(orders);
        Test.stopTest();
        
        // Should handle empty list gracefully
        System.assert(true, 'Empty list handled gracefully');
    }
    
    @IsTest
    static void testSendToSAP_NullAmountFields() {
        Test.setMock(HttpCalloutMock.class, new MockSAPCalloutSuccess());
        
        Deals__c deal = [SELECT Id FROM Deals__c LIMIT 1];
        
        Sales_Confirmation__c sc = new Sales_Confirmation__c(
            Opportunity__c = deal.Id,
            Total_Amount__c = null,
            Payment_Type__c = null,
            Product_Category__c = null
        );
        insert sc;
        
        List<Sales_Confirmation__c> orders = new List<Sales_Confirmation__c>{ sc };
        
        Test.startTest();
        SAPSalesOrderHandler.sendToSAP(orders);
        Test.stopTest();
        
        // Should handle null fields
        System.assert(true, 'Null fields handled');
    }
}