({
    getWarehouses : function(component, event, helper) {   
        var action=component.get("c.getitems");
        action.setCallback(this,function(response){ 
            if(response.getState() == "SUCCESS"){ 
                var retValue = response.getReturnValue();
                component.set('v.itemsList',retValue.items);
                component.set('v.userProfile',retValue.prof);
            }
        });
        $A.enqueueAction(action);
    },
    
})