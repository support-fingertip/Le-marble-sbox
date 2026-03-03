@isTest
public class AccountTriggerHandlerTest {
    @isTest
    static void testDuplicatePhoneAndSecondaryPhone() {
        Account acc1 = new Account(Name = 'A1', Phone = '9991112222', Secondary_Phone__c = '8881112222', GST_Number__c = '22AAAAA0000A1Z5', PAN_Number__c = 'ABCDE1234F');
        insert acc1;
        // Duplicate Phone
        Account acc2 = new Account(Name = 'A2', Phone = '9991112222', GST_Number__c = '33BBBBB0000B2Z6', PAN_Number__c = 'FGHIJ5678K');
        try {
            insert acc2;
            System.assert(false, 'Expected duplicate phone error');
        } catch (DmlException e) {
            System.assert(e.getMessage().contains('Phone already exists'));
        }
        // Duplicate Secondary Phone
        Account acc3 = new Account(Name = 'A3', Secondary_Phone__c = '8881112222', GST_Number__c = '44CCCCC0000C3Z7', PAN_Number__c = 'KLMNO9012P');
        try {
            insert acc3;
            System.assert(false, 'Expected duplicate secondary phone error');
        } catch (DmlException e) {
            System.assert(e.getMessage().contains('Secondary Phone already exists'));
        }
        // Cross check: Phone as Secondary Phone
        Account acc4 = new Account(Name = 'A4', Secondary_Phone__c = '9991112222', GST_Number__c = '55DDDDD0000D4Z8', PAN_Number__c = 'QRSTU3456V');
        try {
            insert acc4;
            System.assert(false, 'Expected cross phone-secondary error');
        } catch (DmlException e) {
            System.assert(e.getMessage().contains('Phone already exists as Secondary Phone'));
        }
        // Cross check: Secondary Phone as Phone
        Account acc5 = new Account(Name = 'A5', Phone = '8881112222', GST_Number__c = '66EEEEE0000E5Z9', PAN_Number__c = 'WXYZA7890B');
        try {
            insert acc5;
            System.assert(false, 'Expected cross secondary-phone error');
        } catch (DmlException e) {
            System.assert(e.getMessage().contains('Secondary Phone already exists as Phone'));
        }
    }

    @isTest
    static void testDuplicateGSTAndPAN() {
        Account acc1 = new Account(Name = 'B1', GST_Number__c = '22AAAAA0000A1Z5', PAN_Number__c = 'ABCDE1234F');
        insert acc1;
        // Duplicate GST
        Account acc2 = new Account(Name = 'B2', GST_Number__c = '22AAAAA0000A1Z5', PAN_Number__c = 'FGHIJ5678K');
        try {
            insert acc2;
            System.assert(false, 'Expected duplicate GST error');
        } catch (DmlException e) {
            System.assert(e.getMessage().contains('GST Number already exists'));
        }
        // Duplicate PAN
        Account acc3 = new Account(Name = 'B3', GST_Number__c = '33BBBBB0000B2Z6', PAN_Number__c = 'ABCDE1234F');
        try {
            insert acc3;
            System.assert(false, 'Expected duplicate PAN error');
        } catch (DmlException e) {
            System.assert(e.getMessage().contains('PAN Number already exists'));
        }
    }

    @isTest
    static void testDuplicateEmailAndSecondaryEmail() {
        Account acc1 = new Account(Name = 'C1', Email__c = 'test@email.com', Secondary_Email__c = 'sec@email.com', GST_Number__c = '22AAAAA0000A1Z5', PAN_Number__c = 'ABCDE1234F');
        insert acc1;
        // Duplicate Email
        Account acc2 = new Account(Name = 'C2', Email__c = 'test@email.com', GST_Number__c = '33BBBBB0000B2Z6', PAN_Number__c = 'FGHIJ5678K');
        try {
            insert acc2;
            System.assert(false, 'Expected duplicate email error');
        } catch (DmlException e) {
            System.assert(e.getMessage().contains('Email already exists'));
        }
        // Duplicate Secondary Email
        Account acc3 = new Account(Name = 'C3', Secondary_Email__c = 'sec@email.com', GST_Number__c = '44CCCCC0000C3Z7', PAN_Number__c = 'KLMNO9012P');
        try {
            insert acc3;
            System.assert(false, 'Expected duplicate secondary email error');
        } catch (DmlException e) {
            System.assert(e.getMessage().contains('Secondary Email already exists'));
        }
    }

    @isTest
    static void testUpdateDuplicateChecks() {
        Account acc1 = new Account(Name = 'D1', Phone = '1234567890', GST_Number__c = '22AAAAA0000A1Z5', PAN_Number__c = 'ABCDE1234F');
        insert acc1;
        Account acc2 = new Account(Name = 'D2', Phone = '0987654321', GST_Number__c = '33BBBBB0000B2Z6', PAN_Number__c = 'FGHIJ5678K');
        insert acc2;
        // Try to update acc2 to duplicate acc1's Phone, GST, PAN
        acc2.Phone = '1234567890';
        acc2.GST_Number__c = '22AAAAA0000A1Z5';
        acc2.PAN_Number__c = 'ABCDE1234F';
        try {
            update acc2;
            System.assert(false, 'Expected duplicate error on update');
        } catch (DmlException e) {
            System.assert(e.getMessage().contains('already exists'));
        }
    }

    @isTest
    static void testNoDuplicateValidInsert() {
        Account acc1 = new Account(Name = 'E1', Phone = '1112223333', Secondary_Phone__c = '4445556666', GST_Number__c = '22AAAAA0000A1Z5', PAN_Number__c = 'ABCDE1234F', Email__c = 'ok@email.com', Secondary_Email__c = 'ok2@email.com');
        insert acc1;
        Account acc2 = new Account(Name = 'E2', Phone = '7778889999', Secondary_Phone__c = '0001112222', GST_Number__c = '33BBBBB0000B2Z6', PAN_Number__c = 'FGHIJ5678K', Email__c = 'ok3@email.com', Secondary_Email__c = 'ok4@email.com');
        insert acc2;
        // No error expected
    }
}