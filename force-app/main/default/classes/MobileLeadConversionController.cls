public with sharing class MobileLeadConversionController {
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getConversionContext(Id leadId) {
        if (leadId == null) {
            throw new AuraHandledException('Lead Id is required.');
        }

        Lead sourceLead = [
            SELECT Id, FirstName, LastName, Company, OwnerId
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
        String opportunityName
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
            throw new AuraHandledException('Please select an existing account.');
        }

        if (useExistingContact == true && existingContactId == null) {
            throw new AuraHandledException('Please select an existing contact.');
        }

        if ((doNotCreateOpportunity == false || doNotCreateOpportunity == null) && String.isBlank(opportunityName)) {
            throw new AuraHandledException('Opportunity name is required when creating an Opportunity.');
        }

        if (useExistingAccount != true && String.isBlank(newAccountName)) {
            throw new AuraHandledException('Account Name is required for new Account conversion.');
        }

        if (useExistingContact != true && String.isBlank(newContactLastName)) {
            throw new AuraHandledException('Last Name is required for new Contact conversion.');
        }

        Lead leadToUpdate = new Lead(Id = leadId);
        Boolean shouldUpdateLead = false;

        if (useExistingAccount != true && String.isNotBlank(newAccountName)) {
            leadToUpdate.Company = newAccountName.trim();
            shouldUpdateLead = true;
        }

        if (useExistingContact != true) {
            if (String.isNotBlank(newContactFirstName)) {
                leadToUpdate.FirstName = newContactFirstName.trim();
                shouldUpdateLead = true;
            }
            if (String.isNotBlank(newContactLastName)) {
                leadToUpdate.LastName = newContactLastName.trim();
                shouldUpdateLead = true;
            }
        }

        if (shouldUpdateLead) {
            update leadToUpdate;
        }

        try {
            Database.LeadConvert leadConvert = new Database.LeadConvert();
            leadConvert.setLeadId(leadId);
            leadConvert.setConvertedStatus(convertedStatus);
            leadConvert.setDoNotCreateOpportunity(doNotCreateOpportunity == true);

            if (ownerId != null) {
                leadConvert.setOwnerId(ownerId);
            }

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

            return new Map<String, Id>{
                'leadId' => conversionResult.getLeadId(),
                'accountId' => conversionResult.getAccountId(),
                'contactId' => conversionResult.getContactId(),
                'opportunityId' => conversionResult.getOpportunityId()
            };
        } catch (AuraHandledException ex) {
            throw ex;
        } catch (Exception ex) {
            throw new AuraHandledException('Error converting lead: ' + ex.getMessage());
        }
    }
}