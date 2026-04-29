import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import getOpenOpportunitiesForAccount from '@salesforce/apex/NewQuoteController.getOpenOpportunitiesForAccount';

const DEFAULT_STAGE = 'Open';
const DEFAULT_CLOSE_DAYS = 30;
const ACCOUNT_FIELDS = [
    'Account.Name',
    'Account.ShippingStreet',
    'Account.ShippingCity',
    'Account.ShippingState',
    'Account.ShippingPostalCode',
    'Account.ShippingCountry'
];

export default class QuoteOpportunityPicker extends LightningElement {

    @api accountId;

    @track opportunities = [];
    @track loaded = false;
    @track showNewOpportunityForm = false;
    @track sameAsAccount = false;

    @track addressLine1 = '';
    @track addressLine2 = '';
    @track addressLine3 = '';
    @track district = '';
    @track pincode = '';
    @track state = '';
    @track country = '';
    @track branchLocation = '';

    _wiredAccountResult;

    @wire(getOpenOpportunitiesForAccount, { accountId: '$accountId' })
    wiredOpps({ data, error }) {
        if (data) {
            this.opportunities = data;
            this.loaded = true;
        } else if (error) {
            this.opportunities = [];
            this.loaded = true;
            this.toast('Error', this.extractError(error), 'error');
        }
    }

    @wire(getRecord, { recordId: '$accountId', fields: ACCOUNT_FIELDS })
    wiredAccount(result) {
        this._wiredAccountResult = result;
    }

    get hasOpportunities() {
        return this.opportunities && this.opportunities.length > 0;
    }

    get accountName() {
        const data = this._wiredAccountResult && this._wiredAccountResult.data;
        return data ? getFieldValue(data, 'Account.Name') : '';
    }

    get defaultCloseDate() {
        const d = new Date();
        d.setDate(d.getDate() + DEFAULT_CLOSE_DAYS);
        const y = d.getFullYear();
        const m = String(d.getMonth() + 1).padStart(2, '0');
        const day = String(d.getDate()).padStart(2, '0');
        return `${y}-${m}-${day}`;
    }

    handleOpportunityClick(event) {
        const id = event.currentTarget.dataset.id;
        const name = event.currentTarget.dataset.name;
        this.dispatchSelected(id, name);
    }

    handleShowNewOppForm() {
        this.showNewOpportunityForm = true;
    }

    handleCancelNewOpp() {
        this.showNewOpportunityForm = false;
        this.resetAddress();
    }

    handleSameAsAccount(event) {
        this.sameAsAccount = event.target.checked;
        if (this.sameAsAccount) {
            this.copyAddressFromAccount();
        }
    }

    handleFieldChange(event) {
        const field = event.target.dataset.field;
        if (!field) return;
        this[field] = event.detail ? event.detail.value : event.target.value;
        // If the user edits any address field after using "same as account",
        // clear the checkbox so the UI matches the data.
        if (this.sameAsAccount && field !== 'branchLocation') {
            this.sameAsAccount = false;
        }
    }

    copyAddressFromAccount() {
        const data = this._wiredAccountResult && this._wiredAccountResult.data;
        if (!data) {
            this.toast('No address', 'This account has no shipping address yet.', 'warning');
            this.sameAsAccount = false;
            return;
        }
        const street = getFieldValue(data, 'Account.ShippingStreet') || '';
        const streetLines = street.split('\n');
        this.addressLine1 = streetLines[0] || '';
        this.addressLine2 = streetLines[1] || '';
        this.addressLine3 = streetLines[2] || '';
        this.district = getFieldValue(data, 'Account.ShippingCity') || '';
        this.state = getFieldValue(data, 'Account.ShippingState') || '';
        this.pincode = getFieldValue(data, 'Account.ShippingPostalCode') || '';
        this.country = getFieldValue(data, 'Account.ShippingCountry') || '';
    }

    resetAddress() {
        this.sameAsAccount = false;
        this.addressLine1 = '';
        this.addressLine2 = '';
        this.addressLine3 = '';
        this.district = '';
        this.pincode = '';
        this.state = '';
        this.country = '';
        this.branchLocation = '';
    }

    handleOpportunitySubmit(event) {
        event.preventDefault();
        const fields = event.detail.fields || {};
        fields.AccountId = this.accountId;
        fields.StageName = DEFAULT_STAGE;
        fields.CloseDate = this.defaultCloseDate;
        fields.AddressLine1__c = this.addressLine1;
        fields.AddressLine2__c = this.addressLine2;
        fields.AddressLine3__c = this.addressLine3;
        fields.District__c = this.district;
        fields.Pin_Code__c = this.pincode;
        fields.State__c = this.state;
        fields.Country__c = this.country;
        fields.Branch_Location__c = this.branchLocation;
        fields.Same_as_Account_Ship_Address__c = this.sameAsAccount;
        this.template.querySelector('lightning-record-edit-form').submit(fields);
    }

    handleOpportunityCreated(event) {
        const newId = event.detail.id;
        this.toast('Success', 'Opportunity created.', 'success');
        this.showNewOpportunityForm = false;
        this.dispatchSelected(newId, '');
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
