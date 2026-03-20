/**
 * @description       : 
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : 
 * @last modified on  : 06-13-2025
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
**/
public class CreatePurchaseOrderInSAP {
    // Utility method to strip HTML tags and decode HTML entities for rich text fields
    private static String stripHtmlTags(String input) {
        if (String.isBlank(input)) {
            return '';
        }
        // Step 1: Remove HTML tags using regex
        String result = input.replaceAll('<[^>]+>', '');
        // Step 2: Decode common HTML entities
        result = result.replaceAll('&amp;', '&');
        result = result.replaceAll('&lt;', '<');
        result = result.replaceAll('&gt;', '>');
        result = result.replaceAll('&quot;', '"');
        result = result.replaceAll('&apos;', '\'');
        result = result.replaceAll('&nbsp;', ' '); // Replace non-breaking space
        // Step 3: Remove extra whitespace and trim
        result = result.replaceAll('\\s+', ' ').trim();
        // Step 4: Truncate to SAP Comments field length (254 chars)
        if (result.length() > 254) {
            System.debug('Warning: Remarks__c truncated from ' + result.length() + ' to 254 characters');
            result = result.left(254);
        }
        return result;
    }

    @future(callout=true)
    public static void createPO(String pendingPurchaseId) {
        try {
            // Step 1: Query the Pending_Purchase__c record
            Pending_Purchase__c purchase = [
                SELECT Id, Vendor__r.Name, Received_Date__c, Remarks__c, Is_PO_Created__c, SAP_DocEntry__c, Status__c
                FROM Pending_Purchase__c
                WHERE Id = :pendingPurchaseId
                LIMIT 1
            ];

            // Check if status is Finance Manager Approved
            if (purchase.Status__c != 'Finance Manager Approved') {
                System.debug('Purchase Order not created/updated as status is not Finance Manager Approved. Current status: ' + purchase.Status__c);
                return;
            }

            // Debug the raw and cleaned Remarks__c values
            System.debug('Raw Remarks__c: ' + purchase.Remarks__c);
            String cleanedRemarks = stripHtmlTags(purchase.Remarks__c);
            System.debug('Cleaned Remarks__c: ' + cleanedRemarks);

            // Step 2: Query related Pending_Purchase_Line_Item__c records
            List<Pending_Purchase_Line_Item__c> lineItems = [
                SELECT Id, Product__r.Product_Code__c, Quantity__c, Warehouse__c, BPL_ID__c
                FROM Pending_Purchase_Line_Item__c
                WHERE Pending_Purchase__c = :pendingPurchaseId
            ];

            // Step 3: Skip if no line items exist
            if (lineItems.isEmpty()) {
                System.debug('No line items found for Pending Purchase: ' + pendingPurchaseId);
                return;
            }

            // Step 4: Login to SAP Service Layer
            Http http = new Http();
            HttpRequest loginRequest = new HttpRequest();
            loginRequest.setEndpoint('https://lemrg.hstconnect.in:50000/b1s/v1/Login');
            loginRequest.setMethod('POST');
            loginRequest.setHeader('Content-Type', 'application/json');
            loginRequest.setBody('{"CompanyDB": "MG_LIVE_WIP_1", "UserName": "manager", "Password": "Mgsap12@"}');
            
            HttpResponse loginResponse = http.send(loginRequest);
            if (loginResponse.getStatusCode() != 200) {
                throw new CalloutException('SAP Login failed: ' + loginResponse.getStatusCode() + ' - ' + loginResponse.getBody());
            }

            // Extract SessionId
            Map<String, Object> loginResult = (Map<String, Object>) JSON.deserializeUntyped(loginResponse.getBody());
            String sessionId = (String) loginResult.get('SessionId');

            // Step 5: Create or Update the PO in SAP
            if (!purchase.Is_PO_Created__c) {
                // Create a new PO
                Map<String, Object> poPayload = new Map<String, Object>();
                poPayload.put('CardCode', purchase.Vendor__r.Name);
                
                // Add BPL_ID if available
                String branchId = lineItems.isEmpty() ? null : lineItems[0].BPL_ID__c;
                if (String.isNotBlank(branchId)) {
                    poPayload.put('BPL_IDAssignedToInvoice', branchId);
                }
                
                poPayload.put('Comments', cleanedRemarks);
                poPayload.put('DocDueDate', purchase.Received_Date__c);

                List<Map<String, Object>> docLines = new List<Map<String, Object>>();
                for (Integer i = 0; i < lineItems.size(); i++) {
                    Map<String, Object> lineItem = new Map<String, Object>();
                    lineItem.put('LineNum', i);
                    lineItem.put('ItemCode', lineItems[i].Product__r.Product_Code__c);
                    lineItem.put('Quantity', lineItems[i].Quantity__c);
                    lineItem.put('WarehouseCode', lineItems[i].Warehouse__c);
                    docLines.add(lineItem);
                }
                poPayload.put('DocumentLines', docLines);

                HttpRequest poRequest = new HttpRequest();
                poRequest.setEndpoint('https://lemrg.hstconnect.in:50000/b1s/v1/PurchaseOrders');
                poRequest.setMethod('POST');
                poRequest.setHeader('Content-Type', 'application/json');
                poRequest.setHeader('Cookie', 'B1SESSION=' + sessionId);
                poRequest.setBody(JSON.serialize(poPayload));

                HttpResponse poResponse = http.send(poRequest);
                if (poResponse.getStatusCode() == 201) {
                    System.debug('PO created successfully: ' + poResponse.getBody());
                    // Extract DocEntry from the response
                    Map<String, Object> poResult = (Map<String, Object>) JSON.deserializeUntyped(poResponse.getBody());
                    String docEntry = String.valueOf(poResult.get('DocEntry'));
                    // Update the Pending_Purchase__c record
                    purchase.Is_PO_Created__c = true;
                    purchase.SAP_DocEntry__c = docEntry;
                    update purchase;
                } else {
                    throw new CalloutException('PO creation failed: ' + poResponse.getStatusCode() + ' - ' + poResponse.getBody());
                }
            } else {
                // Update the existing PO
                if (String.isBlank(purchase.SAP_DocEntry__c)) {
                    throw new CalloutException('SAP_DocEntry__c is blank, cannot update PO.');
                }

                // Step 6: Query the existing PO to get current DocumentLines
                HttpRequest getRequest = new HttpRequest();
                getRequest.setEndpoint('https://lemrg.hstconnect.in:50000/b1s/v1/PurchaseOrders(' + purchase.SAP_DocEntry__c + ')');
                getRequest.setMethod('GET');
                getRequest.setHeader('Content-Type', 'application/json');
                getRequest.setHeader('Cookie', 'B1SESSION=' + sessionId);

                HttpResponse getResponse = http.send(getRequest);
                if (getResponse.getStatusCode() != 200) {
                    throw new CalloutException('Failed to retrieve PO: ' + getResponse.getStatusCode() + ' - ' + getResponse.getBody());
                }

                Map<String, Object> poData = (Map<String, Object>) JSON.deserializeUntyped(getResponse.getBody());
                List<Object> existingLines = (List<Object>) poData.get('DocumentLines');

                // Step 7: Build updated DocumentLines
                List<Map<String, Object>> updatedLines = new List<Map<String, Object>>();
                Integer nextLineNum = 0;

                // Create a map of Salesforce line items for easier lookup
                Map<String, Pending_Purchase_Line_Item__c> sfLineItemMap = new Map<String, Pending_Purchase_Line_Item__c>();
                for (Pending_Purchase_Line_Item__c lineItem : lineItems) {
                    sfLineItemMap.put(lineItem.Product__r.Product_Code__c, lineItem);
                }

                // Step 8: Process existing SAP lines
                if (existingLines != null && !existingLines.isEmpty()) {
                    for (Object lineObj : existingLines) {
                        Map<String, Object> sapLine = (Map<String, Object>) lineObj;
                        String itemCode = String.valueOf(sapLine.get('ItemCode'));
                        Integer lineNum = Integer.valueOf(sapLine.get('LineNum'));

                        if (sfLineItemMap.containsKey(itemCode)) {
                            // Update existing line
                            Pending_Purchase_Line_Item__c sfLine = sfLineItemMap.get(itemCode);
                            sapLine.put('Quantity', sfLine.Quantity__c);
                            sapLine.put('WarehouseCode', sfLine.Warehouse__c);
                            updatedLines.add(sapLine);
                            sfLineItemMap.remove(itemCode); // Remove processed line
                        } else {
                            // Line no longer exists in Salesforce, skip to remove it
                            System.debug('Removing SAP line with ItemCode: ' + itemCode);
                        }

                        if (lineNum >= nextLineNum) {
                            nextLineNum = lineNum + 1;
                        }
                    }
                }

                // Step 9: Add new lines from Salesforce
                for (Pending_Purchase_Line_Item__c sfLine : sfLineItemMap.values()) {
                    Map<String, Object> newLine = new Map<String, Object>();
                    newLine.put('LineNum', nextLineNum);
                    newLine.put('ItemCode', sfLine.Product__r.Product_Code__c);
                    newLine.put('Quantity', sfLine.Quantity__c);
                    newLine.put('WarehouseCode', sfLine.Warehouse__c);
                    updatedLines.add(newLine);
                    nextLineNum++;
                    System.debug('Adding new SAP line with ItemCode: ' + sfLine.Product__r.Product_Code__c);
                }

                // Step 10: Update the PO with all fields
                Map<String, Object> updatePayload = new Map<String, Object>();
                updatePayload.put('CardCode', purchase.Vendor__r.Name);
                updatePayload.put('Comments', cleanedRemarks);
                updatePayload.put('DocDueDate', purchase.Received_Date__c);
                
                // Add BPL_ID if available
                String branchId = lineItems.isEmpty() ? null : lineItems[0].BPL_ID__c;
                if (String.isNotBlank(branchId)) {
                    updatePayload.put('BPL_IDAssignedToInvoice', branchId);
                }
                
                updatePayload.put('DocumentLines', updatedLines);

                HttpRequest updateRequest = new HttpRequest();
                updateRequest.setEndpoint('https://lemrg.hstconnect.in:50000/b1s/v1/PurchaseOrders(' + purchase.SAP_DocEntry__c + ')');
                updateRequest.setMethod('PATCH');
                updateRequest.setHeader('Content-Type', 'application/json');
                updateRequest.setHeader('Cookie', 'B1SESSION=' + sessionId);
                updateRequest.setBody(JSON.serialize(updatePayload));

                HttpResponse updateResponse = http.send(updateRequest);
                if (updateResponse.getStatusCode() == 204) {
                    System.debug('PO updated successfully for DocEntry: ' + purchase.SAP_DocEntry__c);
                } else {
                    throw new CalloutException('PO update failed: ' + updateResponse.getStatusCode() + ' - ' + updateResponse.getBody());
                }
            }
        } catch (Exception e) {
            System.debug('Error in createPO: ' + e.getMessage());
        }
    }
}