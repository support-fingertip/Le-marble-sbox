public class SAPInvoiceSync {
    private static final String SAP_BASE_URL = 'https://lemrg.hstconnect.in:50000/b1s/v1';
    private static final String LOGIN_URL = SAP_BASE_URL + '/Login';
    private static final String COMPANY_DB = 'MG_LIVE_WIP_1';
    private static final String USERNAME = 'manager';
    private static final String PASSWORD = 'Mgsap12@';

    @future(callout=true)
    public static void fetchInvoicesData() {
        syncInvoices();
    }

    public static void syncInvoices() {
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
            String baseUrl = SAP_BASE_URL + '/Invoices?';
            String queryString =
                '$filter=UpdateDate ge ' + formattedDate + ' or DocDate ge ' + formattedDate +
                '&$select=DocEntry,DocNum,DocDate,DocTotal,VatSum,DiscountPercent,PaidToDate,CardCode,DocumentStatus,BaseEntry,BaseType,DocumentLines' +
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
                processInvoices(res.getBody());
            } else {
                System.debug('SAPInvoiceSync HTTP Error: ' + res.getStatusCode() + ' - ' + res.getBody());
            }
        } catch (Exception e) {
            System.debug('SAPInvoiceSync Exception: ' + e.getMessage() + '\nStack Trace: ' + e.getStackTraceString());
        }
    }

    public static void processInvoices(String responseBody) {
        try {
            Map<String, Object> jsonResponse = (Map<String, Object>) JSON.deserializeUntyped(responseBody);
            List<Object> invoices = (List<Object>) jsonResponse.get('value');

            List<Invoice__c> invoicesToUpsert = new List<Invoice__c>();
            Set<String> cardCodes = new Set<String>();
            Set<String> deliveryIds = new Set<String>();

            for (Object invObj : invoices) {
                Map<String, Object> inv = (Map<String, Object>) invObj;
                Invoice__c invoice = new Invoice__c();

                invoice.Doc_Entry__c = String.valueOf(inv.get('DocEntry'));
                invoice.Name = String.valueOf(inv.get('DocNum'));
                invoice.Invoice_Date__c = inv.get('DocDate') != null ? Date.valueOf(String.valueOf(inv.get('DocDate'))) : null;
                invoice.Invoice_Amount__c = inv.get('DocTotal') != null ? Decimal.valueOf(String.valueOf(inv.get('DocTotal'))) : 0;
                invoice.GST_Amount__c = inv.get('VatSum') != null ? Decimal.valueOf(String.valueOf(inv.get('VatSum'))) : 0;
                invoice.Discount_Applied__c = inv.get('DiscountPercent') != null ? Decimal.valueOf(String.valueOf(inv.get('DiscountPercent'))) : 0;

                Decimal paidToDate = inv.get('PaidToDate') != null ? Decimal.valueOf(String.valueOf(inv.get('PaidToDate'))) : 0;
                Decimal docTotal = invoice.Invoice_Amount__c;
                invoice.Payment_Status__c = paidToDate >= docTotal ? 'Paid' : (paidToDate > 0 ? 'Partially Paid' : 'Unpaid');

                if (inv.get('CardCode') != null) {
                    cardCodes.add(String.valueOf(inv.get('CardCode')));
                }

                // NEW: Collect deliveryIds from DocumentLines
                List<Object> docLines = (List<Object>) inv.get('DocumentLines');
                if (docLines != null) {
                    for (Object lineObj : docLines) {
                        Map<String, Object> line = (Map<String, Object>) lineObj;
                        if (line.get('BaseType') == 15 && line.get('BaseEntry') != null) {
                            deliveryIds.add(String.valueOf(line.get('BaseEntry')));
                        }
                    }
                }

                invoicesToUpsert.add(invoice);
            }

            Map<String, Id> cardCodeToDealId = new Map<String, Id>();
            if (!cardCodes.isEmpty()) {
                for (Deals__c deal : [SELECT Id, Customer__r.Customer_ID__c FROM Deals__c WHERE Customer__r.Customer_ID__c IN :cardCodes LIMIT 10000]) {
                    cardCodeToDealId.put(deal.Customer__r.Customer_ID__c, deal.Id);
                }
            }

            Map<String, Id> deliveryIdToGroupId = new Map<String, Id>();
            if (!deliveryIds.isEmpty()) {
                for (Delivery_Group__c dg : [SELECT Id, Delivery_Id_SAP__c FROM Delivery_Group__c WHERE Delivery_Id_SAP__c IN :deliveryIds LIMIT 10000]) {
                    deliveryIdToGroupId.put(dg.Delivery_Id_SAP__c, dg.Id);
                }
            }

            for (Invoice__c inv : invoicesToUpsert) {
                Map<String, Object> invData = (Map<String, Object>) invoices[invoicesToUpsert.indexOf(inv)];
                inv.Opportunity__c = cardCodeToDealId.get(String.valueOf(invData.get('CardCode')));

                // NEW: Set Delivery_Group__c from DocumentLines
                List<Object> docLines = (List<Object>) invData.get('DocumentLines');
                String deliveryGroupId = null;
                if (docLines != null) {
                    for (Object lineObj : docLines) {
                        Map<String, Object> line = (Map<String, Object>) lineObj;
                        if (line.get('BaseType') == 15 && line.get('BaseEntry') != null) {
                            deliveryGroupId = deliveryIdToGroupId.get(String.valueOf(line.get('BaseEntry')));
                            break;
                        }
                    }
                }
                inv.Delivery_Group__c = deliveryGroupId;
            }

            if (!invoicesToUpsert.isEmpty()) {
                upsert invoicesToUpsert Doc_Entry__c;
                System.debug('Upserted ' + invoicesToUpsert.size() + ' invoices.');
            }
        } catch (Exception e) {
            System.debug('SAPInvoiceSync-ProcessInvoices Exception: ' + e.getMessage() + '\nStack Trace: ' + e.getStackTraceString());
        }
    }
}