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
            
            // Auto-fill Company (Standard required field)
            // Auto-fill Company ONLY for B2C
            if (ls.Customer_Type__c != 'B2B') {
                String fullName = '';
                if (String.isNotBlank(ls.FirstName)) fullName += ls.FirstName;
                if (String.isNotBlank(ls.LastName))  fullName += (fullName != '' ? ' ' : '') + ls.LastName;
                
                ls.Company = fullName;
            }
            
            // Auto-fill Country 
            if (ls.Country == null || ls.Country == '') {
                ls.Country = 'India';
            }
            
            // Auto-fill Country Code
            if ((ls.Country_Code__c == null || ls.Country_Code__c == '')
                && ls.Country != null
                && ls.Country.toLowerCase() == 'india') {
                    ls.Country_Code__c = '+91';
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
        
        
        // AUTO-FILL COMPANY, COUNTRY & COUNTRY CODE ---
        for (Lead ls : leadList) {
            
             Lead oldLead = oldMap.get(ls.Id);
            
            // Clear Unqualified Reason when status changes back
            if (ls.Status != 'Unqualified' && oldLead.Status == 'Unqualified') {
                ls.Unqualified_Reason__c = '';
            }
            
            if (ls.Customer_Interested__c == true && oldLead.Customer_Interested__c ==false) {
                ls.Status = 'Qualified';
            }
            
            // Auto-fill Company ONLY for B2C
            if (ls.Customer_Type__c != 'B2B') {
                String fullName = '';
                if (String.isNotBlank(ls.FirstName)) fullName += ls.FirstName;
                if (String.isNotBlank(ls.LastName))  fullName += (fullName != '' ? ' ' : '') + ls.LastName;
                
                ls.Company = fullName;
            }
            
            // Auto-fill Country 
            if (ls.Country == null || ls.Country == '') {
                ls.Country = 'India';
            }
            
            // Auto-fill Country Code when India, clear when country is not India
            if (ls.Country != null && (ls.Country.equalsIgnoreCase('India') || ls.Country=='In')) {
                if (String.isBlank(ls.Country_Code__c)) {
                    ls.Country_Code__c = '+91';
                }
            } 
            else if(ls.Country_Code__c == '+91'){
                ls.Country_Code__c =null;
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
    
    
    
    public static void afterUpdate(List<Lead> leadList, Map<Id, Lead> oldMap) {
        
        Set<Id> ownerIds = new Set<Id>();
        List<Lead> unLeads = new List<Lead>();
        
        Set<Id> accountIds = new Set<Id>();
        Map<Id, String> leadEmailMap = new Map<Id, String>();
        
          for (Lead newLead : leadList) {
               Lead oldLead = oldMap.get(newLead.Id);
            if (oldLead == null) continue;

           if (newLead.Status == 'Unqualified' && oldLead.Status != 'Unqualified') {
                unLeads.add(newLead);
                ownerIds.add(newLead.OwnerId);
            }
               
          }

 
        Map<Id, User> ownerMap = new Map<Id, User>( [SELECT Id, ManagerId FROM User WHERE Id IN :ownerIds AND ManagerId != null] );
        
        // Notification Types (use EXACT developer names from Setup)
        CustomNotificationType unqualifiedType =
            [SELECT Id FROM CustomNotificationType WHERE DeveloperName = 'Lead_Unqualified_Notification' LIMIT 1];
        
        CustomNotificationType assignType =
            [SELECT Id FROM CustomNotificationType WHERE DeveloperName = 'Lead_Assigned_Notification' LIMIT 1];
        
        CustomNotificationType convertedType =
            [SELECT Id FROM CustomNotificationType WHERE DeveloperName = 'Lead_Converted_Notification' LIMIT 1];
        
        for (Lead newLead : leadList) {
            Lead oldLead = oldMap.get(newLead.Id);
            if (oldLead == null) continue;
            
            
            if (newLead.IsConverted == true && oldLead.IsConverted == false && newLead.Email != null) {
                accountIds.add(newLead.ConvertedAccountId);
                leadEmailMap.put(newLead.ConvertedAccountId, newLead.Email); 
            }
            
            String fullName = '';
            if (String.isNotBlank(newLead.Salutation)) fullName += newLead.Salutation;
             if (String.isNotBlank(newLead.FirstName))  fullName += (fullName != '' ? ' ' : '') + newLead.FirstName;
            if (String.isNotBlank(newLead.LastName))  fullName += (fullName != '' ? ' ' : '') + newLead.LastName;
            
            // Build Full Name
          /*  String sal = (newLead.Salutation != null) ? newLead.Salutation + '. ' : '';
            String fname = (newLead.FirstName != null) ? newLead.FirstName + ' ' : '';
            String lname = (newLead.LastName != null) ? newLead.LastName : '';
            String fullName = sal + fname + lname;*/
            String company = (newLead.Company != null) ? newLead.Company : '';
            
            // LEAD UNQUALIFIED NOTIFICATION (to Admin/Manager as per BRD)
            if (newLead.Status == 'Unqualified' && oldLead.Status != 'Unqualified') {
                 System.debug(' sending unqualified notification: ');
                try {
                    Set<String> managerIds = new Set<String>();
                    managerIds.add(ownerMap.get(newLead.OwnerId).ManagerId);
                    managerIds.add(newLead.OwnerId);
                     System.debug('managerIds )'+managerIds);
                    Messaging.CustomNotification noti = new Messaging.CustomNotification();
                    noti.setTitle('Lead Marked as Unqualified');
                    noti.setBody('Lead "' + fullName + '" (' + company + ') has been marked as Unqualified.');
                    noti.setNotificationTypeId(unqualifiedType.Id);
                    noti.setTargetId(newLead.Id);
                    
                    // Example: send to Owner (change to Manager if BRD)
                    noti.send(managerIds);
                    
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
                    noti.send(new Set<String>{ String.valueOf(newLead.OwnerId) });
                    
                } catch (Exception e) {
                    System.debug('Error sending assignment notification: ' + e.getMessage());
                }
            }
            
            //  LEAD CONVERTED NOTIFICATION (send to Lead Owner / assigned user)
            if (newLead.IsConverted == true && oldLead.IsConverted == false) {
                try {
                    Messaging.CustomNotification noti = new Messaging.CustomNotification();
                    noti.setTitle('Lead Converted');
                    noti.setBody('Lead "' + fullName + '" (' + company + ') has been successfully converted.');
                    noti.setNotificationTypeId(convertedType.Id);
                    noti.setTargetId(newLead.Id);
                    
                    // ✅ Send to assigned user/owner
                    noti.send(new Set<String>{ String.valueOf(newLead.OwnerId) });
                    
                } catch (Exception e) {
                    System.debug('Error sending conversion notification: ' + e.getMessage());
                }
            }
        }
        
        //update account email with lead email
        if (!accountIds.isEmpty()) {
            List<Account> accounts = [ SELECT Id, Email__c FROM Account WHERE Id IN :accountIds ];
            
            for (Account acc : accounts) {
                if (leadEmailMap.containsKey(acc.Id)) {
                    acc.Email__c = leadEmailMap.get(acc.Id);
                }
            }
            
            update accounts;
        }
        
    }
    
    
    // AFTER INSERT 
    public static void afterInsert(List<Lead> leadList) {
        
        CustomNotificationType assignType =
            [SELECT Id FROM CustomNotificationType WHERE DeveloperName = 'Lead_Assigned_Notification' LIMIT 1];
        
        for (Lead ld : leadList) {
            try {
                Messaging.CustomNotification noti = new Messaging.CustomNotification();
                noti.setTitle('New Lead Assigned');
                noti.setBody('A new lead "' + ld.FirstName+' '+ld.LastName + '" has been assigned to you.');
                noti.setNotificationTypeId(assignType.Id);
                noti.setTargetId(ld.Id);
                noti.send(new Set<String>{ String.valueOf(ld.OwnerId) });
            } catch (Exception e) {
                System.debug('Error sending assignment notification after insert: ' + e.getMessage());
            }
        }
        List<Id> leadIds = new List<Id>();
        for (Lead ld : leadList) {
            
            if (ld.Email != null) {
                leadIds.add(ld.Id);
            }
            String phone = ld.Phone != null ? ld.Phone : ld.MobilePhone;
            if (phone != null) {
                String phoneNumber = phone.replaceAll('[^0-9]', '');
                if (!phoneNumber.startsWith('91') && phoneNumber.length() == 10) {
                    phoneNumber = '91' + phoneNumber;
                }
                WhatsAppMessageSender.sendThanksMessage(phoneNumber);
            }
        }
        //  if (!leadIds.isEmpty()) {
        // LeadThankYouEmailHelper.sendThankYouEmail(leadIds);
        // }
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