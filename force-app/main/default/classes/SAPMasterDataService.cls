public with sharing class SAPMasterDataService {
    private static final String SAP_BASE_URL = 'https://lemrg.hstconnect.in:50000/b1s/v1';
    private static final String COMPANY_DB = 'MG_LIVE_WIP_1';
    private static final String USERNAME = 'manager';
    private static final String PASSWORD = 'Mgsap12@';

    private static String loginToSAP() {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(SAP_BASE_URL + '/Login');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setBody(JSON.serialize(new Map<String, String>{
            'CompanyDB' => COMPANY_DB,
            'UserName' => USERNAME,
            'Password' => PASSWORD
        }));
        Http http = new Http();
        HttpResponse res = http.send(req);
        System.debug('SAP Login Response Status: ' + res.getStatusCode());
        System.debug('SAP Login Response Body: ' + res.getBody());
        if (res.getStatusCode() != 200) return null;
        Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        return String.valueOf(result.get('SessionId'));
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getActiveWarehouses() {
        String sessionId = loginToSAP();
        if (String.isBlank(sessionId)) {
            System.debug('SAP Login Failed');
            return new List<Map<String, Object>>();
        }

        List<Map<String, Object>> allWarehouses = new List<Map<String, Object>>();
        String nextLink = null;
        
        do {
            HttpRequest req = new HttpRequest();
            if (nextLink == null) {
                String queryParams = '$filter=Inactive eq \'tNO\'&$select=WarehouseCode,WarehouseName,BusinessPlaceID';
                String encodedQueryParams = EncodingUtil.urlEncode(queryParams, 'UTF-8');
                req.setEndpoint(SAP_BASE_URL + '/Warehouses?' + encodedQueryParams);
            } else {
                req.setEndpoint(SAP_BASE_URL + '/' + nextLink);
            }
            
            req.setMethod('GET');
            req.setHeader('Cookie', 'B1SESSION=' + sessionId);
            req.setHeader('Content-Type', 'application/json');
            
            Http http = new Http();
            HttpResponse res = http.send(req);
            System.debug('Warehouse Response Status: ' + res.getStatusCode());
            System.debug('Warehouse Response Body: ' + res.getBody());
            
            if (res.getStatusCode() != 200) {
                System.debug('Warehouse API call failed with status: ' + res.getStatusCode());
                break;
            }
            
            Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            List<Object> valueList = (List<Object>) result.get('value');
            
            if (valueList != null) {
                for (Object obj : valueList) {
                    if (obj instanceof Map<String, Object>) {
                        allWarehouses.add((Map<String, Object>) obj);
                    }
                }
            }
            
            nextLink = (String) result.get('odata.nextLink');
            System.debug('Next Link: ' + nextLink);
            
        } while (nextLink != null);
        
        System.debug('Total Warehouses fetched: ' + allWarehouses.size());
        return allWarehouses;
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getWarehousesByBPL(String bplId) {
        System.debug('Getting warehouses for BPL: ' + bplId);
        String sessionId = loginToSAP();
        if (String.isBlank(sessionId)) {
            System.debug('SAP Login Failed');
            return new List<Map<String, Object>>();
        }

        List<Map<String, Object>> allWarehouses = new List<Map<String, Object>>();
        String nextLink = null;
        
        do {
            HttpRequest req = new HttpRequest();
            if (nextLink == null) {
                String queryParams = '$filter=BusinessPlaceID eq ' + bplId + ' and Inactive eq \'tNO\'&$select=WarehouseCode,WarehouseName,BusinessPlaceID';
                String encodedQueryParams = EncodingUtil.urlEncode(queryParams, 'UTF-8');
                req.setEndpoint(SAP_BASE_URL + '/Warehouses?' + encodedQueryParams);
                System.debug('Warehouse Request URL: ' + req.getEndpoint());
            } else {
                req.setEndpoint(SAP_BASE_URL + '/' + nextLink);
            }
            
            req.setMethod('GET');
            req.setHeader('Cookie', 'B1SESSION=' + sessionId);
            req.setHeader('Content-Type', 'application/json');
            
            Http http = new Http();
            HttpResponse res = http.send(req);
            System.debug('Warehouse Response Status: ' + res.getStatusCode());
            System.debug('Warehouse Response Body: ' + res.getBody());
            
            if (res.getStatusCode() != 200) {
                System.debug('Warehouse API call failed with status: ' + res.getStatusCode());
                break;
            }
            
            Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            List<Object> valueList = (List<Object>) result.get('value');
            
            if (valueList != null) {
                for (Object obj : valueList) {
                    if (obj instanceof Map<String, Object>) {
                        Map<String, Object> warehouse = (Map<String, Object>) obj;
                        System.debug('Warehouse found: ' + JSON.serialize(warehouse));
                        allWarehouses.add(warehouse);
                    }
                }
            }
            
            nextLink = (String) result.get('odata.nextLink');
            System.debug('Next Link: ' + nextLink);
            
        } while (nextLink != null);
        
        System.debug('Total Warehouses fetched for BPL ' + bplId + ': ' + allWarehouses.size());
        return allWarehouses;
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getActiveBusinessPlaces() {
        String sessionId = loginToSAP();
        if (String.isBlank(sessionId)) {
            System.debug('SAP Login Failed');
            return new List<Map<String, Object>>();
        }
        System.debug('SAP Login Successful. SessionId: ' + sessionId);
        
        HttpRequest req = new HttpRequest();
        String queryParams = '$filter=Disabled eq \'tNO\'';
        String encodedQueryParams = EncodingUtil.urlEncode(queryParams, 'UTF-8');
        req.setEndpoint(SAP_BASE_URL + '/BusinessPlaces?' + encodedQueryParams);
        req.setMethod('GET');
        req.setHeader('Cookie', 'B1SESSION=' + sessionId);
        req.setHeader('Content-Type', 'application/json');
        
        System.debug('Business Places Request URL: ' + req.getEndpoint());
        System.debug('Business Places Request Headers: ' + req.getHeader('Cookie'));
        
        Http http = new Http();
        HttpResponse res = http.send(req);
        System.debug('Business Place Response Status: ' + res.getStatusCode());
        System.debug('Business Place Response Body: ' + res.getBody());
        
        if (res.getStatusCode() != 200) {
            System.debug('Business Places API call failed with status: ' + res.getStatusCode());
            return new List<Map<String, Object>>();
        }
        
        Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        List<Object> valueList = (List<Object>) result.get('value');
        List<Map<String, Object>> businessPlaces = new List<Map<String, Object>>();
        
        if (valueList != null) {
            for (Object obj : valueList) {
                if (obj instanceof Map<String, Object>) {
                    businessPlaces.add((Map<String, Object>) obj);
                }
            }
        }
        System.debug('Number of Business Places found: ' + businessPlaces.size());
        return businessPlaces;
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getItemInventoryByWarehouse(String warehouseCode, List<String> itemCodes) {
        if (itemCodes == null || itemCodes.isEmpty()) {
            System.debug('Invalid parameters: itemCodes is empty');
            return new List<Map<String, Object>>();
        }
        String sessionId = loginToSAP();
        if (String.isBlank(sessionId)) {
            System.debug('SAP Login Failed');
            return new List<Map<String, Object>>();
        }
        List<Map<String, Object>> inventoryList = new List<Map<String, Object>>();
        String nextLink = null;
        try {
            // First get all warehouses to have BPL mapping
            Map<String, Object> warehouseBPLMap = new Map<String, Object>();
            HttpRequest warehouseReq;
            Http http = new Http();
            String queryParams = '$select=WarehouseCode,WarehouseName,Location,BusinessPlaceID&$filter=BusinessPlaceID eq 3 or BusinessPlaceID eq 4 or BusinessPlaceID eq 5 or BusinessPlaceID eq 6';
            String encodedQueryParams = EncodingUtil.urlEncode(queryParams, 'UTF-8');
            do {
                warehouseReq = new HttpRequest();
                if (nextLink == null) {
                    warehouseReq.setEndpoint(SAP_BASE_URL + '/Warehouses?' + encodedQueryParams);
                } else {
                    warehouseReq.setEndpoint(SAP_BASE_URL + '/' + nextLink);
                }
                warehouseReq.setMethod('GET');
                warehouseReq.setHeader('Cookie', 'B1SESSION=' + sessionId);
                warehouseReq.setHeader('Content-Type', 'application/json');
                System.debug('Warehouse Request URL: ' + warehouseReq.getEndpoint());
                HttpResponse warehouseRes = http.send(warehouseReq);
                System.debug('Warehouse Response Status: ' + warehouseRes.getStatusCode());
                System.debug('Warehouse Response Body: ' + warehouseRes.getBody());
                if (warehouseRes.getStatusCode() == 200) {
                    Map<String, Object> warehouseResult = (Map<String, Object>) JSON.deserializeUntyped(warehouseRes.getBody());
                    List<Object> warehouses = (List<Object>) warehouseResult.get('value');
                    System.debug('Total Warehouses found in this page: ' + warehouses.size());
                    for (Object w : warehouses) {
                        Map<String, Object> warehouse = (Map<String, Object>) w;
                        String whsCode = String.valueOf(warehouse.get('WarehouseCode'));
                        warehouseBPLMap.put(whsCode, warehouse);
                        System.debug('Added warehouse to map: ' + whsCode + ' for BPL: ' + warehouse.get('BusinessPlaceID') + ' Location: ' + warehouse.get('Location'));
                    }
                    nextLink = (String) warehouseResult.get('odata.nextLink');
                    System.debug('Next Link for Warehouses: ' + nextLink);
                } else {
                    System.debug('Warehouse API call failed with status: ' + warehouseRes.getStatusCode());
                    break;
                }
            } while (nextLink != null);

            // Now get item inventory
            queryParams = '$select=ItemCode,ItemWarehouseInfoCollection';
            List<String> itemFilters = new List<String>();
            for (String itemCode : itemCodes) {
                if (String.isNotBlank(itemCode)) {
                    itemFilters.add('ItemCode eq \'' + String.escapeSingleQuotes(itemCode) + '\'');
                }
            }
            if (!itemFilters.isEmpty()) {
                queryParams += '&$filter=' + String.join(itemFilters, ' or ');
            }
            encodedQueryParams = EncodingUtil.urlEncode(queryParams, 'UTF-8');
            
            System.debug('Item Inventory Request URL: ' + SAP_BASE_URL + '/Items?' + encodedQueryParams);
            
            do {
                HttpRequest req = new HttpRequest();
                if (nextLink == null) {
                    req.setEndpoint(SAP_BASE_URL + '/Items?' + encodedQueryParams);
                } else {
                    req.setEndpoint(SAP_BASE_URL + '/' + nextLink);
                }
                req.setMethod('GET');
                req.setHeader('Cookie', 'B1SESSION=' + sessionId);
                req.setHeader('Content-Type', 'application/json');
                HttpResponse res = http.send(req);
                
                System.debug('Item Inventory Response Status: ' + res.getStatusCode());
                System.debug('Item Inventory Response Body: ' + res.getBody());
                
                if (res.getStatusCode() != 200) {
                    break;
                }
                Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                List<Object> valueList = (List<Object>) result.get('value');
                if (valueList != null) {
                    for (Object obj : valueList) {
                        if (obj instanceof Map<String, Object>) {
                            Map<String, Object> item = (Map<String, Object>) obj;
                            List<Object> warehouseInfoList = (List<Object>) item.get('ItemWarehouseInfoCollection');
                            if (warehouseInfoList != null) {
                                for (Object warehouseObj : warehouseInfoList) {
                                    Map<String, Object> warehouseInfo = (Map<String, Object>) warehouseObj;
                                    String currentWarehouseCode = String.valueOf(warehouseInfo.get('WarehouseCode'));
                                    Object inStockObj = warehouseInfo.get('InStock');
                                    Decimal inStock = 0;
                                    if (inStockObj != null) {
                                        if (inStockObj instanceof Decimal) {
                                            inStock = (Decimal)inStockObj;
                                        } else if (inStockObj instanceof Integer) {
                                            inStock = (Integer)inStockObj;
                                        } else if (inStockObj instanceof String) {
                                            inStock = Decimal.valueOf((String)inStockObj);
                                        }
                                    }
                                    // Fetch U_ReservedQTY
                                    Object reservedObj = warehouseInfo.get('Committed');
                                    Decimal reservedQty = 0;
                                    if (reservedObj != null) {
                                        if (reservedObj instanceof Decimal) {
                                            reservedQty = (Decimal)reservedObj;
                                        } else if (reservedObj instanceof Integer) {
                                            reservedQty = (Integer)reservedObj;
                                        } else if (reservedObj instanceof String) {
                                            reservedQty = Decimal.valueOf((String)reservedObj);
                                        }
                                    }
                                    Map<String, Object> warehouseData = (Map<String, Object>)warehouseBPLMap.get(currentWarehouseCode);
                                    if (warehouseData != null) {
                                        System.debug('Adding warehouse to inventory list: ' + currentWarehouseCode + ' with stock: ' + inStock + ' for BPL: ' + warehouseData.get('BusinessPlaceID') + ' Location: ' + warehouseData.get('Location') + ' Committed: ' + reservedQty);
                                        inventoryList.add(new Map<String, Object>{
                                            'ItemCode' => item.get('ItemCode'),
                                            'InStock' => inStock,
                                            'WarehouseCode' => currentWarehouseCode,
                                            'WarehouseName' => warehouseData.get('WarehouseName'),
                                            'Location' => warehouseData.get('Location'),
                                            'BusinessPlaceID' => warehouseData.get('BusinessPlaceID'),
                                            'Committed' => reservedQty
                                        });
                                    } else {
                                        System.debug('Warehouse not found in BPL map: ' + currentWarehouseCode);
                                    }
                                }
                            }
                        }
                    }
                }
                nextLink = (String) result.get('odata.nextLink');
            } while (nextLink != null);
            
            System.debug('Total inventory records found: ' + inventoryList.size());
            return inventoryList;
        } catch (Exception e) {
            System.debug('Error in getItemInventoryByWarehouse: ' + e.getMessage() + '\n' + e.getStackTraceString());
            throw new AuraHandledException('Error fetching inventory data: ' + e.getMessage());
        }
    }
}