public class sapIntegration {
    public static final String SAP_BASE_URL = 'https://lemrg.hstconnect.in:50000/b1s/v1';
    private static final String COMPANY_DB = 'MG_LIVE_WIP_1';
    private static final String USERNAME = 'manager';
    private static final String PASSWORD = 'Mgsap12@';
    
    @AuraEnabled 
    public static list<account> getAccount(){
        return [select id, name,Customer_Number__c from account];	
        
    }
    public class Sap_comp{
        @auraEnabled public list<product2> items{get;set;}
        @auraEnabled public string prof{get;set;}        
    }
    @auraEnabled
    public static Sap_comp getitems(){
        Sap_comp wr=new Sap_comp();
        

        string prf= [SELECT Id, Name, Profile.Name FROM User WHERE Id = :UserInfo.getUserId()].Profile.Name;
        system.debug(prf);
        wr.items=[select id,name,Product_Code__c from product2 where isactive=true];
        wr.prof=prf;
        return wr;
    }
    @AuraEnabled(cacheable=false)
    
    public static List<CreateSOFromQuoteController.WarehouseStockWrapper> getStockFromSAP(string itemcode) {
        return CreateSOFromQuoteController.getBatchStock(itemcode, '');
    }  
    
    public static String loginToSAP() {
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
                ShippingState,ShippingCountry, ShippingCity,ShippingStreet,ShippingAddress,BillingAddress,ShippingPostalCode,Customer_Type__c,GST_Type__c,POC_Name__c,POC_Number__c,pin_code__c,
                BillingState,BillingCountry, BillingCity,BillingStreet,BillingPostalCode,ownerId FROM Account
                WHERE Id = :dealId
                LIMIT 1
            ];
            addressee.add(deal.ownerId);
            String ownerSAPCode = [SELECT Id,name,SAP_Emp_Code__c FROM User WHERE id=:deal.ownerId].SAP_Emp_Code__c; 
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
                String sapErrorMsg = '';
                try {
                    Map<String, Object> errWrapper = (Map<String, Object>) JSON.deserializeUntyped(getResponse.getBody());
                    if (errWrapper.containsKey('error')) {
                        Map<String, Object> errObj = (Map<String, Object>) errWrapper.get('error');
                        Map<String, Object> msgObj = (Map<String, Object>) errObj.get('message');
                        sapErrorMsg = (String) msgObj.get('value');
                    }
                } catch (Exception ex) {
                    sapErrorMsg = getResponse.getBody();
                }
                log.status__c='Failed';
                log.response__c= 'Status code : '+getResponse.getStatusCode() +' Response body: '+ getResponse.getBody();
                log.Error_Message__c = 'Status code : '+getResponse.getStatusCode()+ ' Error: ' + sapErrorMsg;
                insert  log;  
                notification.setBody('Error While sending Account to SAP: Status code: '+getResponse.getStatusCode()+ ' Error: ' + sapErrorMsg);    
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
            string bCountryCode=deal.BillingCountry;
            if(deal.BillingCountry != null && deal.BillingCountry.length() > 2){
                 bCountryCode= getCountryCode(deal.BillingCountry);
            }
            String bStateCode=deal.BillingState ;
           if(deal.BillingState != null && deal.BillingState.length() > 2){ 
             bStateCode = getStateCode(deal.BillingState);
           } 
           else if(deal.BillingState != null && deal.BillingState.length() == 2){ 
                if(deal.BillingState=='KA'){
                        deal.BillingState='KT';
                }
                else if(deal.BillingState=='DH'){
                        deal.BillingState='DN';
                }
           }
            // Build BPAddresses[]
            List<Map<String, Object>> bpAddresses = new List<Map<String, Object>>();
            String uniqueSuffix = String.valueOf(DateTime.now().getTime());
          string gstT='';    
          if(deal.GST_Type__c!=null){
             //   gstT= 'gstRegularTDSISD';
          gstT= deal.GST_Type__c;  
          }
            String part1 = '';
            String part2 = '';
            String part3 = '';
            
            if(deal.BillingStreet!=null){     
                List<String> parts = deal.BillingStreet.split(',');
                
                if (parts.size() >= 1) {
                    part1 = parts[0].trim();
                }
                
                if (parts.size() >= 2) {
                    part2 = parts[1].trim();
                }
                
                if (parts.size() > 2) {
                    for (Integer i = 2; i < parts.size(); i++) {
                        if (part3 != '') {
                            part3 += ', ';
                        }
                        part3 += parts[i].trim();
                    }
                }
            } 
            
            // Ship To address from Address__ fields
            Map<String, Object> shipToAddress = new Map<String, Object>{
                'AddressName'   => deal.Address_Line1__c!=null? deal.Address_Line1__c:'',
                    'Street'        => deal.Corporation__c!=null? deal.Corporation__c +', ':'' + deal.Municipality__c!=null? deal.Municipality__c+', ':'' + deal.Panchayath__c!=null? deal.Panchayath__c:'',
                    'City'          => deal.Village__c!=null? deal.Village__c:'',
                     'County'         => deal.district__c!=null? deal.district__c:'',   
                    'State'         => deal.State__c!=null? deal.State__c:'',
                    'ZipCode'       => deal.pin_code__c!=null?String.valueOf(deal.pin_code__c):'',
                    'Country'       => deal.country__c!=null? deal.country__c:'', //IN
                    'AddressType'   => 'bo_ShipTo',
                    'AddressName2'  => deal.Address_Line2__c!=null? deal.Address_Line2__c:'',
                    'AddressName3'  => deal.Address_Line3__c!=null? deal.Address_Line3__c:'',
                     'GstType'  =>  gstT,
                     'GSTIN'  =>  deal.GST_Number__c!=null? deal.GST_Number__c:'',
                          'U_Contact' =>  deal.POC_Name__c!=''? deal.POC_Name__c:''+ deal.POC_Number__c!=''?  ' - '+deal.POC_Number__c:''
                    };
                        bpAddresses.add(shipToAddress);
            
            // Bill To address from Billing_Address__ fields
            Map<String, Object> billToAddress = new Map<String, Object>{
                'AddressName'   => deal.name,
                    'Street'        => part3,
                    'City'          => deal.BillingCity!=null? deal.BillingCity:'',
                    'State'         => bStateCode!=null? bStateCode:'',//KL 
                    'ZipCode'       => deal.BillingPostalcode!=null? deal.BillingPostalcode:'',
                    'Country'       =>  bCountryCode!=null? bCountryCode:'',//IN
                    'AddressType'   => 'bo_BillTo',
                    'AddressName2'  => part1,
                    'AddressName3'  => part2,
                     'GSTIN'  =>  deal.GST_Number__c!=null? deal.GST_Number__c:'',
                           'GstType'  =>  gstT,
                         'U_Contact' =>  deal.POC_Name__c!=null? deal.POC_Name__c:''+ deal.POC_Number__c!=null?  ' - '+deal.POC_Number__c:''
                    };
                        bpAddresses.add(billToAddress);
          
          
            // Create Business Partner payload
            Map<String, Object> bpPayload = new Map<String, Object>{
                	'CardCode'       => deal.Customer_Number__c!=null? deal.Customer_Number__c:'',
                    'CardName'       => deal.Name!=null? deal.Name:'',
                    'CardType'       => 'cCustomer',
                    'Currency'       => deal.BillingCountry=='India'? 'INR':'',
                    'EmailAddress'   => deal.Email__c!=null? deal.Email__c:'',
                    'Phone1'         => deal.Phone!=null? deal.Phone:'',
                    'Phone2'         => deal.Secondary_Phone__c!=null? deal.Secondary_Phone__c:'',
                    'CardForeignName'=> deal.Name!=null? deal.Name:'',
                    'Notes'          => deal.Description!=null? deal.Description:'',
                    'BPAddresses'    => bpAddresses,
                    'SalesPersonCode'     =>  ownerSAPCode!=null? ownerSAPCode:'',
                    'U_BPType' 		 =>  deal.Customer_Type__c!=null? deal.Customer_Type__c:''
                        
                      
               //     'U_Contact' =>  deal.POC_Name__c!=null? deal.POC_Name__c:''
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
                deal.Pushed_to_SAP__c=true;
                update deal;
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
                
                Map<String, Object> errorWrapper = (Map<String, Object>) JSON.deserializeUntyped(bpResponse.getBody());
                 String errorMessage='';
                if (errorWrapper.containsKey('error')) {
                    Map<String, Object> errorObj =(Map<String, Object>) errorWrapper.get('error');
                    
                    //   Integer errorCode = (Integer) errorObj.get('code');
                    
                    Map<String, Object> messageObj =
                        (Map<String, Object>) errorObj.get('message');
                    
                     errorMessage = (String) messageObj.get('value');
                    
                }
                
                
                notification.setBody('BP creation failed:'+errorMessage );  
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
                Address_Line1__c, Address_Line2__c,Address_Line3__c,Corporation__c,Municipality__c,Panchayath__c,Village__c,State__c,Country__c,Description,District__c,GST_Number__c,POC_Number__c,
                ShippingState,ShippingCountry, ShippingCity,ShippingStreet,ShippingAddress,BillingAddress,ShippingPostalCode,GST_Type__c,POC_Name__c,Account.OwnerId, Account.Customer_Type__c,pin_code__c,
                BillingState,BillingCountry, BillingCity,BillingStreet,BillingPostalCode FROM Account
                WHERE Id = :dealId
                LIMIT 1
            ];
            log.Request_Type__c ='Account Update -'+deal.Customer_Number__c;
            Http http = new Http();
          String ownerSAPCode = [SELECT Id,name,SAP_Emp_Code__c FROM User WHERE id=:deal.ownerId].SAP_Emp_Code__c; 
   
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
                

            }
            
            Boolean shipToAddressFoundAndUpdated = false;
            Boolean billToAddressFoundAndUpdated = false;
             
            string bCountryCode=deal.BillingCountry;
            if(deal.BillingCountry != null && deal.BillingCountry.length() > 2){
                 bCountryCode= getCountryCode(deal.BillingCountry);
            }
            String stateCode=deal.BillingState;
           if(deal.BillingState != null && deal.BillingState.length() > 2){ 
             stateCode = getStateCode(deal.BillingState);
           } 
            
           
        string gstT='';
            
            
            if(deal.Customer_Type__c=='B2B' && deal.GST_Type__c!=null){
                //gstT= 'gstRegularTDSISD';
                gstT= deal.GST_Type__c; 
            }  	
            
            String part1 = '';
            String part2 = '';
            String part3 = '';
            
            if(deal.BillingStreet!=null){     
                List<String> parts = deal.BillingStreet.split(',');
                
                if (parts.size() >= 1) {
                    part1 = parts[0].trim();
                }
                
                if (parts.size() >= 2) {
                    part2 = parts[1].trim();
                }
                
                if (parts.size() > 2) {
                    for (Integer i = 2; i < parts.size(); i++) {
                        if (part3 != '') {
                            part3 += ', ';
                        }
                        part3 += parts[i].trim();
                    }
                }
            } 
            
            for (Map<String, Object> existingAddr : bpAddresses) {
                String addrName = (String)existingAddr.get('AddressType');
                String addr = (String)existingAddr.get('AddressName');
                
                if ( addrName == 'bo_ShipTo' && addr == deal.Address_Line1__c) {
                     existingAddr.put('AddressName', deal.Address_Line1__c!=null? deal.Address_Line1__c:'');                       
                    existingAddr.put('Street', deal.Corporation__c!=null? deal.Corporation__c +', ':'' + deal.Municipality__c!=null? deal.Municipality__c+', ':'' + deal.Panchayath__c!=null? deal.Panchayath__c:'');
                    existingAddr.put('City', deal.Village__c!=null? deal.Village__c:'');
                    existingAddr.put('County',  deal.district__c!=null?deal.district__c:'');
                     existingAddr.put('State',  deal.State__c!=null?deal.State__c:'');
                    existingAddr.put('ZipCode', deal.pin_code__c!=null?String.valueOf(deal.pin_code__c):'');
                    existingAddr.put('Country', deal.country__c!=null?deal.country__c:'');
                    existingAddr.put('AddressType', 'bo_ShipTo');
                    existingAddr.put('AddressName2',  deal.Address_Line2__c!=null?deal.Address_Line2__c:'');
                    existingAddr.put('AddressName3', deal.Address_Line3__c!=null?deal.Address_Line3__c:'');
                     existingAddr.put('U_Contact', deal.POC_Name__c!=null?deal.POC_Name__c:''+ deal.POC_Number__c!=''?  ' - '+deal.POC_Number__c:'');
                     existingAddr.put('GSTIN',  deal.GST_Number__c!=null?deal.GST_Number__c:'');
                    existingAddr.put('GstType', gstT);
                    shipToAddressFoundAndUpdated = true;
                }
                
               
                
                if (deal.BillingAddress != null && addrName == 'bo_BillTo') {
                    existingAddr.put('AddressName', deal.Name);     
                    existingAddr.put('Street', part3);
                    existingAddr.put('City', deal.BillingCity!=null?deal.BillingCity:'');
                    existingAddr.put('State',  stateCode!=null?stateCode:'');
                    existingAddr.put('ZipCode', deal.BillingPostalCode!=null?deal.BillingPostalCode:'');
                    existingAddr.put('Country', bCountryCode!=null?bCountryCode:'');                    
                    existingAddr.put('AddressType', 'bo_BillTo');
                    existingAddr.put('AddressName2',  part1);
                    existingAddr.put('AddressName3', part2);
                    existingAddr.put('GSTIN',  deal.GST_Number__c!=null?deal.GST_Number__c:'');
                    existingAddr.put('GstType', gstT);
                    existingAddr.put('U_Contact', deal.POC_Name__c!=null?deal.POC_Name__c:''+ deal.POC_Number__c!=null?  ' - '+deal.POC_Number__c:'');
                    billToAddressFoundAndUpdated = true;
                }
            }
            
            if (!shipToAddressFoundAndUpdated ) {
                bpAddresses.add(new Map<String, Object>{
                    'AddressName'   => deal.Address_Line1__c!=null? deal.Address_Line1__c:'',
                    'Street'        => deal.Corporation__c!=null? deal.Corporation__c +', ':'' + deal.Municipality__c!=null? deal.Municipality__c+', ':'' + deal.Panchayath__c!=null? deal.Panchayath__c:'',
                    'City'          => deal.Village__c!=null? deal.Village__c:'',
                    'County'         => deal.district__c!=null? deal.district__c:'',   
                    'State'         => deal.State__c!=null? deal.State__c:'',
                    'ZipCode'       => deal.pin_code__c!=null?String.valueOf(deal.pin_code__c):'',
                    'Country'       => deal.country__c!=null? deal.country__c:'', //IN
                    'AddressType'   => 'bo_ShipTo',
                    'AddressName2'  => deal.Address_Line2__c!=null? deal.Address_Line2__c:'',
                    'AddressName3'  => deal.Address_Line3__c!=null? deal.Address_Line3__c:'',
 					'GSTIN'  =>  deal.GST_Number__c!=null? deal.GST_Number__c:'',
                 	'GstType'  =>  gstT,
    				'U_Contact' =>  deal.POC_Name__c!=''? deal.POC_Name__c:''+ deal.POC_Number__c!=''?  ' - '+deal.POC_Number__c:''
                        
                        });
            }				
            
            
            if (!billToAddressFoundAndUpdated && deal.BillingAddress != null) {
                bpAddresses.add(new Map<String, Object>{
                    'AddressName' => deal.Name,
                    'Street'        => part3,
                    'City'          => deal.BillingCity!=null? deal.BillingCity:'',
                    'State'         => stateCode!=null? stateCode:'',//KL 
                    'ZipCode'       => deal.BillingPostalcode!=null? deal.BillingPostalcode:'',
                    'Country'       =>  bCountryCode!=null? bCountryCode:'',//IN
                    'AddressType'   => 'bo_BillTo',
                    'AddressName2'  => part1,
                    'AddressName3'  => part2,
 					'GSTIN'  =>  deal.GST_Number__c!=null? deal.GST_Number__c:'',
                  	'GstType'  =>  gstT,
                    'U_Contact' =>  deal.POC_Name__c!=null? deal.POC_Name__c:''+ deal.POC_Number__c!=null?  ' - '+deal.POC_Number__c:''
                        
                        });
            }
          
                system.debug(JSON.serialize(bpAddresses));   
            // Update BP payload with the final list of addresses
            Map<String, Object> updatePayload = new Map<String, Object>{
                'Currency'       => deal.BillingCountry=='India'? 'INR':'',
                    'EmailAddress'   => deal.Email__c!=null? deal.Email__c:'',
                    'Phone1'         => deal.Phone,
                    'Phone2'         => deal.Secondary_Phone__c!=null? deal.Secondary_Phone__c:'',
                    'CardForeignName'=> deal.Name,
                    'Notes'          => deal.Description!=null? deal.Description:'',
                    'BPAddresses'    => bpAddresses,
	                'SalesPersonCode'     =>  ownerSAPCode!=null? ownerSAPCode:'',
                    'U_BPType' 		 =>  deal.Customer_Type__c!=null? deal.Customer_Type__c:''
                //        'GstType'  =>  gstT
               //     

                    };
        system.debug(JSON.serialize(updatePayload));                
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
                log.response__c= 'BP update failed: ' + patchResponse.getBody();
                insert log;
                
                Map<String, Object> errorWrapper = (Map<String, Object>) JSON.deserializeUntyped(patchResponse.getBody());
                
                if (errorWrapper.containsKey('error')) {
                    Map<String, Object> errorObj =(Map<String, Object>) errorWrapper.get('error');
                    
                    //   Integer errorCode = (Integer) errorObj.get('code');
                    
                    Map<String, Object> messageObj =
                        (Map<String, Object>) errorObj.get('message');
                    
                    String errorMessage = (String) messageObj.get('value');
                    Integer errorCode = (Integer) errorObj.get('code');
                    
                    //  If BP does not exist in SAP, trigger creation
                    if (errorCode == -2028 &&
                        errorMessage != null &&
                        (errorMessage.contains('No matching records found') || errorMessage.contains('does not exist'))) {
                            System.enqueueJob(new CreateBusinessPartnerQueueable(deal.Id));
                            return;
                            
                        }
                }
                
                
                System.debug(LoggingLevel.ERROR, 'BP update failed: ' + patchResponse.getBody());
            }
            else{
                log.status__c='SUCCESS';
                log.response__c= 'Business Partner update: ' + patchResponse.getBody();
                insert log;
            }
            
        } catch (Exception e) {
            log.status__c='Failed';
            log.response__c= 'Error updating Business Partner: ' +  e.getMessage();
            insert log;
            System.debug(LoggingLevel.ERROR, 'Error updating Business Partner: ' + e.getMessage());
        }
    }
    
    public static String getCountryCode(String countryLabel) {
        if (String.isBlank(countryLabel) || countryLabel==null) {
            return null;
        }
        String input = countryLabel.trim().toLowerCase();
        Schema.DescribeFieldResult dfr = Account.Country__c.getDescribe();
        
        for (Schema.PicklistEntry ple : dfr.getPicklistValues()) {
            if (ple.getLabel() != null &&
            ple.getLabel().trim().toLowerCase() == input) {
                
                return ple.getValue(); // API name (Country Code)
            }
            
        }
        return null;
    }

      public static String getStateCode(String stateLabel) {
        if (String.isBlank(stateLabel) || stateLabel==null) {
            return null;
        }
        String input = stateLabel.trim().toLowerCase();
        Schema.DescribeFieldResult dfr =
            Account.State__c.getDescribe();
        
        for (Schema.PicklistEntry ple : dfr.getPicklistValues()) {
            if (ple.getLabel() != null &&
            ple.getLabel().trim().toLowerCase() == input) {
                
                return ple.getValue(); // API name (Country Code)
            }
            
        }
        return null;
    }

    
  /*  public static void sendOrderToSAP(id order) {
        Order ord = [SELECT id, name, OrderNumber, Order_Owner__c, accountId, account.name, account.Customer_Number__c, account.Customer_Type__c, Warehouse__r.Warehouse_Code__c,
            AddressLine1__c, AddressLine2__c, AddressLine3__c, District__c, State__c, Country__c //, BranchLocation__c
            FROM Order WHERE Id = :order LIMIT 1 ];

        // Fetch Account with address fields
      
    //sapIntegration.updateBusinessPartner(acc.id);
        // Now call the SAP order callout asynchronously
        sapIntegrationAsync.sendOrderToSAPAsync(ord.Id);

        
    }*/
    @future(callout=true)
    public static void sendOrderToSAP(Id order) {
        Order ord = [
            SELECT
                id,
                name,
                OrderNumber,
                Order_Owner__c,
                accountId,
                account.name,
                account.Customer_Number__c,
                account.Customer_Type__c,
                Warehouse__r.Warehouse_Code__c,
                OpportunityId,  
                ownerid,
                SAP_Doc_Num__c,
                Order_status__c,
                opportunity.AddressLine1__c,
                opportunity.AddressLine2__c,
                opportunity.AddressLine3__c,
                opportunity.District__c,
                opportunity.State__c,
                opportunity.Country__c,
                opportunity.pin_code__c,
                opportunity.Sale_Type__c,
            Freight_Charge__c,
            Loading_Charges__c,
            Unloading_Charges__c
            FROM Order
            WHERE Id = :order
            LIMIT 1
        ];
          Account acc = [SELECT Id, Address_Line1__c, Address_Line2__c, Address_Line3__c, District__c, State__c, Country__c FROM Account WHERE Id = :ord.accountId LIMIT 1];

        List<Apex_Log__c> logList = new List<Apex_Log__c>();
        Apex_Log__c log = new Apex_Log__c();
        CustomNotificationType notificationType = [SELECT Id, DeveloperName FROM CustomNotificationType WHERE DeveloperName='Sales_Order_Notification'];
        Messaging.CustomNotification notification = new Messaging.CustomNotification();
        notification.setNotificationTypeId(notificationType.Id);
        notification.setTargetId(ord.id);
        String adminUserId = [SELECT Id FROM User WHERE Profile.Name = 'System Administrator' and isactive=true LIMIT 1].Id;
        Set<String> addressee = new Set<String>();
       
        addressee.add(UserInfo.getUserId());
        System.debug('Order '+ord);
        notification.setTitle('Order :'+ord.OrderNumber);
        String NotificationBody =  'Order Id : ' + ord.OrderNumber +'\nOrder created by : ' + ord.account.name;
        if( ord.account.name != null ) {
            NotificationBody += '\nCustomer Name : ' + ord.account.name ;
        }
        String sessionId=loginToSAP();
        if(sessionId!=null){              
            log.Request_Type__c ='Order -'+ord.OrderNumber;
            SAPOrderPayload body= buildPayload(ord);
            System.debug('Full SAP payload: ' + JSON.serialize(body));
            HttpRequest req = new HttpRequest();
            req.setEndpoint(SAP_BASE_URL + '/Orders');
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setHeader('Cookie', 'B1SESSION=' + sessionId);
            req.setBody(JSON.serialize(body));
            Http http = new Http();
            HttpResponse res = http.send(req);
            log.Request__c =SAP_BASE_URL + '/Orders /n'+JSON.serialize(body); 
            if (res.getStatusCode() != 201) {
                System.debug(' Failed to create SAP Order: ' + res.getBody());
                String errorBody = res.getBody();
                log.Status__c = 'FAILED';
                log.Error_Message__c = 'Failed to create SAP Order:  Statuscode: '+res.getStatusCode()+'/n' +errorBody ;
                logList.add(log);
                String errorMsgValue = '';
                try {
                    Map<String, Object> errorMap = (Map<String, Object>) JSON.deserializeUntyped(errorBody);
                    if (errorMap.containsKey('error')) {
                        Map<String, Object> err = (Map<String, Object>)errorMap.get('error');
                        if (err.containsKey('message')) {
                            Map<String, Object> msg = (Map<String, Object>)err.get('message');
                            if (msg.containsKey('value')) {
                                errorMsgValue = String.valueOf(msg.get('value'));
                            }
                        }
                    }
                } catch (Exception e) {
                    // ignore JSON parse errors
                }
                notification.setBody( 'Failed to create SAP Order:  Statuscode: '+res.getStatusCode() + (errorMsgValue != '' ? ('\n' + errorMsgValue) : '') );
                    if(adminUserId!=null){
                        addressee.add(adminUserId); 
                        }
            } else {
                log.status__c='SUCCESS';
                System.debug(' Order created in SAP for: ' + ord.OrderNumber);
                System.debug('SAP Response Body: ' + res.getBody());
                try {
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
                    ord.SAP_Doc_Num__c= sapDocNum;
                    ord.Order_status__c= 'Sent to SAP';
                    update ord;
                    notification.setTitle('Order Created in SAP');
                    notification.setBody(NotificationBody);
                    // Add quote owner to notification recipients (again, in case not already added)
                    if (ord.OpportunityId != null) {
                        try {
                            Opportunity opp = [SELECT Id, OwnerId FROM Opportunity WHERE Id = :ord.OpportunityId LIMIT 1];
                            if (opp.OwnerId != null) {
                                addressee.add(opp.OwnerId);
                            }
                        } catch (Exception e) {
                            System.debug('Could not add quote owner to notification: ' + e.getMessage());
                        }
                    }
                    logList.add(log);
                } catch (Exception e) {
                    log.status__c='FAILED';
                    log.response__c= 'Status code : '+res.getStatusCode() +' Response body: '+ res.getBody();
                    log.Error_Message__c = 'Status code : '+res.getStatusCode()+ ' Error: Callout failed. Please review the response for additional details.';
                    logList.add(log);
                    notification.setBody('Error: '+e.getMessage());   
                     if(adminUserId!=null){
                            addressee.add(adminUserId); 
                        }
                    System.debug('❌ Error parsing SAP response: ' + e.getMessage());
                    System.debug('Response that caused error: ' + res.getBody());
                }
            }
        } else {
            notification.setBody('Error While sending Order:No access token generated ');   
             if(adminUserId!=null){
                    addressee.add(adminUserId); 
                }
            log.status__c='FAILED';
            log.Error_Message__c = 'Token not generated';
        }
        if(logList.size()>0){
            insert logList;
        }
        try {
            notification.send(addressee);
        } catch (Exception e) {
            System.debug('Problem sending notification: ' + e.getMessage());
        }
    }
    
    
    public class SAPOrderPayload {

            public String CardCode;
            public String DocDate;
            public String DocDueDate;
            public String TaxDate;
            public String DocCurrency;
            public String BPL_IDAssignedToInvoice;
            
            public String U_To_Delivery_date;
            //  public String StartDeliveryDate;
            //public String StartDeliveryTime;
            //public String EndDeliveryDate;
            
            // public String EndDeliveryTime;
            public String U_TYPE;
            public String U_Approval;
            public String U_DELIVERY_TIME;
            
            public String SalesPersonCode;
            public String DocumentsOwner;
            
            public String ShipToCode;
            public String ShipToDescription;
            
            public List<DocumentLine> DocumentLines;
         public List<DocumentAdditionalExpenses> DocumentAdditionalExpenses;
            public List<BPAddress> BPAddresses;
        }
        public class BPAddress {
            public String AddressName;
            public String AddressType;
            public String Street;
            public String Block;
            public String City;
            public String ZipCode;
            public String State;
            public String Country;
        }  
        public class DocumentLine {
            public String ItemCode;
            public Decimal Quantity;
            public String WarehouseCode;
            public Decimal UnitPrice;
            public String TaxCode;
            public Decimal Price;
            public Decimal U_ReservedQTY;
            public List<BatchNumber> BatchNumbers;
        }
        
      public class DocumentAdditionalExpenses {
            public Decimal ExpenseCode;
            public Decimal LineTotal;
            public String TaxCode;
        }
        
    
        public class BatchNumber {
            public String BatchNumber;
            public Decimal Quantity;
        }
    
    public static SAPOrderPayload buildPayload(order order) {
        SAPOrderPayload payload = new SAPOrderPayload();
        string oppowner = [select id,ownerid from opportunity where id=:order.opportunityId].ownerid;
        string oppOwnId = [select id, SAP_Emp_Code__c from user where id=:oppowner].SAP_Emp_Code__c;
        string ordOwnId = [select id, SAP_Emp_Code__c from user where id=:order.ownerid].SAP_Emp_Code__c;
        Date currentDate = Date.today();
        Date endDeliveryDate = currentDate.addDays(2);
        // Format dates for SAP in YYYY-MM-DD format
        String docDate = currentDate.year() + '-' + 
            String.valueOf(currentDate.month()).leftPad(2, '0') + '-' + 
            String.valueOf(currentDate.day()).leftPad(2, '0');
        String dueDate = currentDate.addDays(10).year() + '-' + 
            String.valueOf(currentDate.addDays(10).month()).leftPad(2, '0') + '-' + 
            String.valueOf(currentDate.addDays(10).day()).leftPad(2, '0');
        String taxDate = docDate;
        String deliveryDate = docDate;
        String endDeliveryDateStr = endDeliveryDate.year() + '-' + 
            String.valueOf(endDeliveryDate.month()).leftPad(2, '0') + '-' + 
            String.valueOf(endDeliveryDate.day()).leftPad(2, '0');
        String deliveryTime = '12:00:59';
        String endDeliveryTime = '12:00:59';
        // Get U_TYPE from Order Type__c field
        String uType;
        if(order.account.Customer_Type__c == 'B2B'){
            uType= 'PROJECT';
        } else {
            uType= 'RETAIL';
        }
        if(order.opportunity.Sale_Type__c != null){
            uType = order.opportunity.Sale_Type__c;
        }

        payload.CardCode = order.account.Customer_Number__c;
        payload.DocDate = docDate;
        payload.DocDueDate = dueDate;
        payload.DocCurrency = 'INR';
        payload.BPL_IDAssignedToInvoice = '3';
        payload.U_To_Delivery_date = deliveryDate;
        payload.U_DELIVERY_TIME = deliveryTime;
        payload.U_TYPE = uType;
        payload.U_Approval = 'Y';
        payload.SalesPersonCode = oppOwnId;
        payload.DocumentsOwner = ordOwnId;
        // Set ShipToCode from AddressLine1__c
   //     payload.ShipToCode = order.AddressLine1__c;
        // Build BPAddresses for Ship To
        BPAddress shipAddr = new BPAddress();
        shipAddr.AddressName = order.opportunity.AddressLine1__c;
        shipAddr.AddressType = 'bo_ShipTo';
        shipAddr.Street = order.opportunity.AddressLine2__c;
        shipAddr.Block = order.opportunity.AddressLine3__c;
        shipAddr.City = order.opportunity.District__c;
        shipAddr.State = order.opportunity.State__c;
        shipAddr.Country = order.opportunity.Country__c;
        payload.BPAddresses = new List<BPAddress>{ shipAddr };
             payload.DocumentAdditionalExpenses = new List<DocumentAdditionalExpenses>();
        
        
			string TaxCode;
        	if(order.opportunity.State__c=='KL'){
                TaxCode = 'CG SG 18';
            }
            else{
                TaxCode = 'IGST 18';
            }
      DocumentAdditionalExpenses dc= new DocumentAdditionalExpenses();      
        	dc.ExpenseCode = 1;
            dc.LineTotal = order.Freight_Charge__c;
            dc.TaxCode = TaxCode;
          payload.DocumentAdditionalExpenses.add(dc);   
        
   DocumentAdditionalExpenses dc1= new DocumentAdditionalExpenses();             
            dc.ExpenseCode = 2;
            dc.LineTotal = order.Loading_Charges__c;
            dc.TaxCode = TaxCode;
        payload.DocumentAdditionalExpenses.add(dc1);
        
  DocumentAdditionalExpenses dc2= new DocumentAdditionalExpenses();              
            dc.ExpenseCode = 3;
            dc.LineTotal = order.Unloading_Charges__c;
            dc.TaxCode = TaxCode;
			payload.DocumentAdditionalExpenses.add(dc2);
        
        payload.DocumentLines = new List<DocumentLine>();
        List<OrderItem> orderItems = [ SELECT Id,Quantity,Block_Quantity__c,PricebookEntry.Product2.Product_Code__c,Warehouse__r.Warehouse_Code__c,After_Disc_Price_Sqft__c,ListPrice,UnitPrice FROM OrderItem WHERE OrderId = :order.Id ]; //,Tax_Code__c
        Map<Id, List<Order_Batch_Item__c>> batchByItem = new Map<Id, List<Order_Batch_Item__c>>();
        for (Order_Batch_Item__c b : [SELECT Order_Product__c, Batch__c,Quantity__c,Block_Quantity__c, Warehouse_Code__c FROM Order_Batch_Item__c  WHERE Order_Product__c IN :orderItems ]) {
            if (!batchByItem.containsKey(b.Order_Product__c)) {
                batchByItem.put(b.Order_Product__c, new List<Order_Batch_Item__c>());
            }
            batchByItem.get(b.Order_Product__c).add(b);
        }
        //️⃣ Build DocumentLines (GROUP BY WAREHOUSE)
        for (OrderItem oi : orderItems) {

            if (!batchByItem.containsKey(oi.Id)) {
                
                Decimal unitPriceAfterTax = oi.UnitPrice != null ? oi.UnitPrice : 0;
                Decimal unitPriceBeforeTax =oi.ListPrice != null ? oi.ListPrice : 0;
                Decimal priceFieldValue = unitPriceBeforeTax;
                priceFieldValue= oi.After_Disc_Price_Sqft__c;
                
                DocumentLine dl = new DocumentLine();
                dl.ItemCode = oi.PricebookEntry.Product2.Product_Code__c;
                dl.WarehouseCode = oi.Warehouse__r.Warehouse_Code__c;
                dl.UnitPrice = unitPriceBeforeTax.setScale(2);
                //   dl.Quantity = oi.Quantity;
                dl.Price = priceFieldValue;
                //     dl.TaxCode = oi.Tax_Code__c;
                dl.BatchNumbers = new List<BatchNumber>();
                dl.U_ReservedQTY = oi.Block_Quantity__c;
                dl.Quantity = oi.Quantity;
                

                
                
                payload.documentLines.add(dl);
                continue;
                
            }

            // warehouse → batches
            Map<String, List<Order_Batch_Item__c>> warehouseMap = new Map<String, List<Order_Batch_Item__c>>();

            for (Order_Batch_Item__c b : batchByItem.get(oi.Id)) {
                if (!warehouseMap.containsKey(b.Warehouse_Code__c)) {
                    warehouseMap.put(b.Warehouse_Code__c, new List<Order_Batch_Item__c>());
                }
                warehouseMap.get(b.Warehouse_Code__c).add(b);
            }

            // Create one DocumentLine per warehouse
            for (String wh : warehouseMap.keySet()) {
                
                Decimal unitPriceAfterTax = oi.UnitPrice != null ? oi.UnitPrice : 0;
                Decimal unitPriceBeforeTax =oi.ListPrice != null ? oi.ListPrice : 0;
                Decimal priceFieldValue = unitPriceBeforeTax;
                priceFieldValue= oi.After_Disc_Price_Sqft__c;
                
                DocumentLine dl = new DocumentLine();
                dl.ItemCode = oi.PricebookEntry.Product2.Product_Code__c;
                dl.WarehouseCode = wh;
                dl.UnitPrice = unitPriceBeforeTax.setScale(2);
             //   dl.Quantity = oi.Quantity;
                dl.Price = priceFieldValue;
                //     dl.TaxCode = oi.Tax_Code__c;
                dl.BatchNumbers = new List<BatchNumber>();
                
                
          //      docLines.add(docLine);
                             
                Decimal totalQty = 0;
                Decimal bloQty = 0;

                for (Order_Batch_Item__c b : warehouseMap.get(wh)) {
                    BatchNumber bn = new BatchNumber();
                    bn.BatchNumber = b.Batch__c;
                    bn.Quantity = b.Quantity__c;

                    dl.BatchNumbers.add(bn);
                    totalQty += b.Quantity__c;
                    bloQty += b.Block_Quantity__c;
                }

                dl.U_ReservedQTY = bloQty;
                dl.Quantity = totalQty;
                payload.DocumentLines.add(dl);
            }
 
            
            
        } 
        system.debug('payload>>'+JSON.serialize(payload));
 //       }
            return payload;
    }

    
     @AuraEnabled
    public static void getInvoiceMaster(String formattedDate ) {
        
        String sessionId=loginToSAP();
        if(sessionId!=null){  
            
            List<Apex_Log__c> logList = new List<Apex_Log__c>();
            Apex_Log__c log = new Apex_Log__c();
            log.Request_Type__c ='Invoice';
            
            if(formattedDate == null || formattedDate == ''){
                Date today = Date.today();
                formattedDate = String.valueOf(today);
            }
            
            
            String fullUrl = SAP_BASE_URL + '/Invoices?$filter=(' + 
                EncodingUtil.urlEncode('UpdateDate eq ' + '\'' + formattedDate + '\' or CreationDate  eq \'' + formattedDate + '\'', 'UTF-8')+')';
            
            Boolean isError = false;
            String errorMsg = '';
            
            string method = 'GET';
            String outcomeMsg;
            if (Limits.getCallouts() >= Limits.getLimitCallouts()) {
                outcomeMsg = 'Maximum number of callouts has been reached.';
                log.Status__c = 'FAILED';
                log.Error_Message__c = 'Maximum number of callouts has been reached.';
            }
            else {
                
                HttpRequest itemReq = new HttpRequest();
                itemReq.setEndpoint(fullUrl);
                itemReq.setMethod('GET');
                itemReq.setHeader('Content-Type', 'application/json');
                itemReq.setHeader('Accept', 'application/json');
                itemReq.setHeader('Cookie', 'B1SESSION=' + sessionId);
                itemReq.setTimeout(120000);
                system.debug(itemReq);
                Http http = new Http();
                HttpResponse itemRes = http.send(itemReq);
                
                
                log.response__c= string.valueof(itemRes.getStatusCode());
                log.Request__c =fullUrl;     
                
                
                system.debug(itemRes);
                
                
                if ((itemRes.getStatusCode() == 200 || itemRes.getStatusCode() == 201) && itemRes.getBody() != null ) {
                    log.status__c='SUCCESS';
                    
                    if(itemRes.getBody().length()<100000){
                        //    log.response__c= res.getStatusCode();
                    } 
                    list<invoice__c> invList= new list<invoice__c>();
                    
                    List<Invoice_Item__c> invItemList = new List<Invoice_Item__c>();
					Set<String> docEntrySet = new Set<String>();
                    
                    Map<String, Object> json = (Map<String, Object>) JSON.deserializeUntyped(itemRes.getBody());
                    List<Object> items = (List<Object>) json.get('value');

                    // Collect all lookup codes first
                    Set<String> accountCodes = new Set<String>();
                    Set<String> salesPersonCodes = new Set<String>();
                    Set<String> saleOrderNumbers = new Set<String>();
                    
                    for (Object o : items) {
                        Map<String, Object> it = (Map<String, Object>) o;
                        String cc = String.valueOf(it.get('CardCode'));
                        String sp = String.valueOf(it.get('SalesPersonCode'));
                        String so = String.valueOf(it.get('U_Saleorder'));
                        if (cc != null && cc != '') accountCodes.add(cc);
                        if (sp != null && sp != '') salesPersonCodes.add(sp);
                        if (so != null && so != '') saleOrderNumbers.add(so);
                    }

                    // Build lookup maps
                    Map<String, Id> accountMap = new Map<String, Id>();
                    for (Account a : [SELECT Id, Customer_Number__c FROM Account WHERE Customer_Number__c IN :accountCodes]) {
                        accountMap.put(a.Customer_Number__c, a.Id);
                    }
                    Map<String, Id> userMap = new Map<String, Id>();
                    for (User u : [SELECT Id, SAP_Emp_Code__c FROM User WHERE SAP_Emp_Code__c IN :salesPersonCodes]) {
                        userMap.put(u.SAP_Emp_Code__c, u.Id);
                    }
                    Map<String, Id> orderMap = new Map<String, Id>();
                    for (Order ord : [SELECT Id, SAP_Doc_Num__c FROM Order WHERE SAP_Doc_Num__c IN :saleOrderNumbers]) {
                        orderMap.put(ord.SAP_Doc_Num__c, ord.Id);
                    }

                    for (Object obj : items) {
                        Map<String, Object> item = (Map<String, Object>) obj;
                        Invoice__c inv = new Invoice__c();
                        
                        inv.Doc_Entry__c = String.valueOf(item.get('DocEntry'));
                         docEntrySet.add(inv.Doc_Entry__c);
                        inv.Doc_Num__c = String.valueOf(item.get('DocNum'));
                        if(item.get('DocDate') != null){    
                            inv.Invoice_Date__c = 
                                Date.valueOf(String.valueOf(item.get('DocDate')));
                        }

                        inv.Invoice_Amount__c = Decimal.valueOf(String.valueOf(item.get('DocTotal')));
                        inv.Comments__c= String.valueOf(item.get('Comments'));
                        inv.Account_Code__c= String.valueOf(item.get('CardCode'));
                        inv.SalesPersonCode__c= String.valueOf(item.get('SalesPersonCode'));
                        inv.Cancel_Status__c= String.valueOf(item.get('Cancelled'));
                        inv.Total_Discount__c =     Decimal.valueOf(String.valueOf(item.get('TotalDiscount')));
						inv.SaleOrder_Number__c = String.valueOf(item.get('U_Saleorder'));
                        inv.Payment_Mode__c = String.valueOf(item.get('U_Payment_method'));
                        inv.Branch_Name__c = String.valueOf(item.get('BPLName'));
                        if (inv.Account_Code__c != null && inv.Account_Code__c != '' && accountMap.containsKey(inv.Account_Code__c)) {
                            inv.Account__c = accountMap.get(inv.Account_Code__c);
                        }
                        if (inv.SalesPersonCode__c != null && inv.SalesPersonCode__c != '' && userMap.containsKey(inv.SalesPersonCode__c)) {
                            inv.OwnerId = userMap.get(inv.SalesPersonCode__c);
                        }
                        if (inv.SaleOrder_Number__c != null && inv.SaleOrder_Number__c != '' && orderMap.containsKey(inv.SaleOrder_Number__c)) {
                            inv.Sales_Order__c = orderMap.get(inv.SaleOrder_Number__c);
                        }

                        inv.Vehicle_No__c = String.valueOf(item.get('VehicleNo'));
                        inv.VehicleType__c = String.valueOf(item.get('VehicleType'));
                        inv.TransportationMode__c = String.valueOf(item.get('TransportationMode'));
                        inv.Driver__c = String.valueOf(item.get('U_DRIVER'));
                         inv.Total_KM__c = Decimal.valueOf(String.valueOf(item.get('U_TOTALKM')));
                        inv.Card_Name__c = String.valueOf(item.get('CardName'));
                         inv.Address__c = String.valueOf(item.get('Address'));
                invList.add(inv);    
                    List<Object> documentLines =
                        (List<Object>) item.get('DocumentLines');
                    
                    if (documentLines != null) {  
                            for (Object lineObj : documentLines) {
                                Map<String, Object> line = (Map<String, Object>) lineObj;
                                Invoice_Item__c invItem = new Invoice_Item__c(); 
                                Integer lineNum = (Integer) line.get('LineNum');
                                invItem.Line_No__c = inv.Doc_Entry__c +' '+lineNum;
                                invItem.Item_Code__c = String.valueOf(line.get('ItemCode'));
                                invItem.Line_Total__c = (decimal) line.get('LineTotal');
                                invItem.Price__c = (decimal) line.get('Price');
                                invItem.Price_After_VAT__c= (decimal) line.get('PriceAfterVAT');
                                invItem.Sqm__c = (decimal) line.get('U_SQMT');
                                invItem.Sqft__c = (decimal) line.get('U_SQFT');
                            //    invItem.Product__c= String.valueOf(line.get('CancelStatus'));
                                invItem.Quantity__c= (decimal) line.get('Quantity');
                                if(item.get('ShipDate') != null){
                                    invItem.Ship_Date__c = Date.valueOf(String.valueOf(item.get('ShipDate')));
                                }
                               if( invItem.Item_Code__c!= null &&  invItem.Item_Code__c != '')  invItem.Product__r = new Product2(Product_Code__c = invItem.Item_Code__c);
                                invItem.ItemDescription__c = String.valueOf(line.get('ItemDescription'));
                                invItem.Tax_Amount__c= (decimal) line.get('TaxTotal');
                                invItem.Unit_Price__c= (decimal) line.get('UnitPrice');
                                invItem.Warehouse_Code__c= String.valueOf(line.get('WarehouseCode'));
                                invItem.Invoice_No__c = String.valueOf(line.get('DocEntry'));
                                invItemList.add(invItem);
                            }
                        }
                    }
                    
                    Database.upsert(invList, Invoice__c.Doc_Entry__c, false);
                    
                   // Query to get Ids for relationship
                    Map<String, Id> invoiceMap = new Map<String, Id>();
                    for (Invoice__c i : [ SELECT Id, Doc_Entry__c  FROM Invoice__c WHERE Doc_Entry__c IN :docEntrySet ]) {
                        invoiceMap.put(i.Doc_Entry__c, i.Id);
                    }
                    
                    for (Invoice_Item__c itemRec : invItemList) {
                        
                        String parentKey =  itemRec.Invoice_No__c;
                        
                        if(invoiceMap.containsKey(parentKey)){
                            itemRec.Invoice__c = invoiceMap.get(parentKey);
                        }
                    }
                    Database.upsert(invItemList, Invoice_Item__c.Line_No__c, false);
                } 
            }
            
            
        }  
        
    }
    
    
    @AuraEnabled(cacheable=false)  
    public static decimal getCustOutstanding(string accountId) {
        
        string bpCode=[select id,Customer_Number__c from account where id=:accountId].Customer_Number__c;
        //    bpCode='CU0000270';
        decimal CurrentAccountBalance;
        String sessionId=loginToSAP();
        if(sessionId!=null){  
            
            List<Apex_Log__c> logList = new List<Apex_Log__c>();
            Apex_Log__c log = new Apex_Log__c();
            log.Request_Type__c ='Outstanding';
            
            Date today = Date.today();
            String formattedDate = String.valueOf(today);
            
            
            String fullUrl = SAP_BASE_URL + '/BusinessPartners('+'\''+bpCode+ '\')';
            
            Boolean isError = false;
            String errorMsg = '';
            
            string method = 'GET';
            String outcomeMsg;
            if (Limits.getCallouts() >= Limits.getLimitCallouts()) {
                outcomeMsg = 'Maximum number of callouts has been reached.';
                log.Status__c = 'FAILED';
                log.Error_Message__c = 'Maximum number of callouts has been reached.';
            }
            else {
                
                HttpRequest itemReq = new HttpRequest();
                itemReq.setEndpoint(fullUrl);
                itemReq.setMethod('GET');
                itemReq.setHeader('Content-Type', 'application/json');
                itemReq.setHeader('Accept', 'application/json');
                itemReq.setHeader('Cookie', 'B1SESSION=' + sessionId);
                itemReq.setTimeout(120000);
                system.debug(itemReq);
                Http http = new Http();
                HttpResponse itemRes = http.send(itemReq);
                
                
                log.response__c= string.valueof(itemRes.getStatusCode());
                log.Request__c =fullUrl;     
                
                
                system.debug(itemRes);
                
                
                if ((itemRes.getStatusCode() == 200 || itemRes.getStatusCode() == 201) && itemRes.getBody() != null ) {
                    String responseBody = itemRes.getBody();
                    
                    //CurrentAccountBalance
                    Map<String, Object> result =
                        (Map<String, Object>) JSON.deserializeUntyped(responseBody);
                    CurrentAccountBalance = (decimal) result.get('CurrentAccountBalance');
                    
                    
                }
                else{
                    System.debug(' Failed to fetch outstanding: ' + itemRes.getBody());
                    String errorBody = itemRes.getBody();
                    log.Status__c = 'FAILED';
                    log.Error_Message__c = 'Maximum number of callouts has been reached.';
                    if(log.Status__c=='FAILED'){
                        insert log;
                    }
                }
                
            }
        }
        
        system.debug(CurrentAccountBalance);
        return CurrentAccountBalance;  
    }


   @AuraEnabled  
    public static void getPayments() {
        String sessionId = loginToSAP();
        if (sessionId != null) {
            
            List<Apex_Log__c> logList = new List<Apex_Log__c>();
            Apex_Log__c log = new Apex_Log__c();
            log.Request_Type__c = 'Payment';
            
            Date today = Date.today();
            String formattedDate = String.valueOf(today);
            
            String fullUrl = SAP_BASE_URL + '/IncomingPayments?$filter=(' +
                EncodingUtil.urlEncode('DocDate eq \'' + formattedDate + '\' or TaxDate eq \'' + formattedDate + '\'', 'UTF-8') + ')';
            
            String outcomeMsg;
            if (Limits.getCallouts() >= Limits.getLimitCallouts()) {
                outcomeMsg = 'Maximum number of callouts has been reached.';
                log.Status__c = 'FAILED';
                log.Error_Message__c = outcomeMsg;
            } else {
                
                HttpRequest itemReq = new HttpRequest();
                itemReq.setEndpoint(fullUrl);
                itemReq.setMethod('GET');
                itemReq.setHeader('Content-Type', 'application/json');
                itemReq.setHeader('Accept', 'application/json');
                itemReq.setHeader('Cookie', 'B1SESSION=' + sessionId);
                itemReq.setTimeout(120000);
           system.debug(' fullUrl>>'+fullUrl);          
                Http http = new Http();
                HttpResponse itemRes = http.send(itemReq);
           system.debug(' itemRes>>'+itemRes);
                log.response__c = String.valueOf(itemRes.getStatusCode());
                log.Request__c = fullUrl;
                
                if ((itemRes.getStatusCode() == 200 || itemRes.getStatusCode() == 201) && itemRes.getBody() != null) {
                    log.status__c = 'SUCCESS';
                    
                    List<Payment__c> paymentList = new List<Payment__c>();
                    
                    Map<String, Object> json = (Map<String, Object>) JSON.deserializeUntyped(itemRes.getBody());
                    List<Object> items = (List<Object>) json.get('value');
                     
                    // Collect CardCodes to build Account lookup map
                    Set<String> cardCodes = new Set<String>();
                    Set<String> invCodes = new Set<String>();
                    for (Object o : items) {
                        Map<String, Object> it = (Map<String, Object>) o;
                        String cc = String.valueOf(it.get('CardCode'));
                        if (cc != null && cc != '') cardCodes.add(cc);
                          String inv = String.valueOf(it.get('DocEntry'));
                        if (inv != null && inv != '') invCodes.add(inv);
                    }
                    Map<String, Id> accountMap = new Map<String, Id>();
                    for (Account a : [SELECT Id, Customer_Number__c FROM Account WHERE Customer_Number__c IN :cardCodes]) {
                        accountMap.put(a.Customer_Number__c, a.Id);
                    }
                     Map<String, Id> invMap = new Map<String, Id>();
                    for (Invoice__c a : [SELECT Id, Doc_Entry__c FROM Invoice__c WHERE Doc_Entry__c IN :invCodes]) {
                        invMap.put(a.Doc_Entry__c, a.Id);
                    }
                    
                   system.debug(' items>>'+items);   
                    for (Object obj : items) {
                        Map<String, Object> item = (Map<String, Object>) obj;
                        Payment__c pmt = new Payment__c();
                        
                        pmt.Doc_Entry__c = String.valueOf(item.get('DocNum'));
                        pmt.Doc_Num__c = String.valueOf(item.get('DocNum'));
                        pmt.Name = String.valueOf(item.get('DocNum'));
                        if (item.get('DocDate') != null) {
                            pmt.Payment_Date__c = Date.valueOf(String.valueOf(item.get('DocDate')));
                        }
                        if (item.get('TransferSum') != null) {
                            pmt.TransferSum__c = Decimal.valueOf(String.valueOf(item.get('TransferSum')));
                        }
                        if (item.get('CashSum') != null) {
                            pmt.CashSum__c = Decimal.valueOf(String.valueOf(item.get('CashSum')));
                        }
                        pmt.Invoice_Entry__c= String.valueOf(item.get('DocEntry'));
                         String invCode = String.valueOf(item.get('DocEntry'));
                        if (invCode != null && invCode != '' && invMap.containsKey(invCode)) {
                            pmt.Invoice__c = invMap.get(invCode);
                        }

                        pmt.Branch_Name__c = String.valueOf(item.get('BPLName'));
                         pmt.JournalRemarks__c = String.valueOf(item.get('JournalRemarks'));
                        pmt.Payment_Type__c = String.valueOf(item.get('PaymentType'));
                        pmt.Card_Name__c = String.valueOf(item.get('CardName'));

                        String cardCode = String.valueOf(item.get('CardCode'));
                        if (cardCode != null && cardCode != '' && accountMap.containsKey(cardCode)) {
                            pmt.Account__c = accountMap.get(cardCode);
                        }
                        
                        paymentList.add(pmt);
                    }
                   system.debug(' paymentList>>'+paymentList);   
                    if (!paymentList.isEmpty()) {
                     // insert paymentList;
                    Database.upsert(paymentList, Payment__c.Doc_Entry__c, false);
                    }
                    
                    insert log;
                } else {
                    log.Status__c = 'FAILED';
                    log.Error_Message__c = 'Failed to fetch payments. Status: ' + itemRes.getStatusCode();
                    insert log;
                }
            }
        }
    }

    @AuraEnabled
    public static String addShipToAddressToSAP(Id opportunityId) {
        Opportunity opp = [
            SELECT Id, AccountId, Account.Customer_Number__c,
                   AddressLine1__c, AddressLine2__c, AddressLine3__c,
                   Corporation__c, Municipality__c, Panchayath__c,
                   Village__c, District__c, State__c, Country__c, Pin_Code__c,
                   GST_Number__c, Account.Customer_Type__c, Account.GST_Type__c
            FROM Opportunity
            WHERE Id = :opportunityId
            LIMIT 1
        ];

        if (opp.Account.Customer_Number__c == null) {
            throw new AuraHandledException('Account does not have a Customer Number.');
        }

        String sessionId = loginToSAP();
        if (sessionId == null) {
            throw new AuraHandledException('Failed to login to SAP.');
        }

        Http http = new Http();

        // Build the address
        String street = '';
        if (opp.Corporation__c != null) street += opp.Corporation__c;
        if (opp.Municipality__c != null) street += (street != '' ? ', ' : '') + opp.Municipality__c;
        if (opp.Panchayath__c != null) street += (street != '' ? ', ' : '') + opp.Panchayath__c;

        String stateCode = opp.State__c;
        if (opp.State__c != null && opp.State__c.length() > 2) {
            stateCode = getStateCode(opp.State__c);
        }
        String countryCode = opp.Country__c;
        if (opp.Country__c != null && opp.Country__c.length() > 2) {
            countryCode = getCountryCode(opp.Country__c);
        }

        Map<String, Object> shipToAddress = new Map<String, Object>{
            'AddressName'  => opp.AddressLine1__c != null ? opp.AddressLine1__c : '',
            'AddressType'  => 'bo_ShipTo',
            'Street'       => street,
            'City'         => opp.Village__c != null ? opp.Village__c : '',
            'County'       => opp.District__c != null ? opp.District__c : '',
            'ZipCode'      => opp.Pin_Code__c != null ? String.valueOf(opp.Pin_Code__c) : '',
            'State'        => stateCode != null ? stateCode : '',
            'Country'      => countryCode != null ? countryCode : '',
            'AddressName2' => opp.AddressLine2__c != null ? opp.AddressLine2__c : '',
            'AddressName3' => opp.AddressLine3__c != null ? opp.AddressLine3__c : '',
            'GSTIN'        => opp.GST_Number__c != null ? opp.GST_Number__c : ''
        };

        String gstT = '';
        if (opp.Account.Customer_Type__c == 'B2B' && opp.Account.GST_Type__c != null) {
            gstT = opp.Account.GST_Type__c;
        }
        if (String.isNotBlank(gstT)) {
            shipToAddress.put('GstType', gstT);
        }

        // Get existing addresses first
        HttpRequest getReq = new HttpRequest();
        getReq.setEndpoint(SAP_BASE_URL + '/BusinessPartners(\'' + opp.Account.Customer_Number__c + '\')');
        getReq.setMethod('GET');
        getReq.setHeader('Cookie', 'B1SESSION=' + sessionId);
        HttpResponse getRes = http.send(getReq);

        List<Map<String, Object>> bpAddresses = new List<Map<String, Object>>();
        if (getRes.getStatusCode() == 200) {
            Map<String, Object> bpData = (Map<String, Object>) JSON.deserializeUntyped(getRes.getBody());
            if (bpData.containsKey('BPAddresses') && bpData.get('BPAddresses') != null) {
                for (Object addr : (List<Object>) bpData.get('BPAddresses')) {
                    bpAddresses.add((Map<String, Object>) addr);
                }
            }
        } else {
            throw new AuraHandledException('Business Partner not found in SAP: ' + opp.Account.Customer_Number__c);
        }

        // Add the new address
        bpAddresses.add(shipToAddress);

        Map<String, Object> updatePayload = new Map<String, Object>{
            'BPAddresses' => bpAddresses
        };

        HttpRequest patchReq = new HttpRequest();
        patchReq.setEndpoint(SAP_BASE_URL + '/BusinessPartners(\'' + opp.Account.Customer_Number__c + '\')');
        patchReq.setMethod('PATCH');
        patchReq.setHeader('Content-Type', 'application/json');
        patchReq.setHeader('Cookie', 'B1SESSION=' + sessionId);
        patchReq.setBody(JSON.serialize(updatePayload));

        HttpResponse patchRes = http.send(patchReq);

        if (patchRes.getStatusCode() == 204) {
            return 'Address added successfully to SAP.';
        } else {
            String errorMsg = patchRes.getBody();
            Integer errorCode = 0;
            try {
                Map<String, Object> errWrapper = (Map<String, Object>) JSON.deserializeUntyped(patchRes.getBody());
                if (errWrapper.containsKey('error')) {
                    Map<String, Object> errObj = (Map<String, Object>) errWrapper.get('error');
                    Map<String, Object> msgObj = (Map<String, Object>) errObj.get('message');
                    errorMsg = (String) msgObj.get('value');
                    errorCode = (Integer) errObj.get('code');
                }
            } catch (Exception ex) {
                // keep raw body as errorMsg
            }
            if (errorCode == -2035) {
                throw new AuraHandledException('This address already exists in SAP.');
            }
            throw new AuraHandledException('Failed to add address: ' + errorMsg);
        }
    }
}