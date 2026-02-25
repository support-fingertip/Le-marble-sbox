public class sapIntegrationAsync {
    @future(callout=true)
    public static void sendOrderToSAPAsync(Id orderId) {
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
                AddressLine1__c,
                AddressLine2__c,
                AddressLine3__c,
                District__c,
                State__c,
                Country__c
            FROM Order
            WHERE Id = :orderId
            LIMIT 1
        ];
        List<Apex_Log__c> logList = new List<Apex_Log__c>();
        Apex_Log__c log = new Apex_Log__c();
        CustomNotificationType notificationType = [SELECT Id, DeveloperName FROM CustomNotificationType WHERE DeveloperName='Sales_Order_Notification'];
        Messaging.CustomNotification notification = new Messaging.CustomNotification();
        notification.setNotificationTypeId(notificationType.Id);
        notification.setTargetId(ord.id);
        String adminUserId = [SELECT Id FROM User WHERE Profile.Name = 'System Administrator' and isactive=true LIMIT 1].Id;
        Set<String> addressee = new Set<String>();
        if(adminUserId!=null){
            addressee.add(adminUserId); 
        }
        addressee.add(UserInfo.getUserId());
        System.debug('Order '+ord);
        notification.setTitle('Order :'+ord.OrderNumber);
        String NotificationBody =  'Order Id : ' + ord.Name +'\nOrder created by : ' + ord.account.name;
        if( ord.account.name != null ) {
            NotificationBody += '\nCustomer Name : ' + ord.account.name ;
        }
        String sessionId=sapIntegration.loginToSAP();
        if(sessionId!=null){              
            log.Request_Type__c ='Order -'+ord.OrderNumber;
            sapIntegration.SAPOrderPayload body= sapIntegration.buildPayload(ord);
            System.debug('Full SAP payload: ' + JSON.serialize(body));
            HttpRequest req = new HttpRequest();
            req.setEndpoint(sapIntegration.SAP_BASE_URL + '/Orders');
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setHeader('Cookie', 'B1SESSION=' + sessionId);
            req.setBody(JSON.serialize(body));
            Http http = new Http();
            HttpResponse res = http.send(req);
            log.Request__c =sapIntegration.SAP_BASE_URL + '/Orders /n'+JSON.serialize(body); 
            if (res.getStatusCode() != 201) {
                System.debug(' Failed to create SAP Order: ' + res.getBody());
                String errorBody = res.getBody();
                log.Status__c = 'FAILED';
                log.Error_Message__c = 'Failed to create SAP Order:  Statuscode: '+res.getStatusCode()+'/n'+errorBody ;
                logList.add(log);
                if (errorBody.contains('OITW.Locked') || errorBody.contains('warehouse is locked')) {
                    //                return null;
                }
            } else {
                log.status__c='SUCCESS';
                System.debug(' Order created in SAP for: ' + ord.Id);
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
                    logList.add(log);
                } catch (Exception e) {
                    log.status__c='FAILED';
                    log.response__c= 'Status code : '+res.getStatusCode() +' Response body: '+ res.getBody();
                    log.Error_Message__c = 'Status code : '+res.getStatusCode()+ ' Error: Callout failed. Please review the response for additional details.';
                    logList.add(log);
                    notification.setBody('Error: '+e.getMessage());   
                    System.debug('❌ Error parsing SAP response: ' + e.getMessage());
                    System.debug('Response that caused error: ' + res.getBody());
                }
            }
        } else {
            notification.setBody('Error While sending Order:No access token generated ');   
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
}