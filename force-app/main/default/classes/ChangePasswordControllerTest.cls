@isTest
public class ChangePasswordControllerTest {
    
    @isTest
    static void testChangePasswordMethod() {
        
        // Create test user
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        
        User u = new User(
            FirstName = 'Test',
            LastName = 'User',
            Email = 'testuser@example.com',
            Username = 'testuser' + DateTime.now().getTime() + '@example.com',
            Alias = 'tuser',
            TimeZoneSidKey = 'Asia/Kolkata',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = p.Id,
            LanguageLocaleKey = 'en_US'
        );
        insert u;

        System.runAs(u) {
            
            Test.startTest();
            
            ChangePasswordController controller = new ChangePasswordController();
            
            controller.oldPassword = 'OldPassword123';
            controller.newPassword = 'NewPassword123';
            controller.verifyNewPassword = 'NewPassword123';
            
            PageReference result = controller.changePassword();
            
            Test.stopTest();
            
            // Since Site context is not available in test,
            // result can be null but method should execute
            System.assertEquals(null, result);
        }
    }
}