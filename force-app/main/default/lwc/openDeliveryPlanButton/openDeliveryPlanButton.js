import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

export default class OpenDeliveryPlanButton extends NavigationMixin(LightningElement) {
    @api recordId;

    handleOpenDeliveryPlan() {
        this[NavigationMixin.Navigate]({
            type: 'standard__navItemPage',
            attributes: {
                apiName: 'Sales_Delivery_Scheduler'
            },
            state: {
                c__orderId: this.recordId
            }
        });
    }
}