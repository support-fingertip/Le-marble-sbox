public class LeadTriggerHandler {

    // BEFORE INSERT — MAP DIGITAL LEADS & AUTO-FILL FIELDS
    public static void beforeInsert(List<Lead> leadList) {

        //  MAP DIGITAL CAMPAIGN ---
        Set<String> campSet = new Set<String>();
        for (Lead ld : leadList) {
            if (ld.Campaign_ID__c != null) {
                campSet.add(ld.Campaign_ID__c);
            }
        }
        if(!campSet.isEmpty()){

            Map<String, String> CamMap = new Map<String, String>();
            for (Campaign cm : [
                SELECT Id, Name FROM Campaign WHERE Name IN :campSet
            ]) {
                CamMap.put(cm.Name, cm.Id);
            }

            for (Lead ld : leadList) {
                if (ld.Campaign_ID__c != null && CamMap.containsKey(ld.Campaign_ID__c)) {
                    ld.Campaign__c = CamMap.get(ld.Campaign_ID__c);
                }
            }
        }

        //  AUTO-FILL COMPANY & COUNTRY ---
        for (Lead ls : leadList) {

            // Auto-fill Company 
            if (ls.Company == null) {
                String fullName = '';
                if (String.isNotBlank(ls.FirstName))  fullName += ls.FirstName;
                if (String.isNotBlank(ls.LastName))   fullName += (fullName != '' ? ' ' : '') + ls.LastName;
                ls.Company = fullName;
            }

            // Auto-fill Country 
            if (ls.Country == null || ls.Country == '') {
                ls.Country = 'India';
            }
        }


        // SALES EXECUTIVE OWNER LOGIC (BEFORE INSERT)
       
        Database.DMLOptions dml = new Database.DMLOptions();

        for (Lead ld : leadList) {

            if (ld.Sales_Executive__c != null) {
                // Assign to sales executive
                ld.OwnerId = ld.Sales_Executive__c;

                // Disable assignment rules
                dml.assignmentRuleHeader.useDefaultRule = false;
                ld.setOptions(dml);
            }
            else {
                // Enable assignment rules
                if(ld.Curent_User_Profile_Name__c == 'System Administrator' ){
                     dml.assignmentRuleHeader.useDefaultRule = true;
                }else{
                    dml.assignmentRuleHeader.useDefaultRule = false; }
                ld.setOptions(dml);
            }
        }
        checkDuplicateLead(leadList, null);

    }




    // BEFORE UPDATE — CLEAR UNQUALIFIED REASON + AUTO-FILL FIELDS
    public static void beforeUpdate(List<Lead> leadList, Map<Id, Lead> oldMap) {

        for (Lead ld : leadList) {
            Lead oldLead = oldMap.get(ld.Id);

            // Clear Unqualified Reason when status changes back
            if (ld.Status != 'Unqualified' && oldLead.Status == 'Unqualified') {
                ld.Unqualified_Reason__c = '';
            }
        }

        // AUTO-FILL COMPANY & COUNTRY 
        for (Lead ls : leadList) {

            // Auto-fill Company
            if (ls.Company == null) {
                String fullName = '';
                if (String.isNotBlank(ls.FirstName))  fullName += ls.FirstName;
                if (String.isNotBlank(ls.LastName))   fullName += (fullName != '' ? ' ' : '') + ls.LastName;
                ls.Company = fullName;
            }

            // Auto-fill Country
            if (ls.Country == null || ls.Country == '') {
                ls.Country = 'India';
            }
        }


        // SALES EXECUTIVE OWNER LOGIC (BEFORE UPDATE)
       
        Database.DMLOptions dml = new Database.DMLOptions();

        for (Lead ld : leadList) {

            if (ld.Sales_Executive__c != null) {
                // Assign to Sales Executive
                ld.OwnerId = ld.Sales_Executive__c;

                // Disable assignment rules
                dml.assignmentRuleHeader.useDefaultRule = false;
                ld.setOptions(dml);
            }
            else {
                // Enable assignment rules
                dml.assignmentRuleHeader.useDefaultRule = true;
                ld.setOptions(dml);
            }
        }
        checkDuplicateLead(leadList, oldMap);

    }



    // AFTER UPDATE — ALL NOTIFICATIONS
    public static void afterUpdate(List<Lead> leadList, Map<Id, Lead> oldMap) {

        // Notification Types
        CustomNotificationType unqualifiedType =
            [SELECT Id FROM CustomNotificationType WHERE DeveloperName = 'Lead_unqualified_notification' LIMIT 1];

        CustomNotificationType assignType =
            [SELECT Id FROM CustomNotificationType WHERE DeveloperName = 'Lead_assign_notification' LIMIT 1];

        CustomNotificationType convertedType =
            [SELECT Id FROM CustomNotificationType WHERE DeveloperName = 'Lead_converted_notification' LIMIT 1];

        // Admin recipient
        Id adminId = [
            SELECT Id FROM User WHERE Profile.Name = 'System Administrator' AND IsActive = true LIMIT 1
        ].Id;


        for (Lead newLead : leadList) {

            Lead oldLead = oldMap.get(newLead.Id);

            // Build Full Name
            String sal = (newLead.Salutation != null) ? newLead.Salutation + '. ' : '';
            String fname = (newLead.FirstName != null) ? newLead.FirstName + ' ' : '';
            String lname = (newLead.LastName != null) ? newLead.LastName : '';
            String fullName = sal + fname + lname;
            String company = (newLead.Company != null) ? newLead.Company : '';

            //  LEAD UNQUALIFIED NOTIFICATION
            if (newLead.Status == 'Unqualified' && oldLead.Status != 'Unqualified') {
                try {
                    Messaging.CustomNotification noti = new Messaging.CustomNotification();
                    noti.setTitle('Lead Marked as Unqualified');
                    noti.setBody('Lead "' + fullName + '" (' + company + ') has been marked as Unqualified.');
                    noti.setNotificationTypeId(unqualifiedType.Id);
                    noti.setTargetId(newLead.Id);
                    noti.send(new Set<String>{ adminId });
                } catch (Exception e) {
                    System.debug('Error sending unqualified notification: ' + e.getMessage());
                }
            }

            // LEAD ASSIGNED NOTIFICATION
            if (newLead.OwnerId != oldLead.OwnerId) {
                try {
                    Messaging.CustomNotification noti = new Messaging.CustomNotification();
                    noti.setTitle('New Lead Assigned');
                    noti.setBody('A new lead "' + fullName + '" (' + company + ') has been assigned to you.');
                    noti.setNotificationTypeId(assignType.Id);
                    noti.setTargetId(newLead.Id);
                    noti.send(new Set<String>{ newLead.OwnerId });
                } catch (Exception e) {
                    System.debug('Error sending assignment notification: ' + e.getMessage());
                }
            }

            // LEAD CONVERTED NOTIFICATION
            if (newLead.IsConverted == true && oldLead.IsConverted == false) {
                try {
                    Messaging.CustomNotification noti = new Messaging.CustomNotification();
                    noti.setTitle('Lead Converted');
                    noti.setBody('Lead "' + fullName + '" (' + company + ') has been successfully converted.');
                    noti.setNotificationTypeId(convertedType.Id);
                    noti.setTargetId(newLead.Id);
                    noti.send(new Set<String>{ adminId });
                } catch (Exception e) {
                    System.debug('Error sending conversion notification: ' + e.getMessage());
                }
            }
        }
    }



    // AFTER INSERT — SEND THANK YOU EMAIL
    public static void afterInsert(List<Lead> leadList) {
        List<Id> leadIds = new List<Id>();

        for (Lead ld : leadList) {
            if (ld.Email != null) {
                leadIds.add(ld.Id);
            }
        }

        if (!leadIds.isEmpty()) {
            LeadThankYouEmailHelper.sendThankYouEmail(leadIds);
        }
    }
    
// DUPLICATION CHECK (EMAIL + SECONDARY EMAIL + PHONE + SEC PHONE)

   private static void checkDuplicateLead(List<Lead> newList, Map<Id, Lead> oldMap) {

    Set<String> emails = new Set<String>();
    Set<String> secEmails = new Set<String>();
    Set<String> phones = new Set<String>();
    Set<String> secPhones = new Set<String>();

    // Collect values from new records
    for (Lead l : newList) {

        if (!String.isBlank(l.Email))
            emails.add(l.Email.toLowerCase().trim());

        if (!String.isBlank(l.Secondary_Email__c))
            secEmails.add(l.Secondary_Email__c.toLowerCase().trim());

        if (!String.isBlank(l.Phone))
            phones.add(normalizePhone(l.Phone));

        if (!String.isBlank(l.Secondary_Phone__c))
            secPhones.add(normalizePhone(l.Secondary_Phone__c));
    }

    // Query matching leads
    List<Lead> existing = [
        SELECT Id, Name, Email, Secondary_Email__c, Phone, Secondary_Phone__c
        FROM Lead
        WHERE 
            Email IN :emails OR
            Secondary_Email__c IN :emails OR
            Email IN :secEmails OR
            Secondary_Email__c IN :secEmails OR
            Phone IN :phones OR
            Secondary_Phone__c IN :phones OR
            Phone IN :secPhones OR
            Secondary_Phone__c IN :secPhones
    ];

    Map<String, Lead> emailMap = new Map<String, Lead>();
    Map<String, Lead> secEmailMap = new Map<String, Lead>();
    Map<String, Lead> phoneMap = new Map<String, Lead>();
    Map<String, Lead> secPhoneMap = new Map<String, Lead>();

    for (Lead e : existing) {

        if (!String.isBlank(e.Email))
            emailMap.put(e.Email.trim().toLowerCase(), e);

        if (!String.isBlank(e.Secondary_Email__c))
            secEmailMap.put(e.Secondary_Email__c.trim().toLowerCase(), e);

        if (!String.isBlank(e.Phone))
            phoneMap.put(normalizePhone(e.Phone), e);

        if (!String.isBlank(e.Secondary_Phone__c))
            secPhoneMap.put(normalizePhone(e.Secondary_Phone__c), e);
    }


    // Validate duplicates + phone length
    for (Lead l : newList) {

        String em  = String.isBlank(l.Email) ? null : l.Email.toLowerCase().trim();
        String sem = String.isBlank(l.Secondary_Email__c) ? null : l.Secondary_Email__c.toLowerCase().trim();
        String ph  = String.isBlank(l.Phone) ? null : normalizePhone(l.Phone);
        String sph = String.isBlank(l.Secondary_Phone__c) ? null : normalizePhone(l.Secondary_Phone__c);

       
        if (l.Country__c != null && l.Country__c.trim().toLowerCase() == 'india')
 {

            // PRIMARY PHONE VALIDATION
            if (ph != null && ph.length() != 10) {
                l.addError('For India, Phone number must be exactly 10 digits.');
            }

            // SECONDARY PHONE VALIDATION
            if (sph != null && sph.length() != 10) {
                l.addError('For India, Secondary Phone must be exactly 10 digits.');
            }
        }

        // EMAIL CHECK
        if (em != null) {
            Lead dup = null;

            if (emailMap.containsKey(em))
                dup = emailMap.get(em);
            else if (secEmailMap.containsKey(em))
                dup = secEmailMap.get(em);

            if (dup != null && dup.Id != l.Id)
                l.addError('Duplicate found — this Email already exists in another Lead (Email): ' + l.Email);
        }

        // SECONDARY EMAIL CHECK
        if (sem != null) {
            Lead dup = null;

            if (emailMap.containsKey(sem))
                dup = emailMap.get(sem);
            else if (secEmailMap.containsKey(sem))
                dup = secEmailMap.get(sem);

            if (dup != null && dup.Id != l.Id)
                l.addError('Duplicate found — this Secondary Email already exists in another Lead (Secondary Email): ' + l.Secondary_Email__c);
        }

        // PHONE CHECK
        if (ph != null) {
            Lead dup = phoneMap.get(ph);
            if (dup == null) dup = secPhoneMap.get(ph);

            if (dup != null && dup.Id != l.Id)
                l.addError('Duplicate found — this Phone already exists in another Lead (Phone): ' + l.Phone);
        }

        // SECONDARY PHONE CHECK
        if (sph != null) {
            Lead dup = phoneMap.get(sph);
            if (dup == null) dup = secPhoneMap.get(sph);

            if (dup != null && dup.Id != l.Id)
                l.addError('Duplicate found — this Secondary Phone already exists in another Lead (Secondary Phone): ' + l.Secondary_Phone__c);
        }
    }
}


// Helper to clean phone numbers
  private static String normalizePhone(String p) {
    return p == null ? null : p.replaceAll('[^0-9]', '');
}

}