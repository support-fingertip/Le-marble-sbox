import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import sendOrderToSAPFromButton from '@salesforce/apex/sapIntegration.sendOrderToSAPFromButton';

export default class SendOrderToSAPButton extends LightningElement {
    @api recordId;
    @track isLoading = false;
    @track isButtonVisible = true;

    handleSendToSAP() {
        this.isLoading = true;
        this.isButtonVisible = false;
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