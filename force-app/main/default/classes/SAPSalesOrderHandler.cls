public class SAPSalesOrderHandler {
    private static final String SAP_BASE_URL = 'https://lemrg.hstconnect.in:50000/b1s/v1';
    private static final String LOGIN_URL = SAP_BASE_URL + '/Login';
    private static final String COMPANY_DB = 'MG_LIVE_WIP_1';
    private static final String USERNAME = 'manager';
    private static final String PASSWORD = 'Mgsap12@';

    public static void sendToSAP(List<Sales_Confirmation__c> orders) {
        HttpRequest loginReq = new HttpRequest();
        loginReq.setEndpoint(LOGIN_URL);
        loginReq.setMethod('POST');
        loginReq.setHeader('Content-Type', 'application/json');
        loginReq.setBody(JSON.serialize(new Map<String, String>{
            'CompanyDB' => COMPANY_DB,
            'UserName'  => USERNAME,
            'Password'  => PASSWORD
        }));

        Http http = new Http();
        HttpResponse loginRes = http.send(loginReq);
        if (loginRes.getStatusCode() != 200) {
            System.debug('Login Failed: ' + loginRes.getBody());
            return;
        }

        String sessionId = (String)((Map<String, Object>)JSON.deserializeUntyped(loginRes.getBody())).get('SessionId');

        for (Sales_Confirmation__c order : orders) {
            Map<String, Object> payload = new Map<String, Object>();
            payload.put('DocDate', Date.today().format());
            payload.put('DocDueDate', Date.today().addDays(3).format()); // adjust logic
            payload.put('CardCode', 'CU0000016'); // assuming mapping
            payload.put('DocCurrency', 'INR');
            payload.put('Comments', 'Auto-created from Salesforce');
            payload.put('DocTotal', order.Total_Amount__c);
            payload.put('DocType', 'dDocument_Items');
            payload.put('PaymentMethod',order.Payment_Type__c);
            payload.put('U_ProductName', order.Product_Category__c);
            
  

            // Add line items (mock)
            List<Map<String, Object>> lines = new List<Map<String, Object>>();
            // You need to fetch and map related OpportunityLineItems or custom records
            lines.add(new Map<String, Object>{
                'ItemCode' => 'TL01172', // you must map this dynamically
                'Quantity' => 1,
                'UnitPrice' => order.Total_Amount__c,
                'WarehouseCode' => 'VNGW0002'
            });

            payload.put('DocumentLines', lines);

            HttpRequest req = new HttpRequest();
            req.setEndpoint(SAP_BASE_URL + '/Orders');
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setHeader('Accept', 'application/json');
            req.setHeader('Cookie', 'B1SESSION=' + sessionId);
            req.setBody(JSON.serialize(payload));

            HttpResponse res = http.send(req);
            System.debug('SAP Order Create Response: ' + res.getBody());
        }
    }
}