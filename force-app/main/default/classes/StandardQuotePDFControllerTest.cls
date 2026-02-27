@IsTest
private class StandardQuotePDFControllerTest {
    @IsTest
    static void testInstantiation() {
        Test.startTest();
        StandardQuotePDFController controller = new StandardQuotePDFController();
        Test.stopTest();

        System.assertNotEquals(null, controller);
    }
}