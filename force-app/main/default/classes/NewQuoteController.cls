/**
* @File Name : NewQuoteController.cls
* @Description : using in newQuoteFromOpp LWC
* @Author :
* @Last Modified By : Roopesh
* @Last Modified On : 27/11/2025
* @Modification Log :
*==============================================================================
* Ver | Date | Author | Modification
*==============================================================================
* 1.0 | 27/11/2025 |   | Initial Version
**/

public class NewQuoteController {
    public class ProductWrapper {
        @AuraEnabled public Id pricebookEntryId;
        @AuraEnabled public Decimal unitPrice;
        
        @AuraEnabled public Id Id;
        @AuraEnabled public String Name;
        @AuraEnabled public String productCode;
        @AuraEnabled public String customProductCode;
        @AuraEnabled public String category;
        @AuraEnabled public Decimal tax;
        @AuraEnabled public string sqftPiece;
        //   @AuraEnabled public Boolean inStock;
    }
    
    @AuraEnabled(cacheable=true)
    public static List<ProductWrapper> getProducts(String category,String pricebookName ) {
        //  try{
        system.debug(category+' '+pricebookName);
        
        Pricebook2 pb = [
            SELECT Id
            FROM Pricebook2
            WHERE Name = :pricebookName
            LIMIT 1
        ];
        
        List<PricebookEntry> pbeList = [
            SELECT
            Id,
            UnitPrice,
            Product2Id,
            Product2.Name,
            Product2.ProductCode,
            Product2.Product_Code__c,
            Product2.Product_Category__c,
            Product2.Tax__c,
            Product2.Sqft_Piece__c,
            Product2.In_Stock__c
            FROM PricebookEntry
            WHERE Pricebook2Id = :pb.Id
            AND IsActive = true
            AND Product2.IsActive = true
            AND Product2.Product_Category__c = :category
            ORDER BY Product2.Name ASC
        ];
        
        List<ProductWrapper> result = new List<ProductWrapper>();
        
        for (PricebookEntry pbe : pbeList) {
            ProductWrapper pw = new ProductWrapper();
            
            pw.pricebookEntryId = pbe.Id;
            pw.unitPrice = pbe.UnitPrice;
            
            pw.Id = pbe.Product2Id;
            pw.Name = pbe.Product2.Name;
            pw.productCode = pbe.Product2.Product_Code__c;
            //    pw.customProductCode = pbe.Product2.Product_Code__c;
            pw.category = pbe.Product2.Product_Category__c;
            pw.tax = pbe.Product2.Tax__c;
            pw.sqftPiece = pbe.Product2.Sqft_Piece__c;
            //        pw.inStock = pbe.Product2.In_Stock__c;
            
            result.add(pw);
        }
        
        return result;
        
        /*   } catch (Exception e) {
throw new AuraHandledException(e.getMessage());
}*/
    }
    
    @AuraEnabled(cacheable=true)
    public static List<OpportunityLineItem> getOpportunityItems(Id oppId, String pricebookName,String category) {
        Pricebook2 pb = [
            SELECT Id FROM Pricebook2 WHERE Name = :pricebookName LIMIT 1
        ];
        
        return [
            SELECT Id, Quantity, UnitPrice, Discount, TotalPrice, 
            Product2Id, Product2.Name, Product2.Product_Code__c, Area__c,
            Product2.Product_Category__c,
            PricebookEntryId,
            Description
            FROM OpportunityLineItem
            WHERE OpportunityId = :oppId and Product2.Product_Category__c=:category
            AND PricebookEntry.Pricebook2Id = :pb.Id  // ensure same PB
        ];
    }
    
    @AuraEnabled(cacheable=true)
    public static List<Quote> getPendingQuotes(Id oppId){
        return [
            SELECT Id, Name 
            FROM Quote 
            WHERE OpportunityId = :oppId 
            AND Approval_Status__c IN ('Approval Pending', 'Manager Approval Pending')
            LIMIT 1
        ];
    }
    @AuraEnabled(cacheable=true)
    public static List<PricebookEntry> getPBEntries(String pbName) {
        
        Pricebook2 pb = [
            SELECT Id	
            FROM Pricebook2
            WHERE Name = :pbName
            LIMIT 1
        ];
        system.debug('Pricebook2>>'+pb);
        system.debug('PricebookEntry>>>'+[
            SELECT Id, Name, UnitPrice, Product2Id, Product2.Name,Pricebook2Id
            FROM PricebookEntry
            WHERE Pricebook2Id = :pb.Id
            AND IsActive = true
        ]);
        return [
            SELECT Id, Name, UnitPrice, Product2Id, Product2.Name,Pricebook2Id
            
            FROM PricebookEntry
            WHERE Pricebook2Id = :pb.Id
            AND IsActive = true
        ];
    }
    
    @AuraEnabled(cacheable=true)
    public static List<String> getProductCategories() {
        try {
            Schema.DescribeFieldResult fieldResult = Product2.Product_Category__c.getDescribe();
            List<Schema.PicklistEntry> ple = fieldResult.getPicklistValues();
            List<String> categories = new List<String>();
            
            for(Schema.PicklistEntry pickListVal : ple) {
                categories.add(pickListVal.getLabel());
            }
            
            return categories;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static List<String> getPriceNames() {
        try {
            list<Pricebook2>pbs=[select id,name from Pricebook2 where IsActive=true];
            List<String> pbNames = new List<String>();
            
            for(Pricebook2 pb : pbs) {
                
                pbNames.add(pb.name);
            }
            
            return pbNames;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    // Method to create cart and cart line items
    @AuraEnabled
    public static String createCart(String customerId, List<Map<String, Object>> cartItems,Decimal freightCharge, Decimal loadingCharge, 
                                    Decimal unloadingCharge,string pbName,decimal orderTotal,string category) {
                                        
                                        system.debug('orderTotal>>'+orderTotal);
                                        system.debug('pbName>>'+pbName);
                                        //      try {
                                        Pricebook2 pb = [
                                            SELECT Id
                                            FROM Pricebook2
                                            WHERE Name = :pbName
                                            LIMIT 1
                                        ];
                                        System.debug('Creating cart for customerId: ' + customerId);
                                        System.debug('Cart items count: ' + (cartItems != null ? cartItems.size() : 0));
                                        System.debug('Freight: ' + freightCharge + ', Loading: ' + loadingCharge + ', Unloading: ' + unloadingCharge);
                                        
                                        string oppName=[select id, name from Opportunity where id=:customerId].name; 
                                        integer vQuote=[SELECT COUNT() FROM Quote WHERE OpportunityId = :customerId];
                                        Decimal priceLimit = Decimal.valueOf(Label.Quote_Approval_limit); 
                                        
                                        opportunity oppParent=[select id,name,Account.name,Account.BillingStreet,Account.BillingCity,Account.BillingState,Account.BillingCountry,Account.Email__c,Account.Phone,Account.BillingPostalCode,              
                                                               AddressLine1__c,AddressLine2__c,AddressLine3__c,Corporation__c,Country__c,District__c,Municipality__c,Panchayath__c,State__c,Village__c from Opportunity where id=:customerId];          
                                        
                                        // Create new Cart record
                                        Quote cart = new Quote();
                                        cart.OpportunityId=customerId;
                                        cart.Name=oppName+'- V'+vQuote;
                                        cart.Pricebook2Id = pb.id;  
                                        cart.Quote_Category__c=category;
                                        
                                        cart.BillingStreet   = oppParent.Account.BillingStreet;
                                        cart.BillingCity     = oppParent.Account.BillingCity;
                                        cart.BillingState    = oppParent.Account.BillingState;
                                        cart.BillingPostalCode = oppParent.Account.BillingPostalCode;
                                        cart.BillingCountry  = oppParent.Account.BillingCountry;
                                        
                                        //     cart.BillingAddress=oppParent.Account.BillingAddress;
                                        cart.Email=oppParent.Account.Email__c;
                                        cart.Phone=oppParent.Account.Phone;
                                        
                                        
                                        cart.AddressLine1__c= oppParent.AddressLine1__c;
                                        cart.AddressLine2__c= oppParent.AddressLine2__c;
                                        cart.AddressLine3__c= oppParent.AddressLine3__c;
                                        cart.District__c= oppParent.District__c;
                                        cart.State__c= oppParent.State__c;
                                        cart.Country__c= oppParent.country__c;
          
                                        
                                        // Set other fields
                                        cart.Freight_Charge__c = freightCharge != null ? freightCharge : 0;
                                        cart.Loading_Charge__c = loadingCharge != null ? loadingCharge : 0;
                                        cart.Unloading_Charge__c = unloadingCharge != null ? unloadingCharge : 0;
                                        if(priceLimit>orderTotal){                                           
                                            cart.Approval_Status__c = 'Approved'; 
                                            cart.Status='Approved';
                                        }
                                        insert cart;
                                        System.debug('Quote created with ID: ' + cart.Id);
                                        
                                        // Create Quote Line Items if any items exist
                                        if (cartItems == null || cartItems.isEmpty()) {
                                            System.debug('No Quote items to process');
                                            return cart.Id;
                                        }
                                        
                                        List<QuoteLineItem> lineItems = new List<QuoteLineItem>();
                                        for(Map<String, Object> item : cartItems) {
                                            system.debug('item>> '+(String)item.get('totalPrice'));
                                            try {
                                                if (item == null || !item.containsKey('id')) {
                                                    System.debug('Skipping null item or item without product ID');
                                                    continue;
                                                }
                                                
                                                QuoteLineItem lineItem = new QuoteLineItem(
                                                    QuoteId = cart.Id,
                                                    Product2Id = (String)item.get('id'),
                                                    PricebookEntryId =(String)item.get('pricebookEntryId')
                                                );
                                                
                                                
                                                if(item.containsKey('totalPrice')) {
                                                    lineItem.Calculated_Total_Price__c = safeDecimalConversion(item.get('totalPrice'));
                                                }
                                                
                                                // Handle fields with safe conversion
                                                if(item.containsKey('category')) {
                                                    lineItem.Product_Category__c = String.valueOf(item.get('category'));
                                                }
                                                
                                                if(item.containsKey('quantity')) {
                                                    lineItem.Quantity = safeDecimalConversion(item.get('quantity'));
                                                } else {
                                                    lineItem.Quantity = 1; // Default to 1 if missing
                                                }
                                                
                                                if(item.containsKey('uom')) {
                                                    lineItem.UOM__c = String.valueOf(item.get('uom'));
                                                }
                                                
                                                // For tiles, use unitPriceAfterTax and pricePerSqft
                                                if(item.containsKey('unitPriceAfterTax')) {
                                                    lineItem.UnitPrice = safeDecimalConversion(item.get('unitPriceAfterTax'));
                                                } else if(item.containsKey('unitPrice')) {
                                                    lineItem.UnitPrice = safeDecimalConversion(item.get('unitPrice'));
                                                }
                                                if(item.containsKey('pricePerSqft')) {
                                                    lineItem.Price_Sqft__c = safeDecimalConversion(item.get('pricePerSqft'));
                                                } else if(item.containsKey('priceSqft')) {
                                                    lineItem.Price_Sqft__c = safeDecimalConversion(item.get('priceSqft'));
                                                }
                                                System.debug('DEBUG: LineItem.Unit_Price__c: ' + lineItem.UnitPrice);
                                                System.debug('DEBUG: LineItem.Price_Sqft__c: ' + lineItem.Price_Sqft__c);
                                                
                                                /*       if(item.containsKey('sqft')) {
lineItem.Sqft__c = safeDecimalConversion(item.get('sqft'));
}*/
                                                
                                                if(item.containsKey('sqm')) {
                                                    lineItem.Sqm__c = safeDecimalConversion(item.get('sqm'));
                                                }
                                                
                                                if(item.containsKey('discType')) {
                                                    lineItem.Disc_Type__c = String.valueOf(item.get('discType'));
                                                }
                                                
                                                if(item.containsKey('discValue')) {
                                                    lineItem.Dis_Value__c = safeDecimalConversion(item.get('discValue'));
                                                }
                                                
                                                // Original discount field - may be needed for backward compatibility
                                                if(item.containsKey('discount')) {
                                                    //       lineItem.Discount = safeDecimalConversion(item.get('discount'));
                                                }
                                                
                                                // Original price field - may be needed for backward compatibility
                                                if(item.containsKey('price')) {
                                                    lineItem.Price__c = safeDecimalConversion(item.get('price'));
                                                }
                                                if(item.containsKey('requiredSqft')) {
                                                    lineItem.Sqft__c = safeDecimalConversion(item.get('requiredSqft'));
                                                }
                                                
                                                
                                                
                                                if(item.containsKey('afterDiscPricePiece')) {
                                                    lineItem.After_Disc_Price_Piece__c = safeDecimalConversion(item.get('afterDiscPricePiece'));
                                                }
                                                
                                                if(item.containsKey('afterDiscPriceSqft')) {
                                                    lineItem.After_Disc_Price_Sqft__c = safeDecimalConversion(item.get('afterDiscPriceSqft'));
                                                }
                                                
                                                if(item.containsKey('blocked')) {
                                                    lineItem.Blocked__c = safeDecimalConversion(item.get('blocked'));
                                                }
                                                
                                                if(item.containsKey('roomType')) {
                                                    lineItem.Room_Type__c = String.valueOf(item.get('roomType'));
                                                }
                                                
                                                /*                     if(item.containsKey('msp')) {
lineItem.MSP__c = safeDecimalConversion(item.get('msp'));
}*/
                                                
                                                
                                                if(item.containsKey('description')) lineItem.Description = String.valueOf(item.get('description'));
                                                
                                                System.debug('Added line item : ' + lineItem);
                                                lineItems.add(lineItem);
                                                System.debug('Added line item for product: ' + lineItem.Product2Id);
                                            } 
                                            catch(Exception e) {
                                                System.debug('Error processing cart item: ' + e.getMessage());
                                                System.debug('Stack trace: ' + e.getStackTraceString());
                                                if(item != null) {
                                                    System.debug('Cart item data: ' + JSON.serialize(item));
                                                }
                                                // Continue with next item
                                            }
                                        }
                                        
                                        if(!lineItems.isEmpty()) {
                                            try {
                                                insert lineItems;
                                                if(priceLimit < orderTotal){      
                                                    checkAndSubmitForApproval(cart,orderTotal);
                                                }  
                                                List<Quote> quotesToUpdate = [
                                                    SELECT Id, Approval_Status__c 
                                                    FROM Quote 
                                                    WHERE OpportunityId =:customerId and id!=:cart.id
                                                    AND Approval_Status__c = 'Approved'
                                                ];
                                                
                                                // Change status → Revised
                                                for(Quote q : quotesToUpdate){
                                                    q.Approval_Status__c = 'Revised';
                                                }
                                                
                                                if(!quotesToUpdate.isEmpty()) {
                                                    update quotesToUpdate;
                                                }
                                                System.debug('Inserted ' + lineItems.size() + ' line items');
                                            } catch(Exception e) {
                                                System.debug('Error inserting line items: ' + e.getMessage());
                                                System.debug('Stack trace: ' + e.getStackTraceString());
                                                // Even if line items fail, return the cart ID
                                            }
                                        } else {
                                            System.debug('No valid line items to insert');
                                        }
                                        
                                        return cart.Id;
                                        //} 
                                        /*catch (Exception e) {
System.debug('Error creating cart: ' + e.getMessage());
System.debug('Error stack trace: ' + e.getStackTraceString());
throw new AuraHandledException('Error creating cart: ' + e.getMessage());
}*/
                                    }
    
    // Helper method to safely convert values to Decimal
    private static Decimal safeDecimalConversion(Object val) {
        if(val == null) return null;
        
        if(val instanceof Decimal) {
            return (Decimal)val;
        } else if(val instanceof Integer) {
            return Decimal.valueOf((Integer)val);
        } else if(val instanceof Double) {
            return Decimal.valueOf((Double)val);
        } else if(val instanceof String) {
            String strVal = (String)val;
            if(strVal.trim() == '') return null;
            return Decimal.valueOf(strVal);
        } else {
            String strVal = String.valueOf(val);
            if(strVal.trim() == '') return null;
            return Decimal.valueOf(strVal);
        }
    }
    
    // Method to get existing cart for a deal
    @AuraEnabled(cacheable=true)
    public static List<quote> getCustomerCarts(String dealId) {
        try {
            return [SELECT Id, Name, TotalPrice, Freight_Charge__c, Loading_Charge__c, Unloading_Charge__c,
                    (SELECT Id, LineNumber, Product2Id, Product_Category__c, 
                     Quantity, UOM__c, Unit_Price__c, Price_Sqft__c, 
                     Disc_Type__c, Dis_Value__c, Sqft__c, Sqm__c,
                     After_Disc_Price_Piece__c, After_Disc_Price_Sqft__c, Total_Price__c 
                     FROM QuoteLineItems)
                    FROM quote 
                    WHERE OpportunityId = :dealId
                    ORDER BY CreatedDate DESC];
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    public static void checkAndSubmitForApproval(quote newQuotes, decimal grandTotal){
        Decimal priceLimit = Decimal.valueOf(Label.Quote_Approval_limit); 
        
        List<Approval.ProcessSubmitRequest> requests = new List<Approval.ProcessSubmitRequest>();
        
        if(grandTotal > priceLimit){
            
            Approval.ProcessSubmitRequest req = new Approval.ProcessSubmitRequest();
            req.setObjectId(newQuotes.Id);
            requests.add(req);
        }
        
        
        for(Approval.ProcessSubmitRequest req : requests){
            Approval.ProcessResult result = Approval.process(req);
        }
    }
    
    private static final String SAP_BASE_URL = 'https://lemrg.hstconnect.in:50000/b1s/v1';
    private static final String LOGIN_URL = SAP_BASE_URL + '/Login';
    private static final String SERIES_SERVICE_URL = SAP_BASE_URL + '/SeriesService_GetSeries';
    
    
    private static final String COMPANY_DB = 'MG_LIVE_WIP_1';
    private static final String USERNAME = 'manager';
    private static final String PASSWORD = 'Mgsap12@';
    
    public class WarehouseStockWrapper {
        @AuraEnabled public String warehouseCode;
        @AuraEnabled public Decimal inStock;
        @AuraEnabled public Decimal committed;
    }
    
    @AuraEnabled(cacheable=false)
    public static List<WarehouseStockWrapper> checkLiveStock(string itemcode) {
        String InStock;
        List<WarehouseStockWrapper> resultList = new List<WarehouseStockWrapper>();
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
            if (loginRes.getStatusCode() == 200) {
                system.debug(loginRes.getBody());
                Map<String, Object> loginResult = (Map<String, Object>) JSON.deserializeUntyped(loginRes.getBody());
                String sessionId = String.valueOf(loginResult.get('SessionId'));
                if (!String.isBlank(sessionId)){
                    String ITEMS_URL = SAP_BASE_URL + '/Items(\'' + itemcode + '\')';
                    
                    String decodedUrl = EncodingUtil.urlDecode(ITEMS_URL, 'UTF-8');
                    log.Request__c =decodedUrl; 
                    
                    System.debug('Decoded ITEMS_URL: ' + decodedUrl);
                    system.debug('ITEMS_URL>>>'+ITEMS_URL);
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
                        
                        
                    }
                    Map<String, Object> data = (Map<String, Object>) JSON.deserializeUntyped(itemRes.getBody());
                    List<Object> warehouseInfoList = (List<Object>) data.get('ItemWarehouseInfoCollection');
                    
                    
                    if (warehouseInfoList != null && !warehouseInfoList.isEmpty()) {    
                        if (warehouseInfoList != null) {
                            
                            for (Object warehouseObj : warehouseInfoList) {
                                Map<String, Object> warehouseInfo = (Map<String, Object>) warehouseObj;
                                /*    String whsCode = String.valueOf(warehouseInfo.get('WarehouseCode'));
if(whsCode==wareHCode){  
InStock = String.valueOf(warehouseInfo.get('InStock'));
}*/
                                WarehouseStockWrapper wrap = new WarehouseStockWrapper();
                                wrap.warehouseCode = String.valueOf(warehouseInfo.get('WarehouseCode'));
                                wrap.inStock = (Decimal) warehouseInfo.get('InStock');
                                wrap.committed = (Decimal) warehouseInfo.get('Committed');
                                
                                resultList.add(wrap);
                                System.debug(' warehouseInfo: ' + warehouseInfo);
                            }
                        }
                    }  
                    
                    
                    
                }
            }
            
        } catch (Exception e) {
            System.debug(' Sync failed: ' + e.getMessage() + '\\n' + e.getStackTraceString());
        }
        System.debug(' InStock: ' + InStock);
        return resultList;
        
    }
    
    @AuraEnabled
    public static String createCartLineItem(String cartId, Map<String, Object> item) {
        try {
            quote q=[select id from quote where id=:cartId];
            QuoteLineItem lineItem = new QuoteLineItem(
                quote = q,
                Product2Id = (String)item.get('id'),
                PricebookEntryId =(String)item.get('PricebookEntry')
            );
            if(item.containsKey('category')) lineItem.Product_Category__c = String.valueOf(item.get('category'));
            if(item.containsKey('quantity')) lineItem.Quantity = safeDecimalConversion(item.get('quantity'));
            if(item.containsKey('uom')) lineItem.UOM__c = String.valueOf(item.get('uom'));
            if(item.containsKey('unitPrice')) lineItem.UnitPrice = safeDecimalConversion(item.get('unitPrice'));
            if(item.containsKey('priceSqft')) lineItem.Price_Sqft__c = safeDecimalConversion(item.get('priceSqft'));
            if(item.containsKey('sqft')) lineItem.Sqft__c = safeDecimalConversion(item.get('sqft'));
            if(item.containsKey('sqm')) lineItem.Sqm__c = safeDecimalConversion(item.get('sqm'));
            if(item.containsKey('discType')) lineItem.Disc_Type__c = String.valueOf(item.get('discType'));
            if(item.containsKey('discValue')) lineItem.Dis_Value__c = safeDecimalConversion(item.get('discValue'));
            if(item.containsKey('discount')) lineItem.Discount = safeDecimalConversion(item.get('discount'));
            if(item.containsKey('price')) lineItem.Price__c = safeDecimalConversion(item.get('price'));
            if(item.containsKey('afterDiscPricePiece')) lineItem.After_Disc_Price_Piece__c = safeDecimalConversion(item.get('afterDiscPricePiece'));
            if(item.containsKey('afterDiscPriceSqft')) lineItem.After_Disc_Price_Sqft__c = safeDecimalConversion(item.get('afterDiscPriceSqft'));
            if(item.containsKey('blocked')) lineItem.Blocked__c = safeDecimalConversion(item.get('blocked'));
            if(item.containsKey('roomType')) lineItem.Room_Type__c = String.valueOf(item.get('roomType'));
            if(item.containsKey('description')) lineItem.Description = String.valueOf(item.get('description'));
            
            insert lineItem;
            return lineItem.Id;
        } catch (Exception e) {
            throw new AuraHandledException('Error creating cart line item: ' + e.getMessage());
        }
    }
    // Dummy method 1: Utility to log information
    public static void logInfo(String message) {
        System.debug('INFO: ' + message);
    }
    // Dummy method 2: Utility to log errors
    public static void logError(String message) {
        System.debug('ERROR: ' + message);
    }
    // Dummy method 3: Generate a greeting message
    public static String generateGreeting(String name) {
        if (String.isEmpty(name)) {
            return 'Hello, Guest!';
        }
        return 'Hello, ' + name + '!';
    }
    // Dummy method 4: Perform a simple arithmetic operation
    public static Integer addNumbers(Integer a, Integer b) {
        return a + b;
    }
    // Dummy method 5: Validate a Lead Source
    public static Boolean isValidLeadSource(String leadSource) {
        List<String> validSources = new List<String>{'Web', 'Referral', 'Advertisement'};
            return validSources.contains(leadSource);
    }
    // Dummy method 6: Convert a Lead Source to a custom value
    public static String mapLeadSource(String leadSource) {
        if (leadSource == 'Web') {
            return 'Online';
        } else if (leadSource == 'Referral') {
            return 'Word of Mouth';
        } else if (leadSource == 'Advertisement') {
            return 'Marketing Campaign';
        }
        return 'Unknown';
    }
    // Dummy method 7: Generate a random number between a range
    public static Integer generateRandomNumber(Integer min, Integer max) {
        return min + (Integer) Math.floor(Math.random() * (max - min + 1));
    }
    // Dummy method 9: Convert a string to uppercase
    public static String convertToUpperCase(String input) {
        return input != null ? input.toUpperCase() : null;
    }
    // Dummy method 10: Calculate factorial of a number
    public static Integer calculateFactorial(Integer num) {
        if (num < 0) {
            throw new IllegalArgumentException('Number must be non-negative');
        }
        Integer factorial = 1;
        for (Integer i = 1; i <= num; i++) {
            factorial *= i;
        }
        return factorial;
    }
    // Dummy method 11: Reverse a string
    public static String reverseString(String input) {
        if (String.isEmpty(input)) {
            return input;
        }
        String reversed = '';
        for (Integer i = input.length() - 1; i >= 0; i--) {
            reversed += input.substring(i, i + 1);
        }
        return reversed;
    }
    // Dummy method 12: Check if a string is a palindrome
    public static Boolean isPalindrome(String input) {
        if (String.isEmpty(input)) {
            return false;
        }
        String reversed = reverseString(input);
        return input.equals(reversed);
    }
    // Dummy method 13: Sum of the digits of a number (without modulus operator)
    public static Integer sumOfDigits(Integer num) {
        Integer sum = 0;
        while (num > 0) {
            sum += (num - (num / 10) * 10);  // Extract the last digit
            num = num / 10;  // Remove the last digit
        }
        return sum;
    }
    // Dummy method 14: Check if a number is prime (without modulus operator)
    public static Boolean isPrimeNumber(Integer num) {
        if (num <= 1) {
            return false;  // Numbers <= 1 are not prime
        }
        for (Integer i = 2; i * i <= num; i++) {  // We check up to sqrt(num)
            if (i * (num / i) == num) {  // Check divisibility without modulus
                return false;  // Not prime if divisible
            }
        }
        return true;  // Prime number
    }
    // Dummy method 15: Find the largest digit in a number
    public static Integer findLargestDigit(Integer num) {
        Integer largestDigit = 0;
        while (num > 0) {
            Integer digit = num - (num / 10) * 10;  // Extract the last digit
            largestDigit = Math.max(largestDigit, digit);  // Update largest digit
            num = num / 10;  // Remove the last digit
        }
        return largestDigit;
    }
    // Dummy method 16: Reverse an array (list) of integers
    public static List<Integer> reverseArray(List<Integer> arr) {
        List<Integer> reversedList = new List<Integer>();
        for (Integer i = arr.size() - 1; i >= 0; i--) {
            reversedList.add(arr.get(i));  // Add elements in reverse order
        }
        return reversedList;
    }
    public static Boolean isLeapYear(Integer year) {
        if (year == null || year < 0) return false; // Invalid year
        Boolean divisibleBy4 = (Math.floor(year / 4) * 4 == year);
        Boolean divisibleBy100 = (Math.floor(year / 100) * 100 == year);
        Boolean divisibleBy400 = (Math.floor(year / 400) * 400 == year);
        return (divisibleBy4 && !divisibleBy100) || divisibleBy400;
    }
    public static Integer countWords(String input) {
        if (String.isEmpty(input)) return 0;
        return input.trim().split('\\s+').size(); // Splits by whitespace and counts words
    }
}