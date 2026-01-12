public class SAPProductSyncJob implements Schedulable {

    private static final String SAP_BASE_URL = 'https://lemrg.hstconnect .in:50000/b1s/v1';
    private static final String LOGIN_URL = SAP_BASE_URL + '/Login';
    private static final String SERIES_SERVICE_URL = SAP_BASE_URL + '/SeriesService_GetSeries';

    private static final String COMPANY_DB = 'MG_LIVE_WIP_1';
    private static final String USERNAME = 'manager';
    private static final String PASSWORD = 'Mgsap12@';

    public void execute(SchedulableContext sc) {
        runSync();
    }

    public static void runSync() {
        try {
            Http http = new Http();

            // 1. Login to SAP
            HttpRequest loginReq = new HttpRequest();
            loginReq.setEndpoint(LOGIN_URL);
            loginReq.setMethod('POST');
            loginReq.setHeader('Content-Type', 'application/json');
            loginReq.setHeader('Accept', 'application/json');
            loginReq.setTimeout(120000);

            loginReq.setBody(JSON.serialize(new Map<String, String>{
                'CompanyDB' => COMPANY_DB,
                'UserName' => USERNAME,
                'Password' => PASSWORD
            }));

            HttpResponse loginRes = http.send(loginReq);

            if (loginRes.getStatusCode() != 200) {
                System.debug('❌ SAP Login Failed: ' + loginRes.getBody());
                return;
            }

            Map<String, Object> loginResult = (Map<String, Object>) JSON.deserializeUntyped(loginRes.getBody());
            String sessionId = String.valueOf(loginResult.get('SessionId'));

            if (String.isBlank(sessionId)) {
                System.debug('❌ Missing SAP session ID');
                return;
            }

            // 2. Determine Last Sync Time
            Product_Sync_Setting__c setting = Product_Sync_Setting__c.getInstance();
            DateTime lastSync = setting.Last_Sync__c != null ? setting.Last_Sync__c : System.now().addDays(-1);
            String formattedDate = lastSync.format('yyyy-MM-dd\'T\'HH:mm:ss');
            String filter = 'UpdateDate ge datetime\'' + formattedDate + '\' or CreateDate ge datetime\'' + formattedDate + '\'';
            String itemsUrl = '$filter=' + EncodingUtil.urlEncode(filter, 'UTF-8') + '&$orderby=UpdateTime';
            String ITEMS_URL = SAP_BASE_URL + '/Items?' + itemsUrl;

            List<Product__c> allRecords = new List<Product__c>();

            while (!String.isBlank(ITEMS_URL)) {
                HttpRequest itemReq = new HttpRequest();
                itemReq.setEndpoint(ITEMS_URL);
                itemReq.setMethod('GET');
                itemReq.setHeader('Content-Type', 'application/json');
                itemReq.setHeader('Accept', 'application/json');
                itemReq.setHeader('Cookie', 'B1SESSION=' + sessionId);
                itemReq.setTimeout(120000);

                HttpResponse itemRes = http.send(itemReq);

                if (itemRes.getStatusCode() != 200) {
                    System.debug('❌ Failed to fetch items: ' + itemRes.getBody());
                    break;
                }

                Map<String, Object> json = (Map<String, Object>) JSON.deserializeUntyped(itemRes.getBody());
                List<Object> items = (List<Object>) json.get('value');

                for (Object obj : items) {
                    Map<String, Object> item = (Map<String, Object>) obj;
                    Product__c prod = new Product__c();

                    prod.Product_Code__c = String.valueOf(item.get('ItemCode'));
                    prod.Name = String.valueOf(item.get('ItemName'));
                    prod.Brand__c = (String)item.get('U_Brand');
                    
                    // Get product category from Series service
                    Integer series = (Integer)item.get('Series');
                    if (series != null) {
                        String categoryName = getSeriesName(sessionId, series, http);
                        prod.Product_Category__c = categoryName;
                    }
                    
                    // Set MRP__c and MSP__c from ItemPrices array
                    List<Object> itemPrices = (List<Object>)item.get('ItemPrices');
                    if (itemPrices != null) {
                        for (Object priceObj : itemPrices) {
                            Map<String, Object> priceMap = (Map<String, Object>)priceObj;
                            Integer priceList = (priceMap.containsKey('PriceList') && priceMap.get('PriceList') != null) ? Integer.valueOf(String.valueOf(priceMap.get('PriceList'))) : null;
                            Decimal price = getDecimal(priceMap, 'Price');
                            System.debug('Product: ' + prod.Product_Code__c + ', PriceList: ' + priceList + ', Price: ' + price);
                            if (priceList == 1) {
                                prod.MRP__c = price;
                            } else if (priceList == 2) {
                                prod.MSP__c = price;
                            }
                        }
                    }
                    prod.Price_Sqft__c = getDecimal(item, 'U_UnitPrice');
                    prod.Product_Image__c = (String)item.get('U_Image');
                    prod.Size__c = (String)item.get('U_Size');
                    prod.Sqft_Piece__c = item.get('U_SquareFt') != null ? String.valueOf(item.get('U_SquareFt')) : null;
                    prod.Tax__c = getDecimal(item, 'U_TaxRate');
                    prod.UOM__c = (String)item.get('InventoryUOM');

                    // Fetch warehouse info for billable qty
                    Decimal totalBillable = 0;
                    List<String> billableWhs = new List<String>{
                        'AMP0004', 'BDBS0022', 'IMAM0019', 'IMP0015',
                        'MLPB0001', 'NSD0007', 'VNGS0003', 'VNGW0002'
                    };

                    // Use ItemWarehouseInfoCollection from the item response instead of separate API call
                    List<Object> warehouseInfoList = (List<Object>) item.get('ItemWarehouseInfoCollection');
                    if (warehouseInfoList != null) {
                        System.debug('Warehouse data for product: ' + prod.Product_Code__c);
                        System.debug('Total warehouses found: ' + warehouseInfoList.size());

                        for (Object warehouseObj : warehouseInfoList) {
                            Map<String, Object> warehouseInfo = (Map<String, Object>) warehouseObj;
                            String whsCode = String.valueOf(warehouseInfo.get('WarehouseCode'));
                            System.debug('Checking warehouse: ' + whsCode + ', Is billable: ' + billableWhs.contains(whsCode));
                            
                            if (billableWhs.contains(whsCode)) {
                                Decimal billable = getDecimal(warehouseInfo, 'U_Billable');
                                System.debug('Warehouse: ' + whsCode + ', U_Billable: ' + billable + ', Product: ' + prod.Product_Code__c);
                                if (billable != null) totalBillable += billable;
                            }
                        }
                    }

                    prod.In_Stock__c = totalBillable;
                    System.debug('Product: ' + prod.Product_Code__c + ', Total Billable: ' + totalBillable);
                    allRecords.add(prod);
                }

                ITEMS_URL = (String) json.get('@odata.nextLink');
            }

            // 3. Upsert into Salesforce
            if (!allRecords.isEmpty()) {
                Set<String> productCodes = new Set<String>();
                for (Product__c p : allRecords) {
                    if (!String.isBlank(p.Product_Code__c)) {
                        productCodes.add(p.Product_Code__c);
                    }
                }

                Map<String, Id> existingProducts = new Map<String, Id>();
                for (Product__c existing : [
                    SELECT Id, Product_Code__c FROM Product__c WHERE Product_Code__c IN :productCodes
                ]) {
                    existingProducts.put(existing.Product_Code__c, existing.Id);
                }

                List<Product__c> toInsert = new List<Product__c>();
                List<Product__c> toUpdate = new List<Product__c>();

                for (Product__c p : allRecords) {
                    if (existingProducts.containsKey(p.Product_Code__c)) {
                        p.Id = existingProducts.get(p.Product_Code__c);
                        toUpdate.add(p);
                    } else {
                        toInsert.add(p);
                    }
                }

                if (!toInsert.isEmpty()) insert toInsert;
                if (!toUpdate.isEmpty()) update toUpdate;

                System.debug('✅ Inserted: ' + toInsert.size() + ', Updated: ' + toUpdate.size());
            }

            // 4. Save last sync time
            setting.Last_Sync__c = System.now();
            upsert setting;

            System.debug('✔ Sync complete: ' + allRecords.size() + ' products processed.');

        } catch (Exception e) {
            System.debug('❌ Sync failed: ' + e.getMessage() + '\\n' + e.getStackTraceString());
        }
    }

    private static String getSeriesName(String sessionId, Integer series, Http http) {
        try {
            HttpRequest seriesReq = new HttpRequest();
            seriesReq.setEndpoint(SERIES_SERVICE_URL);
            seriesReq.setMethod('POST');
            seriesReq.setHeader('Content-Type', 'application/json');
            seriesReq.setHeader('Accept', 'application/json');
            seriesReq.setHeader('Cookie', 'B1SESSION=' + sessionId);
            seriesReq.setTimeout(120000);

            Map<String, Object> requestBody = new Map<String, Object>{
                'SeriesParams' => new Map<String, Object>{
                    'Series' => series
                }
            };

            seriesReq.setBody(JSON.serialize(requestBody));

            HttpResponse seriesRes = http.send(seriesReq);

            if (seriesRes.getStatusCode() == 200) {
                Map<String, Object> seriesResult = (Map<String, Object>) JSON.deserializeUntyped(seriesRes.getBody());
                String seriesName = (String) seriesResult.get('Name');
                System.debug('Series ' + series + ' name: ' + seriesName);
                return seriesName;
            } else {
                System.debug('❌ Failed to fetch series name for series ' + series + ': ' + seriesRes.getBody());
                return null;
            }
        } catch (Exception e) {
            System.debug('❌ Error fetching series name for series ' + series + ': ' + e.getMessage());
            return null;
        }
    }

    private static Decimal getDecimal(Map<String, Object> item, String key) {
        try {
            return item.containsKey(key) && item.get(key) != null
                ? Decimal.valueOf(String.valueOf(item.get(key)))
                : null;
        } catch (Exception e) {
            return null;
        }
    }
}