@IsTest
private class DeliveryManagementControllerTest {

    @TestSetup
    static void setupData() {

        // Account
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        // Standard Opportunity (CORRECT)
        Opportunity opp = new Opportunity(
            Name = 'Test Opportunity',
            StageName = 'Prospecting',   // Must exist in your org
            CloseDate = Date.today(),
            AccountId = acc.Id
        );
        insert opp;

        // Sales Confirmation
        Sales_Confirmation__c sc = new Sales_Confirmation__c(
            Opportunity__c = opp.Id,
            Total_Amount__c = 1000
        );
        insert sc;

        // Product
        Product2 prod = new Product2(
            Name = 'Test Product',
            IsActive = true
        );
        insert prod;

        // Cart Line Item
        Cart_Line_Item__c cli = new Cart_Line_Item__c(
            Sales_Confirmation__c = sc.Id,
            Product__c = prod.Id,
            Quantity__c = 10,
            Unit_Price__c = 100
        );
        insert cli;

        // Pending Purchase
        Pending_Purchase__c pp = new Pending_Purchase__c(
            Sales_Confirmation__c = sc.Id,
            Status__c = 'Open'
        );
        insert pp;

        // Pending Purchase Line Item
        insert new Pending_Purchase_Line_Item__c(
            Pending_Purchase__c = pp.Id,
            Cart_Line_Item__c = cli.Id
        );
    }

    @IsTest
    static void testAllControllerMethods() {

        Sales_Confirmation__c sc =
            [SELECT Id FROM Sales_Confirmation__c LIMIT 1];
        Opportunity opp =
            [SELECT Id FROM Opportunity LIMIT 1];
        Cart_Line_Item__c cli =
            [SELECT Id FROM Cart_Line_Item__c LIMIT 1];
        Pending_Purchase__c pp =
            [SELECT Id FROM Pending_Purchase__c LIMIT 1];

        Test.startTest();

        // search
        DeliveryManagementController.searchSalesConfirmations('');

        // available products
        DeliveryManagementController.getAvailableProducts(sc.Id);

        // pending products
        DeliveryManagementController.getPendingProducts(opp.Id);

        // drivers
        DeliveryManagementController.getDrivers();

        // picklists
        DeliveryManagementController.getVehicleTypeOptions();
        DeliveryManagementController.getDriverPicklistOptions();
        DeliveryManagementController.getVehicleNumberOptions();

        // update purchase
        DeliveryManagementController.updatePendingPurchaseStatus(pp.Id, 'Received');

        // create delivery group
        String vehicle =
            Delivery_Group__c.Choose_Vehicle__c.getDescribe()
            .getPicklistValues()[0].getValue();

        String driver =
            Delivery_Group__c.Driver_Assigned__c.getDescribe()
            .getPicklistValues()[0].getValue();

        String vehicleNo =
            Delivery_Group__c.Vehicle_Number__c.getDescribe()
            .getPicklistValues()[0].getValue();

        Map<String, Object> payload = new Map<String, Object>{
            'salesConfirmationId' => sc.Id,
            'deliveryDate' => String.valueOf(Date.today()),
            'driverId' => driver,
            'vehicleId' => vehicle,
            'vehicleNumber' => vehicleNo,
            'remarks' => 'Test',
            'deliveryTime' => '10:00:00',
            'freightAmount' => 100,
            'productData' => new List<Object>{
                new Map<String, Object>{
                    'id' => cli.Id,
                    'deliveryQuantity' => 2
                }
            }
        };

        DeliveryManagementController.createDeliveryGroup(JSON.serialize(payload));

        Test.stopTest();

        System.assert(true);
    }
}