@IsTest
public class DeliveryPlanTriggerHandlerTest {

    
      // COMMON TEST DATA METHOD
    
    private static Delivery_Group__c createDeliveryPlan(String approvalStatus) {

        // Admin user
        User adminUser = [
            SELECT Id
            FROM User
            WHERE Profile.Name = 'System Administrator'
            AND IsActive = true
            LIMIT 1
        ];

        // Warehouse (required fields)
        Warehouse__c wh = new Warehouse__c(
            Name = 'Test Warehouse',
            Warehouse_Manager__c = adminUser.Id,
            Location__c = 'Test Location',
            Total_Capacity__c = 1000
        );
        insert wh;

        // Account
        Account acc = new Account(
            Name = 'Test Account'
        );
        insert acc;

        // STANDARD SALES ORDER (Order)
        Order ord = new Order(
            AccountId = acc.Id,
            EffectiveDate = Date.today(),
            Status = 'Draft'
        );
        insert ord;

        // Delivery Plan (linked to Order)
        Delivery_Group__c dp = new Delivery_Group__c(
            Name = 'Test Delivery Plan',
            Warehouse__c = wh.Id,
            Sales_Order__c = ord.Id,   // 🔴 MUST be lookup to Order
            Quantity__c = 10,
            Delivery_Status__c = 'Draft',
            Approval_Status__c = approvalStatus
        );
        insert dp;

        return dp;
    }

   
      // TEST 1: Warehouse Manager Population
   
    @IsTest
    static void testWarehouseManagerPopulation() {

        Delivery_Group__c dp = createDeliveryPlan('Draft');

        Delivery_Group__c fetchedDp = [
            SELECT Warehouse_Manager__c
            FROM Delivery_Group__c
            WHERE Id = :dp.Id
        ];

        System.assertNotEquals(
            null,
            fetchedDp.Warehouse_Manager__c
        );
    }

   
     //  TEST 2: Block Delivered WITHOUT Approval
   
    @IsTest
    static void testDeliveredWithoutApprovalBlocked() {

        Delivery_Group__c dp = createDeliveryPlan('Draft');
        dp.Delivery_Status__c = 'Delivered';

        Test.startTest();
        try {
            update dp;
            System.assert(false, 'Update should have failed');
        } catch (DmlException e) {
            System.assert(
                e.getMessage().contains('approved')
            );
        }
        Test.stopTest();
    }

   
       //TEST 3: Allow Delivered WITH Approval
   
    @IsTest
    static void testDeliveredWithApprovalAllowed() {

        Delivery_Group__c dp = createDeliveryPlan('Approved');
        dp.Delivery_Status__c = 'Delivered';

        Test.startTest();
        update dp;
        Test.stopTest();

        Delivery_Group__c updatedDp = [
            SELECT Delivery_Status__c
            FROM Delivery_Group__c
            WHERE Id = :dp.Id
        ];

        System.assertEquals(
            'Delivered',
            updatedDp.Delivery_Status__c
        );
    }

  
       //TEST 4: After Insert Logic
    
    @IsTest
    static void testAfterInsertNotification() {

        Test.startTest();
        Delivery_Group__c dp = createDeliveryPlan('Draft');
        Test.stopTest();

        System.assertNotEquals(
            null,
            dp.Id
        );
    }
}