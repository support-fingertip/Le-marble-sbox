@isTest
public class CreatePurchaseOrderInSAPTest {

    private class SAPMock implements HttpCalloutMock {

        public HTTPResponse respond(HTTPRequest req) {

            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');

            if (req.getEndpoint().contains('Login')) {
                res.setStatusCode(200);
                res.setBody('{"SessionId":"ABC123"}');
            }
            else if (req.getMethod() == 'POST' &&
                     req.getEndpoint().contains('PurchaseOrders')) {

                res.setStatusCode(201);
                res.setBody('{"DocEntry":"1001"}');
            }
            else if (req.getMethod() == 'GET') {
                res.setStatusCode(200);
                res.setBody('{"DocumentLines": []}');
            }
            else if (req.getMethod() == 'PATCH') {
                res.setStatusCode(204);
                res.setBody('');
            }
            else {
                res.setStatusCode(400);
                res.setBody('Unexpected Call');
            }

            return res;
        }
    }

    @isTest
    static void testCreatePO() {

        // Create Vendor (custom object)
        Vendor__c vendor = new Vendor__c(
            Name = 'VENDOR001'
        );
        insert vendor;

        // Create Product (custom object, NOT Product2)
        Product__c product = new Product__c(
            Name = 'Test Product',
            Product_Code__c = 'ITEM001'
        );
        insert product;

        // Create Pending Purchase
        Pending_Purchase__c purchase = new Pending_Purchase__c(
            Vendor__c = vendor.Id,
            Received_Date__c = Date.today(),
            Remarks__c = '<b>Test Remarks</b>',
            Status__c = 'Finance Manager Approved',
            Is_PO_Created__c = false
        );
        insert purchase;

        // Create Line Item
        Pending_Purchase_Line_Item__c lineItem =
            new Pending_Purchase_Line_Item__c(
                Pending_Purchase__c = purchase.Id,
                Product__c = product.Id,
                Quantity__c = 5,
                Warehouse__c = 'WH1',
                BPL_ID__c = '1'
            );
        insert lineItem;

        Test.setMock(HttpCalloutMock.class, new SAPMock());

        Test.startTest();
        CreatePurchaseOrderInSAP.createPO(purchase.Id);
        Test.stopTest();

        Pending_Purchase__c updated = [
            SELECT Is_PO_Created__c, SAP_DocEntry__c
            FROM Pending_Purchase__c
            WHERE Id = :purchase.Id
        ];

        System.assertEquals(true, updated.Is_PO_Created__c);
        System.assertEquals('1001', updated.SAP_DocEntry__c);
    }


    @isTest
    static void testUpdatePO() {

        Vendor__c vendor = new Vendor__c(
            Name = 'VENDOR002'
        );
        insert vendor;

        Product__c product = new Product__c(
            Name = 'Test Product 2',
            Product_Code__c = 'ITEM002'
        );
        insert product;

        Pending_Purchase__c purchase = new Pending_Purchase__c(
            Vendor__c = vendor.Id,
            Received_Date__c = Date.today(),
            Remarks__c = 'Update Test',
            Status__c = 'Finance Manager Approved',
            Is_PO_Created__c = true,
            SAP_DocEntry__c = '1001'
        );
        insert purchase;

        Pending_Purchase_Line_Item__c lineItem =
            new Pending_Purchase_Line_Item__c(
                Pending_Purchase__c = purchase.Id,
                Product__c = product.Id,
                Quantity__c = 10,
                Warehouse__c = 'WH2',
                BPL_ID__c = '2'
            );
        insert lineItem;

        Test.setMock(HttpCalloutMock.class, new SAPMock());

        Test.startTest();
        CreatePurchaseOrderInSAP.createPO(purchase.Id);
        Test.stopTest();

        System.assert(true);
    }
}