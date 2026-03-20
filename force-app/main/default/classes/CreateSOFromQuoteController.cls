public without sharing class CreateSOFromQuoteController {

    // ================================
    // 1. Get Quote Header Information
    // ================================
 @AuraEnabled(cacheable=true)
public static Map<String, Object> getQuoteInfo(Id quoteId) {
    try {
        Quote q = [
            SELECT
                Id,

                Name,
                AccountId,
                Account.Name,
                Account.Phone,
                Account.BillingStreet,
                Account.BillingCity,
                Account.BillingState,
                Account.BillingPostalCode,
                Account.BillingCountry,
             Account.Blocked_Account__c,
             Opportunity.Delivery_Committed_Date__c,
                Owner.Name,
                OpportunityId,
                Pricebook2Id,
                Email,
                Sales_Order_Created__c
            FROM Quote
            WHERE Id = :quoteId
            LIMIT 1
        ];

        return new Map<String, Object>{
            'quote' => q,
            'email' => q.Email
        };

    } catch (Exception e) {
        throw new AuraHandledException('Error fetching quote info: ' + e.getMessage());
    }
}

    // =================================
    // 2. Get Quote Line Items for UI
    // =================================
    @AuraEnabled(cacheable=true)
    public static List<QuoteLineItem> getQuoteLineItems(Id quoteId) {
    try {
        return [
            SELECT
                Id,
            Quantity,
            UnitPrice,
            Product2.Name,
            Product2.Tax__c,
            Product2.ProductCode,
            Product2.Product_Code__c,
            Product2.Family,
            Product2.Product_Category__c,
            PricebookEntry.Product2.Product_Category__c,
            Order_Created__c
            FROM QuoteLineItem
            WHERE QuoteId = :quoteId
            AND Order_Created__c = false
            ORDER BY CreatedDate ASC
        ];
    } catch (Exception e) {
        throw new AuraHandledException(
            'Error fetching quote line items: ' + e.getMessage()
        );
    }
}

    
    // 3. Create Order from Quote
    
    @AuraEnabled
    public static Id createOrderFromQuote(Id quoteId , Id warehouseId,List<Id> selectedQuoteLineItemIds, Map<Id, Decimal> blockQtyMap,Map<Id, String> warehouseCodeMap, Date deliveryCommittedDate, String remarks,boolean credit, String paymentMethod, String batchJson,boolean againstOrder) {
     
        system.debug('quoteId>>'+quoteId);
         system.debug('warehouseId>>'+warehouseId);
        system.debug('selectedQuoteLineItemIds>>'+selectedQuoteLineItemIds);
         system.debug('blockQtyMap>>'+blockQtyMap);
        system.debug('warehouseCodeMap>>'+warehouseCodeMap);
        system.debug('Date--'+ deliveryCommittedDate+'!!, String>>' +remarks+'  !,boolean>>'+ credit+'  String ' +batchJson);
        
        //  try {
             ///️⃣ Validate warehouse
        if (warehouseId == null) {
            throw new AuraHandledException('Please select a Warehouse');
        }
            // Fetch Quote
         Quote q = [SELECT Id, AccountId, OpportunityId,Contact_Person_Number__c,Contact_Person_Name__c, Round_Off__c,
           Pricebook2Id,  Sales_Order_Created__c, Freight_Charge__c, Loading_Charge__c,Unloading_Charge__c,ContactId,Contact.Name,Contact.Phone,BillingStreet,BillingCity, BillingState, BillingPostalCode,
           BillingCountry,ShippingStreet, ShippingCity, ShippingState, ShippingPostalCode, ShippingCountry FROM Quote WHERE Id = :quoteId LIMIT 1];
        Account acc = [ SELECT BillingStreet, BillingCity, BillingState, BillingPostalCode, BillingCountry FROM Account  WHERE Id = :q.AccountId LIMIT 1];


        // Fetch Warehouse Manager  PUT IT HERE
        Warehouse__c wh = [
            SELECT Id, Warehouse_Manager__c
            FROM Warehouse__c
            WHERE Id = :warehouseId
            LIMIT 1
        ];

            // Check if there are any unordered line items left
            Integer unorderedCount = [SELECT COUNT() FROM QuoteLineItem WHERE QuoteId = :quoteId AND Order_Created__c = false];
            if (unorderedCount == 0) {
                throw new AuraHandledException(
                    'All items in this Quote have already been ordered.'
                );
            }
    if (warehouseId == null) {
    throw new AuraHandledException('Please select a Warehouse');
}


        if (selectedQuoteLineItemIds == null || selectedQuoteLineItemIds.isEmpty()) {
    throw new AuraHandledException('Please select at least one product');
    }

    if (deliveryCommittedDate == null) {
    throw new AuraHandledException(
        'Delivery Committed Date is mandatory'
    );
}

if (deliveryCommittedDate < Date.today()) {
    throw new AuraHandledException(
        'Delivery Committed Date cannot be in the past'
    );
}
            
              // Fetch Quote Line Items
           List<QuoteLineItem> qlis = [
    SELECT
        Id,
        Quantity,
        UnitPrice,Product2.tax__c,Disc_Type__c,Dis_Value__c,
        PricebookEntryId,Product2.Product_Code__c,
        PricebookEntry.Product2.Product_Category__c,after_discount_uom_price__c
    FROM QuoteLineItem
    WHERE Id IN :selectedQuoteLineItemIds
    ];


        String category = qlis[0].PricebookEntry.Product2.Product_Category__c;

            // Create Order
            Order ord = new Order();
            ord.AccountId     = q.AccountId;
            ord.Customer__c   = q.AccountId;
            ord.OpportunityId = q.OpportunityId;
            ord.Pricebook2Id  = q.Pricebook2Id;

            ord.QuoteId           = q.Id;          // standard
            ord.Standard_Quote__c = q.Id;   
            ord.Warehouse__c  = warehouseId; 
            ord.Delivery_Committed_Date__c = deliveryCommittedDate;   
            ord.Remarks__c = remarks;   
            ord.Round_Off__c=q.Round_Off__c;

            ord.EffectiveDate = Date.today();
            ord.Status = 'Draft';
        ord.Order_status__c = 'Draft';
			ord.credit__c=credit;
            
            // Set Payment Method if credit order
            if (credit && String.isNotBlank(paymentMethod)) {
                ord.Payment_methods__c = paymentMethod;
            }
            ord.Product_Category__c = category;
            ord.Against_Order__c = againstOrder;

                ord.Contact_Person_Name__c =q.Contact_Person_Name__c;
                ord.Contact_Person_Number__c =q.Contact_Person_Number__c;

           ord.BillingStreet     = q.BillingStreet;
            ord.BillingCity       = q.BillingCity;
            ord.BillingState      = q.BillingState;
           ord.BillingPostalCode = q.BillingPostalCode;
            ord.BillingCountry    = q.BillingCountry;        
        
        if (String.isBlank(q.ShippingStreet)) {
            Account shipAcc = [
                SELECT ShippingStreet, ShippingCity, ShippingState,
                ShippingPostalCode, ShippingCountry
                FROM Account
                WHERE Id = :q.AccountId
                LIMIT 1
            ];
            
            ord.ShippingStreet     = shipAcc.ShippingStreet;
            ord.ShippingCity       = shipAcc.ShippingCity;
            ord.ShippingState      = shipAcc.ShippingState;
            ord.ShippingPostalCode = shipAcc.ShippingPostalCode;
            ord.ShippingCountry    = shipAcc.ShippingCountry; 
        }
        
        ord.Freight_Charge__c     = q.Freight_Charge__c;
        ord.Loading_Charges__c   = q.Loading_Charge__c;
        ord.Unloading_Charges__c = q.Unloading_Charge__c;

        
        ord.Warehouse_Manager__c = wh.Warehouse_Manager__c;
        insert ord;
            
            q.Status='Accepted';
            // Only mark quote as fully ordered if all line items are now ordered
            Integer remainingItems = [SELECT COUNT() FROM QuoteLineItem WHERE QuoteId = :quoteId AND Order_Created__c = false AND Id NOT IN :selectedQuoteLineItemIds];
            if (remainingItems == 0) {
                q.Sales_Order_Created__c = true;
            }
            update q;
        
        Set<String> warehouseCodes = new Set<String>();
        
        for (String code : warehouseCodeMap.values()) {
            if (String.isNotBlank(code)) {
                warehouseCodes.add(code);
            }
        }
        Map<String, Id> warehouseCodeToIdMap = new Map<String, Id>();
       system.debug('warehouseCodes  >>'+warehouseCodes); 
        if (!warehouseCodes.isEmpty()) {
            for (Warehouse__c w : [
                SELECT Id, Warehouse_Code__c
                FROM Warehouse__c
                WHERE Warehouse_Code__c IN :warehouseCodes
            ]) {
                warehouseCodeToIdMap.put(w.Warehouse_Code__c, w.Id);
            }
        }

            // Create Order Items
            List<OrderItem> orderItems = new List<OrderItem>();
            for (QuoteLineItem qli : qlis) {
                OrderItem oi = new OrderItem();
                oi.OrderId          = ord.Id;
                oi.QuoteLineItemId  = qli.Id;
                oi.PricebookEntryId = qli.PricebookEntryId;
                oi.Quantity         = qli.Quantity;
                oi.UnitPrice        = qli.UnitPrice;
                oi.UOM_Price_without_tax_and_after_disc__c = qli.After_Discount_UOM_Price__c;
                oi.Block_Quantity__c = (blockQtyMap != null && blockQtyMap.containsKey(qli.Id))? blockQtyMap.get(qli.Id): 0;
                oi.Tax_Percentage__c = qli.Product2.tax__c;
                oi.Dis_Value__c = qli.Dis_Value__c;
                oi.Disc_Type__c = qli.Disc_Type__c;
                if(warehouseCodeMap != null && 
                   warehouseCodeMap.containsKey(qli.Id)) {
                   system.debug('warehouseCodeMap  >>'+warehouseCodeMap);   
                        system.debug('warehouseCodeMap.get(qli.Id)  >>'+warehouseCodeMap.get(qli.Id));     
                       oi.Warehouse_Code__c = warehouseCodeMap.get(qli.Id);
                   }
                system.debug('oi>>'+oi); 

                orderItems.add(oi);
            }

            if (!orderItems.isEmpty()) {
                insert orderItems;
            }

            // Mark selected QuoteLineItems as ordered
            List<QuoteLineItem> qlisToUpdate = new List<QuoteLineItem>();
            for (QuoteLineItem qli : qlis) {
                qlisToUpdate.add(new QuoteLineItem(
                    Id = qli.Id,
                    Order_Created__c = true
                ));
            }
            if (!qlisToUpdate.isEmpty()) {
                update qlisToUpdate;
            }
    
//Batch recoord creation        
        if (!String.isBlank(batchJson)) {
            List<WarehouseStockWrapper> batches = (List<WarehouseStockWrapper>) JSON.deserialize(batchJson, List<WarehouseStockWrapper>.class );
            Map<Id, Id> qliToOrderItemMap = new Map<Id, Id>();
            
            for (Integer i = 0; i < qlis.size(); i++) {
                qliToOrderItemMap.put(qlis[i].Id, orderItems[i].Id);
            }
            
            List<Order_Batch_Item__c> batchRecords = new List<Order_Batch_Item__c>();
            
            for (WarehouseStockWrapper bw : batches) {
                
                if (bw == null || bw.quantity == null ||
                    bw.quantity <= 0 ||!qliToOrderItemMap.containsKey(bw.quoteLineItemId)) {
                    continue;
                }
                
                batchRecords.add(new Order_Batch_Item__c(
                    Order_Product__c = qliToOrderItemMap.get(bw.quoteLineItemId),
                    Eid__c           = bw.Eid,
                    Batch__c         = bw.Batch,
                    Warehouse_Code__c = bw.warehouseCode, // if exists
                    Quantity__c      = bw.quantity,
                    Block_Quantity__c = bw.blkQty
                ));
            }
            
            if (!batchRecords.isEmpty()) {
                insert batchRecords;
            }
        }
        if(ord.credit__c==false){
            ord.Status = 'Approved';
             ord.order_Status__c = 'Approved';
            update ord;
        }
            return ord.Id;

        
        /*}
        catch (Exception e) {
            throw new AuraHandledException(
                'Error creating order from quote: ' + e.getMessage()
            );
        }*/
    }
     // 4. Get Payment Type Options
    
    @AuraEnabled(cacheable=true)
    public static List<String> getPaymentTypeOptions() {
        return new List<String>{ 'Cash', 'Credit' };
    }

    // 5. Get Payment Methods Picklist Options (for Credit Orders)
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getPaymentMethodOptions() {
        List<Map<String, String>> options = new List<Map<String, String>>();
        Schema.DescribeFieldResult fieldResult = Order.Payment_methods__c.getDescribe();
        List<Schema.PicklistEntry> picklistEntries = fieldResult.getPicklistValues();
        for (Schema.PicklistEntry entry : picklistEntries) {
            if (entry.isActive()) {
                options.add(new Map<String, String>{
                    'label' => entry.getLabel(),
                    'value' => entry.getValue()
                });
            }
        }
        return options;
    }

   @AuraEnabled(cacheable=true)
    public static List<Warehouse__c> getActiveWarehouses() {
    return [
        SELECT Id, Name,type__c
        FROM Warehouse__c
        ORDER BY Name
    ];
    }
    
  /*  @AuraEnabled
    public static void saveBatchItems( Id orderItemId, List<Object> batchList) {
        System.debug('batchList >> ' + batchList);
        
        List<Order_Batch_Item__c> records = new List<Order_Batch_Item__c>();
        List<WarehouseStockWrapper> parsedList =
            (List<WarehouseStockWrapper>) JSON.deserialize(
                JSON.serialize(batchList),
                List<WarehouseStockWrapper>.class
            );
        for (WarehouseStockWrapper w : parsedList) {
            if (w.quantity != null && w.quantity > 0) {
                records.add(new Order_Batch_Item__c(
                    Order_Product__c = orderItemId,
                    Eid__c = w.Eid,
                    Quantity__c = w.quantity,
                    Batch__c = w.Batch,
                    Block_Quantity__c = w.blkQty
                ));
            }
        }
          System.debug('records >> ' + records);
        if (!records.isEmpty()) {
            upsert records Eid__c;
        }
    }

    */
    

    private static final String SERIES_SERVICE_URL = 'https://lemrg.hstconnect.in:8081/salesforce/api/Get_BatchStock';
    /*
@AuraEnabled
public static List<Map<String, Object>> getBatchStock1(Id orderItemId) {

    // Call SAP / API logic here
    // Example response mapping

    List<Map<String, Object>> batchList = new List<Map<String, Object>>();

    Map<String, Object> row = new Map<String, Object>();
    row.put('Batch', 'B16');
    row.put('BatchStock', 15);
    row.put('ItemCode', 'TL02811');

    batchList.add(row);
    return batchList;
}

 */   
    public class WarehouseStockWrapper {
        @AuraEnabled public String warehouseCode;
        @AuraEnabled public decimal inStock;
        @AuraEnabled public String warehouseName;
        @AuraEnabled public String IsBatchEnable;
        @AuraEnabled public String Batch;
        @AuraEnabled public String Eid;
        @AuraEnabled public decimal quantity;
         @AuraEnabled public decimal blkQty;
        @AuraEnabled public Id quoteLineItemId;
        @AuraEnabled public decimal billable;
        @AuraEnabled public decimal reserved;
        
        
    }
    
    @AuraEnabled(cacheable=false)
    public static List<WarehouseStockWrapper> getBatchStock(string orderItemId,string warehouse) {
        System.debug(' warehouse: ' + warehouse);
         list<string>wCodes= new list<string>();
            if(warehouse!=null && warehouse!=''){
                    Warehouse__c wc=[select id,Location__c from Warehouse__c where id=:warehouse];
                list<Warehouse__c>wcList=[select id,name,Warehouse_Code__c,Location__c from Warehouse__c where Location__c =:wc.Location__c];
             
                for(Warehouse__c w:wcList){
                    wCodes.add(w.Warehouse_Code__c);
            }
        }
        
        
        String InStock;
        List<WarehouseStockWrapper> resultList = new List<WarehouseStockWrapper>();
        try {
            
            List<Apex_Log__c> logList = new List<Apex_Log__c>();
            Apex_Log__c log = new Apex_Log__c();
            log.Request_Type__c ='Batch';
            
            Http http = new Http();
            Map<String, Object> bodyMap = new Map<String, Object>();
            bodyMap.put('ApiKey', 'SKYHSTskb2h82yhdc76512rgsv');
            bodyMap.put('ProductCode', orderItemId);
            // TL02811   orderItemId
            String requestBody = JSON.serialize(bodyMap);
 System.debug(' requestBody: ' + requestBody);
                    
                    String decodedUrl = EncodingUtil.urlDecode(SERIES_SERVICE_URL, 'UTF-8');
                    log.Request__c =decodedUrl; 
                    
                    System.debug('Decoded ITEMS_URL: ' + decodedUrl);
                    HttpRequest itemReq = new HttpRequest();
                    itemReq.setEndpoint(SERIES_SERVICE_URL); 
                    itemReq.setMethod('POST');
                    itemReq.setHeader('Content-Type', 'application/json');
                    itemReq.setHeader('Accept', 'application/json');
                    itemReq.setTimeout(120000);
                      itemReq.setBody(requestBody);
             System.debug(' itemReq: ' + itemReq);
                    HttpResponse itemRes = http.send(itemReq);
            System.debug(' HttpResponse: ' + itemRes);
                    log.response__c= string.valueof(itemRes.getStatusCode());
                    if (itemRes.getStatusCode() != 200) {
                        System.debug('❌ Failed to fetch items: ' + itemRes.getBody());
                        log.status__c='FAILED';
                        log.response__c= 'Status code : '+itemRes.getStatusCode() +' Response body: '+ itemRes.getBody();
                        log.Error_Message__c = 'Status code : '+itemRes.getStatusCode()+ ' Error: Callout failed. Please review the response for additional details.';
                        
                        
                    }   
                    Map<String, Object> data = (Map<String, Object>) JSON.deserializeUntyped(itemRes.getBody());
                    List<Object> warehouseInfoList = (List<Object>) data.get('oMBatchStockLsts');
                    
                    
                    if (warehouseInfoList != null && !warehouseInfoList.isEmpty()) {    
                        if (warehouseInfoList != null) {
                            
                            for (Object warehouseObj : warehouseInfoList) {
                                Map<String, Object> warehouseInfo = (Map<String, Object>) warehouseObj;
                                WarehouseStockWrapper wrap = new WarehouseStockWrapper();
                                wrap.Batch = String.valueOf(warehouseInfo.get('Batch'));
                             //   wrap.inStock = String.valueOf(warehouseInfo.get('Stock'));
                                wrap.warehouseCode = String.valueOf( warehouseInfo.get('WhsCode'));
                                wrap.warehouseName = String.valueOf(warehouseInfo.get('WhsName')); 
                                wrap.IsBatchEnable = String.valueOf(warehouseInfo.get('IsBatchEnable')); 
                              //  wrap.reserved = String.valueOf(warehouseInfo.get('Reserved')); 
                             //   wrap.billable = String.valueOf(warehouseInfo.get('Billable')); 
                                Object stockVal = warehouseInfo.get('Stock');
                                wrap.inStock = stockVal != null ? Decimal.valueOf(String.valueOf(stockVal)): 0;

                                 Object reserv = warehouseInfo.get('Reserved');
                                wrap.reserved = reserv != null ? Decimal.valueOf(String.valueOf(reserv)): 0;

                                 Object billable = warehouseInfo.get('Billable');
                                wrap.billable = billable != null ? Decimal.valueOf(String.valueOf(billable)): 0;

                                system.debug(wrap.inStock);
                                wrap.Eid = wrap.warehouseCode+wrap.Batch+ system.now() ; 
                                //wrap.IsBatchEnable=='Yes' && 
                                if(wCodes.contains( wrap.warehouseCode) && wrap.inStock>0){
                                    resultList.add(wrap);
                                   
                                }
                   //calling from newQuoteController             
                                else if(warehouse=='' && wrap.inStock>0){
                                    resultList.add(wrap);
                                }
                                System.debug(' warehouseInfo: ' + warehouseInfo);
                            }
                        }
                    }  
                    
                    
                    
                
            
            
        } catch (Exception e) {
            System.debug(' Sync failed: ' + e.getMessage() + '\\n' + e.getStackTraceString());
        }
         System.debug(' resultList: ' + resultList);
        return resultList;
        
    }
   
}