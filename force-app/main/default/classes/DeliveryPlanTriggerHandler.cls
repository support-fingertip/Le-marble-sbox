Public class DeliveryPlanTriggerHandler {

    // Fetch Admin User ID
    private static Id adminId = [
        SELECT Id
        FROM User
        WHERE Profile.Name = 'System Administrator'
        AND IsActive = true
        LIMIT 1
    ].Id;

    // Fetch Notification Type
    private static CustomNotificationType dpType = [
        SELECT Id
        FROM CustomNotificationType
        WHERE DeveloperName = 'DeliveryPlan_Notification'
        LIMIT 1
    ];

    // Block Delivered status without approval
    public static void beforeUpdate( List<Delivery_Group__c> newList, Map<Id, Delivery_Group__c> oldMap) {
        for (Delivery_Group__c newDp : newList) {
            Delivery_Group__c oldDp = oldMap.get(newDp.Id);

            if (
                newDp.Delivery_Status__c == 'Delivered' &&
                oldDp.Delivery_Status__c != 'Delivered'
            ) {
                if (newDp.Approval_Status__c != 'Approved') {
                    newDp.addError(
                        'You cannot mark this Delivery Plan as Delivered until it is approved by the Warehouse Manager.'
                    );
                }
            }
        }
    }

    // Notify Admin when Delivery Plan is created
    public static void afterInsert(List<Delivery_Group__c> newPlans) {
        for (Delivery_Group__c dp : newPlans) {
            Messaging.CustomNotification noti =
                new Messaging.CustomNotification();

            noti.setTitle('Delivery Plan Created');
            noti.setBody(
                'A new Delivery Plan "' + dp.Name + '" has been created.'
            );
            noti.setNotificationTypeId(dpType.Id);
            noti.setTargetId(dp.Id);
            noti.send(new Set<String>{ adminId });
        }
    }

    // Notify Admin when Delivery Plan is marked Delivered
    public static void afterUpdate(List<Delivery_Group__c> newList, Map<Id, Delivery_Group__c> oldMap ) {
        for (Delivery_Group__c newDp : newList) {
            Delivery_Group__c oldDp = oldMap.get(newDp.Id);

            if (oldDp.Delivery_Status__c != 'Delivered' && newDp.Delivery_Status__c == 'Delivered' )
            {
                Messaging.CustomNotification noti = new Messaging.CustomNotification();

                noti.setTitle('Delivery Plan Delivered');
                noti.setBody(
                    'Delivery Plan "' + newDp.Name + '" has been marked as Delivered.'
                );
                noti.setNotificationTypeId(dpType.Id);
                noti.setTargetId(newDp.Id);
                noti.send(new Set<String>{ adminId });
            }
        }
    }

    // Populate Warehouse Manager based on Warehouse
    public static void populateWarehouseManager( List<Delivery_Group__c> newList,Map<Id, Delivery_Group__c> oldMap) {
        Set<Id> warehouseIds = new Set<Id>();

        for (Delivery_Group__c dp : newList) {
            if (
                dp.Warehouse__c != null &&
                (
                    oldMap == null ||
                    !oldMap.containsKey(dp.Id) ||
                    dp.Warehouse__c != oldMap.get(dp.Id).Warehouse__c
                )
            ) {
                warehouseIds.add(dp.Warehouse__c);
            }
        }

        if (warehouseIds.isEmpty()) return;

        Map<Id, Warehouse__c> warehouseMap =
            new Map<Id, Warehouse__c>([
                SELECT Id, Warehouse_Manager__c
                FROM Warehouse__c
                WHERE Id IN :warehouseIds
            ]);

        for (Delivery_Group__c dp : newList) {
            if (
                dp.Warehouse__c != null &&
                warehouseMap.containsKey(dp.Warehouse__c)
            ) {
                dp.Warehouse_Manager__c =
                    warehouseMap.get(dp.Warehouse__c).Warehouse_Manager__c;
            }
        }
    }
    

    // 🔹 Delivery Plan Created
    public static void onCreate(List<Delivery_Group__c> newOrders) {
        List<Delivery_Group__c> ordersWithQuote = new List<Delivery_Group__c>();

        for (Delivery_Group__c o : newOrders) {
            if (o.QuoteId__c != null) {
                ordersWithQuote.add(o);
            }
        }

        if (!ordersWithQuote.isEmpty()) {
            sendNotification(
                ordersWithQuote,
                'Delivery Plan Created from Salse Order',
                'A new Delivery Plan has been created from your quote.'
            );
        }
    }

    // 🔹 Order Approved / Rejected
    public static void onStatusChange(List<Delivery_Group__c> newList, Map<Id, Delivery_Group__c> oldMap) {
        List<Delivery_Group__c> approvedOrders = new List<Delivery_Group__c>();
        List<Delivery_Group__c> rejectedOrders = new List<Delivery_Group__c>();

        for (Delivery_Group__c o : newList) {
            Delivery_Group__c old = oldMap.get(o.Id);

            if (o.Approval_Status__c != old.Approval_Status__c && o.QuoteId__c != null) {
                if (o.Approval_Status__c == 'Activated') {
                    approvedOrders.add(o);
                } else if (o.Approval_Status__c == 'Rejected') {
                    rejectedOrders.add(o);
                }
            }
        }

        if (!approvedOrders.isEmpty()) {
            sendNotification(approvedOrders,'Delivery Plan Approved', 'Delivery Plan has been approved.');
        }

        if (!rejectedOrders.isEmpty()) {
            sendNotification(rejectedOrders,'Delivery Plan Rejected','Delivery Plan has been rejected.');
        }
    }

    // 🔹 Common Notification Method
    private static void sendNotification( List<Delivery_Group__c> orders, String title, String message) {
        // Collect Quote Ids
        Set<Id> quoteIds = new Set<Id>();
        for (Delivery_Group__c o : orders) {
            quoteIds.add(o.QuoteId__c);
        }

        // Get Quotes
        Map<Id, Quote> quoteMap = new Map<Id, Quote>(
            [SELECT Id, OwnerId FROM Quote WHERE Id IN :quoteIds]
        );


        for (Delivery_Group__c o : orders) {
            Quote q = quoteMap.get(o.QuoteId__c);
            if (q == null) continue;

            Messaging.CustomNotification notification =
                new Messaging.CustomNotification();

            notification.setTitle(title);
            notification.setBody(message + ' Order No: ' + o.Name);
            notification.setNotificationTypeId(dpType.Id);
            notification.setTargetId(o.Id);

            notification.send(new Set<String>{ q.OwnerId });
        }
    }
}