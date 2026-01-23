public class OpportunityProductNotificationHandler {

    public static void handleAfterInsert(List<OpportunityLineItem> newList) {
    System.debug('STEP 1: Trigger fired. New OLI count = ' + newList.size());
        // Product Category → Public Group
        Map<String, String> categoryToGroup = new Map<String, String>{
            'SANITARY'      => 'PG SANITARY',
            'ROOF TILES'    => 'ROOF TILES',
            'ADHESIVES'     => 'ADHESIVES',
            'FITTINGS'      => 'FITTINGS',
            'GLASS BRICK'   => 'GLASS BRICK',
            'LIGHTS'        => 'LIGHTS',
            'NATURAL STONE' => 'NATURAL STONE',
            'TILE'          => 'TILE'
        };

        // Collect OLI Ids
        Set<Id> oliIds = new Set<Id>();
        for (OpportunityLineItem oli : newList) {
            oliIds.add(oli.Id);
        }

        // Re-query Product Category
        List<OpportunityLineItem> oliList = [
            SELECT Id, OpportunityId, Product2.Product_Category__c
            FROM OpportunityLineItem
            WHERE Id IN :oliIds
        ];
        System.debug('STEP 2: Re-queried OLIs = ' + oliList.size());


        // Fetch users from Public Groups
        Map<String, Set<String>> groupToUsers = new Map<String, Set<String>>();

        for (GroupMember gm : [
            SELECT Group.Name, UserOrGroupId
            FROM GroupMember
            WHERE Group.Name IN :categoryToGroup.values()
        ]) {
            if (gm.UserOrGroupId.getSObjectType() == User.SObjectType) {

                if (!groupToUsers.containsKey(gm.Group.Name)) {
                    groupToUsers.put(gm.Group.Name, new Set<String>());
                }
                groupToUsers
                    .get(gm.Group.Name)
                    .add(String.valueOf(gm.UserOrGroupId));
            }
        }

        // Notification Type
        CustomNotificationType cnt = [
            SELECT Id
            FROM CustomNotificationType
            WHERE DeveloperName = 'Opportunity_Product_Added'
            LIMIT 1
        ];

        // Resolve users
        Set<String> notifyUsers = new Set<String>();

        for (OpportunityLineItem oli : oliList) {
        System.debug(
    'STEP 3: Product Category = ' +
    oli.Product2.Product_Category__c
);
            String grp = categoryToGroup.get(oli.Product2.Product_Category__c);
            if (grp != null && groupToUsers.containsKey(grp)) {
                notifyUsers.addAll(groupToUsers.get(grp));
            }
        }

        // Send notification (QUOTE STYLE)
        System.debug('STEP 4: Users resolved for notification = ' + notifyUsers);
        if (!notifyUsers.isEmpty()) {

            Messaging.CustomNotification notification =
                new Messaging.CustomNotification();

            notification.setNotificationTypeId(cnt.Id);
            notification.setTitle('Opportunity Product Added');
            notification.setBody('A product has been added to an opportunity');
            notification.setTargetId(oliList[0].OpportunityId);

            notification.send(notifyUsers);
        }
    }
}