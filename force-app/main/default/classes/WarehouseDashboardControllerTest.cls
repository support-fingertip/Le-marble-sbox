@IsTest
private class WarehouseDashboardControllerTest {
    @IsTest
    static void testInstantiation() {
        Test.startTest();
        WarehouseDashboardController controller = new WarehouseDashboardController();
        Test.stopTest();

        System.assertNotEquals(null, controller);
    }
}