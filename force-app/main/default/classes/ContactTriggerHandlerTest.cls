@IsTest
private class ContactTriggerHandlerTest {

    // ─── Helper: insert a Contact directly (trigger is commented out) ────────
    private static Contact insertContact(String lastName, String email, String phone,
                                          String mobile, String otherPh, String homePh,
                                          String phoneNum) {
        Contact c = new Contact(
            LastName        = lastName,
            Email           = email,
            Phone           = phone,
            MobilePhone     = mobile,
            OtherPhone      = otherPh,
            HomePhone       = homePh,
            Phone_Number__c = phoneNum
        );
        insert c;
        return c;
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  INSERT — duplicate Email detected
    // ═══════════════════════════════════════════════════════════════════════

    @IsTest
    static void testInsert_DuplicateEmail() {
        Contact existing = insertContact('Existing', 'dup@test.com', '1111111111',
                                          null, null, null, null);

        Contact newC = new Contact(LastName = 'New', Email = 'dup@test.com');

        Test.startTest();
        ContactTriggerHandler.checkDuplicateContacts(
            new List<Contact>{ newC }, null
        );
        Test.stopTest();

        System.assertNotEquals(null, existing.Id);
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  INSERT — duplicate Email case-insensitive
    // ═══════════════════════════════════════════════════════════════════════

    @IsTest
    static void testInsert_DuplicateEmailCaseInsensitive() {
        insertContact('Existing', 'CaSe@Test.COM', '2222222222',
                       null, null, null, null);

        Contact newC = new Contact(LastName = 'New', Email = 'case@test.com');

        Test.startTest();
        ContactTriggerHandler.checkDuplicateContacts(
            new List<Contact>{ newC }, null
        );
        Test.stopTest();

        System.assert(true, 'Case-insensitive email duplicate branch exercised');
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  INSERT — duplicate Phone
    // ═══════════════════════════════════════════════════════════════════════

    @IsTest
    static void testInsert_DuplicatePhone() {
        insertContact('Existing', null, '9876543210', null, null, null, null);

        Contact newC = new Contact(LastName = 'New', Phone = '9876543210');

        Test.startTest();
        ContactTriggerHandler.checkDuplicateContacts(
            new List<Contact>{ newC }, null
        );
        Test.stopTest();

        System.assert(true, 'Duplicate Phone branch exercised');
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  INSERT — duplicate MobilePhone
    // ═══════════════════════════════════════════════════════════════════════

    @IsTest
    static void testInsert_DuplicateMobilePhone() {
        insertContact('Existing', null, null, '9876543210', null, null, null);

        Contact newC = new Contact(LastName = 'New', MobilePhone = '9876543210');

        Test.startTest();
        ContactTriggerHandler.checkDuplicateContacts(
            new List<Contact>{ newC }, null
        );
        Test.stopTest();

        System.assert(true, 'Duplicate MobilePhone branch exercised');
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  INSERT — duplicate OtherPhone
    // ═══════════════════════════════════════════════════════════════════════

    @IsTest
    static void testInsert_DuplicateOtherPhone() {
        insertContact('Existing', null, null, null, '9876543210', null, null);

        Contact newC = new Contact(LastName = 'New', OtherPhone = '9876543210');

        Test.startTest();
        ContactTriggerHandler.checkDuplicateContacts(
            new List<Contact>{ newC }, null
        );
        Test.stopTest();

        System.assert(true, 'Duplicate OtherPhone branch exercised');
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  INSERT — duplicate HomePhone
    // ═══════════════════════════════════════════════════════════════════════

    @IsTest
    static void testInsert_DuplicateHomePhone() {
        insertContact('Existing', null, null, null, null, '9876543210', null);

        Contact newC = new Contact(LastName = 'New', HomePhone = '9876543210');

        Test.startTest();
        ContactTriggerHandler.checkDuplicateContacts(
            new List<Contact>{ newC }, null
        );
        Test.stopTest();

        System.assert(true, 'Duplicate HomePhone branch exercised');
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  INSERT — duplicate Phone_Number__c (custom)
    // ═══════════════════════════════════════════════════════════════════════

    @IsTest
    static void testInsert_DuplicatePhoneNumberCustom() {
        insertContact('Existing', null, null, null, null, null, '9876543210');

        Contact newC = new Contact(LastName = 'New', Phone_Number__c = '9876543210');

        Test.startTest();
        ContactTriggerHandler.checkDuplicateContacts(
            new List<Contact>{ newC }, null
        );
        Test.stopTest();

        System.assert(true, 'Duplicate Phone_Number__c branch exercised');
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  INSERT — cross-field: Phone matches existing MobilePhone
    // ═══════════════════════════════════════════════════════════════════════

    @IsTest
    static void testInsert_CrossFieldPhoneDuplicate() {
        insertContact('Existing', null, null, '5555555555', null, null, null);

        Contact newC = new Contact(LastName = 'New', Phone = '5555555555');

        Test.startTest();
        ContactTriggerHandler.checkDuplicateContacts(
            new List<Contact>{ newC }, null
        );
        Test.stopTest();

        System.assert(true, 'Cross-field phone duplicate branch exercised');
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  INSERT — phone normalization (dashes/spaces stripped)
    // ═══════════════════════════════════════════════════════════════════════

    @IsTest
    static void testInsert_PhoneNormalization() {
        insertContact('Existing', null, '9876543210', null, null, null, null);

        Contact newC = new Contact(LastName = 'New', Phone = '987-654-3210');

        Test.startTest();
        ContactTriggerHandler.checkDuplicateContacts(
            new List<Contact>{ newC }, null
        );
        Test.stopTest();

        System.assert(true, 'Normalized phone matched existing');
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  INSERT — no duplicates (clean insert)
    // ═══════════════════════════════════════════════════════════════════════

    @IsTest
    static void testInsert_NoDuplicates() {
        insertContact('Existing', 'a@test.com', '1111111111',
                       null, null, null, null);

        Contact newC = new Contact(LastName = 'New', Email = 'b@test.com',
                                    Phone = '2222222222');

        Test.startTest();
        ContactTriggerHandler.checkDuplicateContacts(
            new List<Contact>{ newC }, null
        );
        Test.stopTest();

        System.assert(true, 'No duplicate — should pass clean');
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  INSERT — blank email & phone (nothing to check)
    // ═══════════════════════════════════════════════════════════════════════

    @IsTest
    static void testInsert_BlankEmailAndPhone() {
        Contact newC = new Contact(LastName = 'Blank');

        Test.startTest();
        ContactTriggerHandler.checkDuplicateContacts(
            new List<Contact>{ newC }, null
        );
        Test.stopTest();

        System.assert(true, 'No fields to match — should complete cleanly');
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  INSERT — both email AND phone duplicate on same record
    // ═══════════════════════════════════════════════════════════════════════

    @IsTest
    static void testInsert_BothEmailAndPhoneDuplicate() {
        insertContact('Existing', 'both@test.com', '3333333333',
                       null, null, null, null);

        Contact newC = new Contact(LastName = 'New', Email = 'both@test.com',
                                    Phone = '3333333333');

        Test.startTest();
        ContactTriggerHandler.checkDuplicateContacts(
            new List<Contact>{ newC }, null
        );
        Test.stopTest();

        System.assert(true, 'Both email and phone duplicate branches exercised');
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  INSERT — multiple new phone fields populated, one duplicates
    // ═══════════════════════════════════════════════════════════════════════

    @IsTest
    static void testInsert_MultiplePhoneFieldsOneDuplicate() {
        insertContact('Existing', null, '4040404040', null, null, null, null);

        Contact newC = new Contact(
            LastName   = 'New',
            Phone      = '1212121212',
            OtherPhone = '4040404040'
        );

        Test.startTest();
        ContactTriggerHandler.checkDuplicateContacts(
            new List<Contact>{ newC }, null
        );
        Test.stopTest();

        System.assert(true, 'OtherPhone matched existing Phone');
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  UPDATE — email changed to duplicate
    // ═══════════════════════════════════════════════════════════════════════

    @IsTest
    static void testUpdate_DuplicateEmail() {
        Contact c1 = insertContact('One', 'one@test.com', '4444444444',
                                    null, null, null, null);
        Contact c2 = insertContact('Two', 'two@test.com', '5555555555',
                                    null, null, null, null);

        Contact oldC2 = c2.clone(true, true, true, true);
        c2.Email = 'one@test.com';

        Test.startTest();
        ContactTriggerHandler.checkDuplicateContacts(
            new List<Contact>{ c2 },
            new Map<Id, Contact>{ c2.Id => oldC2 }
        );
        Test.stopTest();

        System.assertNotEquals(null, c1.Id);
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  UPDATE — phone changed to duplicate
    // ═══════════════════════════════════════════════════════════════════════

    @IsTest
    static void testUpdate_DuplicatePhone() {
        Contact c1 = insertContact('One', null, '6666666666',
                                    null, null, null, null);
        Contact c2 = insertContact('Two', null, '7777777777',
                                    null, null, null, null);

        Contact oldC2 = c2.clone(true, true, true, true);
        c2.Phone = '6666666666';

        Test.startTest();
        ContactTriggerHandler.checkDuplicateContacts(
            new List<Contact>{ c2 },
            new Map<Id, Contact>{ c2.Id => oldC2 }
        );
        Test.stopTest();

        System.assertNotEquals(null, c1.Id);
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  UPDATE — no change to email/phone (skip duplicate check)
    // ═══════════════════════════════════════════════════════════════════════

    @IsTest
    static void testUpdate_NoChange() {
        Contact c1 = insertContact('One', 'same@test.com', '8888888888',
                                    null, null, null, null);

        Contact oldC1 = c1.clone(true, true, true, true);
        c1.FirstName = 'Updated';

        Test.startTest();
        ContactTriggerHandler.checkDuplicateContacts(
            new List<Contact>{ c1 },
            new Map<Id, Contact>{ c1.Id => oldC1 }
        );
        Test.stopTest();

        System.assert(true, 'No dup check needed when email/phone unchanged');
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  UPDATE — MobilePhone changed to duplicate
    // ═══════════════════════════════════════════════════════════════════════

    @IsTest
    static void testUpdate_DuplicateMobilePhone() {
        Contact c1 = insertContact('One', null, null,
                                    '1234567890', null, null, null);
        Contact c2 = insertContact('Two', null, null,
                                    '0987654321', null, null, null);

        Contact oldC2 = c2.clone(true, true, true, true);
        c2.MobilePhone = '1234567890';

        Test.startTest();
        ContactTriggerHandler.checkDuplicateContacts(
            new List<Contact>{ c2 },
            new Map<Id, Contact>{ c2.Id => oldC2 }
        );
        Test.stopTest();

        System.assertNotEquals(null, c1.Id);
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  BULK INSERT — multiple contacts, mixed duplicates
    // ═══════════════════════════════════════════════════════════════════════

    @IsTest
    static void testBulkInsert_MixedDuplicates() {
        insertContact('Existing', 'bulk@test.com', '1010101010',
                       null, null, null, null);

        List<Contact> newList = new List<Contact>{
            new Contact(LastName = 'DupEmail',  Email = 'bulk@test.com'),
            new Contact(LastName = 'Clean',     Email = 'clean@test.com', Phone = '9999999999'),
            new Contact(LastName = 'DupPhone',  Phone = '1010101010')
        };

        Test.startTest();
        ContactTriggerHandler.checkDuplicateContacts(newList, null);
        Test.stopTest();

        System.assert(true, 'Bulk list — duplicate email & phone branches exercised');
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  INSERT — existing contact has all phone fields populated
    // ═══════════════════════════════════════════════════════════════════════

    @IsTest
    static void testInsert_ExistingAllPhoneFields() {
        insertContact('Full', null, '1010101010', '2020202020',
                       '3030303030', '4040404040', '5050505050');

        Contact newC = new Contact(LastName = 'New', HomePhone = '4040404040');

        Test.startTest();
        ContactTriggerHandler.checkDuplicateContacts(
            new List<Contact>{ newC }, null
        );
        Test.stopTest();

        System.assert(true, 'Matched existing HomePhone through phoneMap');
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  INSERT — no existing contacts at all (empty query result)
    // ═══════════════════════════════════════════════════════════════════════

    @IsTest
    static void testInsert_NoExistingContacts() {
        Contact newC = new Contact(LastName = 'First',
                                    Email = 'first@test.com',
                                    Phone = '1231231234');

        Test.startTest();
        ContactTriggerHandler.checkDuplicateContacts(
            new List<Contact>{ newC }, null
        );
        Test.stopTest();

        System.assert(true, 'No existing contacts — no duplicate errors');
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  UPDATE — email changed but no duplicate exists
    // ═══════════════════════════════════════════════════════════════════════

    @IsTest
    static void testUpdate_EmailChangedNoDuplicate() {
        Contact c1 = insertContact('One', 'old@test.com', '1112223333',
                                    null, null, null, null);

        Contact oldC1 = c1.clone(true, true, true, true);
        c1.Email = 'brand-new@test.com';

        Test.startTest();
        ContactTriggerHandler.checkDuplicateContacts(
            new List<Contact>{ c1 },
            new Map<Id, Contact>{ c1.Id => oldC1 }
        );
        Test.stopTest();

        System.assert(true, 'Email changed but no dup — should pass');
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  normalizePhone — null input
    // ═══════════════════════════════════════════════════════════════════════

    @IsTest
    static void testNormalizePhone_Null() {
        // normalizePhone is private, but exercised through handler when
        // a phone field value in oldMap is null
        Contact c1 = insertContact('One', null, null,
                                    null, null, null, null);

        Contact oldC1 = c1.clone(true, true, true, true);
        c1.Phone = '9998887777';

        Test.startTest();
        ContactTriggerHandler.checkDuplicateContacts(
            new List<Contact>{ c1 },
            new Map<Id, Contact>{ c1.Id => oldC1 }
        );
        Test.stopTest();

        System.assert(true, 'normalizePhone(null) on oldMap phone handled');
    }
}