({
    getWarehouses : function(component, event, helper) {   
        var action=component.get("c.getWarehouses");
        action.setCallback(this,function(response){ 
            if(response.getState() == "SUCCESS"){ 
                var retValue = response.getReturnValue();
                component.set('v.WarehouseList',retValue.warehouse);
                component.set('v.userProfile',retValue.prof);
            }
        });
        $A.enqueueAction(action);
    },
    
})