import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

export default class GoToEditQuote extends NavigationMixin(LightningElement) {
    @api recordId; // This will receive the Quote ID from the Quote record page

    handleClick() {
        if (!this.recordId) {
            console.error('No Quote ID available');
            return;
        }

        console.log('Navigating with Quote ID:', this.recordId);
        // Navigate to EditQuote page with Quote ID (same pattern as goToNewQuote)
        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: {
                url: `/lightning/n/Edit_Quote?c__recordId=${this.recordId}`
            }
        });
    }

    get buttonClass() {
        return 'custom-edit-quote-button';
    }
}