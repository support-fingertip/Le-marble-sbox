/**
* @File Name : FinanceTransactionController.cls
* @Description : Controller for Payment__c object operations
* @Author :
* @Last Modified By :
* @Last Modified On : March 17, 2025
* @Modification Log :
*==============================================================================
* Ver | Date | Author | Modification
*==============================================================================
* 1.0 | March 17, 2025 |   | Initial Version
**/

public with sharing class FinanceTransactionController {
    @AuraEnabled(cacheable=true)
    public static List<Payment__c> getFinanceTransactions() {
        try {
            // First, get all payments without relationships to check if records exist
            List<Payment__c> allPayments = [
                SELECT Id, Name, Opportunity__c
                FROM Payment__c
                LIMIT 10
            ];
            System.debug('Total Payments found: ' + allPayments.size());
            
            // Now get the detailed records with relationships
            List<Payment__c> payments = [
                SELECT Id, Name, 
                       Opportunity__c,
                       Opportunity__r.Name,
                       Opportunity__r.Customer__c,
                       Opportunity__r.Customer__r.Name,
                       Sales_Confirmation__c,
                       Sales_Confirmation__r.Total_Amount__c,
                       Payment_Type__c, 
                       Due_Date__c, 
                       Payment_Status__c, 
                       Amount__c,
                       Doc_Entry__c, 
                       Payment_Date__c,
                       Invoice__c
                FROM Payment__c
                LIMIT 10
            ];
            
            System.debug('Payments with Opportunity: ' + payments.size());
            for(Payment__c payment : payments) {
                System.debug('Payment: ' + payment.Name + 
                           ', Opportunity: ' + payment.Opportunity__c + 
                           ', Customer: ' + (payment.Opportunity__r != null && payment.Opportunity__r.Customer__r != null ? 
                                           payment.Opportunity__r.Customer__r.Name : 'null'));
            }
            
            return payments;
        } catch (Exception e) {
            System.debug('Error in getFinanceTransactions: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    @AuraEnabled
    public static void updatePaymentStatus(Id paymentId, String newStatus) {
        try {
            Payment__c payment = [
                SELECT Id, Payment_Status__c, Payment_Type__c
                FROM Payment__c
                WHERE Id = :paymentId
                LIMIT 1
            ];
            
            // Validate status transition
            if(!isValidStatusTransition(payment.Payment_Status__c, newStatus)) {
                throw new AuraHandledException('Invalid status transition');
            }
            
            // Update status
            payment.Payment_Status__c = newStatus;
            
            // If payment is marked as Applied, update payment date
            if(newStatus == 'Applied') {
                payment.Payment_Date__c = Date.today();
            }
            
            update payment;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    @AuraEnabled
    public static void updateTransactionReference(Id paymentId, String docEntry) {
        try {
            Payment__c payment = [
                SELECT Id, Doc_Entry__c
                FROM Payment__c
                WHERE Id = :paymentId
                LIMIT 1
            ];
            
            payment.Doc_Entry__c = docEntry;
            update payment;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    @AuraEnabled
    public static void updateDueDate(Id paymentId, Date newDueDate) {
        try {
            Payment__c payment = [
                SELECT Id, Due_Date__c, Payment_Type__c
                FROM Payment__c
                WHERE Id = :paymentId
                LIMIT 1
            ];
            
            if(payment.Payment_Type__c != 'Credit') {
                throw new AuraHandledException('Due date can only be set for credit payments');
            }
            
            payment.Due_Date__c = newDueDate;
            update payment;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    private static Boolean isValidStatusTransition(String currentStatus, String newStatus) {
        // Define valid status transitions
        Map<String, Set<String>> validTransitions = new Map<String, Set<String>>{
            'Received' => new Set<String>{'Applied', 'Overdue'},
            'Overdue' => new Set<String>{'Applied'},
            'Applied' => new Set<String>{} // No valid transitions from Applied
        };
        
        return validTransitions.containsKey(currentStatus) && 
               validTransitions.get(currentStatus).contains(newStatus);
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getPaymentTypeOptions() {
        List<Map<String, String>> options = new List<Map<String, String>>();
        Schema.DescribeFieldResult fieldResult = Payment__c.Payment_Type__c.getDescribe();
        for (Schema.PicklistEntry entry : fieldResult.getPicklistValues()) {
            if (entry.isActive()) {
                options.add(new Map<String, String>{
                    'label' => entry.getLabel(),
                    'value' => entry.getValue()
                });
            }
        }
        return options;
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getPaymentStatusOptions() {
        List<Map<String, String>> options = new List<Map<String, String>>();
        Schema.DescribeFieldResult fieldResult = Payment__c.Payment_Status__c.getDescribe();
        for (Schema.PicklistEntry entry : fieldResult.getPicklistValues()) {
            if (entry.isActive()) {
                options.add(new Map<String, String>{
                    'label' => entry.getLabel(),
                    'value' => entry.getValue()
                });
            }
        }
        return options;
    }
}