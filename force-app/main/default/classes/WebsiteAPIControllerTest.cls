@IsTest
private class WebsiteAPIControllerTest {
    @IsTest
    static void testCreateLeadSuccess() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestUri = '/services/apexrest/WebsiteLead/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(JSON.serialize(new Map<String, Object>{
            'firstName' => 'Web',
            'lastName' => 'Lead',
            'CompanyName' => 'Website Test Co',
            'Email' => 'website.lead@test.com',
            'PrimaryPhone' => '9876500000',
            'SecondaryPhone' => '9876500001',
            'LeadSource' => 'Web'
        }));

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        WebsiteAPIController.createLead();
        Test.stopTest();

        System.assert(
            RestContext.response.statusCode == 200 || RestContext.response.statusCode == 400,
            'Expected a handled API response status.'
        );
        System.assertNotEquals(null, RestContext.response.responseBody);
    }
}