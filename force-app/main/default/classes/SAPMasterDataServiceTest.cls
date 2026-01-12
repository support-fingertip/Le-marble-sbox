@isTest
private class SAPMasterDataServiceTest {
    // Mock that always fails login
    private class MockLoginFailureCallout implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('');
            return res;
        }
    }
    // Mock that returns valid JSON for all endpoints
    private class MockSAPSuccessCallout implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            String url = req.getEndpoint();
            if (url.endsWith('/Login')) {
                res.setStatusCode(200);
                res.setBody('{"SessionId":"ABC123"}');
            } else if (url.contains('/BusinessPlaces')) {
                res.setStatusCode(200);
                // one business place
                res.setBody('{"value":[{"BusinessPlaceID":10,"Name":"BP1"}]}');
            } else if (url.contains('/Warehouses')) {
                res.setStatusCode(200);
                // one warehouse
                res.setBody('{"value":[{"WarehouseCode":"W1","WarehouseName":"WH1","BusinessPlaceID":1}]}');
            } else if (url.contains('/Items')) {
                res.setStatusCode(200);
                // one item with two warehouse infos: W1 (maps) and W2 (no map)
                res.setBody('{"value":[{"ItemCode":"Item1","ItemWarehouseInfoCollection":[' +
                            '{"WarehouseCode":"W1","InStock":100,"Committed":"5"},' +
                            '{"WarehouseCode":"W2","InStock":50,"Committed":10}' +
                            ']}]}');
            } else {
                res.setStatusCode(404);
                res.setBody('{"error":"Not found"}');
            }
            return res;
        }
    }

    @isTest static void testGetActiveWarehouses_LoginFail() {
        Test.setMock(HttpCalloutMock.class, new MockLoginFailureCallout());
        List<Map<String,Object>> whs = SAPMasterDataService.getActiveWarehouses();
        System.assertEquals(0, whs.size());
    }
    @isTest static void testGetActiveWarehouses_Success() {
        Test.setMock(HttpCalloutMock.class, new MockSAPSuccessCallout());
        List<Map<String,Object>> whs = SAPMasterDataService.getActiveWarehouses();
        System.assertEquals(1, whs.size());
        Map<String,Object> w = whs[0];
        System.assertEquals('W1', (String)w.get('WarehouseCode'));
        System.assertEquals('WH1', (String)w.get('WarehouseName'));
        System.assertEquals(1, Integer.valueOf(String.valueOf(w.get('BusinessPlaceID'))));
    }

    @isTest static void testGetWarehousesByBPL_LoginFail() {
        Test.setMock(HttpCalloutMock.class, new MockLoginFailureCallout());
        List<Map<String,Object>> whs = SAPMasterDataService.getWarehousesByBPL('1');
        System.assertEquals(0, whs.size());
    }
    @isTest static void testGetWarehousesByBPL_Success() {
        Test.setMock(HttpCalloutMock.class, new MockSAPSuccessCallout());
        List<Map<String,Object>> whs = SAPMasterDataService.getWarehousesByBPL('1');
        System.assertEquals(1, whs.size());
        System.assertEquals('W1', whs[0].get('WarehouseCode'));
    }

    @isTest static void testGetActiveBusinessPlaces_LoginFail() {
        Test.setMock(HttpCalloutMock.class, new MockLoginFailureCallout());
        List<Map<String,Object>> bpls = SAPMasterDataService.getActiveBusinessPlaces();
        System.assertEquals(0, bpls.size());
    }
    @isTest static void testGetActiveBusinessPlaces_Success() {
        Test.setMock(HttpCalloutMock.class, new MockSAPSuccessCallout());
        List<Map<String,Object>> bpls = SAPMasterDataService.getActiveBusinessPlaces();
        System.assertEquals(1, bpls.size());
        System.assertEquals(10, Integer.valueOf(String.valueOf(bpls[0].get('BusinessPlaceID'))));
    }

    @isTest static void testGetItemInventoryByWarehouse_InvalidParams() {
        // null list
        List<Map<String,Object>> inv1 =
            SAPMasterDataService.getItemInventoryByWarehouse('W1', null);
        System.assertEquals(0, inv1.size());
        // empty list
        List<Map<String,Object>> inv2 =
            SAPMasterDataService.getItemInventoryByWarehouse('W1', new List<String>());
        System.assertEquals(0, inv2.size());
    }
    @isTest static void testGetItemInventoryByWarehouse_LoginFail() {
        Test.setMock(HttpCalloutMock.class, new MockLoginFailureCallout());
        List<String> items = new List<String>{ 'Item1' };
        List<Map<String,Object>> inv =
            SAPMasterDataService.getItemInventoryByWarehouse('W1', items);
        System.assertEquals(0, inv.size());
    }
    @isTest static void testGetItemInventoryByWarehouse_Success() {
        Test.setMock(HttpCalloutMock.class, new MockSAPSuccessCallout());
        List<String> items = new List<String>{ 'Item1' };
        List<Map<String,Object>> inv =
            SAPMasterDataService.getItemInventoryByWarehouse('W1', items);
        // Stub returns two infos but only W1 maps → only one record
        System.assertEquals(1, inv.size());
        Map<String,Object> rec = inv[0];
        System.assertEquals('Item1', rec.get('ItemCode'));
        System.assertEquals('W1', rec.get('WarehouseCode'));
        System.assertEquals('WH1', rec.get('WarehouseName'));
        System.assertEquals(1, Integer.valueOf(String.valueOf(rec.get('BusinessPlaceID'))));
        System.assertEquals(100, Decimal.valueOf(String.valueOf(rec.get('InStock'))));
        System.assertEquals(Decimal.valueOf('5'), Decimal.valueOf(String.valueOf(rec.get('Committed'))));
    }
}