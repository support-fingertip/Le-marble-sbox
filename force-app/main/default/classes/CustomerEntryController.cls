public with sharing class CustomerEntryController {
    // You can remove the getUsers method if it's not needed elsewhere
    // @AuraEnabled(cacheable=true)
    // public static List<User> getUsers() {
    //     return [SELECT Id, Name FROM User WHERE IsActive = true ORDER BY Name LIMIT 100];
    // }

    /**
     * Creates a new Customer record with the provided information
     * @param customerData Map containing the customer information
     * @return Id of the newly created Customer
     */
    @AuraEnabled
    public static String createCustomer
    (Map<String, Object> customerData) {
        try {
            // Create a new Customer record
            Customer__c newCustomer = new Customer__c();
            
            // Combine salutation, firstName, and lastName for Customer Name
            String fullName = '';
            if (customerData.containsKey('salutation')) {
                fullName += (String)customerData.get('salutation') + ' ';
            }
            if (customerData.containsKey('firstName')) {
                // Convert firstName to uppercase
                String firstName = ((String)customerData.get('firstName')).toUpperCase();
                fullName += firstName + ' ';
            }
            if (customerData.containsKey('lastName')) {
                // Convert lastName to uppercase
                String lastName = ((String)customerData.get('lastName')).toUpperCase();
                fullName += lastName;
            }
            newCustomer.Name = fullName.trim();
            
            // Set Company field
            if (customerData.containsKey('company')) {
                newCustomer.Company__c = (String)customerData.get('company');
            }
            
            // Contact information
            if (customerData.containsKey('primaryPhone')) {
                newCustomer.Phone__c = (String)customerData.get('primaryPhone');
            }
            
            if (customerData.containsKey('secondaryPhone')) {
                newCustomer.SecondaryPhone__c = (String)customerData.get('secondaryPhone');
            }
            
            if (customerData.containsKey('email')) {
                newCustomer.Email__c = (String)customerData.get('email');
            }

            // Set remarks field
            if (customerData.containsKey('remarks')) {
                newCustomer.Remarks__c = (String)customerData.get('remarks');
            }
            
            // Set Address field components using specific field APIs
            if (customerData.containsKey('city')) {
                newCustomer.Address__City__s = (String)customerData.get('city');
            }
            if (customerData.containsKey('state')) {
                newCustomer.Address__StateCode__s = (String)customerData.get('state');
            }
            if (customerData.containsKey('panchayat')) {
                newCustomer.Address__Street__s = (String)customerData.get('panchayat');
            }
            newCustomer.Address__CountryCode__s = 'IN'; // Default to India
            
            if (customerData.containsKey('customerSource')) {
                newCustomer.LeadSource__c = (String)customerData.get('customerSource');
            }
            
            // Handle reference types
            String referenceType = (String)customerData.get('referenceType');
            newCustomer.ReferenceType__c = referenceType;

            if (customerData.containsKey('phoneNumber')) {
                String referredPhoneNumber = (String)customerData.get('phoneNumber');
                
                if (referenceType == 'Customer') {
                    // Search for existing customer with the phone number
                    List<Customer__c> existingCustomers = [
                        SELECT Id, Name 
                        FROM Customer__c 
                        WHERE Phone__c = :referredPhoneNumber 
                        LIMIT 1
                    ];
                    
                    if (!existingCustomers.isEmpty()) {
                        // If customer exists, link it to the new customer
                        newCustomer.Refered_by_Customer__c = existingCustomers[0].Id;
                    } else {
                        // If customer doesn't exist, create a new one with provided name
                        Customer__c referredCustomer = new Customer__c(
                            Name = ((String)customerData.get('referralName')).toUpperCase(),
                            Phone__c = referredPhoneNumber,
                            CustomerEntryDate__c = Date.today(),
                            Status__c = 'New',
                            LeadSource__c = 'Reference',
                            Remarks__c = 'Created from customer referral on ' + 
                                        DateTime.now().format('MMM dd, yyyy HH:mm:ss') + 
                                        ' by ' + UserInfo.getName()
                        );
                        insert referredCustomer;
                        newCustomer.Refered_by_Customer__c = referredCustomer.Id;
                    }
                } else if (new Set<String>{'Contractor', 'Maison', 'Engineer', 'Architect', 'Plumber'}.contains(referenceType)) {
                    List<Architect__c> existingReferrals = [
                        SELECT Id FROM Architect__c 
                        WHERE Phone_Number__c = :referredPhoneNumber 
                        AND Reference_Type__c = :referenceType
                        LIMIT 1
                    ];
                    
                    if (!existingReferrals.isEmpty()) {
                        newCustomer.Reference_Architect__c = existingReferrals[0].Id;
                    } else {
                        Architect__c newReferral = new Architect__c(
                            Name = ((String)customerData.get('referralName')).toUpperCase(),
                            Phone_Number__c = referredPhoneNumber,
                            Reference_Type__c = referenceType
                        );
                        insert newReferral;
                        newCustomer.Reference_Architect__c = newReferral.Id;
                    }
                }
            } else if (customerData.containsKey('referralName') && 
                       (referenceType == 'Contractor' || referenceType == 'Maison' || 
                        referenceType == 'Engineer' || referenceType == 'Architect' || referenceType == 'Plumber')) {
                Architect__c newArchitect = new Architect__c();
                newArchitect.Name = (String)customerData.get('referralName');
                newArchitect.Phone_Number__c = (String)customerData.get('phoneNumber');
                newArchitect.Reference_Type__c = referenceType;
                insert newArchitect;
            }

            // Other fields
            if (customerData.containsKey('type')) {
                newCustomer.Type__c = (String)customerData.get('type');
            } else if (customerData.containsKey('leadType')) {
                newCustomer.Type__c = (String)customerData.get('leadType');
            }
            
            if (customerData.containsKey('leadPurpose')) {
                newCustomer.LeadPurpose__c = (String)customerData.get('leadPurpose');
            }
            
            // Set Customer Entry Date to today's date
            newCustomer.CustomerEntryDate__c = Date.today();
            
            // Set assigned executive
            if (customerData.containsKey('assignedExecutive')) {
                newCustomer.OwnerId = (String)customerData.get('assignedExecutive');
            }

            if (customerData.containsKey('socialMedia')) {
                newCustomer.Social_Media__c = (String)customerData.get('socialMedia');
            }

            // Handle direct architect reference
            if (customerData.containsKey('referenceArchitect')) {
                newCustomer.Reference_Architect__c = (String)customerData.get('referenceArchitect');
            }

            // Handle POC fields for Project type
            if (customerData.containsKey('type') && (String)customerData.get('type') == 'Project') {
                if (customerData.containsKey('pocName')) {
                    newCustomer.POC_Name__c = (String)customerData.get('pocName');
                }
                if (customerData.containsKey('pocContactNo')) {
                    newCustomer.POC_Contact_No__c = (String)customerData.get('pocContactNo');
                }
                if (customerData.containsKey('pocEmail')) {
                    newCustomer.POC_Email__c = (String)customerData.get('pocEmail');
                }
            }
       
            // Insert the Customer record
            insert newCustomer;
            
            return newCustomer.Id;
        } catch (DmlException e) {
            // Check for duplicate error by querying for the phone number
            if (e.getMessage() != null && e.getMessage().contains('DUPLICATES_DETECTED')) {
                String phone = (String)customerData.get('primaryPhone');
                List<Customer__c> dup = [SELECT Id FROM Customer__c WHERE Phone__c = :phone LIMIT 1];
                if (!dup.isEmpty()) {
                    throw new AuraHandledException('DUPLICATE_FOUND:' + dup[0].Id);
                }
            }
            throw new AuraHandledException('Error creating Customer: ' + e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<Customer__c> searchCustomers(String searchTerm) {
        String searchKey = '%' + searchTerm + '%';
        return [
            SELECT Id, Name, Company__c, Phone__c, Email__c 
            FROM Customer__c 
            WHERE Name LIKE :searchKey OR Company__c LIKE :searchKey
            ORDER BY LastModifiedDate DESC 
            LIMIT 10
        ];
    }

    @AuraEnabled(cacheable=true)
    public static List<Architect__c> searchArchitects(String searchTerm) {
        String searchKey = '%' + searchTerm + '%';
        return [
            SELECT Id, Name, Phone_Number__c, Reference_Type__c
            FROM Architect__c 
            WHERE Name LIKE :searchKey 
            OR Phone_Number__c LIKE :searchKey
            ORDER BY Name 
            LIMIT 10
        ];
    }

    @AuraEnabled
    public static Architect__c createArchitect(String name, String phoneNumber) {
        try {
            Architect__c newArchitect = new Architect__c(
                Name = name,
                Phone_Number__c = phoneNumber,
                Reference_Type__c = 'Architect'
            );
            insert newArchitect;
            return newArchitect;
        } catch (Exception e) {
            throw new AuraHandledException('Failed to create architect: ' + e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<Architect__c> searchContractors(String searchTerm) {
        String searchKey = '%' + searchTerm + '%';
        return [
            SELECT Id, Name, Reference_Type__c 
            FROM Architect__c 
            WHERE Name LIKE :searchKey 
            AND Reference_Type__c = 'Contractor'
            ORDER BY Name 
            LIMIT 10
        ];
    }

    @AuraEnabled
    public static Architect__c createContractor(String name) {
        try {
            Architect__c newContractor = new Architect__c(
                Name = name,
                Reference_Type__c = 'Contractor'
            );
            insert newContractor;
            return newContractor;
        } catch (Exception e) {
            throw new AuraHandledException('Failed to create contractor: ' + e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<Architect__c> searchMaisons(String searchTerm) {
        String searchKey = '%' + searchTerm + '%';
        return [
            SELECT Id, Name, Reference_Type__c 
            FROM Architect__c 
            WHERE Name LIKE :searchKey 
            AND Reference_Type__c = 'Maison'
            ORDER BY Name 
            LIMIT 10
        ];
    }

    /**
     * Retrieves a list of active executives
     * @return List of User records
     */
    @AuraEnabled(cacheable=true)
    public static List<User> getExecutives() {
        User currentUser = [SELECT Id, UserRole.Name, Profile.Name, Name FROM User WHERE Id = :UserInfo.getUserId()];
        String currentRole = currentUser.UserRole != null ? currentUser.UserRole.Name : null;
        String currentProfile = currentUser.Profile.Name;
        String currentUserId = currentUser.Id;

        // Roles for show all except self
        Set<String> showAllExceptSelfRoles = new Set<String>{
            'ADMIN',
            'BUSINESS OPERATIONS HEAD',
            'FINANCE MANAGER',
            'FRONT OFFICE EXECUTIVE'
        };
        // Roles for show all including self
        Set<String> showAllIncludingSelfRoles = new Set<String>{
            'MANAGER SALES',
            'WAREHOUSE MANAGER'
        };
        // Allowed assignable roles
        Set<String> allowedRoles = new Set<String>{
            'FRONT OFFICE EXECUTIVE',
            'MANAGER SALES',
            'WAREHOUSE MANAGER',
            'SALES EXECUTIVES',
            'SENIOR SALES EXECUTIVES',
            'ASSISTANT MANAGER SALES',
            'BUSINESS DEVELOPMENT MANAGER',
            'HEAD PROJECTS AND INSTITUTIONAL SALES',
            'TEAM LEAD SALES COORDINATOR',
            'SALES COORDINATORS',
            'MANAGER OPERATIONS AND PURCHASE'
        };
        // Excluded profiles
        Set<String> excludedProfiles = new Set<String>{
            'System Administrator',
            'Automation User',
            'Integration User'
        };
        // Exclude Front Office Executive from the list
        String excludedRoleName = 'FRONT OFFICE EXECUTIVE';

        Boolean isSysAdmin = (currentProfile == 'System Administrator');

        if (showAllExceptSelfRoles.contains(currentRole) || isSysAdmin) {
            return [
                SELECT Id, Name
                FROM User
                WHERE IsActive = true
                AND UserRole.Name IN :allowedRoles
                AND Profile.Name NOT IN :excludedProfiles
                AND UserRole.Name != :excludedRoleName
                AND Id != :currentUserId
                ORDER BY Name
            ];
        } else if (showAllIncludingSelfRoles.contains(currentRole)) {
            return [
                SELECT Id, Name
                FROM User
                WHERE IsActive = true
                AND UserRole.Name IN :allowedRoles
                AND Profile.Name NOT IN :excludedProfiles
                AND UserRole.Name != :excludedRoleName
                ORDER BY Name
            ];
        } else {
            return [
                SELECT Id, Name
                FROM User
                WHERE Id = :currentUserId
            ];
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<String> getReferenceTypes() {
        return getPicklistValues('Customer__c', 'ReferenceType__c');
    }

    @AuraEnabled(cacheable=true)
    public static List<String> getLeadSources() {
        return getPicklistValues('Customer__c', 'LeadSource__c');
    }

    @AuraEnabled(cacheable=true)
    public static List<String> getCustomerTypes() {
        return getPicklistValues('Customer__c', 'Type__c');
    }

    @AuraEnabled(cacheable=true)
    public static List<String> getSocialMediaPlatforms() {
        return getPicklistValues('Customer__c', 'Social_Media__c');
    }

    private static List<String> getPicklistValues(String objectName, String fieldName) {
        List<String> picklistValues = new List<String>();
        try {
            Schema.SObjectType sObjectType = Schema.getGlobalDescribe().get(objectName);
            Schema.DescribeSObjectResult describeSObjectResult = sObjectType.getDescribe();
            Schema.DescribeFieldResult fieldResult = describeSObjectResult.fields.getMap().get(fieldName).getDescribe();
            List<Schema.PicklistEntry> picklistEntries = fieldResult.getPicklistValues();

            for (Schema.PicklistEntry entry : picklistEntries) {
                if (entry.isActive()) {
                    picklistValues.add(entry.getLabel());
                }
            }
        } catch (Exception e) {
            System.debug('Error fetching picklist values: ' + e.getMessage());
            throw new AuraHandledException('Error fetching picklist values: ' + e.getMessage());
        }
        return picklistValues;
    }

    @AuraEnabled
    public static Map<String, Object> checkReferredCustomer(String phoneNumber) {
        Map<String, Object> result = new Map<String, Object>();
        
        List<Customer__c> existingCustomers = [
            SELECT Id, Name, Phone__c 
            FROM Customer__c 
            WHERE Phone__c = :phoneNumber 
            LIMIT 1
        ];
        
        result.put('exists', !existingCustomers.isEmpty());
        if (!existingCustomers.isEmpty()) {
            result.put('customerId', existingCustomers[0].Id);
            result.put('customerName', existingCustomers[0].Name);
        }
        
        return result;
    }

    @AuraEnabled
    public static Map<String, Object> checkReferralExists(String phoneNumber, String referenceType) {
        Map<String, Object> result = new Map<String, Object>();
        
        List<Architect__c> existingReferrals = [
            SELECT Id, Name, Phone_Number__c, Reference_Type__c 
            FROM Architect__c 
            WHERE Phone_Number__c = :phoneNumber 
            AND Reference_Type__c = :referenceType
            LIMIT 1
        ];
        
        result.put('exists', !existingReferrals.isEmpty());
        if (!existingReferrals.isEmpty()) {
            result.put('id', existingReferrals[0].Id);
            result.put('name', existingReferrals[0].Name);
        }
        
        return result;
    }

    @AuraEnabled
    public static Architect__c createMaison(String name) {
        try {
            Architect__c newMaison = new Architect__c(
                Name = name,
                Reference_Type__c = 'Maison'
            );
            insert newMaison;
            return newMaison;
        } catch (Exception e) {
            throw new AuraHandledException('Failed to create maison: ' + e.getMessage());
        }
    }
}