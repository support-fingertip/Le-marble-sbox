({
    doInit : function(component, event, helper) {
        console.log(component.get("v.recordId"))
        var pageSize = component.get("v.pageSize");
        //alert(component.get('v.selFilter'));
        var action = component.get("c.GetData");
        action.setParams({
            ldId: component.get("v.recordId"),
            filter: component.get('v.selFilter')
        }); 
        action.setCallback(this, function(response){ 
            if(response.getState()=="SUCCESS"){ 
                
                console.log('values:'+JSON.stringify(response.getReturnValue()))
                component.set("v.AccountData",response.getReturnValue());
                component.set("v.initDone","true");
                console.log(component.get("v.AccountData"));
                
                component.set("v.totalSize", component.get("v.AccountData").length);
                component.set("v.start",0);
                component.set("v.end",pageSize-1);
                
                var paginationList = [];
                for(var i=0; i< pageSize; i++)
                {
                    paginationList.push(response.getReturnValue()[i]);
                }
                component.set("v.paginationList", paginationList);
            }
        });
        $A.enqueueAction(action);
    },
    onChange : function(component, event, helper){
      //  alert(component.get('v.selFilter'));
       // var selVal = component.find('filter').get('v.value');
         var pageSize = component.get("v.pageSize");
        //alert(component.get('v.selFilter'));
        var action = component.get("c.GetData");
        action.setParams({
            ldId: component.get("v.recordId"),
            filter: component.get('v.selFilter')
        }); 
        action.setCallback(this, function(response){ 
            if(response.getState()=="SUCCESS"){ 
                
                console.log('values:'+JSON.stringify(response.getReturnValue()))
                component.set("v.AccountData",response.getReturnValue());
                component.set("v.initDone","true");
                console.log(component.get("v.AccountData"));
                
                component.set("v.totalSize", component.get("v.AccountData").length);
                component.set("v.start",0);
                component.set("v.end",pageSize-1);
                
                var paginationList = [];
                for(var i=0; i< pageSize; i++)
                {
                    paginationList.push(response.getReturnValue()[i]);
                }
                component.set("v.paginationList", paginationList);
            }
        });
        $A.enqueueAction(action);
        
    },
   
    first : function(component, event, helper)
    {
        
        var oppList = component.get("v.AccountData");
        var pageSize = component.get("v.pageSize");
        var paginationList = [];
        for(var i=0; i< pageSize; i++)
        {
            paginationList.push(oppList[i]);
        }
        component.set("v.paginationList", paginationList);
        component.set("v.start",0);
        component.set("v.end",1);
    },
    
    last : function(component, event, helper)
    {
        
        var oppList = component.get("v.AccountData");
        var pageSize = component.get("v.pageSize");
        var totalSize = component.get("v.totalSize");
        var paginationList = [];
        
        for(var i=totalSize-pageSize+1; i< totalSize; i++)
        {
            paginationList.push(oppList[i]);
        }
        component.set("v.paginationList", paginationList);
       component.set("v.start",1);
        component.set("v.end",totalSize);
    },
    
    next : function(component, event, helper)
    {
        
        var oppList = component.get("v.AccountData");
        var end = component.get("v.end");
        var start = component.get("v.start");
        var pageSize = component.get("v.pageSize");
        var paginationList = [];
        var counter = 0;
        
        for(var i=end+1; i<end+pageSize+1; i++)
        {
            if(oppList.length > end)
            {
                paginationList.push(oppList[i]);
                counter ++ ;
            }
        }
        
        start = start + counter;
        end = end + counter;
        component.set("v.start",start);
        component.set("v.end",end);
        component.set("v.paginationList", paginationList);
        
    },
    
    previous : function(component, event, helper)
    {
        
        var oppList = component.get("v.AccountData");
        var end = component.get("v.end");
        var start = component.get("v.start");
        var pageSize = component.get("v.pageSize");
        var paginationList = [];
        var counter = 0;
        
        for(var i= start-pageSize; i < start ; i++)
        {
            if(i > -1)
            {
                paginationList.push(oppList[i]);
                counter ++;
            }
            else {
                start++;
            }
        }
        
        start = start - counter;
        end = end - counter;
        component.set("v.start",start);
        component.set("v.end",end);
        component.set("v.paginationList", paginationList);
    },
     refresh : function(component, event, helper)
    {
        $A.enqueueAction(component.get('c.doInit'));
        $A.get("e.force:refreshView").fire();
    }
})