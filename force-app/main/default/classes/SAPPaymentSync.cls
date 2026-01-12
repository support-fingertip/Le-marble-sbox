public class SAPPaymentSync {
    private static final String SAP_BASE_URL = 'https://lemrg.hstconnect.in:50000/b1s/v1';
    private static final String LOGIN_URL = SAP_BASE_URL + '/Login';
    private static final String COMPANY_DB = 'MG_LIVE_WIP_1';
    private static final String USERNAME = 'manager';
    private static final String PASSWORD = 'Mgsap12@';

    @future(callout=true)
    public static void fetchDownPaymentsData() {
        syncDownPayments();
    }
    @future(callout=true)
    public static void fetchIncomingPaymentsData() {
        syncIncomingPayments();
    }

    public static void syncDownPayments() {
        try {
            // 1. Get last sync time
            SAP_Sync_Setting__c setting = SAP_Sync_Setting__c.getValues('Global');
            if (setting == null) {
                System.debug('SAP_Sync_Setting__c not found. Skipping sync.');
                return;
            }
            DateTime lastSync = setting.Last_Sync__c != null ? setting.Last_Sync__c : System.now().addDays(-1);
            String formattedDate = lastSync.format('yyyy-MM-dd\'T\'HH:mm:ss');

            // 2. Build query with filter (use UpdateDate and DocDate)
            String baseUrl = SAP_BASE_URL + '/DownPayments?';
            String queryString =
                '$filter=UpdateDate ge ' + formattedDate + ' or DocDate ge ' + formattedDate +
                '&$select=DocEntry,DocNum,DocDate,DocTotal,VatSum,CardCode,PaidToDate,DocumentStatus' +
                '&$top=10';
            String endpoint = baseUrl + EncodingUtil.urlEncode(queryString, 'UTF-8');
            HttpRequest req = new HttpRequest();
            req.setEndpoint(endpoint);
            req.setMethod('GET');
            req.setHeader('Content-Type', 'application/json');
            req.setHeader('Accept', 'application/json');
            // SAP login
            HttpRequest loginReq = new HttpRequest();
            loginReq.setEndpoint(LOGIN_URL);
            loginReq.setMethod('POST');
            loginReq.setHeader('Content-Type', 'application/json');
            loginReq.setHeader('Accept', 'application/json');
            loginReq.setTimeout(120000);
            loginReq.setBody(JSON.serialize(new Map<String, String>{
                'CompanyDB' => COMPANY_DB,
                'UserName'  => USERNAME,
                'Password'  => PASSWORD
            }));
            Http http = new Http();
            HttpResponse loginRes = http.send(loginReq);
            if (loginRes.getStatusCode() != 200) {
                System.debug('❌ SAP Login Failed: ' + loginRes.getStatusCode() + ' - ' + loginRes.getBody());
                return;
            }
            Map<String, Object> loginResult = (Map<String, Object>) JSON.deserializeUntyped(loginRes.getBody());
            String sessionId = String.valueOf(loginResult.get('SessionId'));
            if (String.isBlank(sessionId)) {
                System.debug('❌ SAP Login Failed - No SessionId');
                return;
            }
            req.setHeader('Cookie', 'B1SESSION=' + sessionId);
            req.setHeader('B1SESSION', sessionId);
            req.setTimeout(120000);
            HttpResponse res = http.send(req);
            if (res.getStatusCode() == 200) {
                processDownPayments(res.getBody());
            } else {
                System.debug('SAPPaymentSync-DownPayments HTTP Error: ' + res.getStatusCode() + ' - ' + res.getBody());
            }
        } catch (Exception e) {
            System.debug('SAPPaymentSync-DownPayments Exception: ' + e.getMessage() + '\nStack Trace: ' + e.getStackTraceString());
        }
    }

    public static void syncIncomingPayments() {
        try {
            // 1. Get last sync time
            SAP_Sync_Setting__c setting = SAP_Sync_Setting__c.getValues('Global');
            if (setting == null) {
                System.debug('SAP_Sync_Setting__c not found. Skipping sync.');
                return;
            }
            DateTime lastSync = setting.Last_Sync__c != null ? setting.Last_Sync__c : System.now().addDays(-1);
            String formattedDate = lastSync.format('yyyy-MM-dd\'T\'HH:mm:ss');

            // 2. Build query with filter (use UpdateDate and DocDate)
            String baseUrl = SAP_BASE_URL + '/IncomingPayments?';
            String queryString =
                '$filter=DocDate ge ' + formattedDate +
                '&$select=DocEntry,DocNum,DocDate,CashSum,TransferSum,DueDate,CardCode' +
                '&$top=10';
            String endpoint = baseUrl + EncodingUtil.urlEncode(queryString, 'UTF-8');
            HttpRequest req = new HttpRequest();
            req.setEndpoint(endpoint);
            req.setMethod('GET');
            req.setHeader('Content-Type', 'application/json');
            req.setHeader('Accept', 'application/json');
            // SAP login
            HttpRequest loginReq = new HttpRequest();
            loginReq.setEndpoint(LOGIN_URL);
            loginReq.setMethod('POST');
            loginReq.setHeader('Content-Type', 'application/json');
            loginReq.setHeader('Accept', 'application/json');
            loginReq.setTimeout(120000);
            loginReq.setBody(JSON.serialize(new Map<String, String>{
                'CompanyDB' => COMPANY_DB,
                'UserName'  => USERNAME,
                'Password'  => PASSWORD
            }));
            Http http = new Http();
            HttpResponse loginRes = http.send(loginReq);
            if (loginRes.getStatusCode() != 200) {
                System.debug('❌ SAP Login Failed: ' + loginRes.getStatusCode() + ' - ' + loginRes.getBody());
                return;
            }
            Map<String, Object> loginResult = (Map<String, Object>) JSON.deserializeUntyped(loginRes.getBody());
            String sessionId = String.valueOf(loginResult.get('SessionId'));
            if (String.isBlank(sessionId)) {
                System.debug('❌ SAP Login Failed - No SessionId');
                return;
            }
            req.setHeader('Cookie', 'B1SESSION=' + sessionId);
            req.setHeader('B1SESSION', sessionId);
            req.setTimeout(120000);
            HttpResponse res = http.send(req);
            if (res.getStatusCode() == 200) {
                processIncomingPayments(res.getBody());
            } else {
                System.debug('SAPPaymentSync-IncomingPayments HTTP Error: ' + res.getStatusCode() + ' - ' + res.getBody());
            }
        } catch (Exception e) {
            System.debug('SAPPaymentSync-IncomingPayments Exception: ' + e.getMessage() + '\nStack Trace: ' + e.getStackTraceString());
        }
    }

    public static void processDownPayments(String responseBody) {
        try {
            Map<String, Object> jsonResponse = (Map<String, Object>) JSON.deserializeUntyped(responseBody);
                List<Object> downPayments = (List<Object>) jsonResponse.get('value');

                List<Payment__c> paymentsToUpsert = new List<Payment__c>();
                Set<String> cardCodes = new Set<String>();
                Set<String> salesOrderIds = new Set<String>();

                for (Object dpObj : downPayments) {
                    Map<String, Object> dp = (Map<String, Object>) dpObj;
                    Payment__c payment = new Payment__c();

                    payment.Doc_Entry__c = String.valueOf(dp.get('DocEntry'));
                    payment.Name = String.valueOf(dp.get('DocNum'));
                    payment.Payment_Date__c = dp.get('DocDate') != null ? Date.valueOf(String.valueOf(dp.get('DocDate'))) : null;
                    payment.Amount__c = dp.get('DocTotal') != null ? Decimal.valueOf(String.valueOf(dp.get('DocTotal'))) : 0;
                    payment.Payment_Type__c = 'Down Payment';

                    Decimal paidToDate = dp.get('PaidToDate') != null ? Decimal.valueOf(String.valueOf(dp.get('PaidToDate'))) : 0;
                    Decimal docTotal = payment.Amount__c;
                    payment.Payment_Status__c = paidToDate >= docTotal ? 'Received' : (paidToDate > 0 ? 'Partially Received' : 'Not Received');

                    if (dp.get('CardCode') != null) {
                        cardCodes.add(String.valueOf(dp.get('CardCode')));
                    }

                    List<Object> lines = (List<Object>) dp.get('DocumentLines');
                    if (lines != null && !lines.isEmpty()) {
                        Map<String, Object> line = (Map<String, Object>) lines[0];
                        if (line.get('BaseType') == 17 && line.get('BaseEntry') != null) {
                            salesOrderIds.add(String.valueOf(line.get('BaseEntry')));
                        }
                    }

                    paymentsToUpsert.add(payment);
                }

            Map<String, Id> cardCodeToDealId = new Map<String, Id>();
            if (!cardCodes.isEmpty()) {
                for (Deals__c deal : [SELECT Id, Customer__r.Customer_ID__c FROM Deals__c WHERE Customer__r.Customer_ID__c IN :cardCodes LIMIT 10000]) {
                    cardCodeToDealId.put(deal.Customer__r.Customer_ID__c, deal.Id);
                }
            }

                Map<String, Id> salesOrderIdToConfId = new Map<String, Id>();
            if (!salesOrderIds.isEmpty()) {
                for (Sales_Confirmation__c sc : [SELECT Id, Sales_Order_Id__c FROM Sales_Confirmation__c WHERE Sales_Order_Id__c IN :salesOrderIds LIMIT 10000]) {
                    salesOrderIdToConfId.put(sc.Sales_Order_Id__c, sc.Id);
                }
                }

                for (Payment__c pay : paymentsToUpsert) {
                    Map<String, Object> dpData = (Map<String, Object>) downPayments[paymentsToUpsert.indexOf(pay)];
                String cardCode = String.valueOf(dpData.get('CardCode'));
                Id oppId = cardCodeToDealId.containsKey(cardCode) ? cardCodeToDealId.get(cardCode) : null;
                pay.Opportunity__c = oppId;
                System.debug('Payment DocNum: ' + dpData.get('DocNum') + ', CardCode: ' + cardCode + ', Linked Opportunity: ' + oppId);

                    List<Object> lines = (List<Object>) dpData.get('DocumentLines');
                    if (lines != null && !lines.isEmpty()) {
                        Map<String, Object> line = (Map<String, Object>) lines[0];
                        if (line.get('BaseType') == 17 && line.get('BaseEntry') != null) {
                            pay.Sales_Confirmation__c = salesOrderIdToConfId.get(String.valueOf(line.get('BaseEntry')));
                        }
                    }
                }

                if (!paymentsToUpsert.isEmpty()) {
                    upsert paymentsToUpsert Doc_Entry__c;
                    System.debug('Upserted ' + paymentsToUpsert.size() + ' down payments.');
            }
        } catch (Exception e) {
            System.debug('SAPPaymentSync-ProcessDownPayments Exception: ' + e.getMessage() + '\nStack Trace: ' + e.getStackTraceString());
        }
    }

    public static void processIncomingPayments(String responseBody) {
        try {
            Map<String, Object> jsonResponse = (Map<String, Object>) JSON.deserializeUntyped(responseBody);
                List<Object> payments = (List<Object>) jsonResponse.get('value');

                List<Payment__c> paymentsToUpsert = new List<Payment__c>();
                Set<String> cardCodes = new Set<String>();
            Set<String> invoiceDocEntries = new Set<String>();

                for (Object payObj : payments) {
                    Map<String, Object> pay = (Map<String, Object>) payObj;
                    Payment__c payment = new Payment__c();

                    payment.Doc_Entry__c = String.valueOf(pay.get('DocEntry'));
                    payment.Name = String.valueOf(pay.get('DocNum'));
                    payment.Payment_Date__c = pay.get('DocDate') != null ? Date.valueOf(String.valueOf(pay.get('DocDate'))) : null;
                    payment.Due_Date__c = pay.get('DueDate') != null ? Date.valueOf(String.valueOf(pay.get('DueDate'))) : null;
                    Decimal cashSum = pay.get('CashSum') != null ? Decimal.valueOf(String.valueOf(pay.get('CashSum'))) : 0;
                    Decimal transferSum = pay.get('TransferSum') != null ? Decimal.valueOf(String.valueOf(pay.get('TransferSum'))) : 0;
                    payment.Amount__c = cashSum + transferSum;
                    payment.Payment_Type__c = cashSum > 0 ? 'Cash' : (transferSum > 0 ? 'Transfer' : 'Unknown');

                List<Object> invoices = (List<Object>) pay.get('PaymentInvoices');
                payment.Payment_Status__c = (invoices != null && !invoices.isEmpty()) ? 'Applied' : 'Not Applied';

                    if (pay.get('CardCode') != null) {
                        cardCodes.add(String.valueOf(pay.get('CardCode')));
                    }

                if (invoices != null && !invoices.isEmpty()) {
                    for (Object inv : invoices) {
                        Map<String, Object> invData = (Map<String, Object>) inv;
                        if (invData.get('DocEntry') != null) {
                            invoiceDocEntries.add(String.valueOf(invData.get('DocEntry')));
                        }
                    }
                }

                paymentsToUpsert.add(payment);
            }

            Map<String, Id> cardCodeToDealId = new Map<String, Id>();
            if (!cardCodes.isEmpty()) {
                for (Deals__c deal : [SELECT Id, Customer__r.Customer_ID__c FROM Deals__c WHERE Customer__r.Customer_ID__c IN :cardCodes LIMIT 10000]) {
                    cardCodeToDealId.put(deal.Customer__r.Customer_ID__c, deal.Id);
                }
            }

            Map<String, Id> docEntryToInvoiceId = new Map<String, Id>();
            if (!invoiceDocEntries.isEmpty()) {
                for (Invoice__c inv : [SELECT Id, Doc_Entry__c FROM Invoice__c WHERE Doc_Entry__c IN :invoiceDocEntries LIMIT 10000]) {
                    docEntryToInvoiceId.put(inv.Doc_Entry__c, inv.Id);
                }
                }

                for (Payment__c pay : paymentsToUpsert) {
                    Map<String, Object> payData = (Map<String, Object>) payments[paymentsToUpsert.indexOf(pay)];
                    String cardCode = String.valueOf(payData.get('CardCode'));
                    Id oppId = cardCodeToDealId.containsKey(cardCode) ? cardCodeToDealId.get(cardCode) : null;
                    pay.Opportunity__c = oppId;
                    System.debug('Payment DocNum: ' + payData.get('DocNum') + ', CardCode: ' + cardCode + ', Linked Opportunity: ' + oppId);

                    List<Object> invoices = (List<Object>) payData.get('PaymentInvoices');
                    if (invoices != null && !invoices.isEmpty()) {
                        Map<String, Object> invData = (Map<String, Object>) invoices[0];
                        if (invData.get('DocEntry') != null) {
                            pay.Invoice__c = docEntryToInvoiceId.get(String.valueOf(invData.get('DocEntry')));
                        }
                    }
                }

                if (!paymentsToUpsert.isEmpty()) {
                    upsert paymentsToUpsert Doc_Entry__c;
                    System.debug('Upserted ' + paymentsToUpsert.size() + ' incoming payments.');
            }
        } catch (Exception e) {
            System.debug('SAPPaymentSync-ProcessIncomingPayments Exception: ' + e.getMessage() + '\nStack Trace: ' + e.getStackTraceString());
        }
    }
}