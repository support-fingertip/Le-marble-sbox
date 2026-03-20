@IsTest
public class SalesOrderTriggerHandlerTest {
    
    @IsTest
    static void testIsRunningFlag() {
        // Test default value
        System.assertEquals(false, SalesOrderTriggerHandler.isRunning, 'isRunning should default to false');
        
        // Test setting to true
        SalesOrderTriggerHandler.isRunning = true;
        System.assertEquals(true, SalesOrderTriggerHandler.isRunning, 'isRunning should be true after setting');
        
        // Test setting back to false
        SalesOrderTriggerHandler.isRunning = false;
        System.assertEquals(false, SalesOrderTriggerHandler.isRunning, 'isRunning should be false after resetting');
    }
    
    @IsTest
    static void testClassInstantiation() {
        // Test that class can be instantiated
        Test.startTest();
        SalesOrderTriggerHandler handler = new SalesOrderTriggerHandler();
        Test.stopTest();
        
        System.assertNotEquals(null, handler, 'Handler should be instantiated');
    }
}