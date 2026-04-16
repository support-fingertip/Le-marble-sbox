public with sharing class MobileLeadConversionController {
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getConversionContext(Id leadId) {
        if (leadId == null) {
            throw new AuraHandledException('Lead Id is required.');
        }

        Lead sourceLead = [
            SELECT Id, FirstName, LastName, Company, OwnerId, Owner.Name
            FROM Lead
            WHERE Id = :leadId
            LIMIT 1
        ];

        List<LeadStatus> convertedStatuses = [
            SELECT MasterLabel
            FROM LeadStatus
            WHERE IsConverted = true
            ORDER BY SortOrder
        ];

        List<String> statusLabels = new List<String>();
        for (LeadStatus status : convertedStatuses) {
            statusLabels.add(status.MasterLabel);
        }

        String defaultOpportunityName = String.isNotBlank(sourceLead.Company)
            ? sourceLead.Company
            : ((sourceLead.FirstName != null ? sourceLead.FirstName + ' ' : '') + sourceLead.LastName);

        return new Map<String, Object>{
            'leadId' => sourceLead.Id,
            'leadFirstName' => sourceLead.FirstName,
            'leadLastName' => sourceLead.LastName,
            'leadCompany' => sourceLead.Company,
            'ownerId' => sourceLead.OwnerId,
            'ownerName' => sourceLead.Owner.Name,
            'convertedStatuses' => statusLabels,
            'defaultConvertedStatus' => statusLabels.isEmpty() ? null : statusLabels[0],
            'defaultOpportunityName' => defaultOpportunityName
        };
    }

    @AuraEnabled(cacheable=true)
    public static List<Account> searchAccounts(String searchTerm) {
        if (String.isBlank(searchTerm) || searchTerm.trim().length() < 2) {
            return new List<Account>();
        }

        String likeTerm = '%' + searchTerm.trim() + '%';
        return [
            SELECT Id, Name
            FROM Account
            WHERE Name LIKE :likeTerm
            ORDER BY Name
            LIMIT 20
        ];
    }

    @AuraEnabled(cacheable=true)
    public static List<Contact> searchContacts(Id accountId, String searchTerm) {
        if (accountId == null || String.isBlank(searchTerm) || searchTerm.trim().length() < 2) {
            return new List<Contact>();
        }

        String likeTerm = '%' + searchTerm.trim() + '%';
        return [
            SELECT Id, Name, AccountId
            FROM Contact
            WHERE AccountId = :accountId
            AND Name LIKE :likeTerm
            ORDER BY Name
            LIMIT 20
        ];
    }

    @AuraEnabled(cacheable=true)
    public static List<Opportunity> searchOpportunities(Id accountId, String searchTerm) {
        if (accountId == null || String.isBlank(searchTerm) || searchTerm.trim().length() < 2) {
            return new List<Opportunity>();
        }

        String likeTerm = '%' + searchTerm.trim() + '%';
        return [
            SELECT Id, Name, AccountId
            FROM Opportunity
            WHERE AccountId = :accountId
            AND Name LIKE :likeTerm
            ORDER BY LastModifiedDate DESC
            LIMIT 20
        ];
    }

    @AuraEnabled(cacheable=true)
    public static Contact getContactSummary(Id contactId) {
        if (contactId == null) {
            return null;
        }

        return [
            SELECT Id, Name, AccountId
            FROM Contact
            WHERE Id = :contactId
            LIMIT 1
        ];
    }

    @AuraEnabled(cacheable=true)
    public static Opportunity getOpportunitySummary(Id opportunityId) {
        if (opportunityId == null) {
            return null;
        }

        return [
            SELECT Id, Name, AccountId
            FROM Opportunity
            WHERE Id = :opportunityId
            LIMIT 1
        ];
    }

    @AuraEnabled
    public static Map<String, Id> convertLeadForMobile(
        Id leadId,
        String convertedStatus,
        Id ownerId,
        Boolean useExistingAccount,
        Id existingAccountId,
        String newAccountName,
        Boolean useExistingContact,
        Id existingContactId,
        String newContactFirstName,
        String newContactLastName,
        Boolean doNotCreateOpportunity,
        String opportunityName,
        Boolean useExistingOpportunity,
        Id existingOpportunityId
    ) {
        if (leadId == null) {
            throw new AuraHandledException('Lead Id is required for conversion.');
        }

        if (String.isBlank(convertedStatus)) {
            List<LeadStatus> statuses = [
                SELECT MasterLabel
                FROM LeadStatus
                WHERE IsConverted = true
                ORDER BY SortOrder
                LIMIT 1
            ];
            if (statuses.isEmpty()) {
                throw new AuraHandledException('No converted Lead status is configured.');
            }
            convertedStatus = statuses[0].MasterLabel;
        }

        if (useExistingAccount == true && existingAccountId == null) {
            throw new AuraHandledException('Please choose an existing Account.');
        }
        if (useExistingAccount != true && String.isBlank(newAccountName)) {
            throw new AuraHandledException('Account Name is required for conversion.');
        }

        if (useExistingContact == true && existingContactId == null) {
            throw new AuraHandledException('Please choose an existing Contact.');
        }
        if (useExistingContact != true && String.isBlank(newContactLastName)) {
            throw new AuraHandledException('Contact Last Name is required for conversion.');
        }

        if (useExistingOpportunity == true && existingOpportunityId == null) {
            throw new AuraHandledException('Please choose an existing Opportunity.');
        }

        if (useExistingOpportunity == true) {
            doNotCreateOpportunity = true;
        }

        if ((doNotCreateOpportunity == false || doNotCreateOpportunity == null) && String.isBlank(opportunityName)) {
            throw new AuraHandledException('Opportunity name is required when creating an Opportunity.');
        }

        Lead leadToUpdate = [
            SELECT Id, OwnerId, Company, FirstName, LastName, Phone, MobilePhone, Customer_Type__c,
                   Product_Category__c, Branch_Location__c, Check_List_Items__c,
                   Street, City, State, PostalCode, Country,
                   GST_Type__c, GST_Number__c, Pin_Code__c, State__c
            FROM Lead
            WHERE Id = :leadId
            LIMIT 1
        ];

        Boolean shouldUpdateLead = false;

        if (useExistingAccount != true && String.isNotBlank(newAccountName)) {
            String normalizedAccountName = newAccountName.trim();
            if (leadToUpdate.Company != normalizedAccountName) {
                leadToUpdate.Company = normalizedAccountName;
                shouldUpdateLead = true;
            }
        }

        if (useExistingContact != true && String.isNotBlank(newContactFirstName)) {
            String updatedFirstName = newContactFirstName.trim();
            if (leadToUpdate.FirstName != updatedFirstName) {
                leadToUpdate.FirstName = updatedFirstName;
                shouldUpdateLead = true;
            }
        }

        if (useExistingContact != true && String.isNotBlank(newContactLastName)) {
            String updatedLastName = newContactLastName.trim();
            if (leadToUpdate.LastName != updatedLastName) {
                leadToUpdate.LastName = updatedLastName;
                shouldUpdateLead = true;
            }
        }

        if (String.isBlank(leadToUpdate.Check_List_Items__c)) {
            throw new AuraHandledException('Please select at least one Checklist item before converting the Lead.');
        }

        List<String> missingAddressFields = new List<String>();
        if (String.isBlank(leadToUpdate.Street)) {
            missingAddressFields.add('Street');
        }
        if (String.isBlank(leadToUpdate.City)) {
            missingAddressFields.add('City');
        }
        if (String.isBlank(leadToUpdate.State)) {
            missingAddressFields.add('State');
        }
        if (String.isBlank(leadToUpdate.PostalCode)) {
            missingAddressFields.add('Postal Code');
        }
        if (String.isBlank(leadToUpdate.Country)) {
            missingAddressFields.add('Country');
        }

        if (!missingAddressFields.isEmpty()) {
            if (missingAddressFields.size() == 1 && missingAddressFields[0] == 'Country') {
                throw new AuraHandledException('Please select a Country before converting the Lead. The Country field is required for successful conversion.');
            } else {
                throw new AuraHandledException(
                    'Lead Address is required before conversion. Please fill: ' + String.join(missingAddressFields, ', ')
                );
            }
        }

        // VALIDATE PIN CODE AND STATE FOR SHIPPING ADDRESS
        if (leadToUpdate.Pin_Code__c == null) {
            throw new AuraHandledException('Pin Code is required before converting the Lead.');
        }
        if (String.isBlank(leadToUpdate.State__c)) {
            throw new AuraHandledException('State is required before converting the Lead.');
        }


        Boolean requiresIndianPhoneValidation = isIndiaCountry(leadToUpdate.Country);

        if (String.isNotBlank(leadToUpdate.Phone)) {
            String cleanedPhone = digitsOnly(leadToUpdate.Phone);
            if (requiresIndianPhoneValidation && cleanedPhone.length() != 10) {
                throw new AuraHandledException('Phone must be exactly 10 digits when Country is India.');
            }

            if (useExistingContact != true && leadToUpdate.Phone != cleanedPhone) {
                leadToUpdate.Phone = cleanedPhone;
                shouldUpdateLead = true;
            }
        }

        if (String.isNotBlank(leadToUpdate.MobilePhone)) {
            String cleanedMobilePhone = digitsOnly(leadToUpdate.MobilePhone);
            if (requiresIndianPhoneValidation && cleanedMobilePhone.length() != 10) {
                throw new AuraHandledException('Mobile Phone must be exactly 10 digits when Country is India.');
            }

            if (useExistingContact != true && leadToUpdate.MobilePhone != cleanedMobilePhone) {
                leadToUpdate.MobilePhone = cleanedMobilePhone;
                shouldUpdateLead = true;
            }
        }

        if (shouldUpdateLead) {
            update leadToUpdate;
        }

        Id ownerIdToUse = ownerId != null ? ownerId : leadToUpdate.OwnerId;

        if (useExistingContact == true && useExistingAccount == true) {
            Contact existingContactRecord = [
                SELECT Id, AccountId
                FROM Contact
                WHERE Id = :existingContactId
                LIMIT 1
            ];

            if (existingContactRecord.AccountId != existingAccountId) {
                existingAccountId = existingContactRecord.AccountId;
            }
        }

        if (useExistingContact == true && existingContactId != null) {
            syncLeadToExistingContact(leadId, existingContactId, newContactFirstName, newContactLastName);
        }

        if (useExistingAccount == true && existingAccountId != null) {
            syncLeadToExistingAccount(leadId, existingAccountId, newAccountName);
        }

        Opportunity selectedOpportunity;
        if (useExistingOpportunity == true) {
            selectedOpportunity = [
                SELECT Id, AccountId
                FROM Opportunity
                WHERE Id = :existingOpportunityId
                LIMIT 1
            ];

            if (useExistingAccount == true && existingAccountId != selectedOpportunity.AccountId) {
                throw new AuraHandledException('Selected Opportunity must belong to the selected Account.');
            }

            useExistingAccount = true;
            existingAccountId = selectedOpportunity.AccountId;

            syncLeadToExistingOpportunity(leadId, existingOpportunityId);
        }

        if (useExistingContact == true && useExistingOpportunity == true) {
            Contact contactToValidate = [
                SELECT Id, AccountId
                FROM Contact
                WHERE Id = :existingContactId
                LIMIT 1
            ];

            if (contactToValidate.AccountId != existingAccountId) {
                throw new AuraHandledException('Selected Contact must belong to the Opportunity Account.');
            }
        }

        try {
            Database.LeadConvert leadConvert = new Database.LeadConvert();
            leadConvert.setLeadId(leadId);
            leadConvert.setConvertedStatus(convertedStatus);
            leadConvert.setDoNotCreateOpportunity(doNotCreateOpportunity == true);

            leadConvert.setOwnerId(ownerIdToUse);

            if (useExistingAccount == true) {
                leadConvert.setAccountId(existingAccountId);
            }

            if (useExistingContact == true) {
                leadConvert.setContactId(existingContactId);
            }

            if (doNotCreateOpportunity != true && String.isNotBlank(opportunityName)) {
                leadConvert.setOpportunityName(opportunityName.trim());
            }

            Database.LeadConvertResult conversionResult = Database.convertLead(leadConvert);
            if (!conversionResult.isSuccess()) {
                String errorMessage = 'Lead conversion failed.';
                if (!conversionResult.getErrors().isEmpty()) {
                    errorMessage = conversionResult.getErrors()[0].getMessage();
                }
                throw new AuraHandledException(errorMessage);
            }

            Id responseOpportunityId = conversionResult.getOpportunityId();

            if (useExistingOpportunity == true && existingOpportunityId != null) {
                responseOpportunityId = existingOpportunityId;

                if (conversionResult.getContactId() != null) {
                    List<OpportunityContactRole> existingRoles = [
                        SELECT Id
                        FROM OpportunityContactRole
                        WHERE OpportunityId = :existingOpportunityId
                        AND ContactId = :conversionResult.getContactId()
                        LIMIT 1
                    ];

                    if (existingRoles.isEmpty()) {
                        insert new OpportunityContactRole(
                            OpportunityId = existingOpportunityId,
                            ContactId = conversionResult.getContactId(),
                            IsPrimary = false
                        );
                    }
                }
            }

            syncConvertedRecordsFromLead(
                leadId,
                conversionResult,
                useExistingAccount,
                newAccountName,
                useExistingContact,
                newContactFirstName,
                newContactLastName,
                useExistingOpportunity
            );

            return new Map<String, Id>{
                'leadId' => conversionResult.getLeadId(),
                'accountId' => conversionResult.getAccountId(),
                'contactId' => conversionResult.getContactId(),
                'opportunityId' => responseOpportunityId
            };
        } catch (AuraHandledException ex) {
            throw ex;
        } catch (Exception ex) {
            throw new AuraHandledException('Error converting lead: ' + ex.getMessage());
        }
    }

    private static void syncConvertedRecordsFromLead(
        Id leadId,
        Database.LeadConvertResult conversionResult,
        Boolean useExistingAccount,
        String newAccountName,
        Boolean useExistingContact,
        String newContactFirstName,
        String newContactLastName,
        Boolean useExistingOpportunity
    ) {
        if (leadId == null || conversionResult == null) {
            return;
        }

        if (useExistingAccount != true && conversionResult.getAccountId() != null) {
            syncLeadToExistingAccount(leadId, conversionResult.getAccountId(), newAccountName);
        }

        if (useExistingContact != true && conversionResult.getContactId() != null) {
            syncLeadToExistingContact(leadId, conversionResult.getContactId(), newContactFirstName, newContactLastName);
        }

        if (useExistingOpportunity != true && conversionResult.getOpportunityId() != null) {
            syncLeadToExistingOpportunity(leadId, conversionResult.getOpportunityId());
        }
    }

    private static String digitsOnly(String value) {
        if (String.isBlank(value)) {
            return value;
        }

        return value.replaceAll('[^0-9]', '');
    }

    private static Boolean isIndiaCountry(String countryValue) {
        if (String.isBlank(countryValue)) {
            return false;
        }

        String normalizedCountry = countryValue.trim().toLowerCase();
        return normalizedCountry == 'india' || normalizedCountry == 'in';
    }

    private static void syncLeadToExistingAccount(Id leadId, Id accountId, String newAccountName) {
        List<String> commonFields = getCommonLeadAccountFields();
        if (commonFields.isEmpty()) {
            return;
        }

        Map<String, Schema.SObjectField> leadFieldMap = Schema.SObjectType.Lead.fields.getMap();
        Map<String, Schema.SObjectField> accountFieldMap = Schema.SObjectType.Account.fields.getMap();
        Map<String, String> configuredMappings = getLeadToAccountFieldMappings();
        Map<String, String> validMappings = new Map<String, String>();

        for (String leadFieldName : configuredMappings.keySet()) {
            String accountFieldName = configuredMappings.get(leadFieldName);
            if (!leadFieldMap.containsKey(leadFieldName) || !accountFieldMap.containsKey(accountFieldName)) {
                continue;
            }

            Schema.DescribeFieldResult accountDescribe = accountFieldMap.get(accountFieldName).getDescribe();
            Schema.DescribeFieldResult leadDescribe = leadFieldMap.get(leadFieldName).getDescribe();

            if (!accountDescribe.isUpdateable() || accountDescribe.isCalculated() || accountDescribe.isAutoNumber()) {
                continue;
            }

            if (leadDescribe.getType() != accountDescribe.getType()) {
                continue;
            }

            validMappings.put(leadFieldName, accountFieldName);
        }

        Set<String> leadFieldsToQuery = new Set<String>(commonFields);
        leadFieldsToQuery.addAll(validMappings.keySet());

        Set<String> accountFieldsToQuery = new Set<String>(commonFields);
        accountFieldsToQuery.addAll(validMappings.values());

        List<String> leadQueryFields = new List<String>(leadFieldsToQuery);
        leadQueryFields.sort();

        List<String> accountQueryFields = new List<String>(accountFieldsToQuery);
        accountQueryFields.sort();

        String leadQuery = 'SELECT ' + String.join(leadQueryFields, ',') + ' FROM Lead WHERE Id = :leadId LIMIT 1';
        String accountQuery = 'SELECT ' + String.join(accountQueryFields, ',') + ' FROM Account WHERE Id = :accountId LIMIT 1';

        Lead leadForMapping = Database.query(leadQuery);
        Account accountToUpdate = Database.query(accountQuery);

        Boolean shouldUpdateAccount = false;
        for (String fieldName : commonFields) {
            if (fieldName == 'Id' || fieldName == 'Name') {
                continue;
            }

            Object leadValue = leadForMapping.get(fieldName);
            if (leadValue != null) {
                accountToUpdate.put(fieldName, leadValue);
                shouldUpdateAccount = true;
            }
        }

        for (String leadFieldName : validMappings.keySet()) {
            String accountFieldName = validMappings.get(leadFieldName);
            Object leadValue = leadForMapping.get(leadFieldName);
            if (leadValue == null) {
                continue;
            }

            accountToUpdate.put(accountFieldName, leadValue);
            shouldUpdateAccount = true;
        }

        if (String.isNotBlank(newAccountName)) {
            String normalizedName = newAccountName.trim();
            if (accountToUpdate.Name != normalizedName) {
                accountToUpdate.Name = normalizedName;
                shouldUpdateAccount = true;
            }
        }

        if (shouldUpdateAccount) {
            update accountToUpdate;
        }
    }

    private static Map<String, String> getLeadToAccountFieldMappings() {
        return new Map<String, String>{
            'Street' => 'BillingStreet',
            'City' => 'BillingCity',
            'State' => 'BillingState',
            'PostalCode' => 'BillingPostalCode',
            'Country' => 'BillingCountry'
        };
    }

    private static List<String> getCommonLeadAccountFields() {
        Map<String, Schema.SObjectField> leadFields = Schema.SObjectType.Lead.fields.getMap();
        Map<String, Schema.SObjectField> accountFields = Schema.SObjectType.Account.fields.getMap();

        List<String> commonFields = new List<String>{ 'Id', 'Name' };

        for (String fieldName : accountFields.keySet()) {
            if (fieldName == 'Id' || fieldName == 'Name') {
                continue;
            }

            if (!leadFields.containsKey(fieldName)) {
                continue;
            }

            Schema.DescribeFieldResult accountDescribe = accountFields.get(fieldName).getDescribe();
            Schema.DescribeFieldResult leadDescribe = leadFields.get(fieldName).getDescribe();

            if (!accountDescribe.isUpdateable() || accountDescribe.isCalculated() || accountDescribe.isAutoNumber()) {
                continue;
            }

            if (accountDescribe.getType() == Schema.DisplayType.Address ||
                accountDescribe.getType() == Schema.DisplayType.Location ||
                accountDescribe.getType() == Schema.DisplayType.Base64) {
                continue;
            }

            if (leadDescribe.getType() != accountDescribe.getType()) {
                continue;
            }

            commonFields.add(fieldName);
        }

        commonFields.sort();
        return commonFields;
    }

    private static void syncLeadToExistingContact(Id leadId, Id contactId, String newContactFirstName, String newContactLastName) {
        List<String> commonFields = getCommonLeadContactFields();
        if (commonFields.isEmpty()) {
            return;
        }

        Map<String, Schema.SObjectField> leadFieldMap = Schema.SObjectType.Lead.fields.getMap();
        Map<String, Schema.SObjectField> contactFieldMap = Schema.SObjectType.Contact.fields.getMap();
        Map<String, String> configuredMappings = getLeadToContactFieldMappings();
        Map<String, String> validMappings = new Map<String, String>();

        for (String leadFieldName : configuredMappings.keySet()) {
            String contactFieldName = configuredMappings.get(leadFieldName);
            if (!leadFieldMap.containsKey(leadFieldName) || !contactFieldMap.containsKey(contactFieldName)) {
                continue;
            }

            Schema.DescribeFieldResult contactDescribe = contactFieldMap.get(contactFieldName).getDescribe();
            Schema.DescribeFieldResult leadDescribe = leadFieldMap.get(leadFieldName).getDescribe();

            if (!contactDescribe.isUpdateable() || contactDescribe.isCalculated() || contactDescribe.isAutoNumber()) {
                continue;
            }

            if (leadDescribe.getType() != contactDescribe.getType()) {
                continue;
            }

            validMappings.put(leadFieldName, contactFieldName);
        }

        Set<String> leadFieldsToQuery = new Set<String>(commonFields);
        leadFieldsToQuery.addAll(validMappings.keySet());

        Set<String> contactFieldsToQuery = new Set<String>(commonFields);
        contactFieldsToQuery.addAll(validMappings.values());

        List<String> leadQueryFields = new List<String>(leadFieldsToQuery);
        leadQueryFields.sort();

        List<String> contactQueryFields = new List<String>(contactFieldsToQuery);
        contactQueryFields.sort();

        String leadQuery = 'SELECT ' + String.join(leadQueryFields, ',') + ' FROM Lead WHERE Id = :leadId LIMIT 1';
        String contactQuery = 'SELECT ' + String.join(contactQueryFields, ',') + ' FROM Contact WHERE Id = :contactId LIMIT 1';

        Lead leadForMapping = Database.query(leadQuery);
        Contact contactToUpdate = Database.query(contactQuery);

        Boolean shouldUpdateContact = false;

        for (String fieldName : commonFields) {
            if (fieldName == 'Id') {
                continue;
            }

            Object leadValue = leadForMapping.get(fieldName);
            if (leadValue == null) {
                continue;
            }

            Schema.DescribeFieldResult contactFieldDescribe = contactFieldMap.get(fieldName).getDescribe();
            if (contactFieldDescribe.getType() == Schema.DisplayType.Phone) {
                String cleanedPhone = digitsOnly(String.valueOf(leadValue));
                if (String.isBlank(cleanedPhone)) {
                    continue;
                }
                contactToUpdate.put(fieldName, cleanedPhone);
            } else {
                contactToUpdate.put(fieldName, leadValue);
            }

            shouldUpdateContact = true;
        }

        for (String leadFieldName : validMappings.keySet()) {
            String contactFieldName = validMappings.get(leadFieldName);
            Object leadValue = leadForMapping.get(leadFieldName);
            if (leadValue == null) {
                continue;
            }

            Schema.DescribeFieldResult contactFieldDescribe = contactFieldMap.get(contactFieldName).getDescribe();
            if (contactFieldDescribe.getType() == Schema.DisplayType.Phone) {
                String cleanedPhone = digitsOnly(String.valueOf(leadValue));
                if (String.isBlank(cleanedPhone)) {
                    continue;
                }
                contactToUpdate.put(contactFieldName, cleanedPhone);
            } else {
                contactToUpdate.put(contactFieldName, leadValue);
            }

            shouldUpdateContact = true;
        }

        if (String.isNotBlank(newContactFirstName)) {
            String normalizedFirstName = newContactFirstName.trim();
            if (contactToUpdate.FirstName != normalizedFirstName) {
                contactToUpdate.FirstName = normalizedFirstName;
                shouldUpdateContact = true;
            }
        }

        if (String.isNotBlank(newContactLastName)) {
            String normalizedLastName = newContactLastName.trim();
            if (contactToUpdate.LastName != normalizedLastName) {
                contactToUpdate.LastName = normalizedLastName;
                shouldUpdateContact = true;
            }
        }

        if (shouldUpdateContact) {
            update contactToUpdate;
        }
    }

    private static Map<String, String> getLeadToContactFieldMappings() {
        return new Map<String, String>{
            'Street' => 'MailingStreet',
            'City' => 'MailingCity',
            'State' => 'MailingState',
            'PostalCode' => 'MailingPostalCode',
            'Country' => 'MailingCountry'
        };
    }

    private static List<String> getCommonLeadContactFields() {
        Map<String, Schema.SObjectField> leadFields = Schema.SObjectType.Lead.fields.getMap();
        Map<String, Schema.SObjectField> contactFields = Schema.SObjectType.Contact.fields.getMap();

        List<String> commonFields = new List<String>{ 'Id' };

        for (String fieldName : contactFields.keySet()) {
            if (fieldName == 'Id') {
                continue;
            }

            if (!leadFields.containsKey(fieldName)) {
                continue;
            }

            Schema.DescribeFieldResult contactDescribe = contactFields.get(fieldName).getDescribe();
            Schema.DescribeFieldResult leadDescribe = leadFields.get(fieldName).getDescribe();

            if (!contactDescribe.isUpdateable() || contactDescribe.isCalculated() || contactDescribe.isAutoNumber()) {
                continue;
            }

            if (contactDescribe.getType() == Schema.DisplayType.Address ||
                contactDescribe.getType() == Schema.DisplayType.Location ||
                contactDescribe.getType() == Schema.DisplayType.Base64) {
                continue;
            }

            if (leadDescribe.getType() != contactDescribe.getType()) {
                continue;
            }

            commonFields.add(fieldName);
        }

        commonFields.sort();
        return commonFields;
    }

    private static void syncLeadToExistingOpportunity(Id leadId, Id opportunityId) {
        List<String> fieldsToMap = getMappedLeadOpportunityFields();
        if (fieldsToMap.isEmpty()) {
            return;
        }

        Map<String, Schema.SObjectField> leadFieldMap = Schema.SObjectType.Lead.fields.getMap();
        Map<String, Schema.SObjectField> opportunityFieldMap = Schema.SObjectType.Opportunity.fields.getMap();
        Map<String, String> configuredMappings = getLeadToOpportunityFieldMappings();
        Map<String, String> validMappings = new Map<String, String>();

        for (String leadFieldName : configuredMappings.keySet()) {
            String opportunityFieldName = configuredMappings.get(leadFieldName);
            if (!leadFieldMap.containsKey(leadFieldName) || !opportunityFieldMap.containsKey(opportunityFieldName)) {
                continue;
            }

            Schema.DescribeFieldResult leadDescribe = leadFieldMap.get(leadFieldName).getDescribe();
            Schema.DescribeFieldResult opportunityDescribe = opportunityFieldMap.get(opportunityFieldName).getDescribe();

            if (!opportunityDescribe.isUpdateable() || opportunityDescribe.isCalculated() || opportunityDescribe.isAutoNumber()) {
                continue;
            }

            if (!areCompatibleMappedFieldTypes(leadDescribe.getType(), opportunityDescribe.getType())) {
                continue;
            }

            validMappings.put(leadFieldName, opportunityFieldName);
        }

        Set<String> leadFieldsToQuery = new Set<String>(fieldsToMap);
        leadFieldsToQuery.addAll(validMappings.keySet());

        Set<String> opportunityFieldsToQuery = new Set<String>(fieldsToMap);
        opportunityFieldsToQuery.addAll(validMappings.values());

        List<String> leadQueryFields = new List<String>(leadFieldsToQuery);
        leadQueryFields.sort();

        List<String> opportunityQueryFields = new List<String>(opportunityFieldsToQuery);
        opportunityQueryFields.sort();

        String leadQuery = 'SELECT ' + String.join(leadQueryFields, ',') + ' FROM Lead WHERE Id = :leadId LIMIT 1';
        String oppQuery = 'SELECT ' + String.join(opportunityQueryFields, ',') + ' FROM Opportunity WHERE Id = :opportunityId LIMIT 1';

        Lead leadForMapping = Database.query(leadQuery);
        Opportunity opportunityToUpdate = Database.query(oppQuery);

        Boolean shouldUpdateOpportunity = false;

        for (String fieldName : fieldsToMap) {
            if (fieldName == 'Id') {
                continue;
            }

            Object leadValue = leadForMapping.get(fieldName);
            // Only assign if value is not null or (if String) not blank
            if (leadValue == null || (leadValue instanceof String && String.isBlank((String)leadValue))) {
                continue;
            }

            Schema.DescribeFieldResult opportunityFieldDescribe = opportunityFieldMap.get(fieldName).getDescribe();
            if (opportunityFieldDescribe.getType() == Schema.DisplayType.Phone) {
                String cleanedPhone = digitsOnly(String.valueOf(leadValue));
                if (String.isBlank(cleanedPhone)) {
                    continue;
                }
                opportunityToUpdate.put(fieldName, cleanedPhone);
            } else {
                opportunityToUpdate.put(fieldName, leadValue);
            }

            shouldUpdateOpportunity = true;
        }

        for (String leadFieldName : validMappings.keySet()) {
            String opportunityFieldName = validMappings.get(leadFieldName);
            Object leadValue = leadForMapping.get(leadFieldName);
            // Only assign if value is not null or (if String) not blank
            if (leadValue == null || (leadValue instanceof String && String.isBlank((String)leadValue))) {
                continue;
            }
                // Fix: For Country__c, map label to API value
                if (opportunityFieldName == 'Country__c') {
                    String apiValue = getCountryApiValue(String.valueOf(leadValue));
                    if (String.isNotBlank(apiValue)) {
                        opportunityToUpdate.put(opportunityFieldName, apiValue);
                        shouldUpdateOpportunity = true;
                    }
                } else {
                    opportunityToUpdate.put(opportunityFieldName, leadValue);
                    shouldUpdateOpportunity = true;
                }
        }

        if (shouldUpdateOpportunity) {
            update opportunityToUpdate;
        }
    }

    // Helper: Map country label to API value
    private static String getCountryApiValue(String labelOrApiValue) {
        if (String.isBlank(labelOrApiValue)) {
            return null;
        }
        system.debug('labelOrApiValue>>'+labelOrApiValue);
        String normalized = labelOrApiValue.trim().toLowerCase();
        // India special case
        if (normalized == 'india' || normalized == 'in') {
            return 'IN';
        }
        // Validate against actual picklist values
        Set<String> validApiValues = new Set<String>();
        Map<String, String> labelToApiMap = new Map<String, String>();
        Schema.DescribeFieldResult fieldResult = Opportunity.Country__c.getDescribe();
        for (Schema.PicklistEntry entry : fieldResult.getPicklistValues()) {
            if (entry.isActive()) {
                validApiValues.add(entry.getValue().toLowerCase());
                labelToApiMap.put(entry.getLabel().toLowerCase(), entry.getValue());
            }
        }
        // Check if the value matches an API value
        if (validApiValues.contains(normalized)) {
            // Return properly cased API value
            for (Schema.PicklistEntry entry : fieldResult.getPicklistValues()) {
                if (entry.getValue().toLowerCase() == normalized) {
                    return entry.getValue();
                }
            }
        }
        // Check if the value matches a label
        if (labelToApiMap.containsKey(normalized)) {
            return labelToApiMap.get(normalized);
        }
        // Invalid value - return null to prevent error
        return null;
    }

    private static Map<String, String> getLeadToOpportunityFieldMappings() {
        return new Map<String, String>{
            'Street' => 'AddressLine1__c',
            'City' => 'Place__c',
            // 'State' => 'State__c', // (remains commented if not needed)
            'PostalCode' => 'Pin_Code__c',
            'Country' => 'Country__c'
        };
    }

    private static Boolean areCompatibleMappedFieldTypes(
        Schema.DisplayType sourceType,
        Schema.DisplayType targetType
    ) {
        if (sourceType == targetType) {
            return true;
        }

        Set<Schema.DisplayType> textLikeTypes = new Set<Schema.DisplayType>{
            Schema.DisplayType.String,
            Schema.DisplayType.TextArea,
            Schema.DisplayType.Phone,
            Schema.DisplayType.Email,
            Schema.DisplayType.Url,
            Schema.DisplayType.EncryptedString,
            Schema.DisplayType.Picklist,
            Schema.DisplayType.MultiPicklist
        };

        return textLikeTypes.contains(sourceType) && textLikeTypes.contains(targetType);
    }

    private static List<String> getMappedLeadOpportunityFields() {
        Map<String, Schema.SObjectField> leadFields = Schema.SObjectType.Lead.fields.getMap();
        Map<String, Schema.SObjectField> opportunityFields = Schema.SObjectType.Opportunity.fields.getMap();

        Set<String> mappedFieldCandidates = new Set<String>{
            'AddressLine1__c',
            'AddressLine2__c',
            'AddressLine3__c',
            'Branch_Location__c',
            'Corporation__c',
            'Country__c',
            'Description',
            'District__c',
            'Engagement_Type__c',
            'GST_Number__c',
            'GST_Type__c',
            'House_Name_No__c',
            'Municipality__c',
            'Panchayath__c',
            'Pin_Code__c',
            'Place__c',
            'Product_Category__c',
            'Referral_Name__c',
            'State__c',
            'Sub_Source__c',
            'Village__c'
        };

        List<String> fieldsToMap = new List<String>{ 'Id' };

        for (String fieldName : mappedFieldCandidates) {
            if (!leadFields.containsKey(fieldName) || !opportunityFields.containsKey(fieldName)) {
                continue;
            }

            Schema.DescribeFieldResult leadDescribe = leadFields.get(fieldName).getDescribe();
            Schema.DescribeFieldResult opportunityDescribe = opportunityFields.get(fieldName).getDescribe();

            if (!opportunityDescribe.isUpdateable() || opportunityDescribe.isCalculated() || opportunityDescribe.isAutoNumber()) {
                continue;
            }

            if (leadDescribe.getType() != opportunityDescribe.getType()) {
                continue;
            }

            fieldsToMap.add(fieldName);
        }

        fieldsToMap.sort();
        return fieldsToMap;
    }
}