public class SAPBPCreation {

    // Create Business Partner in SAP
    @future(callout=true)
    public static void createBusinessPartner(Id dealId) {
        try {
            Deals__c deal = [
                SELECT Customer__r.Customer_ID__c, Name, Email__c, Phone__c, SecondaryPhone__c,
                       Company__c, Remarks__c,
                       Address__Street__s, Address__City__s, Address__PostalCode__s,
                       Address__StateCode__s, Address__CountryCode__s,
                       Billing_Address__Street__s, Billing_Address__City__s, Billing_Address__StateCode__s,
                       Billing_Address__PostalCode__s, Billing_Address__CountryCode__s,
                       Shipping_Address_Name__c, Shipping_Address_Name_2__c, Shipping_Address_Name_3__c,
                       Billing_Address_Name__c, Billing_Address_Name_2__c, Billing_Address_Name_3__c, Opp_BE_Name__c                FROM Deals__c
                WHERE Id = :dealId
                LIMIT 1
            ];

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

            // 1. Check if BP exists in SAP
            HttpRequest getRequest = new HttpRequest();
            getRequest.setEndpoint('https://lemrg.hstconnect.in:50000/b1s/v1/BusinessPartners(\'' + deal.Customer__r.Customer_ID__c + '\')');
            getRequest.setMethod('GET');
            getRequest.setHeader('Cookie', 'B1SESSION=' + sessionId);
            HttpResponse getResponse = http.send(getRequest);

            if (getResponse.getStatusCode() == 200) {
                // BP already exists, do not create
                System.debug(LoggingLevel.INFO, 'BP already exists in SAP for Customer_ID: ' + deal.Customer__r.Customer_ID__c);
                return;
            }

            // If not found (404), proceed to create
            if (getResponse.getStatusCode() != 404) {
                // Some other error
                System.debug(LoggingLevel.ERROR, 'Error checking BP in SAP: ' + getResponse.getBody());
                return;
            }

            // Build BPAddresses[]
            List<Map<String, Object>> bpAddresses = new List<Map<String, Object>>();
            String uniqueSuffix = String.valueOf(DateTime.now().getTime());

            // Ship To address from Address__ fields
            Map<String, Object> shipToAddress = new Map<String, Object>{
                'AddressName'   => deal.Opp_BE_Name__c,
                'Street'        => deal.Address__Street__s,
                'City'          => deal.Address__City__s,
                'State'         => deal.Address__StateCode__s,
                'ZipCode'       => deal.Address__PostalCode__s,
                'Country'       => deal.Address__CountryCode__s,
                'AddressType'   => 'bo_ShipTo',
                'AddressName2'  => deal.Shipping_Address_Name_2__c,
                'AddressName3'  => deal.Shipping_Address_Name_3__c
            };
            bpAddresses.add(shipToAddress);

            // Bill To address from Billing_Address__ fields
            Map<String, Object> billToAddress = new Map<String, Object>{
                'AddressName'   => deal.Opp_BE_Name__c,
                'Street'        => deal.Billing_Address__Street__s,
                'City'          => deal.Billing_Address__City__s,
                'State'         => deal.Billing_Address__StateCode__s,
                'ZipCode'       => deal.Billing_Address__PostalCode__s,
                'Country'       => deal.Billing_Address__CountryCode__s,
                'AddressType'   => 'bo_BillTo',
                'AddressName2'  => deal.Billing_Address_Name_2__c,
                'AddressName3'  => deal.Billing_Address_Name_3__c
            };
            bpAddresses.add(billToAddress);

            // Create Business Partner payload
            Map<String, Object> bpPayload = new Map<String, Object>{
                'CardCode'       => deal.Customer__r.Customer_ID__c,
                'CardName'       => deal.Opp_BE_Name__c,
                'CardType'       => 'cCustomer',
                'Currency'       => 'INR',
                'EmailAddress'   => deal.Email__c,
                'Phone1'         => deal.Phone__c,
                'Phone2'         => deal.SecondaryPhone__c,
                'CardForeignName'=> deal.Company__c,
                'Notes'          => deal.Remarks__c,
                'BPAddresses'    => bpAddresses
            };
 System.debug('bpPayload: ' + bpPayload);
            HttpRequest bpRequest = new HttpRequest();
            bpRequest.setEndpoint('https://lemrg.hstconnect.in:50000/b1s/v1/BusinessPartners');
            bpRequest.setMethod('POST');
            bpRequest.setHeader('Content-Type', 'application/json');
            bpRequest.setHeader('Cookie', 'B1SESSION=' + sessionId);
            bpRequest.setBody(JSON.serialize(bpPayload));
 System.debug( 'JSON.serialize(bpPayload): ' + JSON.serialize(bpPayload));
            HttpResponse bpResponse = http.send(bpRequest);

            if (bpResponse.getStatusCode() == 201) {
                System.debug(LoggingLevel.INFO, 'Business Partner created: ' + bpResponse.getBody());
            } else {
                System.debug(LoggingLevel.ERROR, 'BP creation failed: ' + bpResponse.getBody());
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error creating Business Partner: ' + e.getMessage());
        }
    }

    // Update Business Partner in SAP
    @future(callout=true)
    public static void updateBusinessPartner(Id dealId) {
        try {
            Deals__c deal = [
                SELECT Customer__r.Customer_ID__c, Name, Email__c, Phone__c, SecondaryPhone__c,
                       Company__c, Remarks__c,
                       Address__Street__s, Address__City__s, Address__PostalCode__s,
                       Address__StateCode__s, Address__CountryCode__s,
                       Billing_Address__Street__s, Billing_Address__City__s, Billing_Address__StateCode__s,
                       Billing_Address__PostalCode__s, Billing_Address__CountryCode__s,
                       Shipping_Address_Name__c, Shipping_Address_Name_2__c, Shipping_Address_Name_3__c,
                       Billing_Address_Name__c, Billing_Address_Name_2__c, Billing_Address_Name_3__c, Opp_BE_Name__c
                FROM Deals__c
                WHERE Id = :dealId
                LIMIT 1
            ];

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
            getRequest.setEndpoint('https://lemrg.hstconnect.in:50000/b1s/v1/BusinessPartners(\'' + deal.Customer__r.Customer_ID__c + '\')');
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

                if (deal.Shipping_Address_Name__c != null && addrName == deal.Shipping_Address_Name__c) {
                    existingAddr.put('Street', deal.Address__Street__s);
                    existingAddr.put('City', deal.Address__City__s);
                    existingAddr.put('State', deal.Address__StateCode__s);
                    existingAddr.put('ZipCode', deal.Address__PostalCode__s);
                    existingAddr.put('Country', deal.Address__CountryCode__s);
                    existingAddr.put('AddressType', 'bo_ShipTo');
                    existingAddr.put('AddressName2', deal.Shipping_Address_Name_2__c);
                    existingAddr.put('AddressName3', deal.Shipping_Address_Name_3__c);
                    shipToAddressFoundAndUpdated = true;
                }

                if (deal.Billing_Address_Name__c != null && addrName == deal.Billing_Address_Name__c) {
                    existingAddr.put('Street', deal.Billing_Address__Street__s);
                    existingAddr.put('City', deal.Billing_Address__City__s);
                    existingAddr.put('State', deal.Billing_Address__StateCode__s);
                    existingAddr.put('ZipCode', deal.Billing_Address__PostalCode__s);
                    existingAddr.put('Country', deal.Billing_Address__CountryCode__s);
                    existingAddr.put('AddressType', 'bo_BillTo');
                    existingAddr.put('AddressName2', deal.Billing_Address_Name_2__c);
                    existingAddr.put('AddressName3', deal.Billing_Address_Name_3__c);
                    billToAddressFoundAndUpdated = true;
                }
            }

            if (!shipToAddressFoundAndUpdated && deal.Shipping_Address_Name__c != null) {
                bpAddresses.add(new Map<String, Object>{
                    'AddressName' => deal.Shipping_Address_Name__c,
                    'Street' => deal.Address__Street__s,
                    'City' => deal.Address__City__s,
                    'State' => deal.Address__StateCode__s,
                    'ZipCode' => deal.Address__PostalCode__s,
                    'Country' => deal.Address__CountryCode__s,
                    'AddressType' => 'bo_ShipTo',
                    'AddressName2' => deal.Shipping_Address_Name_2__c,
                    'AddressName3' => deal.Shipping_Address_Name_3__c
                });
            }

            if (!billToAddressFoundAndUpdated && deal.Billing_Address_Name__c != null) {
                bpAddresses.add(new Map<String, Object>{
                    'AddressName' => deal.Billing_Address_Name__c,
                    'Street' => deal.Billing_Address__Street__s,
                    'City' => deal.Billing_Address__City__s,
                    'State' => deal.Billing_Address__StateCode__s,
                    'ZipCode' => deal.Billing_Address__PostalCode__s,
                    'Country' => deal.Billing_Address__CountryCode__s,
                    'AddressType' => 'bo_BillTo',
                    'AddressName2' => deal.Billing_Address_Name_2__c,
                    'AddressName3' => deal.Billing_Address_Name_3__c
                });
            }

            // Update BP payload with the final list of addresses
            Map<String, Object> updatePayload = new Map<String, Object>{
                'Currency'       => 'INR',
                'EmailAddress'   => deal.Email__c,
                'Phone1'         => deal.Phone__c,
                'Phone2'         => deal.SecondaryPhone__c,
                'CardForeignName'=> deal.Company__c,
                'Notes'          => deal.Remarks__c,
                'BPAddresses'    => bpAddresses
            };

            HttpRequest patchRequest = new HttpRequest();
            patchRequest.setEndpoint('https://lemrg.hstconnect.in:50000/b1s/v1/BusinessPartners(\'' + deal.Customer__r.Customer_ID__c + '\')');
            patchRequest.setMethod('PATCH');
            patchRequest.setHeader('Content-Type', 'application/json');
            patchRequest.setHeader('Cookie', 'B1SESSION=' + sessionId);
            patchRequest.setBody(JSON.serialize(updatePayload));

            HttpResponse patchResponse = http.send(patchRequest);

            if (patchResponse.getStatusCode() != 204) {
                System.debug(LoggingLevel.ERROR, 'BP update failed: ' + patchResponse.getBody());
            }

        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error updating Business Partner: ' + e.getMessage());
        }
    }
    
}