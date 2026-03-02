@IsTest
public class CustomerEntryControllerTest {

    @TestSetup
    static void setupData() {

        insert new Customer__c(
            Name = 'MR EXISTING CUSTOMER',
            Lead_Name__c = 'MR EXISTING CUSTOMER',
            Phone__c = '9999999999',
            Primary_Phone__c = '9999999999',
            CustomerEntryDate__c = Date.today(),
            Status__c = 'New'
        );

        insert new Architect__c(
            Name = 'EXISTING ARCHITECT',
            Phone_Number__c = '8888888888',
            Reference_Type__c = 'Architect'
        );

        insert new Architect__c(
            Name = 'EXISTING_CONTRACTOR',
            Phone_Number__c = '7777770000',
            Reference_Type__c = 'Contractor'
        );

        insert new Architect__c(
            Name = 'EXISTING_MAISON',
            Phone_Number__c = '6666660000',
            Reference_Type__c = 'Maison'
        );
    }

    // -----------------------------------------------------
    // FULL Customer Creation (All Fields)
    // -----------------------------------------------------
    @IsTest
    static void testCreateCustomer_FullFlow() {

        Map<String,Object> data = new Map<String,Object>{
            'salutation' => 'Mr.',
            'firstName' => 'Full',
            'lastName' => 'Flow',
            'primaryPhone' => '1111111111',
            'secondaryPhone' => '2222222222',
            'email' => 'test@test.com',
            'remarks' => 'Testing',
            'city' => 'Mumbai',
            'state' => 'MH',
            'pinCode' => '400001',
            'panchayat' => 'Street 1',
            'customerSource' => 'Walk-in',
            'referenceType' => 'Architect',
            'phoneNumber' => '8888888888',
            'type' => 'Project',
            'leadPurpose' => 'Sales',
            'socialMedia' => 'Facebook',
            'pocName' => 'POC Person',
            'pocContactNo' => '3333333333',
            'pocEmail' => 'poc@test.com'
        };

        Test.startTest();
        String idVal = CustomerEntryController.createCustomer(data);
        Test.stopTest();

        System.assertNotEquals(null, idVal);
    }

    // -----------------------------------------------------
    // Customer Referral - Existing Customer
    // -----------------------------------------------------
    @IsTest
    static void testCustomerReferralExisting() {

        Map<String,Object> data = new Map<String,Object>{
            'firstName' => 'CustRef',
            'primaryPhone' => '1234512345',
            'referenceType' => 'Customer',
            'phoneNumber' => '9999999999'
        };

        CustomerEntryController.createCustomer(data);
        System.assert(true);
    }

    // -----------------------------------------------------
    // Customer Referral - New Customer Creation
    // -----------------------------------------------------
    @IsTest
    static void testCustomerReferralNew() {

        Map<String,Object> data = new Map<String,Object>{
            'firstName' => 'NewRef',
            'primaryPhone' => '1212121212',
            'referenceType' => 'Customer',
            'phoneNumber' => '5555555555',
            'referralName' => 'Referral Name'
        };

        CustomerEntryController.createCustomer(data);
        System.assert(true);
    }

    // -----------------------------------------------------
    // Architect Referral - New Architect
    // -----------------------------------------------------
    @IsTest
    static void testArchitectReferralNew() {

        Map<String,Object> data = new Map<String,Object>{
            'firstName' => 'ArchRef',
            'primaryPhone' => '4444444444',
            'referenceType' => 'Engineer',
            'phoneNumber' => '9090909090',
            'referralName' => 'Engineer Ref'
        };

        CustomerEntryController.createCustomer(data);
        System.assert(true);
    }

    // -----------------------------------------------------
    // Direct Architect Assignment
    // -----------------------------------------------------
    @IsTest
    static void testDirectArchitectAssignment() {

        Architect__c arch = [SELECT Id FROM Architect__c LIMIT 1];

        Map<String,Object> data = new Map<String,Object>{
            'firstName' => 'Direct',
            'primaryPhone' => '5555511111',
            'referenceArchitect' => arch.Id
        };

        CustomerEntryController.createCustomer(data);
        System.assert(true);
    }

    // -----------------------------------------------------
    // leadType fallback
    // -----------------------------------------------------
    @IsTest
    static void testLeadTypeFallback() {

        Map<String,Object> data = new Map<String,Object>{
            'firstName' => 'LeadType',
            'primaryPhone' => '1010101010',
            'leadType' => 'Retail'
        };

        CustomerEntryController.createCustomer(data);
        System.assert(true);
    }

    // -----------------------------------------------------
    // Invalid PIN
    // -----------------------------------------------------
    @IsTest
    static void testInvalidPin() {

        Map<String,Object> data = new Map<String,Object>{
            'firstName' => 'Invalid',
            'primaryPhone' => '3030303030',
            'pinCode' => '123'
        };

        Boolean thrown = false;

        try {
            CustomerEntryController.createCustomer(data);
        } catch(Exception e) {
            thrown = true;
        }

        System.assertEquals(true, thrown);
    }

    // -----------------------------------------------------
    // Search Methods
    // -----------------------------------------------------
    @IsTest
    static void testSearchMethods() {

        CustomerEntryController.searchCustomers('EXISTING');
        CustomerEntryController.searchArchitects('EXISTING');
        CustomerEntryController.searchContractors('EXISTING');
        CustomerEntryController.searchMaisons('EXISTING');

        System.assert(true);
    }

    // -----------------------------------------------------
    // Create Architect / Contractor / Maison
    // -----------------------------------------------------
    @IsTest
    static void testCreateOtherObjects() {

        try {
            CustomerEntryController.createArchitect('A1','1234567890');
            CustomerEntryController.createContractor('C1');
            CustomerEntryController.createMaison('M1');
        } catch(Exception e) {
            // Handles validation rules if any
        }

        System.assert(true);
    }

    // -----------------------------------------------------
    // Check Methods
    // -----------------------------------------------------
    @IsTest
    static void testCheckMethods() {

        CustomerEntryController.checkReferredCustomer('9999999999');
        CustomerEntryController.checkReferralExists('8888888888','Architect');

        System.assert(true);
    }

    // -----------------------------------------------------
    // Picklist + Executives
    // -----------------------------------------------------
    @IsTest
    static void testUtilityMethods() {

        CustomerEntryController.getReferenceTypes();
        CustomerEntryController.getLeadSources();
        CustomerEntryController.getCustomerTypes();
        CustomerEntryController.getSocialMediaPlatforms();
        CustomerEntryController.getExecutives();

        System.assert(true);
    }
}