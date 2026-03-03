/**
 * Class containing tests for SiteRegisterController
 */
@IsTest
public with sharing class SiteRegisterControllerTest {
    
    @IsTest
    static void testControllerProperties() {
        SiteRegisterController controller = new SiteRegisterController();
        
        // Test property setters and getters
        controller.username = 'testuser@force.com';
        controller.email = 'testuser@force.com';
        controller.communityNickname = 'testnick';
        controller.password = 'Test1234!';
        controller.confirmPassword = 'Test1234!';
        
        System.assertEquals('testuser@force.com', controller.username, 'Username should be set');
        System.assertEquals('testuser@force.com', controller.email, 'Email should be set');
        System.assertEquals('testnick', controller.communityNickname, 'Community nickname should be set');
        System.assertEquals('Test1234!', controller.password, 'Password should be set');
        System.assertEquals('Test1234!', controller.confirmPassword, 'Confirm password should be set');
    }
    
    @IsTest
    static void testPasswordMismatch() {
        SiteRegisterController controller = new SiteRegisterController();
        controller.username = 'mismatch@force.com';
        controller.email = 'mismatch@force.com';
        controller.communityNickname = 'mismatchnick';
        controller.password = 'Password123!';
        controller.confirmPassword = 'DifferentPassword123!';
        
        Test.startTest();
        PageReference result = controller.registerUser();
        Test.stopTest();
        
        // Should return null due to password mismatch
        System.assertEquals(null, result, 'Should return null when passwords do not match');
    }
    
    @IsTest
    static void testRegisterUserWithMatchingPasswords() {
        SiteRegisterController controller = new SiteRegisterController();
        controller.username = 'newuser@force.com';
        controller.email = 'newuser@force.com';
        controller.communityNickname = 'newnick';
        controller.password = 'ValidPass123!';
        controller.confirmPassword = 'ValidPass123!';
        
        Test.startTest();
        // registerUser will return null when not accessed as guest user
        PageReference result = controller.registerUser();
        Test.stopTest();
        
        // In test context, Site.createPortalUser returns null
        System.assertEquals(null, result, 'Should return null in test context');
    }
    
    @IsTest
    static void testRegisterUserWithNullPassword() {
        SiteRegisterController controller = new SiteRegisterController();
        controller.username = 'nullpass@force.com';
        controller.email = 'nullpass@force.com';
        controller.communityNickname = 'nullpassnick';
        controller.password = null;
        controller.confirmPassword = null;
        
        Test.startTest();
        PageReference result = controller.registerUser();
        Test.stopTest();
        
        // Should handle null password gracefully
        System.assertEquals(null, result, 'Should return null with null password');
    }
    
    @IsTest
    static void testTrimWhitespace() {
        SiteRegisterController controller = new SiteRegisterController();
        
        // Test that whitespace is trimmed
        controller.password = '  Password123!  ';
        controller.confirmPassword = '  Password123!  ';
        controller.communityNickname = '  testnick  ';
        
        System.assertEquals('Password123!', controller.password, 'Password should be trimmed');
        System.assertEquals('Password123!', controller.confirmPassword, 'Confirm password should be trimmed');
        System.assertEquals('testnick', controller.communityNickname, 'Community nickname should be trimmed');
    }
}