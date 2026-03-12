import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import sendOrderToSAPFromButton from '@salesforce/apex/sapIntegration.sendOrderToSAPFromButton';

export default class SendOrderToSAPButton extends LightningElement {
    @api recordId;
    isLoading = false;

    handleSendToSAP() {
        this.isLoading = true;
        sendOrderToSAPFromButton({ orderId: this.recordId })
            .then((result) => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Success',
                        message: result,
                        variant: 'success'
                    })
                );
            })
            .catch((error) => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error',
                        message: error.body ? error.body.message : 'An error occurred',
                        variant: 'error'
                    })
                );
            })
            .finally(() => {
                this.isLoading = false;
            });
    }
}