import { LightningElement, api } from 'lwc';
import ShowOutstanding from '@salesforce/apex/sapIntegration.getCustOutstanding';

export default class FetchAccountValue extends LightningElement {
    @api recordId; // Account Id
    result;

    handleClick() {
        ShowOutstanding({ accountId: this.recordId })
            .then(res => {
                this.result = res;
            })
            .catch(err => {
                console.error(err);
            });
    }
}