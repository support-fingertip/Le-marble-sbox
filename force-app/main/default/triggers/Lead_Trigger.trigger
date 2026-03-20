trigger Lead_Trigger on Lead (before insert, before update, after insert, after update) {

    if(trigger.isInsert && trigger.isBefore){
        LeadTriggerHandler.beforeInsert(trigger.new);
    }

    if(trigger.isUpdate && trigger.isBefore){
        LeadTriggerHandler.beforeUpdate(trigger.new, trigger.oldMap);
    }

    if(trigger.isInsert && trigger.isAfter){
        LeadTriggerHandler.afterInsert(trigger.new);
    }

    if(trigger.isUpdate && trigger.isAfter){
        LeadTriggerHandler.afterUpdate(trigger.new, trigger.oldMap);
    }
}