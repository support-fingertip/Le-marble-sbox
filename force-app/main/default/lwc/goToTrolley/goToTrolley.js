import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

export default class GoToTrolley extends NavigationMixin(LightningElement) {
    @api recordId; // This will receive the Deal ID from the Deal record page

    handleClick() {
        if (!this.recordId) {
            console.error('No Deal ID available');
            return;
        }

        console.log('Navigating with Deal ID:', this.recordId);
        
        // Navigate to Trolley page with Deal ID
        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: {
                url: `/lightning/n/Trolley?c__recordId=${this.recordId}`
            }
        });
    }

    get buttonClass() {
        return 'custom-trolley-button';
    }
}