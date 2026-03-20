import { LightningElement, api, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';
import { getRecord } from 'lightning/uiRecordApi';
import convertToOpportunity from '@salesforce/apex/CustomerConversionController.convertToOpportunity';

export default class ConvertToOpportunity extends NavigationMixin(LightningElement) {
    @api recordId;
    isLoading = false;

    handleConvert() {
        this.isLoading = true;
        convertToOpportunity({ customerId: this.recordId })
            .then(result => {
                if (result && result.dealId) {
                    this.dispatchEvent(
                        new ShowToastEvent({
                            title: 'Success',
                            message: 'Customer converted successfully',
                            variant: 'success'
                        })
                    );
                    // Navigate to the new Deal record
                    this[NavigationMixin.Navigate]({
                        type: 'standard__recordPage',
                        attributes: {
                            recordId: result.dealId,
                            objectApiName: 'Deals__c',
                            actionName: 'view'
                        }
                    });
                } else {
                    throw new Error('No Deal ID returned from conversion');
                }
            })
            .catch(error => {
                let errorMessage = 'Unknown error occurred';
                if (error.body && error.body.message) {
                    errorMessage = error.body.message;
                } else if (error.message) {
                    errorMessage = error.message;
                } else if (typeof error === 'string') {
                    errorMessage = error;
                }
                
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error',
                        message: errorMessage,
                        variant: 'error'
                    })
                );
            })
            .finally(() => {
                this.isLoading = false;
            });
    }
}