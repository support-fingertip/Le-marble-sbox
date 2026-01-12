public class SAPProductIntegration implements Schedulable {

    private static final String SAP_BASE_URL = 'https://lemrg.hstconnect.in:50000/b1s/v1';
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
                

                System.debug('❌ SAP Login Failed: ' + loginRes.getBody());
                return;
            }

            Map<String, Object> loginResult = (Map<String, Object>) JSON.deserializeUntyped(loginRes.getBody());
            String sessionId = String.valueOf(loginResult.get('SessionId'));

            if (String.isBlank(sessionId)) {
                log.status__c=' login FAILED';
                log.response__c= 'Status code : '+loginRes.getStatusCode() +' Response body: '+ loginRes.getBody();
                log.Error_Message__c = 'Status code : '+loginRes.getStatusCode()+ ' Error: Callout failed. Please review the response for additional details.';
                
                
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

            List<Product2> allRecords = new List<Product2>();
            list<PricebookEntry>pbItems= new list<PricebookEntry>();
            
            
            String decodedUrl = EncodingUtil.urlDecode(ITEMS_URL, 'UTF-8');
              log.Request__c =decodedUrl; 
            
        System.debug('Decoded ITEMS_URL: ' + decodedUrl);
        system.debug('ITEMS_URL>>>'+ITEMS_URL);
            while (!String.isBlank(ITEMS_URL)) {
                HttpRequest itemReq = new HttpRequest();
                itemReq.setEndpoint(ITEMS_URL);
                itemReq.setMethod('GET');
                itemReq.setHeader('Content-Type', 'application/json');
                itemReq.setHeader('Accept', 'application/json');
                itemReq.setHeader('Cookie', 'B1SESSION=' + sessionId);
                itemReq.setTimeout(120000);

                HttpResponse itemRes = http.send(itemReq);
		log.response__c= string.valueof(itemRes.getStatusCode());
                if (itemRes.getStatusCode() != 200) {
                    System.debug('❌ Failed to fetch items: ' + itemRes.getBody());
                     log.status__c='FAILED';
                    log.response__c= 'Status code : '+itemRes.getStatusCode() +' Response body: '+ itemRes.getBody();
                    log.Error_Message__c = 'Status code : '+itemRes.getStatusCode()+ ' Error: Callout failed. Please review the response for additional details.';

                    
                    break;
                }
	 	log.status__c='SUCCESS';
                Map<String, Object> json = (Map<String, Object>) JSON.deserializeUntyped(itemRes.getBody());
                List<Object> items = (List<Object>) json.get('value');

                for (Object obj : items) {
                    Map<String, Object> item = (Map<String, Object>) obj;
                    Product2 prod = new Product2();

                    prod.Product_Code__c = String.valueOf(item.get('ItemCode'));
                     prod.ProductCode = String.valueOf(item.get('ItemCode'));
                    prod.Name = String.valueOf(item.get('ItemName'));
                    prod.Brand__c = (String)item.get('U_Brand');
                 //   prod.IsActive=true;
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
                            string priceList = (priceMap.containsKey('PriceList') && priceMap.get('PriceList') != null) ? string.valueOf(String.valueOf(priceMap.get('PriceList'))) : '';
                            Decimal price = getDecimal(priceMap, 'Price');
                            System.debug('Product: ' + prod.Product_Code__c + ', PriceList: ' + priceList + ', Price: ' + price);
                            if (priceList == '2') {
                                prod.MSP__c = price;
                            }


                            PricebookEntry pbe = new PricebookEntry();
                            pbe.Pricebook2 = new Pricebook2(Price_List_No__c = priceList);
                            pbe.Product2  = new Product2(Product_Code__c = prod.Product_Code__c);
                            pbe.PricebookItem_ExtId__c=prod.Product_Code__c +'-'+ priceList;
                            pbe.UnitPrice    = price;
                            pbe.IsActive     = true;
                            system.debug('PricebookEntry'+pbe);
                            pbItems.add(pbe);
                        }
                    }
                /*    prod.Price_Sqft__c = getDecimal(item, 'U_UnitPrice');
                    prod.Product_Image__c = (String)item.get('U_Image');*/
                    prod.Size__c = (String)item.get('U_Size');
                    prod.Sqft_Piece__c = item.get('U_SquareFt') != null ? String.valueOf(item.get('U_SquareFt')) : null;
                    prod.Tax__c = getDecimal(item, 'U_TaxRate');
                   prod.UOM__c = (String)item.get('InventoryUOM');
                    allRecords.add(prod);
                }

                List<Database.upsertResult> results = new  List<Database.upsertResult>();
                Schema.SObjectField externalId =Product2.Fields.Product_Code__c;
                results= Database.upsert(allRecords,externalId, false);
                
                List<Database.upsertResult> results1 = new  List<Database.upsertResult>();
                Schema.SObjectField externalId1 =PricebookEntry.Fields.PricebookItem_ExtId__c;
                results1= Database.upsert(pbItems,externalId1, false);

                
                
                for(Integer index = 0, size = results.size(); index < size; index++) {
                    if(results[index].isSuccess()) {
                    }else {
                        for(Database.Error error : results[index].getErrors()) {
                            System.debug('Account Error Status : ' + error.getStatusCode() + ' : ' + 'Account Error Fields : ' + error.getFields());
                        }
                    }
                }
                for(Integer index = 0, size = results1.size(); index < size; index++) {
                    if(results1[index].isSuccess()) {
                        System.debug('pb success Status '+results1[index]);
                    }else {
                        for(Database.Error error : results1[index].getErrors()) {
                            System.debug('pb Error Status : ' + error.getStatusCode() + ' : ' + 'pb Error Fields : ' + error.getFields());
                        }
                    }
                }                
                
                ITEMS_URL = (String) json.get('@odata.nextLink');
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