import { LightningElement, api } from 'lwc';
import ShowOutstanding from '@salesforce/apex/sapIntegration.getCustOutstanding';

export default class FetchAccountValue extends LightningElement {
    @api recordId; // Account Id
    result;
    errorMessage;

    get hasResult() {
        return this.result !== undefined && this.result !== null;
    }

    handleClick() {
        ShowOutstanding({ accountId: this.recordId })
            .then(res => {
                this.result = res;
                this.errorMessage = undefined;
            })
            .catch(err => {
                this.result = undefined;
                this.errorMessage =
                    err?.body?.message || err?.message || 'Unable to fetch outstanding value.';
                console.error(err);
            });
    }
}