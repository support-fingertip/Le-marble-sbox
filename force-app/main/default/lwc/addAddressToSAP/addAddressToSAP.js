import { LightningElement, api } from 'lwc';
import addShipToAddressToSAP from '@salesforce/apex/sapIntegration.addShipToAddressToSAP';

export default class AddAddressToSAP extends LightningElement {
    @api recordId;
    isLoading = false;
    successMessage;
    errorMessage;

    handleClick() {
        this.isLoading = true;
        this.successMessage = undefined;
        this.errorMessage = undefined;

        addShipToAddressToSAP({ opportunityId: this.recordId })
            .then(result => {
                this.successMessage = result;
                this.isLoading = false;
            })
            .catch(error => {
                this.errorMessage =
                    error?.body?.message || error?.message || 'Failed to add address to SAP.';
                this.isLoading = false;
            });
    }
}