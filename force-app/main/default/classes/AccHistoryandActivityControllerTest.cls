@IsTest
private class AccHistoryandActivityControllerTest {
    @IsTest
    static void testGetDataContactsFilter() {
        Account acc = new Account(Name = 'AHA Test Account');
        insert acc;

        Contact con = new Contact(LastName = 'AHA Contact', AccountId = acc.Id);
        insert con;

        Test.startTest();
        List<AccHistoryandActivityController.WrapSObject> result =
            AccHistoryandActivityController.GetData(acc.Id, 'Contacts');
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assert(result.size() > 0, 'Expected at least one wrapped contact row.');
    }
}