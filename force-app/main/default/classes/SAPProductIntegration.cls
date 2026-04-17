public class SAPProductIntegration implements Schedulable {

    private static final String SAP_BASE_URL = 'https://lemrg.hstconnect.in:50000/b1s/v1';
    private static final String LOGIN_URL = SAP_BASE_URL + '/Login';
    private static final String SERIES_SERVICE_URL = SAP_BASE_URL + '/SeriesService_GetSeries';

    private static final String COMPANY_DB = 'MG_LIVE_WIP_1';
    private static final String USERNAME = 'manager';
    private static final String PASSWORD = 'Mgsap12@';

    public void execute(SchedulableContext sc) {
         runSync(null);
    }
   public static void runSync() {
        runSync(null);
    }
     public static void runSync(Date selectedDate) {
        try {
            
            List<Apex_Log__c> logList = new List<Apex_Log__c>();
            Apex_Log__c log = new Apex_Log__c();
            log.Request_Type__c ='Product';
            
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
                 log.status__c=' login FAILED';
                log.response__c= 'Status code : '+loginRes.getStatusCode() +' Response body: '+ loginRes.getBody();
                log.Error_Message__c = 'Status code : '+loginRes.getStatusCode()+ ' Error: Callout failed. Please review the response for additional details.';
                
insert log;
                System.debug('❌ SAP Login Failed: ' + loginRes.getBody());
                return;
            }

            Map<String, Object> loginResult = (Map<String, Object>) JSON.deserializeUntyped(loginRes.getBody());
            String sessionId = String.valueOf(loginResult.get('SessionId'));

            if (String.isBlank(sessionId)) {
                log.status__c=' login FAILED';
                log.response__c= 'Status code : '+loginRes.getStatusCode() +' Response body: '+ loginRes.getBody();
                log.Error_Message__c = 'Status code : '+loginRes.getStatusCode()+ ' Error: Callout failed. Please review the response for additional details.';
                
                insert log;
                System.debug('❌ Missing SAP session ID');
                return;
            }
  DateTime fromDateTime;
            Product_Sync_Setting__c setting = Product_Sync_Setting__c.getInstance();

            if (selectedDate != null) {
                // UI-supplied date: fetch everything from midnight of that date
                fromDateTime = DateTime.newInstance(selectedDate, Time.newInstance(0, 0, 0, 0));
                System.debug('ℹ Using UI-supplied date: ' + selectedDate);
            } else {
            // 2. Determine Last Sync Time
                  fromDateTime = (setting.Last_Sync__c != null)
                               ? setting.Last_Sync__c
                               : System.now().addDays(-1);
                System.debug('ℹ Using Last_Sync setting: ' + fromDateTime);
            }
            String formattedDate = fromDateTime.format('yyyy-MM-dd\'T\'HH:mm:ss');

            // Split into two separate callouts: UpdateDate first, then CreateDate
            String updateFilter = 'UpdateDate ge datetime\'' + formattedDate + '\'';
            String createFilter = 'CreateDate ge datetime\'' + formattedDate + '\'';

            List<Product2> allRecords = new List<Product2>();
            List<PricebookEntry> pbItems = new List<PricebookEntry>();

            // First callout: fetch products by UpdateDate
            String updateUrl = SAP_BASE_URL + '/Items?$filter=' + EncodingUtil.urlEncode(updateFilter, 'UTF-8') + '&$orderby=UpdateTime'+'&$top=5000';
            log.Request__c = EncodingUtil.urlDecode(updateUrl, 'UTF-8');
            System.debug('UpdateDate callout URL: ' + EncodingUtil.urlDecode(updateUrl, 'UTF-8'));
            fetchItems(sessionId, updateUrl, http, allRecords, pbItems, log);

            // Second callout: fetch products by CreateDate
            String createUrl = SAP_BASE_URL + '/Items?$filter=' + EncodingUtil.urlEncode(createFilter, 'UTF-8') + '&$orderby=CreateTime'+'&$top=5000';
            System.debug('CreateDate callout URL: ' + EncodingUtil.urlDecode(createUrl, 'UTF-8'));
            fetchItems(sessionId, createUrl, http, allRecords, pbItems, log);

            // 3. Deduplicate by external ID (same record may appear in both the
            //    UpdateDate and CreateDate result sets) then upsert.
            Map<String, Product2> dedupedProducts = new Map<String, Product2>();
            for (Product2 p : allRecords) {
                if (String.isNotBlank(p.Product_Code__c)) {
                    dedupedProducts.put(p.Product_Code__c, p); // later wins
                }
            }
            Map<String, PricebookEntry> dedupedPbes = new Map<String, PricebookEntry>();
            for (PricebookEntry pbe : pbItems) {
                if (String.isNotBlank(pbe.PricebookItem_ExtId__c)) {
                    dedupedPbes.put(pbe.PricebookItem_ExtId__c, pbe);
                }
            }

            if (!dedupedProducts.isEmpty()) {
                List<Product2> toUpsert = dedupedProducts.values();
                List<Database.UpsertResult> results = Database.upsert(toUpsert, Product2.Fields.Product_Code__c, false);
                for (Integer i = 0, sz = results.size(); i < sz; i++) {
                    if (!results[i].isSuccess()) {
                        for (Database.Error error : results[i].getErrors()) {
                            System.debug('Product Error: ' + error.getStatusCode() + ' : ' + error.getFields()
                                + ' code=' + toUpsert[i].Product_Code__c);
                        }
                    }
                }
            }
            if (!dedupedPbes.isEmpty()) {
                List<PricebookEntry> toUpsert = dedupedPbes.values();
                List<Database.UpsertResult> results1 = Database.upsert(toUpsert, PricebookEntry.Fields.PricebookItem_ExtId__c, false);
                for (Integer i = 0, sz = results1.size(); i < sz; i++) {
                    if (!results1[i].isSuccess()) {
                        for (Database.Error error : results1[i].getErrors()) {
                            System.debug('PB Error: ' + error.getStatusCode() + ' : ' + error.getFields()
                                + ' extId=' + toUpsert[i].PricebookItem_ExtId__c);
                        }
                    }
                }
            }

            // 4. Save last sync time
            setting.Last_Sync__c = System.now();
            upsert setting;

            System.debug('✔ Sync complete: ' + allRecords.size() + ' products processed.');

        } catch (Exception e) {
            System.debug('❌ Sync failed: ' + e.getMessage() + '\\n' + e.getStackTraceString());
        }
    }

    private static void fetchItems(String sessionId, String itemsUrl, Http http, List<Product2> allRecords, List<PricebookEntry> pbItems, Apex_Log__c log) {
        while (!String.isBlank(itemsUrl)) {
            HttpRequest itemReq = new HttpRequest();
            itemReq.setEndpoint(itemsUrl);
            itemReq.setMethod('GET');
            itemReq.setHeader('Content-Type', 'application/json');
            itemReq.setHeader('Accept', 'application/json');
            itemReq.setHeader('Cookie', 'B1SESSION=' + sessionId);
            itemReq.setTimeout(120000);

            HttpResponse itemRes = http.send(itemReq);
            log.response__c = String.valueOf(itemRes.getStatusCode());
            if (itemRes.getStatusCode() != 200) {
                System.debug('Failed to fetch items: ' + itemRes.getBody());
                log.status__c = 'FAILED';
                log.response__c = 'Status code : ' + itemRes.getStatusCode() + ' Response body: ' + itemRes.getBody();
                log.Error_Message__c = 'Status code : ' + itemRes.getStatusCode() + ' Error: Callout failed. Please review the response for additional details.';
                break;
            }
            log.status__c = 'SUCCESS';
            Map<String, Object> jsonResp = (Map<String, Object>) JSON.deserializeUntyped(itemRes.getBody());
            List<Object> items = (List<Object>) jsonResp.get('value');

            for (Object obj : items) {
                Map<String, Object> item = (Map<String, Object>) obj;
                Product2 prod = new Product2();

                prod.Product_Code__c = String.valueOf(item.get('ItemCode'));
                prod.ProductCode = String.valueOf(item.get('ItemCode'));
                prod.Name = String.valueOf(item.get('ItemName'));
                prod.Brand__c = (String)item.get('U_Brand');
                prod.Warranty__c = item.get('U_WarrantyPeriod') != null ? Decimal.valueOf(String.valueOf(item.get('U_WarrantyPeriod'))) : 0;

                String vali = (String)item.get('Valid');
                if (vali == 'tYES') {
                    prod.IsActive = true;
                } else if (vali == 'tNO') {
                    prod.IsActive = false;
                }

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
                        String priceList = (priceMap.containsKey('PriceList') && priceMap.get('PriceList') != null) ? String.valueOf(priceMap.get('PriceList')) : '';
                        Decimal price = getDecimal(priceMap, 'Price');
                        System.debug('Product: ' + prod.Product_Code__c + ', PriceList: ' + priceList + ', Price: ' + price);
                        if (priceList == '1') {
                            prod.MSP__c = price;
                        }

                        // Skip PBE rows without a usable parent — blank PriceList cannot resolve
                        // Pricebook2 via Price_List_No__c and surfaces as INVALID_FIELD : () on upsert.
                        if (String.isBlank(priceList) || String.isBlank(prod.Product_Code__c)) {
                            continue;
                        }

                        PricebookEntry pbe = new PricebookEntry();
                        pbe.Pricebook2 = new Pricebook2(Price_List_No__c = priceList);
                        pbe.Product2 = new Product2(Product_Code__c = prod.Product_Code__c);
                        pbe.PricebookItem_ExtId__c = prod.Product_Code__c + '-' + priceList;
                        pbe.UnitPrice = price;
                        pbe.IsActive = true;
                        pbItems.add(pbe);
                    }
                }
                prod.Size__c = (String)item.get('U_Size');
                prod.Sqft_Piece__c = item.get('U_SquareFt') != null ? String.valueOf(item.get('U_SquareFt')) : null;
                prod.Tax__c = getDecimal(item, 'U_TaxRate');
                prod.UOM__c = (String)item.get('InventoryUOM');
                prod.U_ProductName__c = (String)item.get('U_ProductName');

                allRecords.add(prod);
            }

            itemsUrl = (String) jsonResp.get('@odata.nextLink');
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