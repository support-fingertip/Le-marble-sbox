({
    doInit : function(component, event, helper) {
        component.set('v.spinner',true);
        helper.getWarehouses(component, event, helper);
        var action=component.get("c.getAccount");
        
        action.setCallback(this,function(response){ 
            if(response.getState() == "SUCCESS"){ 
                var retValue = response.getReturnValue();
                component.set('v.Accounts',retValue);
                component.set('v.spinner',false);
            }
            
        });
        $A.enqueueAction(action); 
        
    },

    navigateToComponent : function(component, event, helper) {
        var CustName= component.get('v.customerName'); 
        var typ= component.get('v.selectedType');
        var warehouse= component.get('v.warehouse');
        if ((CustName!=undefined && CustName!='')|| typ=='Stock'){
            var componentName = "c:showOutstandingComp"; 
            
            //  var Tdate= component.get('v.ToDate'); 
            var CCode= component.get('v.customerCode');
            var navigateEvent = $A.get("e.force:navigateToComponent");
            navigateEvent.setParams({
                componentDef : componentName,
                componentAttributes: {
                    selectedType: typ,
                    CustName: CustName,
                    CustCode: CCode,
                    Warehouse:warehouse
                }
            });
            
            navigateEvent.fire();
        }
        else{
            var toastEvent = $A.get("e.force:showToast");
            toastEvent.setParams({
                "type":'Error',
                "message":  'Please Select Customer Name'
            });
            toastEvent.fire();

        }
    },    
    
    ondataTypeChange : function(component, event, helper) {
        component.set('v.fromDate','');
        component.set('v.ToDate','');
        component.set('v.customerName','');  
        var sit= component.get('v.WarehouseList');  

    },
    refreshOutstandingData: function(component, event, helper) {
        var  recordId =  component.get('v.customerId');
        var startDate = component.get('v.fromDate');
        var endDate = component.get('v.ToDate');
    
        
        
    },
 
    
    searchText2 : function(component, event, helper) {
        
        var Accounts= component.get('v.Accounts');
        var pr=JSON.parse(JSON.stringify(Accounts));
        // console.log(pr);
        var searchText= component.get('v.searchText2');
        if(searchText!=undefined && searchText!=''){    
            var matchacc=[];
            if(searchText !=''){
                for(var i=0;i<Accounts.length; i++){ 
                    if(Accounts[i].Name.toLowerCase().indexOf(searchText.toLowerCase())  != -1  ){
                        matchacc.push( Accounts[i] );
                    } 
                } 
                if(matchacc.length >0){
                    component.set('v.matchacc',matchacc);
                }
            }else{
                component.set('v.matchacc',[]);
            }
        }
        else{
            component.set('v.matchacc',[]);
        }    
    },
    update: function(component, event, helper) {
        component.set('v.spinner', true);
        var index = event.currentTarget.dataset.record;
        // alert(index)
        var pid =event.currentTarget.dataset.id;
        var acc= component.get('v.matchacc');
        
        for(var i=0;i<acc.length; i++){ 
            if(acc[i].Id === pid ){
                component.set('v.customerId', acc[i].Id); 
                component.set('v.customerName', acc[i].Name); 
                component.set('v.customerCode', acc[i].Customer_Code__c); 
                component.set('v.searchText2', acc[i].Name);
                break;
            }
            
        } 
        
        component.set('v.matchacc',[]);
        component.set('v.spinner', false);
        
        
    },
    sendRequest : function(component, event, helper) {
         component.set('v.spinner',true);
          var fromDate= component.get('v.fromDate');
          var selectedStatus= component.get('v.selectedStatus');
          var Warehouse= component.get('v.warehouse');
        
        var action=component.get("c.callInvoices");
        action.setParams({
            "formattedDate":fromDate
            });
        action.setCallback(this,function(response){ 
          //  if(response.getState() == "SUCCESS"){ 
            component.set('v.fromDate','');
            component.set('v.selectedStatus','');
            component.set('v.warehouse','');
            component.set('v.selectedType','');
            component.set('v.spinner',false);
         //   }
        });
        $A.enqueueAction(action);
    },
    sendRecieptRequest: function(component, event, helper) {
        
         component.set('v.spinner',true);
          var fromDate= component.get('v.fromDate');
        var action=component.get("c.getReceipts");
        action.setParams({
            "fromDate":fromDate,
            "toDate":fromDate
            });
        action.setCallback(this,function(response){ 
          //  if(response.getState() == "SUCCESS"){ 
            component.set('v.fromDate','');
            component.set('v.selectedType','');
            component.set('v.spinner',false);
         //   }
        });
        $A.enqueueAction(action);
    },
})