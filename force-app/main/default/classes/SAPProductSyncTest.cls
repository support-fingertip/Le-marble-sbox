@isTest
public class SAPProductSyncTest {
    // Mock class for HTTP callouts with Series service support
    private class MockHttpCallout implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            
            if (req.getEndpoint().contains('/Login')) {
                res.setBody('{"SessionId": "abc123"}');
            } else if (req.getEndpoint().contains('/SeriesService_GetSeries')) {
                // Mock Series service response
                res.setBody('{"Name": "SANITARY", "Series": 88}');
            } else if (req.getEndpoint().contains('/Items')) {
                // Mock Items API response with Series field
                String responseBody = '{"value": [' +
                    '{"ItemCode": "P001", "ItemName": "Test Product 1", "Series": 88, "U_Brand": "Test Brand", ' +
                    '"ItemPrices": [{"PriceList": 1, "Price": 100.0}, {"PriceList": 2, "Price": 80.0}], ' +
                    '"U_UnitPrice": 50.0, "U_Image": "image1.jpg", "U_Size": "10x10", "U_SquareFt": "1.5", ' +
                    '"U_TaxRate": "18", "InventoryUOM": "NOS", ' +
                    '"ItemWarehouseInfoCollection": [{"WarehouseCode": "AMP0004", "U_Billable": 10.0}]},' +
                    '{"ItemCode": "P002", "ItemName": "Test Product 2", "Series": 89, "U_Brand": "Test Brand 2", ' +
                    '"ItemPrices": [{"PriceList": 1, "Price": 200.0}, {"PriceList": 2, "Price": 160.0}], ' +
                    '"U_UnitPrice": 100.0, "U_Image": "image2.jpg", "U_Size": "20x20", "U_SquareFt": "2.0", ' +
                    '"U_TaxRate": "18", "InventoryUOM": "NOS", ' +
                    '"ItemWarehouseInfoCollection": [{"WarehouseCode": "BDBS0022", "U_Billable": 20.0}]}' +
                ']}';
                res.setBody(responseBody);
            }
            
            res.setStatusCode(200);
            return res;
        }
    }

    // Mock class for Series service error
    private class SeriesServiceErrorMockHttpCallout implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            
            if (req.getEndpoint().contains('/Login')) {
                res.setBody('{"SessionId": "abc123"}');
            } else if (req.getEndpoint().contains('/SeriesService_GetSeries')) {
                // Mock Series service error
                res.setStatusCode(500);
                res.setBody('{"error": "Series service error"}');
            } else if (req.getEndpoint().contains('/Items')) {
                // Mock Items API response
                String responseBody = '{"value": [' +
                    '{"ItemCode": "P001", "ItemName": "Test Product 1", "Series": 88, "U_Brand": "Test Brand", ' +
                    '"ItemPrices": [{"PriceList": 1, "Price": 100.0}, {"PriceList": 2, "Price": 80.0}], ' +
                    '"U_UnitPrice": 50.0, "U_Image": "image1.jpg", "U_Size": "10x10", "U_SquareFt": "1.5", ' +
                    '"U_TaxRate": "18", "InventoryUOM": "NOS", ' +
                    '"ItemWarehouseInfoCollection": [{"WarehouseCode": "AMP0004", "U_Billable": 10.0}]}' +
                ']}';
                res.setBody(responseBody);
            }
            
            res.setStatusCode(req.getEndpoint().contains('/SeriesService_GetSeries') ? 500 : 200);
            return res;
        }
    }

    // Mock class for Series service with null response
    private class SeriesServiceNullMockHttpCallout implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            
            if (req.getEndpoint().contains('/Login')) {
                res.setBody('{"SessionId": "abc123"}');
            } else if (req.getEndpoint().contains('/SeriesService_GetSeries')) {
                // Mock Series service with null Name
                res.setBody('{"Name": null, "Series": 88}');
            } else if (req.getEndpoint().contains('/Items')) {
                // Mock Items API response
                String responseBody = '{"value": [' +
                    '{"ItemCode": "P001", "ItemName": "Test Product 1", "Series": 88, "U_Brand": "Test Brand", ' +
                    '"ItemPrices": [{"PriceList": 1, "Price": 100.0}, {"PriceList": 2, "Price": 80.0}], ' +
                    '"U_UnitPrice": 50.0, "U_Image": "image1.jpg", "U_Size": "10x10", "U_SquareFt": "1.5", ' +
                    '"U_TaxRate": "18", "InventoryUOM": "NOS", ' +
                    '"ItemWarehouseInfoCollection": [{"WarehouseCode": "AMP0004", "U_Billable": 10.0}]}' +
                ']}';
                res.setBody(responseBody);
            }
            
            res.setStatusCode(200);
            return res;
        }
    }

    // Mock class for items without Series field
    private class ItemsWithoutSeriesMockHttpCallout implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            
            if (req.getEndpoint().contains('/Login')) {
                res.setBody('{"SessionId": "abc123"}');
            } else if (req.getEndpoint().contains('/Items')) {
                // Mock Items API response without Series field
                String responseBody = '{"value": [' +
                    '{"ItemCode": "P001", "ItemName": "Test Product 1", "U_Brand": "Test Brand", ' +
                    '"ItemPrices": [{"PriceList": 1, "Price": 100.0}, {"PriceList": 2, "Price": 80.0}], ' +
                    '"U_UnitPrice": 50.0, "U_Image": "image1.jpg", "U_Size": "10x10", "U_SquareFt": "1.5", ' +
                    '"U_TaxRate": "18", "InventoryUOM": "NOS", ' +
                    '"ItemWarehouseInfoCollection": [{"WarehouseCode": "AMP0004", "U_Billable": 10.0}]}' +
                ']}';
                res.setBody(responseBody);
            }
            
            res.setStatusCode(200);
            return res;
        }
    }

    // Mock class for error response
    private class ErrorMockHttpCallout implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('{"error": "Internal Server Error"}');
            return res;
        }
    }

    // Mock class for empty response
    private class EmptyMockHttpCallout implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"value": []}');
            res.setStatusCode(200);
            return res;
        }
    }

    // Mock class for new products response
    private class NewProductsMockHttpCallout implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            
            if (req.getEndpoint().contains('/Login')) {
                res.setBody('{"SessionId": "abc123"}');
            } else if (req.getEndpoint().contains('/SeriesService_GetSeries')) {
                res.setBody('{"Name": "NEW_CATEGORY", "Series": 90}');
            } else if (req.getEndpoint().contains('/Items')) {
                String responseBody = '{"value": [' +
                    '{"ItemCode": "P003", "ItemName": "New Product 1", "Series": 90, "U_Brand": "New Brand", ' +
                    '"ItemPrices": [{"PriceList": 1, "Price": 300.0}, {"PriceList": 2, "Price": 240.0}], ' +
                    '"U_UnitPrice": 150.0, "U_Image": "image3.jpg", "U_Size": "15x15", "U_SquareFt": "2.5", ' +
                    '"U_TaxRate": "18", "InventoryUOM": "NOS", ' +
                    '"ItemWarehouseInfoCollection": [{"WarehouseCode": "MLPB0001", "U_Billable": 15.0}]},' +
                    '{"ItemCode": "P004", "ItemName": "New Product 2", "Series": 91, "U_Brand": "New Brand 2", ' +
                    '"ItemPrices": [{"PriceList": 1, "Price": 400.0}, {"PriceList": 2, "Price": 320.0}], ' +
                    '"U_UnitPrice": 200.0, "U_Image": "image4.jpg", "U_Size": "25x25", "U_SquareFt": "3.0", ' +
                    '"U_TaxRate": "18", "InventoryUOM": "NOS", ' +
                    '"ItemWarehouseInfoCollection": [{"WarehouseCode": "NSD0007", "U_Billable": 25.0}]}' +
                ']}';
                res.setBody(responseBody);
            }
            
            res.setStatusCode(200);
            return res;
        }
    }

    // Mock for failed login
    private class FailedLoginMockHttpCallout implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(401);
            res.setBody('{"error": "Unauthorized"}');
            return res;
        }
    }

    // Mock for missing session ID
    private class MissingSessionIdMockHttpCallout implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{}'); // No SessionId
            return res;
        }
    }

    // Mock for empty product list
    private class EmptyProductListMockHttpCallout implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            if (req.getEndpoint().contains('/Login')) {
                res.setBody('{"SessionId": "abc123"}');
            } else {
                res.setBody('{"value": []}');
            }
            return res;
        }
    }

    // Mock for product upsert (insert and update)
    private class ProductUpsertMockHttpCallout implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            if (req.getEndpoint().contains('/Login')) {
                res.setBody('{"SessionId": "abc123"}');
            } else if (req.getEndpoint().contains('/SeriesService_GetSeries')) {
                res.setBody('{"Name": "UPDATED_CATEGORY", "Series": 88}');
            } else {
                res.setBody('{"value": [' +
                    '{"ItemCode": "P001", "ItemName": "Test Product 1", "Series": 88, "U_Brand": "Updated Brand", ' +
                    '"ItemPrices": [{"PriceList": 1, "Price": 150.0}, {"PriceList": 2, "Price": 120.0}], ' +
                    '"U_UnitPrice": 75.0, "U_Image": "updated_image.jpg", "U_Size": "12x12", "U_SquareFt": "1.8", ' +
                    '"U_TaxRate": "18", "InventoryUOM": "NOS", ' +
                    '"ItemWarehouseInfoCollection": [{"WarehouseCode": "AMP0004", "U_Billable": 15.0}]},' +
                    '{"ItemCode": "P003", "ItemName": "New Product", "Series": 89, "U_Brand": "New Brand", ' +
                    '"ItemPrices": [{"PriceList": 1, "Price": 250.0}, {"PriceList": 2, "Price": 200.0}], ' +
                    '"U_UnitPrice": 125.0, "U_Image": "new_image.jpg", "U_Size": "15x15", "U_SquareFt": "2.2", ' +
                    '"U_TaxRate": "18", "InventoryUOM": "NOS", ' +
                    '"ItemWarehouseInfoCollection": [{"WarehouseCode": "BDBS0022", "U_Billable": 20.0}]}' +
                ']}');
            }
            return res;
        }
    }

    // Mock for exception in HTTP callout
    private class ExceptionMockHttpCallout implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            throw new CalloutException('Simulated callout exception');
        }
    }

    @TestSetup
    static void setupTestData() {
        // Create test user
        Profile p = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
        User testUser = new User(
            Alias = 'testuser',
            Email = 'testuser@test.com',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            TimeZoneSidKey = 'America/Los_Angeles',
            ProfileId = p.Id,
            UserName = 'testuser@test.com' + System.currentTimeMillis(),
            LastName = 'TestUser'
        );
        insert testUser;

        // Create test products
        List<Product__c> products = new List<Product__c>{
            new Product__c(
                Name = 'Test Product 1',
                Product_Code__c = 'P001'
            ),
            new Product__c(
                Name = 'Test Product 2',
                Product_Code__c = 'P002'
            )
        };
        insert products;
    }

    @isTest
    static void testSAPProductSyncJob() {
        // Set up mock for callouts
        Test.setMock(HttpCalloutMock.class, new MockHttpCallout());

        Test.startTest();
        // Execute the job
        SAPProductSyncJob.runSync();
        Test.stopTest();

        // Verify products were updated with Series-based category
        List<Product__c> updatedProducts = [
            SELECT Id, Name, Product_Code__c, Product_Category__c
            FROM Product__c
            ORDER BY Product_Code__c
        ];
        
        System.assertEquals(2, updatedProducts.size(), 'Should have 2 products');
        System.assertEquals('Test Product 1', updatedProducts[0].Name, 'Product 1 name should match');
        System.assertEquals('P001', updatedProducts[0].Product_Code__c, 'Product 1 code should match');
        System.assertEquals('SANITARY', updatedProducts[0].Product_Category__c, 'Product 1 category should be from Series service');
    }

    @isTest
    static void testSAPProductSyncQueueable() {
        // Set up mock for callouts
        Test.setMock(HttpCalloutMock.class, new MockHttpCallout());

        Test.startTest();
        // Execute the queueable
        Id jobId = System.enqueueJob(new SAPProductSyncQueueable());
        Test.stopTest();

        // Verify products were updated
        List<Product__c> updatedProducts = [
            SELECT Id, Name, Product_Code__c, Product_Category__c
            FROM Product__c
            ORDER BY Product_Code__c
        ];
        
        System.assertEquals(2, updatedProducts.size(), 'Should have 2 products');
        System.assertEquals('Test Product 1', updatedProducts[0].Name, 'Product 1 name should match');
        System.assertEquals('P001', updatedProducts[0].Product_Code__c, 'Product 1 code should match');
        System.assertEquals('SANITARY', updatedProducts[0].Product_Category__c, 'Product 1 category should be from Series service');
    }

    @isTest
    static void testSAPProductSyncScheduler() {
        // Set up mock for callouts
        Test.setMock(HttpCalloutMock.class, new MockHttpCallout());

        Test.startTest();
        // Schedule the job
        String cronExp = '0 0 0 * * ?'; // Run at midnight every day
        String jobId = System.schedule('SAP Product Sync Job', cronExp, new SAPProductSyncScheduler());
        Test.stopTest();

        // Verify the job was scheduled
        List<CronTrigger> jobs = [
            SELECT Id, CronExpression, TimesTriggered, NextFireTime
            FROM CronTrigger
            WHERE Id = :jobId
        ];

    }

    @isTest
    static void testSAPProductSyncWithError() {
        // Set up mock for callouts
        Test.setMock(HttpCalloutMock.class, new ErrorMockHttpCallout());

        Test.startTest();
        try {
            // Execute the job
            SAPProductSyncJob.runSync();
        } catch (Exception e) {
            //System.assert(true, 'Exception was thrown as expected');
        }
        Test.stopTest();

        // Verify products were not updated
        List<Product__c> products = [
            SELECT Id, Name, Product_Code__c
            FROM Product__c
            ORDER BY Product_Code__c
        ];
        
        System.assertEquals(2, products.size(), 'Should still have 2 products');
        System.assertEquals('Test Product 1', products[0].Name, 'Product 1 should not be updated');
    }

    @isTest
    static void testSAPProductSyncWithEmptyResponse() {
        // Set up mock for callouts
        Test.setMock(HttpCalloutMock.class, new EmptyMockHttpCallout());

        Test.startTest();
        // Execute the job
        SAPProductSyncJob.runSync();
        Test.stopTest();

        // Verify products were not updated
        List<Product__c> products = [
            SELECT Id, Name, Product_Code__c
            FROM Product__c
            ORDER BY Product_Code__c
        ];
        
        System.assertEquals(2, products.size(), 'Should still have 2 products');
        System.assertEquals('Test Product 1', products[0].Name, 'Product 1 should not be updated');
    }

    @isTest
    static void testSAPProductSyncWithNewProducts() {
        // Set up mock for callouts
        Test.setMock(HttpCalloutMock.class, new NewProductsMockHttpCallout());

        Test.startTest();
        // Execute the job
        SAPProductSyncJob.runSync();
        Test.stopTest();

        // Verify new products were created with Series-based categories
        List<Product__c> products = [
            SELECT Id, Name, Product_Code__c, Product_Category__c
            FROM Product__c
            ORDER BY Product_Code__c
        ];

        System.assertEquals(4, products.size(), 'Should have 4 products (2 existing + 2 new)');
        
        // Verify new products have Series-based categories
        Product__c newProduct1 = [SELECT Product_Category__c FROM Product__c WHERE Product_Code__c = 'P003' LIMIT 1];
        System.assertEquals('NEW_CATEGORY', newProduct1.Product_Category__c, 'New product should have Series-based category');
    }

    @isTest
    static void testFailedLogin() {
        Test.setMock(HttpCalloutMock.class, new FailedLoginMockHttpCallout());
        Test.startTest();
        SAPProductSyncJob.runSync();
        Test.stopTest();
        // Should not throw, just log and return
    }

    @isTest
    static void testMissingSessionId() {
        Test.setMock(HttpCalloutMock.class, new MissingSessionIdMockHttpCallout());
        Test.startTest();
        SAPProductSyncJob.runSync();
        Test.stopTest();
        // Should not throw, just log and return
    }

    @isTest
    static void testEmptyProductList() {
        Test.setMock(HttpCalloutMock.class, new EmptyProductListMockHttpCallout());
        Test.startTest();
        SAPProductSyncJob.runSync();
        Test.stopTest();
        // Should not throw, just log and return
    }

    @isTest
    static void testProductUpsert() {
        // Insert a product to test update logic (using different code to avoid conflicts)
        insert new Product__c(Name='Existing Product', Product_Code__c='EXISTING001');
        Test.setMock(HttpCalloutMock.class, new ProductUpsertMockHttpCallout());
        Test.startTest();
        SAPProductSyncJob.runSync();
        Test.stopTest();
        
        // Should have updated P001 (from mock) and inserted P003 (from mock)
        List<Product__c> products = [SELECT Product_Code__c, Product_Category__c FROM Product__c WHERE Product_Code__c IN ('P001','P003')];
        System.assertEquals(2, products.size(), 'Should have 2 products after upsert (P001 and P003)');
        
        // Verify Series-based category for updated product
        Product__c updatedProduct = [SELECT Product_Category__c FROM Product__c WHERE Product_Code__c = 'P001' LIMIT 1];
        System.assertEquals('UPDATED_CATEGORY', updatedProduct.Product_Category__c, 'Updated product should have Series-based category');
        
        // Verify new product was inserted
        Product__c newProduct = [SELECT Product_Category__c FROM Product__c WHERE Product_Code__c = 'P003' LIMIT 1];
        System.assertNotEquals(null, newProduct, 'New product P003 should be inserted');
        
        // Verify the existing product from TestSetup is still there
        List<Product__c> existingProducts = [SELECT Product_Code__c FROM Product__c WHERE Product_Code__c IN ('P001', 'P002', 'EXISTING001')];
        System.assertEquals(3, existingProducts.size(), 'Should have 3 products including TestSetup products');
    }

    @isTest
    static void testExceptionHandling() {
        Test.setMock(HttpCalloutMock.class, new ExceptionMockHttpCallout());
        Test.startTest();
        SAPProductSyncJob.runSync();
        Test.stopTest();
        // Should not throw, just log and return
    }

    @isTest
    static void testSeriesServiceError() {
        Test.setMock(HttpCalloutMock.class, new SeriesServiceErrorMockHttpCallout());
        Test.startTest();
        SAPProductSyncJob.runSync();
        Test.stopTest();
        
        // Verify products were still processed even with Series service error
        List<Product__c> products = [
            SELECT Id, Name, Product_Code__c, Product_Category__c
            FROM Product__c
            ORDER BY Product_Code__c
        ];
        
        System.assertEquals(2, products.size(), 'Should still have 2 products');
        // Product category should be null when Series service fails
        System.assertEquals(null, products[0].Product_Category__c, 'Product category should be null when Series service fails');
    }

    @isTest
    static void testSeriesServiceNullResponse() {
        Test.setMock(HttpCalloutMock.class, new SeriesServiceNullMockHttpCallout());
        Test.startTest();
        SAPProductSyncJob.runSync();
        Test.stopTest();
        
        // Verify products were processed with null category
        List<Product__c> products = [
            SELECT Id, Name, Product_Code__c, Product_Category__c
            FROM Product__c
            ORDER BY Product_Code__c
        ];
        
        System.assertEquals(2, products.size(), 'Should still have 2 products');
        System.assertEquals(null, products[0].Product_Category__c, 'Product category should be null when Series service returns null');
    }

    @isTest
    static void testItemsWithoutSeries() {
        Test.setMock(HttpCalloutMock.class, new ItemsWithoutSeriesMockHttpCallout());
        Test.startTest();
        SAPProductSyncJob.runSync();
        Test.stopTest();
        
        // Verify products were processed without Series field
        List<Product__c> products = [
            SELECT Id, Name, Product_Code__c, Product_Category__c
            FROM Product__c
            ORDER BY Product_Code__c
        ];
        
        System.assertEquals(2, products.size(), 'Should still have 2 products');
        System.assertEquals(null, products[0].Product_Category__c, 'Product category should be null when Series field is missing');
    }
}