public class sapIntegration {
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
    
    // Create Business Partner in SAP
   @future(callout=true)
    public static void createBusinessPartner(Id dealId) {
          List<Apex_Log__c> logList = new List<Apex_Log__c>();
            Apex_Log__c log = new Apex_Log__c();
        
        CustomNotificationType notificationType = [SELECT Id, DeveloperName
                                                   FROM CustomNotificationType
                                                   WHERE DeveloperName='Account_Notification'];
        Messaging.CustomNotification notification = new Messaging.CustomNotification();
        notification.setNotificationTypeId(notificationType.Id);
        notification.setTargetId(dealId);
            String adminUserId = [SELECT Id FROM User WHERE Profile.Name = 'System Administrator' and isactive=true LIMIT 1].Id;
        Set<String> addressee = new Set<String>();
        if(adminUserId!=null){
               addressee.add(adminUserId); 
            }
        try {
                      
            
            Account deal = [
                SELECT Customer_Number__c, Name, Email__c, Phone, Secondary_Phone__c,Type,
                       Address_Line1__c, Address_Line2__c,Address_Line3__c,Corporation__c,Municipality__c,Panchayath__c,Village__c,State__c,Country__c,Description,District__c,GST_Number__c,Owner_Name__c,
                         ShippingState,ShippingCountry, ShippingCity,ShippingStreet,ShippingAddress,BillingAddress,ShippingPostalCode,
                BillingState,BillingCountry, BillingCity,BillingStreet,BillingPostalCode FROM Account
                WHERE Id = :dealId
                LIMIT 1
            ];
            notification.setTitle('Account :'+deal.Name);
 		 String NotificationBody =  'Account Name : ' + Account.Name +'\nAccount created by : ' + deal.Owner_Name__c;

		log.Request_Type__c ='Account -'+deal.Customer_Number__c;
            
            Http http = new Http();
                string sessionId= loginToSAP();
           
            // 1. Check if BP exists in SAP
            HttpRequest getRequest = new HttpRequest();
            getRequest.setEndpoint('https://lemrg.hstconnect.in:50000/b1s/v1/BusinessPartners(\'' + deal.Customer_Number__c + '\')');
            getRequest.setMethod('GET');
            getRequest.setHeader('Cookie', 'B1SESSION=' + sessionId);
            HttpResponse getResponse = http.send(getRequest);

            if (getResponse.getStatusCode() == 200) {
                log.status__c='Failed';
                log.response__c= 'Status code : '+getResponse.getStatusCode() +' Response body: '+ getResponse.getBody();
                log.Error_Message__c = 'Status code : '+getResponse.getStatusCode()+ 'BP already exists in SAP for Customer_ID: ' + deal.Customer_Number__c;
                insert  log; 
                notification.setBody('BP already exists in SAP for Customer_ID: ' + deal.Customer_Number__c);    
                try {
                    notification.send(addressee);
                    
                }
                catch (Exception ee) {
                    System.debug('Problem sending notification: ' + ee.getMessage());
                }
                // BP already exists, do not create
                System.debug(LoggingLevel.INFO, 'BP already exists in SAP for Customer_ID: ' + deal.Customer_Number__c);
                return;
            }

            // If not found (404), proceed to create
            if (getResponse.getStatusCode() != 404) {
                log.status__c='Failed';
                log.response__c= 'Status code : '+getResponse.getStatusCode() +' Response body: '+ getResponse.getBody();
                log.Error_Message__c = 'Status code : '+getResponse.getStatusCode()+ 'Error ';
                insert  log;  
            notification.setBody('Error While sending Account to SAP: '+ 'Status code : '+getResponse.getStatusCode()+ ' Error: Callout failed.');    
                // Some other error
                System.debug(LoggingLevel.ERROR, 'Error checking BP in SAP: ' + getResponse.getBody());
                    try {
                        notification.send(addressee);
                        
                    }
                catch (Exception ee) {
                    System.debug('Problem sending notification: ' + ee.getMessage());
                }
                return;
            }

            // Build BPAddresses[]
            List<Map<String, Object>> bpAddresses = new List<Map<String, Object>>();
            String uniqueSuffix = String.valueOf(DateTime.now().getTime());

            // Ship To address from Address__ fields
            Map<String, Object> shipToAddress = new Map<String, Object>{
                'AddressName'   => 'Shipping',
                'Street'        => deal.ShippingStreet,
                'City'          => deal.ShippingCity,
                'State'         => 'KL',//deal.State__c,
               'ZipCode'       => deal.ShippingPostalCode,
                'Country'       => 'IN',//deal.Country__c,
                'AddressType'   => 'bo_ShipTo',
                'AddressName2'  => deal.Address_Line2__c,
                'AddressName3'  => deal.Address_Line3__c
            };
            bpAddresses.add(shipToAddress);

            // Bill To address from Billing_Address__ fields
            Map<String, Object> billToAddress = new Map<String, Object>{
                'AddressName'   => 'Billing',
                'Street'        => deal.Billingstreet,
                'City'          => deal.BillingCity,
                'State'         =>  'KL',//deal.BillingState,
                'ZipCode'       => deal.BillingPostalcode,
                'Country'       => 'IN',//deal.billingcountry,
                'AddressType'   => 'bo_BillTo',
                'AddressName2'  => deal.Address_Line2__c,
                'AddressName3'  => deal.Address_Line3__c
            };
            bpAddresses.add(billToAddress);

            // Create Business Partner payload
            Map<String, Object> bpPayload = new Map<String, Object>{
                'CardCode'       => deal.Customer_Number__c,
                'CardName'       => deal.Name,
                'CardType'       => 'cCustomer',
                'Currency'       => 'INR',
                'EmailAddress'   => deal.Email__c,
                'Phone1'         => deal.Phone,
                'Phone2'         => deal.Secondary_Phone__c,
                'CardForeignName'=> deal.Name,
                'Notes'          => deal.Description,
                'BPAddresses'    => bpAddresses
            };

            HttpRequest bpRequest = new HttpRequest();
            bpRequest.setEndpoint('https://lemrg.hstconnect.in:50000/b1s/v1/BusinessPartners');
            bpRequest.setMethod('POST');
            bpRequest.setHeader('Content-Type', 'application/json');
            bpRequest.setHeader('Cookie', 'B1SESSION=' + sessionId);
            bpRequest.setBody(JSON.serialize(bpPayload));
log.Request__c=JSON.serialize(bpPayload);
            HttpResponse bpResponse = http.send(bpRequest);

            if (bpResponse.getStatusCode() == 201) {
                System.debug(LoggingLevel.INFO, 'Business Partner created: ' + bpResponse.getBody());
                log.status__c='SUCCESS';
                log.response__c= 'Business Partner created: ' + bpResponse.getBody();
                insert log;
                notification.setBody('New Business Partner created in SAP' );   
                try {
                    notification.send(addressee);
                    
                }
                catch (Exception ee) {
                    System.debug('Problem sending notification: ' + ee.getMessage());
                }

            } else {
                System.debug(LoggingLevel.ERROR, 'BP creation failed: ' + bpResponse.getBody());
                log.status__c='Failed';
                log.response__c= 'BP creation failed: ' + bpResponse.getBody();
                insert log;
                notification.setBody('BP creation failed:' );  
                try {
                    notification.send(addressee);
                    
                }
                catch (Exception ee) {
                    System.debug('Problem sending notification: ' + ee.getMessage());
                }
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error creating Business Partner: ' + e.getMessage());
            log.status__c='Failed';
            log.response__c= 'Error creating Business Partner: ' +  e.getMessage();
            insert log;
            notification.setBody('Error creating Business Partner n SAP: ');  
            try {
                notification.send(addressee);
                
            }
            catch (Exception ee) {
                System.debug('Problem sending notification: ' + ee.getMessage());
            }
        }
    }

    // Update Business Partner in SAP
    @future(callout=true)
    public static void updateBusinessPartner(Id dealId) {
          List<Apex_Log__c> logList = new List<Apex_Log__c>();
            Apex_Log__c log = new Apex_Log__c();
        
        try {
              Account deal = [
                SELECT Customer_Number__c, Name, Email__c, Phone, Secondary_Phone__c,Type,
                       Address_Line1__c, Address_Line2__c,Address_Line3__c,Corporation__c,Municipality__c,Panchayath__c,Village__c,State__c,Country__c,Description,District__c,GST_Number__c,
                      ShippingState,ShippingCountry, ShippingCity,ShippingStreet,ShippingAddress,BillingAddress,ShippingPostalCode,
                  BillingState,BillingCountry, BillingCity,BillingStreet,BillingPostalCode FROM Account
                WHERE Id = :dealId
                LIMIT 1
            ];
	log.Request_Type__c ='Account Update -'+deal.Customer_Number__c;
            Http http = new Http();

            // Login to SAP
            HttpRequest loginRequest = new HttpRequest();
            loginRequest.setEndpoint('https://lemrg.hstconnect.in:50000/b1s/v1/Login');
            loginRequest.setMethod('POST');
            loginRequest.setHeader('Content-Type', 'application/json');

            Map<String, Object> loginPayload = new Map<String, Object>{
                'CompanyDB' => 'MG_LIVE_WIP_1',
                'UserName'  => 'manager',
                'Password'  => 'Mgsap12@'
            };

            loginRequest.setBody(JSON.serialize(loginPayload));
            HttpResponse loginResponse = http.send(loginRequest);
            if (loginResponse.getStatusCode() != 200) {
                System.debug(LoggingLevel.ERROR, 'SAP Login Failed: ' + loginResponse.getBody());
                return;
            }

            Map<String, Object> loginData = (Map<String, Object>) JSON.deserializeUntyped(loginResponse.getBody());
            String sessionId = (String) loginData.get('SessionId');

            // Retrieve existing BP addresses
            List<Map<String, Object>> bpAddresses = new List<Map<String, Object>>();
            HttpRequest getRequest = new HttpRequest();
            getRequest.setEndpoint('https://lemrg.hstconnect.in:50000/b1s/v1/BusinessPartners(\'' + deal.Customer_Number__c + '\')');
            getRequest.setMethod('GET');
            getRequest.setHeader('Cookie', 'B1SESSION=' + sessionId);
            HttpResponse getResponse = http.send(getRequest);

            if (getResponse.getStatusCode() == 200) {
                Map<String, Object> bpData = (Map<String, Object>) JSON.deserializeUntyped(getResponse.getBody());
                if(bpData.containsKey('BPAddresses') && bpData.get('BPAddresses') != null) {
                    List<Object> existingAddressesRaw = (List<Object>) bpData.get('BPAddresses');
                    for(Object addr : existingAddressesRaw) {
                        bpAddresses.add((Map<String, Object>) addr);
                    }
                }
            } else {
                System.debug(LoggingLevel.ERROR, 'Failed to retrieve BP for update: ' + getResponse.getBody());
                

                                    return;

            }

            Boolean shipToAddressFoundAndUpdated = false;
            Boolean billToAddressFoundAndUpdated = false;

            for (Map<String, Object> existingAddr : bpAddresses) {
                String addrName = (String)existingAddr.get('AddressName');

                if (deal.ShippingAddress != null && addrName == 'Shipping') {
                    existingAddr.put('Street', deal.ShippingStreet!=null?deal.ShippingStreet:'');
                    existingAddr.put('City', deal.ShippingCity!=null?deal.ShippingCity:'');
                    existingAddr.put('State',  deal.ShippingState!=null?deal.ShippingState:'');
                    existingAddr.put('ZipCode', deal.shippingPostalCode!=null?deal.shippingPostalCode:'');
                    existingAddr.put('Country', deal.ShippingCountry!=null?deal.ShippingCountry:'');
                    existingAddr.put('AddressType', 'bo_ShipTo');
                    existingAddr.put('AddressName2',  deal.Address_Line2__c!=null?deal.Address_Line2__c:'');
                    existingAddr.put('AddressName3', deal.Address_Line3__c!=null?deal.Address_Line3__c:'');
                    shipToAddressFoundAndUpdated = true;
                }

                if (deal.BillingAddress != null && addrName == 'Billing') {
                    existingAddr.put('Street', deal.BillingStreet);
                    existingAddr.put('City', deal.BillingCity);
                    existingAddr.put('State', deal.BillingState);
                    existingAddr.put('ZipCode', deal.BillingPostalCode);
                    existingAddr.put('Country', deal.BillingCountry);
                    existingAddr.put('AddressType', 'bo_BillTo');
                    existingAddr.put('AddressName2', deal.Address_Line2__c);
                    existingAddr.put('AddressName3', deal.Address_Line3__c);
                    billToAddressFoundAndUpdated = true;
                }
            }

            if (!shipToAddressFoundAndUpdated && deal.ShippingAddress != null) {
                bpAddresses.add(new Map<String, Object>{
                    'AddressName' =>'Shipping',
                    'Street' => deal.ShippingStreet,
                    'City' => deal.ShippingCity,
                    'State' => deal.ShippingState,
                    'ZipCode' => deal.ShippingPostalCode,
                    'Country' => deal.ShippingCountry,
                    'AddressType' => 'bo_ShipTo',
                    'AddressName2' => deal.Address_Line2__c,
                    'AddressName3' => deal.Address_Line3__c
                });
            }

            if (!billToAddressFoundAndUpdated && deal.BillingAddress != null) {
                bpAddresses.add(new Map<String, Object>{
                     'AddressName' => 'Billing',
                    'Street' => deal.BillingStreet,
                    'City' => deal.BillingCity,
                    'State' => deal.BillingState,
                    'ZipCode' => deal.BillingPostalCode,
                    'Country' => deal.BillingCountry,
                    'AddressType' => 'bo_BillTo',
                    'AddressName2' => deal.Address_Line2__c,
                    'AddressName3' => deal.Address_Line3__c
                    
                });
            }

            // Update BP payload with the final list of addresses
            Map<String, Object> updatePayload = new Map<String, Object>{
                'Currency'       => 'INR',
                'EmailAddress'   => deal.Email__c,
                'Phone1'         => deal.Phone,
                'Phone2'         => deal.Secondary_Phone__c,
                'CardForeignName'=> deal.Name,
                'Notes'          => deal.Description,
                'BPAddresses'    => bpAddresses
            };

            HttpRequest patchRequest = new HttpRequest();
            patchRequest.setEndpoint('https://lemrg.hstconnect.in:50000/b1s/v1/BusinessPartners(\'' + deal.Customer_Number__c + '\')');
            patchRequest.setMethod('PATCH');
            patchRequest.setHeader('Content-Type', 'application/json');
            patchRequest.setHeader('Cookie', 'B1SESSION=' + sessionId);
            patchRequest.setBody(JSON.serialize(updatePayload));
			log.Request__c=JSON.serialize(updatePayload);
            HttpResponse patchResponse = http.send(patchRequest);

            if (patchResponse.getStatusCode() != 204) {
                 log.status__c='Failed';
                log.response__c= 'BP creation failed: ' + patchResponse.getBody();
                insert log;
                
                System.debug(LoggingLevel.ERROR, 'BP update failed: ' + patchResponse.getBody());
            }
            else{
                log.status__c='SUCCESS';
                log.response__c= 'Business Partner created: ' + patchResponse.getBody();
                insert log;
            }

        } catch (Exception e) {
             log.status__c='Failed';
            log.response__c= 'Error creating Business Partner: ' +  e.getMessage();
            insert log;
            System.debug(LoggingLevel.ERROR, 'Error updating Business Partner: ' + e.getMessage());
        }
    }
   
    
            
    public static void sendOrderToSAP(Order order) {
     
        String sessionId=loginToSAP();
     if(sessionId!=null){              
            
        Order ord = [
            SELECT id,account.Customer_Number__c,account.Customer_Type__c,Warehouse__r.Name//, BranchLocation__c,  
            FROM Order WHERE Id = :order.id LIMIT 1 ];


        // Get current date and calculate delivery dates
        Date currentDate = Date.today();
        Date endDeliveryDate = currentDate.addDays(2);
        
        // Format dates for SAP in YYYY-MM-DD format
        String docDate = currentDate.year() + '-' + 
                        String.valueOf(currentDate.month()).leftPad(2, '0') + '-' + 
                        String.valueOf(currentDate.day()).leftPad(2, '0');
        String dueDate = currentDate.addDays(30).year() + '-' + 
                        String.valueOf(currentDate.addDays(30).month()).leftPad(2, '0') + '-' + 
                        String.valueOf(currentDate.addDays(30).day()).leftPad(2, '0');
        String taxDate = docDate;
        String deliveryDate = docDate;
        String endDeliveryDateStr = endDeliveryDate.year() + '-' + 
                                  String.valueOf(endDeliveryDate.month()).leftPad(2, '0') + '-' + 
                                  String.valueOf(endDeliveryDate.day()).leftPad(2, '0');
        
        String deliveryTime = '12:00:59';
        String endDeliveryTime = '12:00:59';
        
        // Get U_TYPE from Order Type__c field
        String uType = ord.account.Customer_Type__c != null ? ord.account.Customer_Type__c : 'RETAIL';

        Map<String, Object> body = new Map<String, Object>{
            'CardCode' => ord.account.Customer_Number__c != null ? ord.account.Customer_Number__c.trim() : '',
            'DocDate' => docDate,
            'DocDueDate' => dueDate,
            'DocCurrency' => 'INR',
       //     'BPL_IDAssignedToInvoice' => bplId,
            'U_To_Delivery_date' => deliveryDate,
            'U_DELIVERY_TIME' => deliveryTime,
            'StartDeliveryDate' => deliveryDate,
            'StartDeliveryTime' => deliveryTime,
            'EndDeliveryDate' => endDeliveryDateStr,
            'EndDeliveryTime' => endDeliveryTime,
            'U_TYPE' => uType,
            'DocumentLines' => getDocumentLines(ord)
        };

        System.debug('Full SAP payload: ' + JSON.serialize(body));

        HttpRequest req = new HttpRequest();
        req.setEndpoint(SAP_BASE_URL + '/Orders');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('Cookie', 'B1SESSION=' + sessionId);
        req.setBody(JSON.serialize(body));

  /*      Http http = new Http();
        HttpResponse res = http.send(req);

        if (res.getStatusCode() != 201) {
            System.debug(' Failed to create SAP Order: ' + res.getBody());
            String errorBody = res.getBody();
            if (errorBody.contains('OITW.Locked') || errorBody.contains('warehouse is locked')) {
//                return null;
            }
            throw new AuraHandledException('Failed to create SAP Order: ' + res.getBody());
        }
        else {
            System.debug('✅ Order created in SAP for: ' + order.Id);
            System.debug('SAP Response Body: ' + res.getBody());
            
            try {
                // Parse the response to get the SAP Order ID
                Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                System.debug('Parsed Response Map: ' + responseMap);
                
                String sapOrderId;
                String sapDocNum;
                if (responseMap.containsKey('DocEntry')) {
                    Object docEntryObj = responseMap.get('DocEntry');
                    sapOrderId = String.valueOf(docEntryObj);
                }
                if (responseMap.containsKey('DocNum')) {
                    Object docNumObj = responseMap.get('DocNum');
                    sapDocNum = String.valueOf(docNumObj);
                }
                
                System.debug('Extracted SAP Order ID: ' + sapOrderId);
                Map<String, String> result = new Map<String, String>{
                    'DocEntry' => sapOrderId,
                    'DocNum' => sapDocNum
                };
//                return result;
            } catch (Exception e) {
                System.debug('❌ Error parsing SAP response: ' + e.getMessage());
                System.debug('Response that caused error: ' + res.getBody());
//                return null;
            }
        }*/
    }
}

    
      private static List<Object> getDocumentLines(Order order) {
        List<OrderItem> lines = [
            SELECT Product2.Product_Code__c, Quantity, UnitPrice,
                 Product2.Product_Category__c, TotalPrice,Sale_Price__c,Disc_Type__c,Dis_Value__c,After_Disc_Price_Sqft__c
                 //  Disc_Type__c, Dis_Value__c, After_Disc_Price_Piece__c, Product_Tax__c, UOM__c, Warehouse__c, Price_Sqft__c,    BPL_IDAssignedToInvoice__c,
            FROM OrderItem  WHERE OrderId = :order.Id
            //AND Item_Chosen__c = TRUE
        ];
    
        List<Object> docLines = new List<Object>();
    
        for (OrderItem line : lines) {
            if (line.Product2 == null || String.isBlank(line.Product2.Product_Code__c)) continue;
    
            // Calculate unit price before tax
//            Decimal taxRate = (line.Product_Tax__c != null) ? (line.Product_Tax__c / 100) : 0;
            Decimal unitPriceAfterTax = line.Sale_Price__c != null ? line.Sale_Price__c : 0;
//            Decimal unitPriceBeforeTax = taxRate > 0 ? (unitPriceAfterTax / (1 + taxRate)) : unitPriceAfterTax;
            Decimal unitPriceBeforeTax =line.UnitPrice != null ? line.UnitPrice : 0;
            // Calculate price field value based on product category and discount
            Decimal priceFieldValue = unitPriceBeforeTax;
            
           priceFieldValue= line.After_Disc_Price_Sqft__c;
    
            Map<String, Object> docLine = new Map<String, Object>{
                'ItemCode' => line.Product2.Product_Code__c,
                'Quantity' => line.Quantity,
                'WarehouseCode' => Order.Warehouse__r.Name!=null?Order.Warehouse__r.Name:'',
                'UnitPrice' => unitPriceBeforeTax.setScale(2),
                'Price' => priceFieldValue   //.setScale(2)
            };
    
            docLines.add(docLine);
        }
    
        return docLines;
    }
}