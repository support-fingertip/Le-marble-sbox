import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

export default class GoToNewQuote extends NavigationMixin(LightningElement) {
    @api recordId; 

    handleClick() {
        if (!this.recordId) {
            console.error('No Opp ID available');
            return;
        }

        console.log('Navigating with Opp ID:', this.recordId);
        
        // Navigate to Trolley page with opp ID
        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: {
                url: `/lightning/n/New_Quote_From_Opportunity?c__recordId=${this.recordId}`
            }
        });
    }

    get buttonClass() {
        return 'custom-trolley-button';
    }
}