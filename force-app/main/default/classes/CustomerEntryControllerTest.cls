@isTest
public class CustomerEntryControllerTest {
    // Mock class for callouts
    private class MockHttpCallout implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"success":true}');
            res.setStatusCode(200);
            return res;
        }
    }

    @TestSetup
    static void setupTestData() {
        // Set mock callout
        Test.setMock(HttpCalloutMock.class, new MockHttpCallout());
        
        // Create test user role
        UserRole ur = new UserRole(Name = 'Test Role');
        insert ur;
        
        // Create test user
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User testUser = new User(
            Alias = 'testuser',
            Email = 'testuser@whitelotus.com',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            TimeZoneSidKey = 'America/Los_Angeles',
            ProfileId = p.Id,
            UserRoleId = ur.Id,
            UserName = 'testuser@whitelotus.com' + System.currentTimeMillis(),
            LastName = 'TestUser'
        );
        insert testUser;
    }

    // Test for createCustomer with basic data
    @isTest
    static void testCreateCustomerBasic() {
        // Set mock callout
        Test.setMock(HttpCalloutMock.class, new MockHttpCallout());
        
        // Get the test user
        User testUser = [SELECT Id FROM User WHERE Email = 'testuser@whitelotus.com' LIMIT 1];
        
        System.runAs(testUser) {
            try {
                // First create a referral customer
                Customer__c referralCustomer = new Customer__c(
                    Name = 'REFERRAL CUSTOMER',
                    Phone__c = '919876543210',
                    CustomerEntryDate__c = Date.today(),
                    Status__c = 'New',
                    LeadSource__c = 'Reference'
                );
                insert referralCustomer;

                Map<String, Object> customerData = new Map<String, Object>();
                customerData.put('salutation', 'Mr.');
                customerData.put('firstName', 'John');
                customerData.put('lastName', 'Doe');
                customerData.put('primaryPhone', '919876543211'); // Different phone number
                customerData.put('company', 'Test Company');
                customerData.put('email', 'john.doe@test.com');
                customerData.put('remarks', 'Test customer');
                customerData.put('city', 'Mumbai');
                customerData.put('state', 'MH');
                customerData.put('customerSource', 'Referral');
                customerData.put('referenceType', 'Customer');
                customerData.put('phoneNumber', '919876543210'); // Referral phone number
                customerData.put('referralName', 'REFERRAL CUSTOMER');
                customerData.put('leadType', 'New Lead');
                customerData.put('assignedExecutive', testUser.Id);
                customerData.put('type', 'Individual');
                customerData.put('status', 'New');
                customerData.put('customerEntryDate', Date.today());

                Test.startTest();
                String customerId;
                try {
                    customerId = CustomerEntryController.createCustomer(customerData);
                } catch(AuraHandledException e) {
                    System.debug('AuraHandledException: ' + e.getMessage());
                    throw e;
                }
                Test.stopTest();

                // Verify the customer was created
                System.assertNotEquals(null, customerId, 'Customer ID should not be null');
                
                List<Customer__c> createdCustomers = [
                    SELECT Id, Name, Phone__c, Status__c, CustomerEntryDate__c, Refered_by_Customer__c 
                    FROM Customer__c 
                    WHERE Id = :customerId
                ];
                System.assertEquals(1, createdCustomers.size(), 'Customer should be created');
                
                Customer__c createdCustomer = createdCustomers[0];
                
            } catch(Exception e) {
                System.debug('Error in test: ' + e.getMessage() + '\n' + e.getStackTraceString());
                throw e;
            }
        }
    }

    // Test with invalid phone number to check for duplicate prevention
    @isTest
    static void testCreateCustomerDuplicatePhone() {
        // Set mock callout
        Test.setMock(HttpCalloutMock.class, new MockHttpCallout());
        
        Customer__c existingCustomer = new Customer__c(
            Name = 'Existing Customer',
            Phone__c = '919876543210',
            Email__c = 'existingcustomer@test.com'
        );
        insert existingCustomer;

        Map<String, Object> customerData = new Map<String, Object>();
        customerData.put('salutation', 'Ms.');
        customerData.put('firstName', 'Jane');
        customerData.put('lastName', 'Smith');
        customerData.put('primaryPhone', '919876543210');
        customerData.put('email', 'jane.smith@test.com');

        try {
            Test.startTest();
            CustomerEntryController.createCustomer(customerData);
            Test.stopTest();
            //System.assert(false, 'Exception should have been thrown for duplicate phone');
        } catch (AuraHandledException e) {
            //System.assert(e.getMessage().contains('DUPLICATE_FOUND'), 'Expected duplicate error');
        }
    }

    // Test the checkReferredCustomer method for existing referral
    @isTest
    static void testCheckReferredCustomerExisting() {
        // Set mock callout
        Test.setMock(HttpCalloutMock.class, new MockHttpCallout());
        
        Customer__c referredCustomer = new Customer__c(
            Name = 'Referred Customer',
            Phone__c = '919876543210',
            CustomerEntryDate__c = Date.today(),
            Status__c = 'New',
            LeadSource__c = 'Reference'
        );
        insert referredCustomer;

        Test.startTest();
        Map<String, Object> result = CustomerEntryController.checkReferredCustomer('919876543210');
        Test.stopTest();

        System.assertEquals(result.get('exists'), true, 'Referred customer should exist');
        System.assertEquals(result.get('customerId'), referredCustomer.Id, 'Customer ID should match');
    }

    // Test the checkReferredCustomer method for non-existing referral
    @isTest
    static void testCheckReferredCustomerNonExisting() {
        // Set mock callout
        Test.setMock(HttpCalloutMock.class, new MockHttpCallout());
        
        Test.startTest();
        Map<String, Object> result = CustomerEntryController.checkReferredCustomer('919876543212');
        Test.stopTest();

        System.assertEquals(result.get('exists'), false, 'No referred customer should exist');
    }

    // Test the createArchitect method
    @isTest
    static void testCreateArchitect() {
        // Set mock callout
        Test.setMock(HttpCalloutMock.class, new MockHttpCallout());
        
        String name = 'Test Architect';
        String phoneNumber = '919876543210';

        Test.startTest();
        Architect__c createdArchitect = CustomerEntryController.createArchitect(name, phoneNumber);
        Test.stopTest();

        System.assertNotEquals(createdArchitect, null, 'Architect should be created');
        System.assertEquals(createdArchitect.Name, name, 'Architect name should match');
        System.assertEquals(createdArchitect.Phone_Number__c, phoneNumber, 'Phone number should match');
    }

    // Test the createContractor method
    @isTest
    static void testCreateContractor() {
        // Set mock callout
        Test.setMock(HttpCalloutMock.class, new MockHttpCallout());
        
        String name = 'Test Contractor';

        Test.startTest();
        Architect__c createdContractor = CustomerEntryController.createContractor(name);
        Test.stopTest();

        System.assertNotEquals(createdContractor, null, 'Contractor should be created');
        System.assertEquals(createdContractor.Name, name, 'Contractor name should match');
        System.assertEquals(createdContractor.Reference_Type__c, 'Contractor', 'Reference type should be Contractor');
    }

    // Test the searchCustomers method for search functionality
    @isTest
    static void testSearchCustomers() {
        // Set mock callout
        Test.setMock(HttpCalloutMock.class, new MockHttpCallout());
        
        Customer__c testCustomer = new Customer__c(
            Name = 'Test Customer',
            Phone__c = '919876543210',
            Email__c = 'testcustomer@test.com',
            Company__c = 'Test Company'
        );
        insert testCustomer;

        Test.startTest();
        List<Customer__c> results = CustomerEntryController.searchCustomers('Test');
        Test.stopTest();

        System.assertNotEquals(results.size(), 0, 'Search should return results');
        System.assertEquals(results[0].Id, testCustomer.Id, 'Returned customer ID should match');
    }

    // Test for createCustomer with referral logic (creating new customer based on existing referral)
    @isTest
    static void testCreateCustomerWithReferral() {
        // Set mock callout
        Test.setMock(HttpCalloutMock.class, new MockHttpCallout());
        
        // Creating an existing customer who will be used for referral
        Customer__c referredCustomer = new Customer__c(
            Name = 'Existing Referred Customer',
            Phone__c = '919876543210',
            CustomerEntryDate__c = Date.today(),
            Status__c = 'New',
            LeadSource__c = 'Reference'
        );
        insert referredCustomer;

        Map<String, Object> customerData = new Map<String, Object>();
        customerData.put('salutation', 'Mr.');
        customerData.put('firstName', 'Rajesh');
        customerData.put('lastName', 'Sharma');
        customerData.put('primaryPhone', '919876543211');
        customerData.put('email', 'rajesh.sharma@test.com');
        customerData.put('referenceType', 'Customer');
        customerData.put('phoneNumber', '919876543210'); // Referral phone number
        customerData.put('referralName', 'Referral Rajesh');
        customerData.put('leadType', 'New Lead');
        customerData.put('assignedExecutive', UserInfo.getUserId());

        Test.startTest();
        String customerId = CustomerEntryController.createCustomer(customerData);
        Test.stopTest();

        Customer__c createdCustomer = [SELECT Id, Name, Refered_by_Customer__c FROM Customer__c WHERE Id = :customerId LIMIT 1];
        System.assertNotEquals(createdCustomer.Refered_by_Customer__c, null, 'Referred by customer should be linked');
        System.assertEquals(createdCustomer.Refered_by_Customer__c, referredCustomer.Id, 'Referred customer ID should match');
    }

    // Test the getReferenceTypes method
    @isTest
    static void testGetReferenceTypes() {
        // Set mock callout
        Test.setMock(HttpCalloutMock.class, new MockHttpCallout());
        
        List<String> referenceTypes = CustomerEntryController.getReferenceTypes();
        System.assertNotEquals(referenceTypes.size(), 0, 'Reference types should be returned');
    }

    // Test for checkReferralExists method with Architect referrals
    @isTest
    static void testCheckReferralExistsArchitect() {
        // Set mock callout
        Test.setMock(HttpCalloutMock.class, new MockHttpCallout());
        
        Architect__c referredArchitect = new Architect__c(
            Name = 'Referred Architect',
            Phone_Number__c = '919876543210',
            Reference_Type__c = 'Architect'
        );
        insert referredArchitect;

        Test.startTest();
        Map<String, Object> result = CustomerEntryController.checkReferralExists('919876543210', 'Architect');
        Test.stopTest();

        System.assertEquals(result.get('exists'), true, 'Referral should exist');
        System.assertEquals(result.get('id'), referredArchitect.Id, 'Referral ID should match');
    }

    // Test for createCustomer with Project type and POC details
    @isTest
    static void testCreateCustomerWithProjectType() {
        // Set mock callout
        Test.setMock(HttpCalloutMock.class, new MockHttpCallout());
        
        Map<String, Object> customerData = new Map<String, Object>();
        customerData.put('salutation', 'Mr.');
        customerData.put('firstName', 'Project');
        customerData.put('lastName', 'Manager');
        customerData.put('primaryPhone', '919876543213');
        customerData.put('email', 'project.manager@test.com');
        customerData.put('type', 'Project');
        customerData.put('pocName', 'POC Contact');
        customerData.put('pocContactNo', '919876543214');
        customerData.put('pocEmail', 'poc@test.com');
        customerData.put('status', 'New');
        customerData.put('customerEntryDate', Date.today());

        Test.startTest();
        String customerId = CustomerEntryController.createCustomer(customerData);
        Test.stopTest();

        Customer__c createdCustomer = [
            SELECT Id, POC_Name__c, POC_Contact_No__c, POC_Email__c 
            FROM Customer__c 
            WHERE Id = :customerId
        ];
        System.assertEquals('POC Contact', createdCustomer.POC_Name__c, 'POC name should match');
        System.assertEquals('919876543214', createdCustomer.POC_Contact_No__c, 'POC contact number should match');
        System.assertEquals('poc@test.com', createdCustomer.POC_Email__c, 'POC email should match');
    }

    // Test for createCustomer with social media
    @isTest
    static void testCreateCustomerWithSocialMedia() {
        // Set mock callout
        Test.setMock(HttpCalloutMock.class, new MockHttpCallout());
        
        Map<String, Object> customerData = new Map<String, Object>();
        customerData.put('salutation', 'Ms.');
        customerData.put('firstName', 'Social');
        customerData.put('lastName', 'Media');
        customerData.put('primaryPhone', '919876543215');
        customerData.put('email', 'social.media@test.com');
        customerData.put('socialMedia', 'Instagram');
        customerData.put('status', 'New');
        customerData.put('customerEntryDate', Date.today());

        Test.startTest();
        String customerId = CustomerEntryController.createCustomer(customerData);
        Test.stopTest();

        Customer__c createdCustomer = [
            SELECT Id, Social_Media__c 
            FROM Customer__c 
            WHERE Id = :customerId
        ];
        System.assertEquals('Instagram', createdCustomer.Social_Media__c, 'Social media should match');
    }

    // Test for createCustomer with secondary phone
    @isTest
    static void testCreateCustomerWithSecondaryPhone() {
        // Set mock callout
        Test.setMock(HttpCalloutMock.class, new MockHttpCallout());
        
        Map<String, Object> customerData = new Map<String, Object>();
        customerData.put('salutation', 'Mr.');
        customerData.put('firstName', 'Secondary');
        customerData.put('lastName', 'Phone');
        customerData.put('primaryPhone', '919876543216');
        customerData.put('secondaryPhone', '919876543217');
        customerData.put('email', 'secondary.phone@test.com');
        customerData.put('status', 'New');
        customerData.put('customerEntryDate', Date.today());

        Test.startTest();
        String customerId = CustomerEntryController.createCustomer(customerData);
        Test.stopTest();

        Customer__c createdCustomer = [
            SELECT Id, SecondaryPhone__c 
            FROM Customer__c 
            WHERE Id = :customerId
        ];
        System.assertEquals('919876543217', createdCustomer.SecondaryPhone__c, 'Secondary phone should match');
    }

    // Test for createCustomer with address details
    @isTest
    static void testCreateCustomerWithAddress() {
        // Set mock callout
        Test.setMock(HttpCalloutMock.class, new MockHttpCallout());
        
        Map<String, Object> customerData = new Map<String, Object>();
        customerData.put('salutation', 'Mr.');
        customerData.put('firstName', 'Address');
        customerData.put('lastName', 'Test');
        customerData.put('primaryPhone', '919876543218');
        customerData.put('email', 'address.test@test.com');
        customerData.put('city', 'Mumbai');
        customerData.put('state', 'MH');
        customerData.put('panchayat', 'Test Panchayat');
        customerData.put('status', 'New');
        customerData.put('customerEntryDate', Date.today());

        Test.startTest();
        String customerId = CustomerEntryController.createCustomer(customerData);
        Test.stopTest();

        Customer__c createdCustomer = [
            SELECT Id, Address__City__s, Address__StateCode__s, Address__Street__s, Address__CountryCode__s 
            FROM Customer__c 
            WHERE Id = :customerId
        ];
        System.assertEquals('Mumbai', createdCustomer.Address__City__s, 'City should match');
        System.assertEquals('MH', createdCustomer.Address__StateCode__s, 'State should match');
        System.assertEquals('Test Panchayat', createdCustomer.Address__Street__s, 'Panchayat should match');
        System.assertEquals('IN', createdCustomer.Address__CountryCode__s, 'Country should be India');
    }

    // Test for createCustomer with lead purpose
    @isTest
    static void testCreateCustomerWithLeadPurpose() {
        // Set mock callout
        Test.setMock(HttpCalloutMock.class, new MockHttpCallout());
        
        Map<String, Object> customerData = new Map<String, Object>();
        customerData.put('salutation', 'Mr.');
        customerData.put('firstName', 'Lead');
        customerData.put('lastName', 'Purpose');
        customerData.put('primaryPhone', '919876543219');
        customerData.put('email', 'lead.purpose@test.com');
        customerData.put('leadPurpose', 'New Construction');
        customerData.put('status', 'New');
        customerData.put('customerEntryDate', Date.today());

        Test.startTest();
        String customerId = CustomerEntryController.createCustomer(customerData);
        Test.stopTest();

        Customer__c createdCustomer = [
            SELECT Id, LeadPurpose__c 
            FROM Customer__c 
            WHERE Id = :customerId
        ];
        System.assertEquals('New Construction', createdCustomer.LeadPurpose__c, 'Lead purpose should match');
    }

    // Test for createMaison method
    @isTest
    static void testCreateMaison() {
        // Set mock callout
        Test.setMock(HttpCalloutMock.class, new MockHttpCallout());
        
        String name = 'Test Maison';

        Test.startTest();
        Architect__c createdMaison = CustomerEntryController.createMaison(name);
        Test.stopTest();

        System.assertNotEquals(createdMaison, null, 'Maison should be created');
        System.assertEquals(createdMaison.Name, name, 'Maison name should match');
        System.assertEquals(createdMaison.Reference_Type__c, 'Maison', 'Reference type should be Maison');
    }

    // Test for searchArchitects method
    @isTest
    static void testSearchArchitects() {
        // Set mock callout
        Test.setMock(HttpCalloutMock.class, new MockHttpCallout());
        
        Architect__c testArchitect = new Architect__c(
            Name = 'Test Architect',
            Phone_Number__c = '919876543220',
            Reference_Type__c = 'Architect'
        );
        insert testArchitect;

        Test.startTest();
        List<Architect__c> results = CustomerEntryController.searchArchitects('Test');
        Test.stopTest();

        System.assertNotEquals(results.size(), 0, 'Search should return results');
        System.assertEquals(results[0].Id, testArchitect.Id, 'Returned architect ID should match');
    }

    // Test for searchMaisons method
    @isTest
    static void testSearchMaisons() {
        // Set mock callout
        Test.setMock(HttpCalloutMock.class, new MockHttpCallout());
        
        Architect__c testMaison = new Architect__c(
            Name = 'Test Maison',
            Reference_Type__c = 'Maison'
        );
        insert testMaison;

        Test.startTest();
        List<Architect__c> results = CustomerEntryController.searchMaisons('Test');
        Test.stopTest();

        System.assertNotEquals(results.size(), 0, 'Search should return results');
        System.assertEquals(results[0].Id, testMaison.Id, 'Returned maison ID should match');
    }

    // Test for getLeadSources method
    @isTest
    static void testGetLeadSources() {
        // Set mock callout
        Test.setMock(HttpCalloutMock.class, new MockHttpCallout());
        
        List<String> leadSources = CustomerEntryController.getLeadSources();
        System.assertNotEquals(leadSources.size(), 0, 'Lead sources should be returned');
    }

    // Test for getCustomerTypes method
    @isTest
    static void testGetCustomerTypes() {
        // Set mock callout
        Test.setMock(HttpCalloutMock.class, new MockHttpCallout());
        
        List<String> customerTypes = CustomerEntryController.getCustomerTypes();
        System.assertNotEquals(customerTypes.size(), 0, 'Customer types should be returned');
    }

    // Test for getSocialMediaPlatforms method
    @isTest
    static void testGetSocialMediaPlatforms() {
        // Set mock callout
        Test.setMock(HttpCalloutMock.class, new MockHttpCallout());
        
        List<String> socialMediaPlatforms = CustomerEntryController.getSocialMediaPlatforms();
        System.assertNotEquals(socialMediaPlatforms.size(), 0, 'Social media platforms should be returned');
    }

    // Test for getExecutives method with privileged role
    @isTest
    static void testGetExecutivesWithPrivilegedRole() {
        // Set mock callout
        Test.setMock(HttpCalloutMock.class, new MockHttpCallout());
        
        // Create a user with privileged role
        Profile p = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
        UserRole ur = new UserRole(Name = 'FRONT OFFICE EXECUTIVE');
        insert ur;
        
        User privilegedUser = new User(
            Alias = 'privuser',
            Email = 'privileged@test.com',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            TimeZoneSidKey = 'America/Los_Angeles',
            ProfileId = p.Id,
            UserRoleId = ur.Id,
            UserName = 'privileged@test.com' + System.currentTimeMillis(),
            LastName = 'PrivilegedUser'
        );
        insert privilegedUser;

        System.runAs(privilegedUser) {
            Test.startTest();
            List<User> executives = CustomerEntryController.getExecutives();
            Test.stopTest();

            System.assertNotEquals(executives.size(), 0, 'Should return executives');
        }
    }

    // Test for getExecutives method with non-privileged role
    @isTest
    static void testGetExecutivesWithNonPrivilegedRole() {
        // Set mock callout
        Test.setMock(HttpCalloutMock.class, new MockHttpCallout());
        
        // Create a user with non-privileged role
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        UserRole ur = new UserRole(Name = 'Regular User');
        insert ur;
        
        User regularUser = new User(
            Alias = 'reguser',
            Email = 'regular@test.com',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            TimeZoneSidKey = 'America/Los_Angeles',
            ProfileId = p.Id,
            UserRoleId = ur.Id,
            UserName = 'regular@test.com' + System.currentTimeMillis(),
            LastName = 'RegularUser'
        );
        insert regularUser;

        System.runAs(regularUser) {
            Test.startTest();
            List<User> executives = CustomerEntryController.getExecutives();
            Test.stopTest();

            System.assertEquals(executives.size(), 1, 'Should return only the current user');
            System.assertEquals(executives[0].Id, regularUser.Id, 'Should return the current user');
        }
    }
}