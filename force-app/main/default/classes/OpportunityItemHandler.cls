public class OpportunityItemHandler {
    
    public static void handleAfterInsert(List<OpportunityLineItem> newList) {
        System.debug('STEP 1: Trigger fired. New OLI count = ' + newList.size());
        // Product Category → Public Group
        Map<String, String> categoryToGroup = new Map<String, String>{
            'SANITARY'      => 'PG SANITARY',
                'ROOF TILES'    => 'ROOF TILES',
                'ADHESIVE'     => 'ADHESIVES',
                'FITTINGS'      => 'FITTINGS',
                'GLSBRK'   => 'GLASS BRICK',
                'LIGHTS'        => 'LIGHTS',
                'N.STONE' => 'NATURAL STONE',
                'TILE'          => 'TILE'
                };
                    
                    // Collect OLI Ids
                    Set<Id> oliIds = new Set<Id>();
        for (OpportunityLineItem oli : newList) {
            oliIds.add(oli.Id);
        }
        
        // Re-query Product Category
               List<OpportunityLineItem> oliList = [
            SELECT Id, OpportunityId,
                   Product2.Name,
                   Product2.Product_Category__c
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

            List<String> prodNames = new List<String>();
            for (OpportunityLineItem oli : oliList) {
                if (oli.Product2 != null && oli.Product2.Name != null) {
                    prodNames.add(oli.Product2.Name);
                }
            }
            String prodNamesStr = String.join(prodNames, ', ');
            
            notification.setTitle('Opportunity Product Added');
            notification.setBody('Product(s) added: ' + prodNamesStr);
            
            notification.setTargetId(oliList[0].OpportunityId);
            notification.send(notifyUsers);
        }
    }
    
    public static void handleBefore(List<OpportunityLineItem> newList) {
        Set<Id> qliIds = new Set<Id>();
    System.debug('OpportunityItemHandler>handleBefore newList ');    
        // 1. Collect QuoteLineItem Ids from formula field
        for (OpportunityLineItem oli : newList) {
            if (oli.QuoteLineItemId__c != null) {
                qliIds.add((Id) oli.QuoteLineItemId__c);
            }
        }
        
        if (qliIds.isEmpty()) return;
        
        // 2. Query QuoteLineItems
        Map<Id, QuoteLineItem> qliMap = new Map<Id, QuoteLineItem>([
            SELECT Id,Area__c,MSP__c,Disc_Type__c,Dis_Value__c,Sqft__c
            FROM QuoteLineItem
            WHERE Id IN :qliIds
        ]);
        System.debug('qliMap '+qliMap);    
        // 3. Copy value to OpportunityLineItem
        for (OpportunityLineItem oli : newList) {
            if (oli.QuoteLineItemId__c != null) {
                Id qliId = (Id) oli.QuoteLineItemId__c;
                if (qliMap.containsKey(qliId)) {
                  oli.Area__c = qliMap.get(qliId).Area__c;
                    oli.MSP__c = qliMap.get(qliId).MSP__c;
                    oli.Disc_Type__c = qliMap.get(qliId).Disc_Type__c;
                    oli.Dis_Value__c = qliMap.get(qliId).Dis_Value__c;
                    oli.Sqft__c = qliMap.get(qliId).Sqft__c;
                }
            }
        }
    }
}