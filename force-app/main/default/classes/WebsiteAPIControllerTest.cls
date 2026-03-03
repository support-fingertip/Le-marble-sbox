@IsTest
private class WebsiteAPIControllerTest {
    @IsTest
    static void testCreateLeadSuccess() {
        // Set mock for callouts
        Test.setMock(HttpCalloutMock.class, new MockHttpCallout());
        // Insert a Campaign for lookup
        Campaign camp = new Campaign(Name = 'TestCampaign', IsActive = true);
        insert camp;

        WebsiteAPIController.leadWrapper wrapper = new WebsiteAPIController.leadWrapper();
        wrapper.firstName = 'Web';
        wrapper.lastName = 'Lead';
        wrapper.CompanyName = 'Website Test Co';
        wrapper.Email = 'website.lead@test.com';
        wrapper.PrimaryPhone = '9876500000';
        wrapper.SecondaryPhone = '9876500001';
        wrapper.SecondaryEmail = 'web.lead2@test.com';
        wrapper.GSTNumber = '22AAAAA0000A1Z5';
        wrapper.LeadSource = 'Web';
        wrapper.SubSource = 'TestSubSource';
        wrapper.Country = 'India';
        wrapper.CountryCode = 'IN';
        wrapper.State = 'Kerala';
        wrapper.District = 'TestDistrict';
        wrapper.Corporation = 'TestCorp';
        wrapper.Municipality = 'TestMunicipality';
        wrapper.Panchayath = 'TestPanchayath';
        wrapper.Village = 'TestVillage';
        wrapper.AddressLine1 = 'Line1';
        wrapper.AddressLine2 = 'Line2';
        wrapper.AddressLine3 = 'Line3';
        wrapper.CampaignID = camp.Name;
        wrapper.Rating = 'Hot';
        wrapper.ProductCategory = 'TestCategory';

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestUri = '/services/apexrest/WebsiteLead/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(JSON.serialize(wrapper));
        RestContext.request = req;
        RestContext.response = res;


        Exception caughtEx;
        Test.startTest();
        try {
            WebsiteAPIController.createLead();
        } catch (Exception ex) {
            caughtEx = ex;
            System.debug('Exception during createLead: ' + ex.getMessage());
        }
        Test.stopTest();
        if (caughtEx != null) {
            System.assert(false, 'Exception thrown by WebsiteAPIController.createLead(): ' + caughtEx.getMessage());
        }

        // Assert Lead was created
        Lead[] leads = [SELECT Id, FirstName, LastName, Company, Email, Phone, Secondary_Phone__c, Campaign__c, Campaign_ID__c FROM Lead WHERE Email = 'website.lead@test.com'];
        System.assertEquals(1, leads.size(), 'Lead should be created. Found: ' + leads.size());
        System.assertEquals('Web', leads[0].FirstName, 'FirstName mismatch');
        System.assertEquals('Lead', leads[0].LastName, 'LastName mismatch');
        // The controller sets Company = firstName + ' ' + lastName
        System.assertEquals('Web Lead', leads[0].Company, 'Company mismatch');
        System.assertEquals('9876500000', leads[0].Phone, 'Phone mismatch');
        System.assertEquals('9876500001', leads[0].Secondary_Phone__c, 'Secondary_Phone__c mismatch');
        System.assertEquals(camp.Name, leads[0].Campaign_ID__c, 'Lead.Campaign_ID__c should match Campaign.Name');
        System.assertEquals(camp.Id, leads[0].Campaign__c, 'Lead.Campaign__c should be mapped to Campaign.Id. Actual: ' + leads[0].Campaign__c + ', Expected: ' + camp.Id);

        // Assert Apex_Log__c was created
        Apex_Log__c[] logs = [SELECT Id, Status__c, Request_Type__c, Request__c, Response__c FROM Apex_Log__c WHERE Request_Type__c LIKE '%WebsiteAPIController%'];
        System.assert(!logs.isEmpty(), 'Apex_Log__c should be created');
        System.assertEquals('SUCCESS', logs[0].Status__c, 'Apex_Log__c status should be SUCCESS');
    }

    @IsTest
    static void testCreateLead_Error() {
        // Prepare invalid JSON
        String invalidJson = '{"firstName":"John"'; // malformed JSON
        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/WebsiteLead/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(invalidJson);
        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        WebsiteAPIController.createLead();
        Test.stopTest();

        // Assert Apex_Log__c was created with FAIL status
        Apex_Log__c[] logs = [SELECT Id, Status__c, Error_Message__c FROM Apex_Log__c WHERE Status__c = 'FAIL'];
        System.assert(!logs.isEmpty(), 'Apex_Log__c should be created for error');
        System.assertNotEquals(null, logs[0].Error_Message__c);
        System.assertEquals(400, RestContext.response.statusCode, 'Should return 400 on error');
    }

    // Minimal mock for HTTP callouts
    class MockHttpCallout implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{}');
            return res;
        }
    }
}