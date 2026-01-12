@isTest(SeeAllData=false)
private class DeliverySchedulingControllerTest {

    // Helper to grab any active picklist value for a given field
    private static String getAnyActiveValue(Schema.SObjectField fld) {
        for (Schema.PicklistEntry pe 
             : fld.getDescribe().getPicklistValues()) {
            if (pe.isActive()) {
                return pe.getValue();
            }
        }
        return null;
    }

    @testSetup
    static void setupTestData() {
        // 1) Cart (auto-numbered Name)
        Cart__c cart = new Cart__c();
        insert cart;

        // 2) Product
        Product__c prod = new Product__c(
            Name                = 'TestProd', 
            Product_Code__c     = 'TP001',
            MSP__c              = 10.00,
            MRP__c              = 15.00,
            Product_Category__c = 'TestCat',
            UOM__c              = 'Each',
            Price_Sqft__c       = 0,
            Size__c             = 'N/A',
            Sqft_Piece__c       = '1',
            Tax__c              = 0,
            In_Stock__c         = 100
        );
        insert prod;

        // 3) Cart Line Item (requires Cart__c and Product__c)
        Cart_Line_Item__c cli = new Cart_Line_Item__c(
            Cart__c     = cart.Id,
            Product__c  = prod.Id,
            Quantity__c = 3
        );
        insert cli;

        // 4) Sales Confirmation (auto-numbered Name)
        Sales_Confirmation__c salesCon = new Sales_Confirmation__c();
        insert salesCon;

        // 5) Delivery Group
        //    - pick a valid Status__c
        //    - pick a valid Choose_Vehicle__c
        String validStatus  = getAnyActiveValue(Delivery_Group__c.Status__c);
        String validVehicle = getAnyActiveValue(Delivery_Group__c.Choose_Vehicle__c);
        System.assert(validStatus  != null, 'No active Status__c values found');
        System.assert(validVehicle != null, 'No active Choose_Vehicle__c values found');

        Delivery_Group__c grp = new Delivery_Group__c(
            Status__c             = validStatus,
            Delivery_Date__c      = Date.today(),
            Choose_Vehicle__c     = validVehicle,
            Sales_Confirmation__c = salesCon.Id,
            Remarks__c            = 'Test setup'
        );
        insert grp;

        // 6) One Delivery_Line_Item__c under that group
        Delivery_Line_Item__c dli = new Delivery_Line_Item__c(
            Delivery_Group__c   = grp.Id,
            Cart_Line_Item__c   = cli.Id
        );
        insert dli;
    }

    static testMethod void testGetDeliveryGroups_ByGroupName() {
        // Grab back the system-assigned Name & subquery child
        Delivery_Group__c insertedGroup = [
            SELECT Id, Name, Status__c,
                   (SELECT Cart_Line_Item__r.Quantity__c 
                    FROM Delivery_Line_Items__r)
            FROM Delivery_Group__c
            LIMIT 1
        ];

        // Call your controller
        List<Delivery_Group__c> found =
            DeliverySchedulingController.getDeliveryGroups(insertedGroup.Name);

        // Verify top-level fields
        System.assertEquals(1, found.size(), 'Exactly one match by Name');
        System.assertEquals(
            insertedGroup.Status__c,
            found[0].Status__c,
            'Status__c should match what we inserted'
        );

        // Verify child list
        System.assertEquals(
            1,
            found[0].Delivery_Line_Items__r.size(),
            'Should return the single child Delivery_Line_Item__c'
        );
        System.assertEquals(
            3,
            found[0].Delivery_Line_Items__r[0].Cart_Line_Item__r.Quantity__c,
            'Quantity__c should be 3'
        );
    }

    static testMethod void testGetDeliveryGroups_BySalesConfirmationName() {
        // Grab the auto-numbered Sales Confirmation.Name
        String scName = [
            SELECT Sales_Confirmation__r.Name
            FROM Delivery_Group__c
            LIMIT 1
        ].Sales_Confirmation__r.Name;

        List<Delivery_Group__c> found =
            DeliverySchedulingController.getDeliveryGroups(scName);
        System.assertEquals(
            1,
            found.size(),
            'Exactly one match by Sales Confirmation Name'
        );
    }

    static testMethod void testMarkDeliveryAsCompleted_UpdatesStatus() {
        // Re-fetch the group
        Delivery_Group__c beforeUpdate = [
            SELECT Id, Status__c
            FROM Delivery_Group__c
            LIMIT 1
        ];
        
        Test.startTest();
        DeliverySchedulingController.markDeliveryAsCompleted(beforeUpdate.Id);
        Test.stopTest();

        // Verify the Status__c is now "Delivered"
        Delivery_Group__c afterUpdate = [
            SELECT Status__c
            FROM Delivery_Group__c
            WHERE Id = :beforeUpdate.Id
        ];
        System.assertEquals(
            'Delivered',
            afterUpdate.Status__c,
            'markDeliveryAsCompleted should set Status__c = Delivered'
        );
    }
}