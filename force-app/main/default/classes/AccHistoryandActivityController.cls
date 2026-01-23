/****************************************************************
* Class Name : AccHistoryandActivityController
* Company : Fingertipplus
* Created Date : 14/01/2026
* @description : Controller class for AccHistoryandActivityCmp   component:added in the account layout
* Purpose: show the account all activity in account record page
* @author : Roopesh T
* Use By : - AccHistoryandActivityCmp Component
* Change Log:
* -----------------------------------------------------------------------------
* Ver | Author 			| Date		 | Description
* -----------------------------------------------------------------------------
* 1.0 | Roopesh | 14/01/2026 | Initial version
* -----------------------------------------------------------------------------
******************************************************************/



global class AccHistoryandActivityController {

    @AuraEnabled
    public static list<WrapSObject> GetData(string ldId, string filter){
        list<WrapSObject> glist = new list<WrapSObject>();
         String type='Account';
		Map<String, Schema.SObjectType> schemaMap = Schema.getGlobalDescribe();
		Schema.SObjectType AccountSchema = schemaMap.get(type);
		Map<String, Schema.SObjectField> fieldMap = AccountSchema.getDescribe().fields.getMap();
        
        if(filter == 'All' || filter == 'Field Updates'){
            list<AccountHistory> llist = [SELECT CreatedById, CreatedBy.Name, CreatedDate, Field, Id, AccountID, NewValue, OldValue FROM AccountHistory WHERE AccountID=:ldId];
           system.debug(llist);
            for(AccountHistory lh:llist){
                if(lh.Field != null){
                    WrapSObject WSO = new WrapSObject();
                    WSO.CreatedByID=lh.CreatedByID;
                    WSO.CreatedBy=lh.CreatedBy.Name;
                    WSO.CreatedDate=lh.CreatedDate;
                    WSO.type = 'History';
                    system.debug(lh.Field);
          
                    WSO.AccountID=lh.AccountID;
                    if(lh.Field=='accountCreatedFromLead'){
                       WSO.Field='Created'; 
                         WSO.CreatedBy='account Created From Lead';
                    } 
                    else if( lh.Field=='Created'){
                        WSO.CreatedBy='SAP Created';
                    }
                    String newval = String.valueOf(lh.NewValue);
                    String oldval = String.valueOf(lh.OldValue);
                    if(newval != null) 
                        if(!newval.startsWith('005'))
                        WSO.NewValue= newval;
                    
                    if(oldval != null) 
                        if(!oldval.startsWith('005'))
                        WSO.OldValue=  oldval;
                    
                    glist.add(WSO);
                }
                
                
            }
        }
        
        if(filter == 'All' || filter == 'Activities'){
            list<Account> leadlist = [SELECT ID,(SELECT Id, ActivityDate, ActivityDateTime, ActivityType, Subject, Description, CreatedDate, CreatedById,CreatedBy.Name , ActivitySubtype FROM ActivityHistories order by  ActivityDate DESC, LastModifiedDate DESC limit 500) FROM Account  where id=:ldId];
            
            for(Account l:leadlist){
                
                for(integer i=0;i<l.ActivityHistories.size();i++){
                    if(l.ActivityHistories[i].Subject != null){
                        WrapSObject WSO = new WrapSObject(); 
                        WSO.CreatedByID=l.ActivityHistories[i].CreatedById;
             
                         WSO.CreatedDate=l.ActivityHistories[i].CreatedDate;
                        WSO.type = 'Activity';
                        WSO.Subject=l.ActivityHistories[i].Subject;
                        WSO.Description=l.ActivityHistories[i].Description;
                        glist.add(WSO);
                        
                    }
                    
                }
                
                
            } 
            
            system.debug(glist);
        }
        
        
        if(filter == 'All' || filter == 'Quotes'){
            list<Quote> QuoteList = [SELECT ID,Name,Total_Amount__c,CreatedDate,Owner.Name FROM Quote where accountId=:ldId];
            
            for(Quote l:QuoteList){
                
                WrapSObject WSO = new WrapSObject(); 
                WSO.CreatedBy=l.Owner.Name;
                WSO.CreatedDate=l.CreatedDate;
                WSO.TotAmount=l.Total_Amount__c;
                
                WSO.type = 'Quotes';
                WSO.LeadName = l.Name;
                
                glist.add(WSO);
                
                
                
            } 
        }
        if(filter == 'All' || filter == 'Contacts'){
            list<Contact> leadlist = [SELECT ID,name,Owner.Name,createddate FROM Contact  where Accountid=:ldId];
            
            for(Contact l:leadlist){
                
                WrapSObject WSO = new WrapSObject(); 
                WSO.CreatedBy=l.Owner.Name;
                WSO.CreatedDate=l.createddate;
                
                WSO.type = 'Contacts';
                WSO.LeadName = l.name;
                
                glist.add(WSO);
                
                
                
            } 
        }
        
        if(filter == 'All' || filter == 'Invoices'){
            list<Invoice__c> leadlist = [SELECT ID,name,Doc_Num__c,Invoice_Amount__c,Invoice_Date__c,CreatedDate,Owner.Name FROM Invoice__c  where Account__c=:ldId];
            
            for(Invoice__c l:leadlist){
                
                WrapSObject WSO = new WrapSObject(); 
                WSO.CreatedBy=l.Owner.Name;
                WSO.CreatedDate=l.Invoice_Date__c;
                
                WSO.type = 'Invoices';
                WSO.LeadName = l.name;
                WSO.TotAmount=l.Invoice_Amount__c;
                glist.add(WSO);
                
                
                
            } 
        }
        if(filter == 'All' || filter == 'Opportunities'){
            list<Opportunity> leadlist = [SELECT ID,name,StageName,CreatedDate FROM Opportunity  where AccountId=:ldId];
            
            for(Opportunity l:leadlist){
                
                WrapSObject WSO = new WrapSObject(); 
                WSO.CreatedBy=l.StageName;
                WSO.CreatedDate=l.CreatedDate;
                
                WSO.type = 'Opportunities';
                WSO.LeadName = l.name;
                
                glist.add(WSO);
                
                
                
            } 
        }
        
        if(filter == 'All' || filter == 'SalesOrder'){
            list<order> orderList = [SELECT ID,Name,TotalAmount,CreatedDate,Owner.Name FROM order where accountId=:ldId];
            
            for(order l:orderList){
                
                WrapSObject WSO = new WrapSObject(); 
                WSO.CreatedBy=l.Owner.Name;
                WSO.CreatedDate=l.CreatedDate;
                WSO.TotAmount=l.TotalAmount;
                
                WSO.type = 'Sales Orders';
                WSO.LeadName = l.Name;
                
                glist.add(WSO);
                
                
                
            } 
        }
          if(filter == 'All' || filter == 'DeliveryPlans'){
            list<Delivery_Group__c> leadlist = [SELECT ID,name,Delivery_Status__c,CreatedDate FROM Delivery_Group__c  where Account__c=:ldId];
            
            for(Delivery_Group__c l:leadlist){
                
                WrapSObject WSO = new WrapSObject(); 
                WSO.CreatedBy=l.Delivery_Status__c;
                WSO.CreatedDate=l.CreatedDate;
                
                WSO.type = 'Delivery Plans';
                WSO.LeadName = l.name;
                
                glist.add(WSO);
                
                
                
            } 
        }

        system.debug('glist:' + glist);
        glist.sort();
        return glist;
    }
    
    global class WrapSObject implements Comparable{
        @AuraEnabled public string CreatedByID{set;get;}
        @AuraEnabled public string CreatedBy{set;get;}
        @AuraEnabled public DateTime CreatedDate{set;get;}
        @AuraEnabled public string Field{set;get;}
        @AuraEnabled public string RecordID{set;get;}
        @AuraEnabled public string AccountID{set;get;}
        @AuraEnabled public string NewValue{set;get;}
        @AuraEnabled public string OldValue{set;get;}
        @AuraEnabled public string Subject{set;get;}
        @AuraEnabled public string Description{set;get;}
        @AuraEnabled public string type{set;get;}
         @AuraEnabled public string LeadName{set;get;}
         @AuraEnabled public decimal TotAmount{set;get;}
        @AuraEnabled public string CallType{set;get;}
       
        @AuraEnabled public string comments{set;get;}
        
        public  Integer compareTo(Object anotherObject){
            WrapSObject wso2=(WrapSObject) anotherObject;
            if(CreatedDate>wso2.CreatedDate){
                return -1;
            }else if(CreatedDate<wso2.CreatedDate){
                return 1;
            }
            return 0;
        }
        
        
    }
    
}