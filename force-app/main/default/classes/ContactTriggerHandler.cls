public class ContactTriggerHandler {

    public static void checkDuplicateContacts(List<Contact> newList, Map<Id, Contact> oldMap) {

        Set<String> emailSet = new Set<String>();
        Set<String> phoneSet = new Set<String>();

        // Collect new values
        for (Contact c : newList) {

            // EMAIL COLLECT
            if (!String.isBlank(c.Email)) {
                if (oldMap == null || oldMap.get(c.Id) == null ||
                    c.Email != oldMap.get(c.Id).Email)
                {
                    emailSet.add(c.Email.trim().toLowerCase());
                }
            }

            // PHONE / MOBILE / OTHER / HOME PHONE COLLECT
            String[] phoneFields = new String[]{
                c.Phone,
                c.MobilePhone,
                c.OtherPhone,
                c.HomePhone,
                c.Phone_Number__c  // your custom Phone Number field
            };

            for (String p : phoneFields) {
                if (!String.isBlank(p)) {
                    String normal = normalizePhone(p);

                    if (oldMap == null || oldMap.get(c.Id) == null ||
                        normal != normalizePhone(oldMap.get(c.Id).Phone))
                    {
                        phoneSet.add(normal);
                    }
                }
            }
        }

        // Query existing Contacts
        List<Contact> existing = [
            SELECT Id, Email, Phone, MobilePhone, OtherPhone, HomePhone, Phone_Number__c
            FROM Contact
            WHERE Email IN :emailSet
               OR Phone IN :phoneSet
               OR MobilePhone IN :phoneSet
               OR OtherPhone IN :phoneSet
               OR HomePhone IN :phoneSet
               OR Phone_Number__c IN :phoneSet
        ];

        // Maps for lookup
        Map<String, Contact> emailMap = new Map<String, Contact>();
        Map<String, Contact> phoneMap = new Map<String, Contact>();

        for (Contact c : existing) {

            if (!String.isBlank(c.Email))
                emailMap.put(c.Email.trim().toLowerCase(), c);

            String[] phoneFields = new String[]{
                c.Phone,
                c.MobilePhone,
                c.OtherPhone,
                c.HomePhone,
                c.Phone_Number__c
            };

            for (String p : phoneFields) {
                if (!String.isBlank(p))
                    phoneMap.put(normalizePhone(p), c);
            }
        }

        // VALIDATION
        for (Contact c : newList) {

            // EMAIL CHECK
            String em = String.isBlank(c.Email) ? null : c.Email.trim().toLowerCase();
            if (em != null) {
                Contact dup = emailMap.get(em);
                if (dup != null && dup.Id != c.Id)
                    c.addError('Duplicate found — this Email already exists in another Contact: ' + c.Email);
            }

            // PHONE CHECK (Phone, Mobile, Other, Home)
            String[] phoneFields = new String[]{
                c.Phone,
                c.MobilePhone,
                c.OtherPhone,
                c.HomePhone,
                c.Phone_Number__c
            };

            for (String p : phoneFields) {
                if (!String.isBlank(p)) {
                    String norm = normalizePhone(p);
                    Contact dupPhone = phoneMap.get(norm);

                    if (dupPhone != null && dupPhone.Id != c.Id) {
                        c.addError('Duplicate found — this Phone number already exists in another Contact: ' + p);
                    }
                }
            }
        }
    }

    private static String normalizePhone(String p) {
        return p == null ? null : p.replaceAll('[^0-9]', '');
    }
}