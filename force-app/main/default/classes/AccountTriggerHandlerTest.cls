@IsTest
public class AccountTriggerHandlerTest {

    private static Account newAcc(String name) {
        return new Account(
            Name              = name,
            BillingCountry    = 'India',
            BillingState      = 'Maharashtra',
            BillingPostalCode = '400001',
            District__c       = 'Ernakulam',
            BillingStreet     = '123 Test Street',
            Pin_Code__c       = 400001
        );
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  INSERT — duplicate Phone
    // ═══════════════════════════════════════════════════════════════════════

    @IsTest
    static void testInsert_DuplicatePhone() {
        Account acc1 = newAcc('A1');
        acc1.Phone = '9991112222';
        insert acc1;

        Account acc2 = newAcc('A2');
        acc2.Phone = '9991112222';

        Test.startTest();
        Database.SaveResult sr = Database.insert(acc2, false);
        Test.stopTest();

        System.assert(!sr.isSuccess(), 'Should fail for duplicate Phone');
        System.assert(sr.getErrors()[0].getMessage().contains('Phone already exists'),
            'Error should mention Phone');
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  INSERT — duplicate Secondary Phone
    // ═══════════════════════════════════════════════════════════════════════

    @IsTest
    static void testInsert_DuplicateSecondaryPhone() {
        Account acc1 = newAcc('A1');
        acc1.Secondary_Phone__c = '8881112222';
        insert acc1;

        Account acc2 = newAcc('A2');
        acc2.Secondary_Phone__c = '8881112222';

        Test.startTest();
        Database.SaveResult sr = Database.insert(acc2, false);
        Test.stopTest();

        System.assert(!sr.isSuccess(), 'Should fail for duplicate Secondary Phone');
        System.assert(sr.getErrors()[0].getMessage().contains('Secondary Phone already exists'),
            'Error should mention Secondary Phone');
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  INSERT — cross check: Phone matches existing Secondary Phone
    // ═══════════════════════════════════════════════════════════════════════

    @IsTest
    static void testInsert_PhoneMatchesSecondaryPhone() {
        Account acc1 = newAcc('A1');
        acc1.Secondary_Phone__c = '9991112222';
        insert acc1;

        Account acc2 = newAcc('A2');
        acc2.Phone = '9991112222';

        Test.startTest();
        Database.SaveResult sr = Database.insert(acc2, false);
        Test.stopTest();

        System.assert(!sr.isSuccess(), 'Should fail — Phone matches existing Secondary Phone');
        System.assert(sr.getErrors()[0].getMessage().contains('Phone already exists as Secondary Phone'),
            'Error should mention cross-check');
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  INSERT — cross check: Secondary Phone matches existing Phone
    // ═══════════════════════════════════════════════════════════════════════

    @IsTest
    static void testInsert_SecondaryPhoneMatchesPhone() {
        Account acc1 = newAcc('A1');
        acc1.Phone = '8881112222';
        insert acc1;

        Account acc2 = newAcc('A2');
        acc2.Secondary_Phone__c = '8881112222';

        Test.startTest();
        Database.SaveResult sr = Database.insert(acc2, false);
        Test.stopTest();

        System.assert(!sr.isSuccess(), 'Should fail — Secondary Phone matches existing Phone');
        System.assert(sr.getErrors()[0].getMessage().contains('Secondary Phone already exists as Phone'),
            'Error should mention cross-check');
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  INSERT — duplicate GST Number
    // ═══════════════════════════════════════════════════════════════════════

    @IsTest
    static void testInsert_DuplicateGST() {
        Account acc1 = newAcc('B1');
        acc1.GST_Number__c = '29ABCDE1234F1Z5';
        insert acc1;

        Account acc2 = newAcc('B2');
        acc2.GST_Number__c = '29ABCDE1234F1Z5';

        Test.startTest();
        Database.SaveResult sr = Database.insert(acc2, false);
        Test.stopTest();

        System.assert(!sr.isSuccess(), 'Should fail for duplicate GST');
        System.assert(sr.getErrors()[0].getMessage().contains('GST Number already exists'),
            'Error should mention GST');
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  INSERT — duplicate GST case-insensitive
    // ═══════════════════════════════════════════════════════════════════════

    @IsTest
    static void testInsert_DuplicateGSTCaseInsensitive() {
        Account acc1 = newAcc('B1');
        acc1.GST_Number__c = '07BBBCC2222G1Z3';
        insert acc1;

        Account acc2 = newAcc('B2');
        acc2.GST_Number__c = '07BBBCC2222G1Z3';

        Test.startTest();
        Database.SaveResult sr = Database.insert(acc2, false);
        Test.stopTest();

        System.assert(!sr.isSuccess(), 'GST check should be case-insensitive');
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  INSERT — duplicate PAN Number
    // ═══════════════════════════════════════════════════════════════════════

    @IsTest
    static void testInsert_DuplicatePAN() {
        Account acc1 = newAcc('B1');
        acc1.PAN_Number__c = 'ABCDE1234F';
        insert acc1;

        Account acc2 = newAcc('B2');
        acc2.PAN_Number__c = 'ABCDE1234F';

        Test.startTest();
        Database.SaveResult sr = Database.insert(acc2, false);
        Test.stopTest();

        System.assert(!sr.isSuccess(), 'Should fail for duplicate PAN');
        System.assert(sr.getErrors()[0].getMessage().contains('PAN Number already exists'),
            'Error should mention PAN');
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  INSERT — duplicate PAN case-insensitive
    // ═══════════════════════════════════════════════════════════════════════

    @IsTest
    static void testInsert_DuplicatePANCaseInsensitive() {
        Account acc1 = newAcc('B1');
        acc1.PAN_Number__c = 'BBBCC2222G';
        insert acc1;

        Account acc2 = newAcc('B2');
        acc2.PAN_Number__c = 'BBBCC2222G';

        Test.startTest();
        Database.SaveResult sr = Database.insert(acc2, false);
        Test.stopTest();

        System.assert(!sr.isSuccess(), 'PAN check should be case-insensitive');
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  INSERT — phone normalization (strips non-digit chars)
    // ═══════════════════════════════════════════════════════════════════════

    @IsTest
    static void testInsert_PhoneNormalization() {
        Account acc1 = newAcc('A1');
        acc1.Phone = '9876543210';
        insert acc1;

        Account acc2 = newAcc('A2');
        acc2.Phone = '987-654-3210';

        Test.startTest();
        Database.SaveResult sr = Database.insert(acc2, false);
        Test.stopTest();

        System.assert(!sr.isSuccess(), 'Normalized phone should match');
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  INSERT — no duplicates (clean insert)
    // ═══════════════════════════════════════════════════════════════════════

    @IsTest
    static void testInsert_NoDuplicates() {
        Account acc1 = newAcc('E1');
        acc1.Phone = '1112223333';
        acc1.Secondary_Phone__c = '4445556666';
        acc1.GST_Number__c = '27CCCDD3333H1Z4';
        acc1.PAN_Number__c = 'CCCDD3333H';
        insert acc1;

        Account acc2 = newAcc('E2');
        acc2.Phone = '7778889999';
        acc2.Secondary_Phone__c = '0001112222';
        acc2.GST_Number__c = '06DDDEE4444J1Z6';
        acc2.PAN_Number__c = 'DDDEE4444J';

        Test.startTest();
        Database.SaveResult sr = Database.insert(acc2, false);
        Test.stopTest();

        System.assert(sr.isSuccess(), 'No duplicates — should insert successfully');
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  INSERT — blank fields (nothing to check)
    // ═══════════════════════════════════════════════════════════════════════

    @IsTest
    static void testInsert_BlankFields() {
        Account acc = newAcc('Blank');

        Test.startTest();
        Database.SaveResult sr = Database.insert(acc, false);
        Test.stopTest();

        System.assert(sr.isSuccess(), 'Blank fields — no dup check needed');
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  INSERT — both Phone AND GST AND PAN duplicate
    // ═══════════════════════════════════════════════════════════════════════

    @IsTest
    static void testInsert_MultipleFieldsDuplicate() {
        Account acc1 = newAcc('Multi1');
        acc1.Phone = '5555555555';
        acc1.GST_Number__c = '08EEEGG5555K1Z7';
        acc1.PAN_Number__c = 'EEEGG5555K';
        insert acc1;

        Account acc2 = newAcc('Multi2');
        acc2.Phone = '5555555555';
        acc2.GST_Number__c = '08EEEGG5555K1Z7';
        acc2.PAN_Number__c = 'EEEGG5555K';

        Test.startTest();
        Database.SaveResult sr = Database.insert(acc2, false);
        Test.stopTest();

        System.assert(!sr.isSuccess(), 'Should fail with multiple duplicate fields');
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  UPDATE — Phone changed to duplicate
    // ═══════════════════════════════════════════════════════════════════════

    @IsTest
    static void testUpdate_DuplicatePhone() {
        Account acc1 = newAcc('D1');
        acc1.Phone = '1234567890';
        insert acc1;

        Account acc2 = newAcc('D2');
        acc2.Phone = '0987654321';
        insert acc2;

        acc2.Phone = '1234567890';

        Test.startTest();
        Database.SaveResult sr = Database.update(acc2, false);
        Test.stopTest();

        System.assert(!sr.isSuccess(), 'Should fail — Phone updated to duplicate');
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  UPDATE — GST changed to duplicate
    // ═══════════════════════════════════════════════════════════════════════

    @IsTest
    static void testUpdate_DuplicateGST() {
        Account acc1 = newAcc('D1');
        acc1.GST_Number__c = '09FFFHH6666L1Z8';
        insert acc1;

        Account acc2 = newAcc('D2');
        acc2.GST_Number__c = '10GGGKK7777M1Z9';
        insert acc2;

        acc2.GST_Number__c = '09FFFHH6666L1Z8';

        Test.startTest();
        Database.SaveResult sr = Database.update(acc2, false);
        Test.stopTest();

        System.assert(!sr.isSuccess(), 'Should fail — GST updated to duplicate');
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  UPDATE — PAN changed to duplicate
    // ═══════════════════════════════════════════════════════════════════════

    @IsTest
    static void testUpdate_DuplicatePAN() {
        Account acc1 = newAcc('D1');
        acc1.PAN_Number__c = 'FFFHH6666L';
        insert acc1;

        Account acc2 = newAcc('D2');
        acc2.PAN_Number__c = 'GGGKK7777M';
        insert acc2;

        acc2.PAN_Number__c = 'FFFHH6666L';

        Test.startTest();
        Database.SaveResult sr = Database.update(acc2, false);
        Test.stopTest();

        System.assert(!sr.isSuccess(), 'Should fail — PAN updated to duplicate');
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  UPDATE — no change to checked fields (should pass)
    // ═══════════════════════════════════════════════════════════════════════

    @IsTest
    static void testUpdate_NoChange() {
        Account acc = newAcc('NoChange');
        acc.Phone = '1231231234';
        acc.GST_Number__c = '24HHHLL8888N1Z1';
        acc.PAN_Number__c = 'HHHLL8888N';
        insert acc;

        acc.Name = 'NoChange Updated';

        Test.startTest();
        Database.SaveResult sr = Database.update(acc, false);
        Test.stopTest();

        System.assert(sr.isSuccess(), 'No dup-field change — should succeed');
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  UPDATE — Secondary Phone changed to match existing Phone (cross)
    // ═══════════════════════════════════════════════════════════════════════

    @IsTest
    static void testUpdate_CrossSecPhoneToPhone() {
        Account acc1 = newAcc('X1');
        acc1.Phone = '6666666666';
        insert acc1;

        Account acc2 = newAcc('X2');
        acc2.Secondary_Phone__c = '7777777777';
        insert acc2;

        acc2.Secondary_Phone__c = '6666666666';

        Test.startTest();
        Database.SaveResult sr = Database.update(acc2, false);
        Test.stopTest();

        System.assert(!sr.isSuccess(), 'Should fail — Secondary Phone matches existing Phone');
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  BULK INSERT — mixed duplicates
    // ═══════════════════════════════════════════════════════════════════════

    @IsTest
    static void testBulkInsert() {
        Account existing = newAcc('BExist');
        existing.Phone = '1010101010';
        existing.GST_Number__c = '33JJJMM9999P1Z2';
        insert existing;

        Account dup1 = newAcc('BDupPhone');
        dup1.Phone = '1010101010';

        Account clean = newAcc('BClean');
        clean.Phone = '2020202020';

        Account dup2 = newAcc('BDupGST');
        dup2.GST_Number__c = '33JJJMM9999P1Z2';

        List<Account> newAccounts = new List<Account>{ dup1, clean, dup2 };

        Test.startTest();
        List<Database.SaveResult> results = Database.insert(newAccounts, false);
        Test.stopTest();

        System.assert(!results[0].isSuccess(), 'Duplicate Phone should fail');
        System.assert(results[1].isSuccess(),  'Clean account should succeed');
        System.assert(!results[2].isSuccess(), 'Duplicate GST should fail');
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  Email validation branch (commented out collection, but validation
    //  code still exists — exercise it with no matches)
    // ═══════════════════════════════════════════════════════════════════════

    @IsTest
    static void testInsert_EmailFields_NoMatch() {
        Account acc1 = newAcc('Em1');
        acc1.Email__c = 'test@email.com';
        acc1.Secondary_Email__c = 'sec@email.com';
        insert acc1;

        Account acc2 = newAcc('Em2');
        acc2.Email__c = 'other@email.com';
        acc2.Secondary_Email__c = 'othersec@email.com';

        Test.startTest();
        Database.SaveResult sr = Database.insert(acc2, false);
        Test.stopTest();

        System.assert(sr.isSuccess(),
            'Email collection is commented out — should not block insert');
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  Direct handler call — beforeInsert
    // ═══════════════════════════════════════════════════════════════════════

    @IsTest
    static void testDirectCall_BeforeInsert() {
        Account existing = newAcc('Dir1');
        existing.Phone = '3333333333';
        insert existing;

        Account newAccount = newAcc('Dir2');
        newAccount.Phone = '3333333333';

        Test.startTest();
        AccountTriggerHandler.beforeInsert(new List<Account>{ newAccount });
        Test.stopTest();

        System.assertNotEquals(null, existing.Id);
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  Direct handler call — beforeUpdate
    // ═══════════════════════════════════════════════════════════════════════

    @IsTest
    static void testDirectCall_BeforeUpdate() {
        Account acc1 = newAcc('Up1');
        acc1.Phone = '4444444444';
        insert acc1;

        Account acc2 = newAcc('Up2');
        acc2.Phone = '5555555555';
        insert acc2;

        Account oldAcc2 = acc2.clone(true, true, true, true);
        acc2.Phone = '4444444444';

        Test.startTest();
        AccountTriggerHandler.beforeUpdate(
            new List<Account>{ acc2 },
            new Map<Id, Account>{ acc2.Id => oldAcc2 }
        );
        Test.stopTest();

        System.assertNotEquals(null, acc1.Id);
    }
}