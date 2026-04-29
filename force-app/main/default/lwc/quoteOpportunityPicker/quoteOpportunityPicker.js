import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getOpenOpportunitiesForAccount from '@salesforce/apex/NewQuoteController.getOpenOpportunitiesForAccount';

export default class QuoteOpportunityPicker extends LightningElement {

    @api accountId;

    @track opportunities = [];
    @track isLoading = false;
    @track loaded = false;
    @track showNewOpportunityForm = false;

    _wiredResult;

    @wire(getOpenOpportunitiesForAccount, { accountId: '$accountId' })
    wiredOpps(result) {
        this._wiredResult = result;
        const { data, error } = result;
        if (data) {
            this.opportunities = data;
            this.loaded = true;
        } else if (error) {
            this.opportunities = [];
            this.loaded = true;
            this.toast('Error', this.extractError(error), 'error');
        }
    }

    get hasOpportunities() {
        return this.opportunities && this.opportunities.length > 0;
    }

    handleOpportunityClick(event) {
        const id = event.currentTarget.dataset.id;
        const name = event.currentTarget.dataset.name;
        this.dispatchSelected(id, name);
    }

    handleSkip() {
        this.dispatchSelected(null, null);
    }

    handleShowNewOppForm() {
        this.showNewOpportunityForm = true;
    }

    handleCancelNewOpp() {
        this.showNewOpportunityForm = false;
    }

    handleOpportunityCreated(event) {
        const newId = event.detail.id;
        const fields = event.detail.fields || {};
        const name = (fields.Name && fields.Name.value) ? fields.Name.value : '';
        this.toast('Success', 'Opportunity created.', 'success');
        this.showNewOpportunityForm = false;
        this.dispatchSelected(newId, name);
    }

    handleOpportunityCreateError(event) {
        const msg = (event && event.detail && event.detail.message) || 'Failed to create opportunity.';
        this.toast('Error', msg, 'error');
    }

    dispatchSelected(opportunityId, opportunityName) {
        this.dispatchEvent(new CustomEvent('oppselected', {
            detail: { opportunityId, opportunityName }
        }));
    }

    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    extractError(error) {
        if (!error) return 'Unknown error';
        if (error.body && error.body.message) return error.body.message;
        if (error.message) return error.message;
        return JSON.stringify(error);
    }
}
