import { LightningElement, api, track } from 'lwc';
import getPendingQuotes from '@salesforce/apex/NewQuoteController.getPendingQuotes';

export default class QuoteSession extends LightningElement {

    // Opportunity (or customer) id - used to look up an existing pending quote
    // and to drive c-new-quote-from-opp when there isn't one.
    @api recordId;

    // Optional explicit quote id. When set, the wrapper goes straight to
    // c-edit-quote and skips the pending-quote lookup. Lets a parent force
    // edit mode for a known quote without round-tripping Apex.
    @api quoteId;

    @track resolvedQuoteId = null;
    @track loaded = false;

    connectedCallback() {
        if (this.quoteId) {
            this.resolvedQuoteId = this.quoteId;
            this.loaded = true;
            return;
        }
        if (!this.recordId) {
            this.loaded = true;
            return;
        }
        getPendingQuotes({ oppId: this.recordId })
            .then(result => {
                if (result && result.length > 0) {
                    this.resolvedQuoteId = result[0].Id;
                }
                this.loaded = true;
            })
            .catch(err => {
                // eslint-disable-next-line no-console
                console.error('Pending quote check failed', err);
                this.loaded = true;
            });
    }

    get isEditMode() {
        return this.loaded && !!this.resolvedQuoteId;
    }

    get isNewMode() {
        return this.loaded && !this.resolvedQuoteId && !!this.recordId;
    }

    get isLoading() {
        return !this.loaded;
    }
}
