/****************************************************************
* Class Name   : WebsiteAPIController
* Company      : Fingertipplus
* Created Date : 25-11-2025
* @description : This class is used for Integration with website for Capturing the Lead into Salesforce 
* @author      : Roopesh

* Change Log:
* -----------------------------------------------------------------------------
* Ver | Author          |     Date      | Description
* -----------------------------------------------------------------------------
* 1.0 | Roopesh         | 25-11-2025    | Initial version
* -----------------------------------------------------------------------------
**************************************************************/
@RestResource(urlMapping='/WebsiteLead/*')
global without sharing class WebsiteAPIController {

    @HttpPost
    global static void createLead() {

        RestRequest req = RestContext.request;
        String requestBody = req.requestBody.toString(); // Get the JSON body
        
        Apex_Log__c log = new Apex_Log__c();
        log.Request_Type__c = 'WebsiteAPIController ' + ' WebsiteLead';
        
        try {
            // Deserialize the JSON body into the callWrapper class
            leadWrapper ldData = (leadWrapper) JSON.deserialize(requestBody, leadWrapper.class);
            log.Request__c = requestBody;

            // Create a new Lead using the deserialized data
            Lead nld = new Lead();
            nld.FirstName               = ldData.firstName;
            nld.lastName                = ldData.lastName;
            nld.Company                 = ldData.CompanyName;
            nld.Email                   = ldData.Email;
            nld.Phone                   = ldData.PrimaryPhone;
            nld.Secondary_Phone__c      = ldData.SecondaryPhone;
        //  nld.FirstName               = ldData.SecondaryEmail;
            nld.GST_Number__c           = ldData.GSTNumber;
            nld.LeadSource              = ldData.LeadSource;
            nld.Sub_Source__c           = ldData.SubSource;   // restored (this was the one you commented)
            nld.Country__c              = ldData.Country;
        //  nld.FirstName               = ldData.CountryCode;
            nld.State__c                = ldData.State;
            nld.District__c             = ldData.District;
            nld.Corporation__c          = ldData.Corporation;
            nld.Municipality__c         = ldData.Municipality;
            nld.Panchayath__c           = ldData.Panchayath;
            nld.Village__c              = ldData.Village;
            nld.AddressLine1__c         = ldData.AddressLine1;
            nld.AddressLine2__c         = ldData.AddressLine2;
            nld.AddressLine3__c         = ldData.AddressLine3;
            nld.Campaign_ID__c          = ldData.CampaignID;
            nld.Rating                  = ldData.Rating;
     //       nld.Product_Category__c     = ldData.ProductCategory;

            List<Campaign> cmp = new List<Campaign>();

            if (ldData.CampaignID != null) {
                cmp = [
                    SELECT Id, Name 
                    FROM Campaign 
                    WHERE Name = :ldData.CampaignID 
                    AND IsActive = true 
                    ORDER BY createddate DESC 
                    LIMIT 1
                ];
            }

        /* else if(ldData.campaignId == null && ldData.campaignName != null){
               cmp = [select Id,Name,Project_Name__c,Source__c,Sub_Source__c from Campaign where Name = :ldData.campaignName and IsActive = true order by createddate desc limit 1];
           } */

            if (cmp.size() > 0) {
                nld.Campaign__c = cmp[0].Id;
           /*     nld.Source_Type__c = cmp[0].Source__c;
                  nld.Lead_source__c = cmp[0].Sub_Source__c;
                  nld.Sub_Source__c  = cmp[0].Name; */
            }

            insert nld;

            // Return success response
            log.response__c = String.valueOf(nld);
            log.Status__c   = 'SUCCESS';
            insert log;
            
            RestContext.response.statusCode = 200;
            RestContext.response.responseBody = Blob.valueOf(
                JSON.serialize(new Map<String, Object>{
                    'success' => true,
                    'Salesforce LeadId' => nld.Id
                })
            );

        } catch (Exception e) {
            
            log.response__c = e.getStackTraceString();
            log.Status__c   = 'FAIL';
            log.Error_Message__c = e.getMessage();
            insert log;
            
            System.debug('Error creating task: ' + e.getMessage());
            
            RestContext.response.statusCode = 400;
            RestContext.response.responseBody = Blob.valueOf('Error: ' + e.getMessage());
        }
    }
    
    // Wrapper class for deserialization
    public class leadWrapper {
        public String firstName;
        public String lastName;
        public String CompanyName;
        public String Email;
        public String PrimaryPhone;
        public String SecondaryPhone;
        public String SecondaryEmail;
        public String GSTNumber;
        public String LeadSource;
        public String SubSource;
        public String Country;
        public String CountryCode;
        public String State;
        public String District;
        public String Corporation;
        public String Municipality;
        public String Panchayath;
        public String Village;
        public String AddressLine1;
        public String AddressLine2;
        public String AddressLine3;
        public String CampaignID;
        public String Rating;
        public String ProductCategory;
    }
    
           /* if(ldData.source =='MagicBricks'|| ldData.source =='99 Acres' || ldData.source =='Housing.com'){
                nld.Source_Type__c ='Digital Marketing';
                nld.Lead_source__c ='Real Estate Portals';
                nld.Tertiary_Source__c =ldData.source;
                
            }
            if(ldData.source =='Website'){
                nld.Source_Type__c ='Digital Marketing';
                nld.Lead_source__c ='Website';
                nld.Tertiary_Source__c = 'Microsite';
                
            }
            if(ldData.source =='GoogleSearch'|| ldData.source =='GoogleDemandgen' || ldData.source =='FacebookCTW'|| ldData.source =='Taboola'){
                nld.Source_Type__c ='Digital Marketing';
                nld.Lead_source__c =ldData.source;
               // nld.Tertiary_Source__c = 'NA';
                
            } */

            /* nld.Source_Type__c = 'Digital';
               nld.UTM_Source__c = ldData.utmSource;
               nld.UTM_Medium__c = ldData.utmMedium;
               nld.UTM_Campaign__c = ldData.utmCampaign;
               nld.UTM_Adgroup__c = ldData.utmAdgroup;
               nld.UTM_Term__c = ldData.utmTerm;
               nld.UTM_Placement__c = ldData.utmPlacment;
               nld.UTM_Device__c = ldData.utmDevice; */

}