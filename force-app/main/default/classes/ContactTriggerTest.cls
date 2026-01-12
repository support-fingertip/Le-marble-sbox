@IsTest
public class ContactTriggerTest {

    @IsTest
    static void testDuplicateEmailOnInsert() {

        // Existing contact
        Contact c1 = new Contact(
            LastName = 'Test One',
            Email = 'test@email.com',
            Phone = '9999999999'
        );
        insert c1;

        // Duplicate email contact
        Contact c2 = new Contact(
            LastName = 'Test Two',
            Email = 'test@email.com'
        );

        Test.startTest();
        Database.SaveResult sr = Database.insert(c2, false);
        Test.stopTest();

        System.assert(!sr.isSuccess(), 'Insert should fail due to duplicate email');
        System.assert(
            sr.getErrors()[0].getMessage().contains('Duplicate found'),
            'Duplicate email error expected'
        );
    }

    @IsTest
    static void testDuplicatePhoneOnInsert() {

        Contact c1 = new Contact(
            LastName = 'Phone One',
            Phone = '8888888888'
        );
        insert c1;

        Contact c2 = new Contact(
            LastName = 'Phone Two',
            MobilePhone = '8888888888'
        );

        Test.startTest();
        Database.SaveResult sr = Database.insert(c2, false);
        Test.stopTest();

        System.assert(!sr.isSuccess(), 'Insert should fail due to duplicate phone');
    }

    @IsTest
    static void testUpdateWithoutChange_ShouldPass() {

        Contact c = new Contact(
            LastName = 'Update Test',
            Email = 'unique@email.com'
        );
        insert c;

        // Update but do NOT change email or phone
        c.FirstName = 'Updated';

        Test.startTest();
        update c;
        Test.stopTest();

        System.assert(true, 'Update without duplicate should succeed');
    }

    @IsTest
    static void testUpdateWithDuplicateEmail_ShouldFail() {

        Contact c1 = new Contact(
            LastName = 'Base',
            Email = 'dup@email.com'
        );
        insert c1;

        Contact c2 = new Contact(
            LastName = 'Target',
            Email = 'unique@email.com'
        );
        insert c2;

        // Update to duplicate email
        c2.Email = 'dup@email.com';

        Test.startTest();
        Database.SaveResult sr = Database.update(c2, false);
        Test.stopTest();

        System.assert(!sr.isSuccess(), 'Update should fail due to duplicate email');
    }
}