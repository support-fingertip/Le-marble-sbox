@isTest
public class Contact_Trigger_Test {
    
    @isTest
    static void testBeforeInsert() {
        
        Test.startTest();
        
        Contact con = new Contact(
            FirstName = 'Priyanshu',
            LastName = 'Sharma',
            Email = 'testcontact@example.com'
        );
        
        insert con;
        
        Test.stopTest();
        
        // Verify record inserted
        Contact insertedCon = [SELECT Id, Email FROM Contact WHERE Id = :con.Id];
        System.assertEquals('testcontact@example.com', insertedCon.Email);
    }
    
    
    @isTest
    static void testBeforeUpdate() {
        
        Contact con = new Contact(
            FirstName = 'Test',
            LastName = 'User',
            Email = 'beforeupdate@example.com'
        );
        insert con;
        
        Test.startTest();
        
        con.Email = 'afterupdate@example.com';
        update con;
        
        Test.stopTest();
        
        // Verify update worked
        Contact updatedCon = [SELECT Email FROM Contact WHERE Id = :con.Id];
        System.assertEquals('afterupdate@example.com', updatedCon.Email);
    }
}