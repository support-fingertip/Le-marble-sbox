public class SAPOrderService {
    private static final String SAP_BASE_URL = 'https://lemrg.hstconnect.in:50000/b1s/v1';
    private static final String LOGIN_URL = SAP_BASE_URL + '/Login';

    private static final String COMPANY_DB = 'MG_LIVE_WIP_1';
    private static final String USERNAME = 'manager';
    private static final String PASSWORD = 'Mgsap12@';

    @future
    public static void updateSalesOrderWithDocEntry(Id salesOrderId, String docEntry, String docNum) {
        try {
            Sales_Confirmation__c order = new Sales_Confirmation__c(
                Id = salesOrderId,
                Sales_Order_Id__c = docEntry,
                SAP_Doc_Num__c = docNum
            );
            update order;
            System.debug('Successfully updated Sales_Confirmation__c record with SAP DocEntry: ' + docEntry + ' and DocNum: ' + docNum);
        } catch (Exception e) {
            System.debug('Error updating Sales_Confirmation__c record: ' + e.getMessage());
        }
    }

    public static void createSAPOrders(List<Sales_Confirmation__c> orders) {
        Map<Id, String> salesforceToSAPOrderMap = new Map<Id, String>();
        try {
            String sessionId = loginToSAP();
            if (String.isBlank(sessionId)) return;

            for (Sales_Confirmation__c order : orders) {
                Map<String, String> sapOrderResult = sendOrderToSAP(order, sessionId);
                if (sapOrderResult != null && sapOrderResult.get('DocEntry') != null && sapOrderResult.get('DocEntry') != 'WAREHOUSE_LOCKED') {
                    updateSalesOrderWithDocEntry(order.Id, sapOrderResult.get('DocEntry'), sapOrderResult.get('DocNum'));
                }
            }
        } catch (Exception e) {
            System.debug('Order Sync Failed: ' + e.getMessage());
        }
    }

    private static String loginToSAP() {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(LOGIN_URL);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setBody(JSON.serialize(new Map<String, String>{
            'CompanyDB' => COMPANY_DB,
            'UserName' => USERNAME,
            'Password' => PASSWORD
        }));

        Http http = new Http();
        HttpResponse res = http.send(req);

        if (res.getStatusCode() != 200) {
            System.debug('❌ Login Failed: ' + res.getBody());
            return null;
        }

        Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        return String.valueOf(result.get('SessionId'));
    }

    private static Map<String, String> sendOrderToSAP(Sales_Confirmation__c order, String sessionId) {
        List<Deals__c> oppList = [
            SELECT Customer__r.Customer_ID__c, BranchLocation__c, Type__c 
            FROM Deals__c 
            WHERE Id = :order.Opportunity__c 
            LIMIT 1
        ];
        if (oppList.isEmpty()) {
            System.debug('❌ No matching Deals__c found for Id: ' + order.Opportunity__c);
            return null;
        }
        Deals__c opp = oppList[0];

        List<Cart_Line_Item__c> lines = [
            SELECT Product__r.Product_Code__c, Quantity__c, Unit_Price__c, Product_Tax__c, UOM__c, Warehouse__c, BPL_IDAssignedToInvoice__c, Product__r.Product_Category__c, Total_Price__c
            FROM Cart_Line_Item__c
            WHERE Sales_Confirmation__c = :order.Id AND Item_Chosen__c = TRUE
        ];
        
        Integer bplId;
        if (!lines.isEmpty() && lines[0].BPL_IDAssignedToInvoice__c != null) {
            bplId = Integer.valueOf(lines[0].BPL_IDAssignedToInvoice__c);
        } else {
            bplId = Integer.valueOf(order.BPL_IDAssignedToInvoice__c);
        }

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
        
        // Get U_TYPE from Opportunity Type__c field
        String uType = opp.Type__c != null ? opp.Type__c : 'RETAIL';

        Map<String, Object> body = new Map<String, Object>{
            'CardCode' => opp.Customer__r.Customer_ID__c != null ? opp.Customer__r.Customer_ID__c.trim() : '',
            'DocDate' => docDate,
            'DocDueDate' => dueDate,
            'DocCurrency' => 'INR',
            'BPL_IDAssignedToInvoice' => bplId,
            'U_To_Delivery_date' => deliveryDate,
            'U_DELIVERY_TIME' => deliveryTime,
            'StartDeliveryDate' => deliveryDate,
            'StartDeliveryTime' => deliveryTime,
            'EndDeliveryDate' => endDeliveryDateStr,
            'EndDeliveryTime' => endDeliveryTime,
            'U_TYPE' => uType,
            'DocumentLines' => getDocumentLines(order)
        };

        System.debug('CardCode sent to SAP: >' + opp.Customer__r.Customer_ID__c.trim() + '<');
        System.debug('Full SAP payload: ' + JSON.serialize(body));

        HttpRequest req = new HttpRequest();
        req.setEndpoint(SAP_BASE_URL + '/Orders');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('Cookie', 'B1SESSION=' + sessionId);
        req.setBody(JSON.serialize(body));

        Http http = new Http();
        HttpResponse res = http.send(req);

        if (res.getStatusCode() != 201) {
            System.debug(' Failed to create SAP Order: ' + res.getBody());
            String errorBody = res.getBody();
            if (errorBody.contains('OITW.Locked') || errorBody.contains('warehouse is locked')) {
                return null;
            }
            throw new AuraHandledException('Failed to create SAP Order: ' + res.getBody());
        } else {
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
                return result;
            } catch (Exception e) {
                System.debug('❌ Error parsing SAP response: ' + e.getMessage());
                System.debug('Response that caused error: ' + res.getBody());
                return null;
            }
        }
    }

    private static Integer getSalesPersonCode(Id ownerId) {
        // You can implement a custom mapping if needed
        // For now, return a default code (e.g., 4 as seen in your file)
        return 4;
    }

    private static List<Object> getDocumentLines(Sales_Confirmation__c order) {
        List<Cart_Line_Item__c> lines = [
            SELECT Product__r.Product_Code__c, Quantity__c, Unit_Price__c, Product_Tax__c, UOM__c, Warehouse__c, 
                   BPL_IDAssignedToInvoice__c, Product__r.Product_Category__c, Total_Price__c, Price_Sqft__c,
                   Disc_Type__c, Dis_Value__c, After_Disc_Price_Piece__c
            FROM Cart_Line_Item__c
            WHERE Sales_Confirmation__c = :order.Id AND Item_Chosen__c = TRUE
        ];
    
        List<Object> docLines = new List<Object>();
    
        for (Cart_Line_Item__c line : lines) {
            if (line.Product__r == null || String.isBlank(line.Product__r.Product_Code__c)) continue;
    
            // Calculate unit price before tax
            Decimal taxRate = (line.Product_Tax__c != null) ? (line.Product_Tax__c / 100) : 0;
            Decimal unitPriceAfterTax = line.Unit_Price__c != null ? line.Unit_Price__c : 0;
            Decimal unitPriceBeforeTax = taxRate > 0 ? (unitPriceAfterTax / (1 + taxRate)) : unitPriceAfterTax;
            
            // Calculate price field value based on product category and discount
            Decimal priceFieldValue = unitPriceBeforeTax;
            
            if (line.Product__r.Product_Category__c == 'TILES') {
                // For TILES products
                if (line.Disc_Type__c == 'Percentage' && line.Dis_Value__c != null) {
                    // Apply discount percentage directly to unit price before tax
                    priceFieldValue = unitPriceBeforeTax - (unitPriceBeforeTax * (line.Dis_Value__c / 100));
                } else if (line.Disc_Type__c == 'Amount' && line.Dis_Value__c != null && line.Price_Sqft__c != null && line.Price_Sqft__c > 0) {
                    // Calculate discount percentage from amount and price per sqft
                    Decimal discountPercentage = (line.Dis_Value__c / line.Price_Sqft__c) * 100;
                    priceFieldValue = unitPriceBeforeTax - (unitPriceBeforeTax * (discountPercentage / 100));
                }
            } else {
                // For other products
                if (line.Disc_Type__c == 'Percentage' && line.Dis_Value__c != null) {
                    // Apply discount percentage directly to unit price before tax
                    priceFieldValue = unitPriceBeforeTax - (unitPriceBeforeTax * (line.Dis_Value__c / 100));
                } else if (line.Disc_Type__c == 'Amount' && line.Dis_Value__c != null && unitPriceAfterTax > 0) {
                    // Calculate discount percentage from amount and unit price after tax
                    Decimal discountPercentage = (line.Dis_Value__c / unitPriceAfterTax) * 100;
                    priceFieldValue = unitPriceBeforeTax - (unitPriceBeforeTax * (discountPercentage / 100));
                }
            }
    
            Map<String, Object> docLine = new Map<String, Object>{
                'ItemCode' => line.Product__r.Product_Code__c,
                'Quantity' => line.Quantity__c,
                'WarehouseCode' => line.Warehouse__c,
                'UnitPrice' => unitPriceBeforeTax.setScale(2),
                'Price' => priceFieldValue.setScale(2)
            };
    
            docLines.add(docLine);
        }
    
        return docLines;
    }
    
}