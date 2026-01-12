public class AccountTriggerHandler {

    public static void beforeInsert(List<Account> accList) {
        checkDuplicateAccount(accList, null);
    }

    public static void beforeUpdate(List<Account> accList, Map<Id, Account> oldMap) {
        checkDuplicateAccount(accList, oldMap);
    }

    // DUPLICATION CHECK 
    private static void checkDuplicateAccount(List<Account> newList, Map<Id, Account> oldMap) {

        // Set<String> emails = new Set<String>();
        // Set<String> secEmails = new Set<String>();
        Set<String> phones = new Set<String>();
        Set<String> secPhones = new Set<String>();
        Set<String> gstSet = new Set<String>(); 
        Set<String> panSet = new Set<String>();  

        // Collect values from new Accounts
        for (Account a :newList) {

            //if (!String.isBlank(a.Email__c))
            //    emails.add(a.Email__c.trim().toLowerCase());

            //if (!String.isBlank(a.Secondary_Email__c))
            //    secEmails.add(a.Secondary_Email__c.trim().toLowerCase());

            if (!String.isBlank(a.Phone))
                phones.add(normalizePhone(a.Phone));

            if (!String.isBlank(a.Secondary_Phone__c))
                secPhones.add(normalizePhone(a.Secondary_Phone__c));

            // GST COLLECT 
            if (!String.isBlank(a.GST_Number__c)) {

                if (oldMap == null || oldMap.get(a.Id) == null ||
                    a.GST_Number__c != oldMap.get(a.Id).GST_Number__c) 
                {
                    gstSet.add(a.GST_Number__c.trim().toUpperCase());
                }
            }

            // PAN COLLECT  
            if (!String.isBlank(a.PAN_Number__c)) {

                if (oldMap == null || oldMap.get(a.Id) == null ||
                    a.PAN_Number__c != oldMap.get(a.Id).PAN_Number__c) 
                {
                    panSet.add(a.PAN_Number__c.trim().toUpperCase());
                }
            }
        }

        // Query existing Accounts
        List<Account> existing = [
             SELECT Id, Email__c, Secondary_Email__c, Phone, Secondary_Phone__c, GST_Number__c, PAN_Number__c
             FROM Account
             WHERE 
             Phone IN :phones OR
             Secondary_Phone__c IN :secPhones OR
             Phone IN :secPhones OR                   
             Secondary_Phone__c IN :phones OR          
             GST_Number__c IN :gstSet OR
             PAN_Number__c IN :panSet
         ];

        // Maps for comparison
        Map<String, Account> emailMap = new Map<String, Account>();
        Map<String, Account> secEmailMap = new Map<String, Account>();
        Map<String, Account> phoneMap = new Map<String, Account>();
        Map<String, Account> secPhoneMap = new Map<String, Account>();
        Map<String, Account> gstMap = new Map<String, Account>();   
        Map<String, Account> panMap = new Map<String, Account>();  

        for (Account a : existing) {

            if (!String.isBlank(a.Email__c))
                emailMap.put(a.Email__c.trim().toLowerCase(), a);

            if (!String.isBlank(a.Secondary_Email__c))
                secEmailMap.put(a.Secondary_Email__c.trim().toLowerCase(), a);

            if (!String.isBlank(a.Phone))
                phoneMap.put(normalizePhone(a.Phone), a);

            if (!String.isBlank(a.Secondary_Phone__c))
                secPhoneMap.put(normalizePhone(a.Secondary_Phone__c), a);

            // GST MAPPING
            if (!String.isBlank(a.GST_Number__c))
                gstMap.put(a.GST_Number__c.trim().toUpperCase(), a);

            // PAN MAPPING 
            if (!String.isBlank(a.PAN_Number__c))
                panMap.put(a.PAN_Number__c.trim().toUpperCase(), a);
        }

        // VALIDATE
        for (Account a : newList) {

            String em  = String.isBlank(a.Email__c) ? null : a.Email__c.trim().toLowerCase();
            String sem = String.isBlank(a.Secondary_Email__c) ? null : a.Secondary_Email__c.trim().toLowerCase();
            String ph  = String.isBlank(a.Phone) ? null : normalizePhone(a.Phone);
            String sph = String.isBlank(a.Secondary_Phone__c) ? null : normalizePhone(a.Secondary_Phone__c);
            String gst = String.isBlank(a.GST_Number__c) ? null : a.GST_Number__c.trim().toUpperCase();  
            String pan = String.isBlank(a.PAN_Number__c) ? null : a.PAN_Number__c.trim().toUpperCase();  

            // EMAIL CHECK
            if (em != null) {
                Account dup = emailMap.get(em);

                if (dup != null && dup.Id != a.Id)
                    a.addError('Duplicate found — this Email already exists in another Account (Email): ' + a.Email__c);
            }

            // SECONDARY EMAIL CHECK
            if (sem != null) {
                Account dup = secEmailMap.get(sem);

                if (dup != null && dup.Id != a.Id)
                    a.addError('Duplicate found — this Secondary Email already exists in another Account (Secondary Email): ' + a.Secondary_Email__c);
            }

            // PHONE CHECK
            if (ph != null) {
                Account dup = phoneMap.get(ph);

                if (dup != null && dup.Id != a.Id)
                    a.addError('Duplicate found — this Phone already exists in another Account (Phone): ' + a.Phone);
            }  

            // SECONDARY PHONE CHECK
            if (sph != null) {
                Account dup = secPhoneMap.get(sph);

                if (dup != null && dup.Id != a.Id)
                    a.addError('Duplicate found — this Secondary Phone already exists in another Account (Secondary Phone): ' + a.Secondary_Phone__c);
            }

         
            // CROSS CHECK 1: PHONE → SECONDARY PHONE 
         
            if (ph != null) {
                Account dupCrossPhone = secPhoneMap.get(ph);
                if (dupCrossPhone != null && dupCrossPhone.Id != a.Id)
                    a.addError('Duplicate found — this Phone already exists as Secondary Phone in another Account: ' + a.Phone);
            }

            
            // CROSS CHECK 2: SECONDARY PHONE → PHONE
            
            if (sph != null) {
                Account dupCrossSec = phoneMap.get(sph);
                if (dupCrossSec != null && dupCrossSec.Id != a.Id)
                    a.addError('Duplicate found — this Secondary Phone already exists as Phone in another Account: ' + a.Secondary_Phone__c);
            }

            // GST VALIDATION
            if (gst != null) {
                Account dup = gstMap.get(gst);

                if (dup != null && dup.Id != a.Id)
                    a.addError('Duplicate found — this GST Number already exists in another Account (GST): ' + a.GST_Number__c);
            }

            // PAN VALIDATION 
            if (pan != null) {
                Account dup = panMap.get(pan);

                if (dup != null && dup.Id != a.Id)
                    a.addError('Duplicate found — this PAN Number already exists in another Account (PAN): ' + a.PAN_Number__c);
            }
        }
    }

    // Phone normalization helper
    private static String normalizePhone(String p) {
        return p == null ? null : p.replaceAll('[^0-9]', '');
    }
}