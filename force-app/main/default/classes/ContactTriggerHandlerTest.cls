@isTest
public class ContactTriggerHandlerTest {

    private static Contact createContact(String email, String phone) {
        return new Contact(
            FirstName = 'Test',
            LastName = 'User',
            Email = email,
            Phone = phone,
            MobilePhone = null,
            OtherPhone = null,
            HomePhone = null,
            Phone_Number__c = null
        );
    }

    @isTest
    static void testDuplicateEmail_Insert() {

        // Insert first contact
        Contact existing = createContact('duplicate@test.com', '1111111111');
        insert existing;

        // Attempt duplicate email
        Contact duplicate = createContact('duplicate@test.com', '2222222222');

        Test.startTest();
        Database.SaveResult sr = Database.insert(duplicate, false);
        Test.stopTest();

        System.assertEquals(false, sr.isSuccess(), 'Insert should fail');

        Boolean foundError = false;
        for (Database.Error err : sr.getErrors()) {
            if (err.getMessage().contains('Duplicate found')) {
                foundError = true;
            }
        }

        System.assertEquals(true, foundError, 'Expected duplicate email error');
    }
}